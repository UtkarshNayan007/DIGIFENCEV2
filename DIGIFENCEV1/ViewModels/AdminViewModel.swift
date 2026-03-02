//
//  AdminViewModel.swift
//  DIGIFENCEV1
//
//  Admin-only operations: create/edit events with polygon geofence,
//  dashboard guest tracking, event lifecycle management, and thumbnail uploading.
//

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import PhotosUI
import MapKit

@MainActor
final class AdminViewModel: ObservableObject {
    
    @Published var title = ""
    @Published var description = ""
    @Published var latitude: Double = 37.7749
    @Published var longitude: Double = -122.4194
    @Published var polygonPoints: [CLLocationCoordinate2D] = []
    
    // Search
    @Published var searchText = ""
    @Published var searchResults: [MKMapItem] = []
    
    @Published var capacity: Int = 100
    @Published var ticketPrice: Double = 0.0
    @Published var invitationURL: String = ""
    @Published var isActive = true
    @Published var startsAt = Date()
    @Published var endsAt = Date().addingTimeInterval(3600 * 8) // +8 hours
    
    // Image selection
    @Published var selectedImageItem: PhotosPickerItem? {
        didSet { Task { await loadSelectedImage() } }
    }
    @Published var selectedImageData: Data?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSuccess = false
    @Published var successMessage = ""
    
    @Published var myEvents: [Event] = []
    @Published var allAdminEvents: [Event] = [] // For dashboard
    
    // Dashboard: tickets per event
    @Published var eventTickets: [String: [Ticket]] = [:]
    @Published var eventAttendanceLogs: [String: [AttendanceLog]] = [:]
    
    private var listener: ListenerRegistration?
    private var ticketListeners: [String: ListenerRegistration] = [:]
    private var locationCancellables = Set<AnyCancellable>()
    private let firebase = FirebaseManager.shared
    
    // MARK: - Image Selection
    
    private func loadSelectedImage() async {
        guard let item = selectedImageItem else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                // simple validation to ensure it's an image
                if let _ = UIImage(data: data) {
                    selectedImageData = data
                }
            }
        } catch {
            print("Failed to load image: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Search & Location
    
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        // Prefer results near current map view
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        request.region = MKCoordinateRegion(center: center, latitudinalMeters: 5000, longitudinalMeters: 5000)
        
        let search = MKLocalSearch(request: request)
        search.start { (response, error) in
            guard let response = response else {
                print("Search error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            self.searchResults = response.mapItems
        }
    }
    
    func centerOnUserLocation(cameraPosition: Binding<MapCameraPosition>) {
        let lm = LocationManager.shared
        
        // Request permission if not granted
        if !lm.hasLocationPermission {
            lm.requestWhenInUseAuthorization()
        }
        
        // Trigger a fresh GPS request
        lm.requestCurrentLocation()
        
        // If we already have a location, use it immediately
        if let location = lm.currentLocation {
            applyLocation(location.coordinate, cameraPosition: cameraPosition)
            return
        }
        
        // Otherwise, observe for the first location update
        var cancellable: AnyCancellable?
        cancellable = lm.$currentLocation
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.applyLocation(location.coordinate, cameraPosition: cameraPosition)
                cancellable?.cancel()
            }
        
        // Store cancellable to keep subscription alive
        if let c = cancellable {
            locationCancellables.insert(c)
        }
    }
    
    private func applyLocation(_ coordinate: CLLocationCoordinate2D, cameraPosition: Binding<MapCameraPosition>) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        cameraPosition.wrappedValue = .region(MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        ))
    }
    
    // MARK: - Polygon Drawing
    
    func addPolygonPoint(_ coordinate: CLLocationCoordinate2D) {
        polygonPoints.append(coordinate)
    }
    
    func removeLastPolygonPoint() {
        guard !polygonPoints.isEmpty else { return }
        polygonPoints.removeLast()
    }
    
    func clearPolygonPoints() {
        polygonPoints.removeAll()
    }
    
    var isPolygonValid: Bool {
        polygonPoints.count >= 3 && !isPolygonSelfIntersecting
    }
    
    var isPolygonSelfIntersecting: Bool {
        guard polygonPoints.count > 3 else { return false }
        
        // Check all pairs of segments for intersection
        for i in 0..<polygonPoints.count {
            for j in (i + 1)..<polygonPoints.count {
                let p1 = polygonPoints[i]
                let p2 = polygonPoints[(i + 1) % polygonPoints.count]
                let p3 = polygonPoints[j]
                let p4 = polygonPoints[(j + 1) % polygonPoints.count]
                
                // Skip adjacent segments (they always share a vertex)
                if i == j || i == (j + 1) % polygonPoints.count || (i + 1) % polygonPoints.count == j {
                    continue
                }
                
                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    return true
                }
            }
        }
        return false
    }
    
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D, p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        let x1 = p1.longitude, y1 = p1.latitude
        let x2 = p2.longitude, y2 = p2.latitude
        let x3 = p3.longitude, y3 = p3.latitude
        let x4 = p4.longitude, y4 = p4.latitude
        
        let denom = (y4-y3)*(x2-x1) - (x4-x3)*(y2-y1)
        if denom == 0 { return false } // Parallel
        
        let ua = ((x4-x3)*(y1-y3) - (y4-y3)*(x1-x3)) / denom
        let ub = ((x2-x1)*(y1-y3) - (y2-y1)*(x1-x3)) / denom
        
        return ua > 0 && ua < 1 && ub > 0 && ub < 1
    }
    
    // MARK: - Create Event
    
    func createEvent() async {
        guard validate() else { return }
        guard let uid = firebase.currentUser?.uid else {
            errorMessage = "You must be signed in."
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            let polygonData = polygonPoints.map { coord in
                ["lat": coord.latitude, "lng": coord.longitude]
            }
            
            var eventData: [String: Any] = [
                "title": title,
                "description": description,
                "polygonCoordinates": polygonData,
                "organizerId": uid,
                "capacity": capacity,
                "ticketsSold": 0,
                "startsAt": Timestamp(date: startsAt),
                "endsAt": Timestamp(date: endsAt),
                "isActive": isActive,
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            if ticketPrice > 0 {
                eventData["ticketPrice"] = ticketPrice
            }
            
            if !invitationURL.trimmingCharacters(in: .whitespaces).isEmpty {
                eventData["invitationURL"] = invitationURL
            }
            
            // 1. Create document
            let docRef = try await firebase.eventsCollection.addDocument(data: eventData)
            
            // 2. Upload image if selected
            if let imageData = selectedImageData {
                let thumbnailURL = try await FirebaseStorageManager.shared.uploadEventThumbnail(eventId: docRef.documentID, imageData: imageData)
                // 3. Update doc with URL
                try await docRef.updateData(["thumbnailURL": thumbnailURL])
            }
            
            successMessage = "Event '\(title)' created successfully!"
            showSuccess = true
            resetForm()
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Listen to My Events
    
    func startListeningToMyEvents() {
        guard let uid = firebase.currentUser?.uid else { return }
        
        listener = firebase.eventsCollection
            .whereField("organizerId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                let events = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Event.self)
                } ?? []
                self.myEvents = events
                self.allAdminEvents = events
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        for (_, listener) in ticketListeners {
            listener.remove()
        }
        ticketListeners.removeAll()
    }
    
    // MARK: - Dashboard: Live Guest Tracking
    
    func startListeningToTickets(for eventId: String) {
        ticketListeners[eventId]?.remove()
        
        let ticketListener = firebase.ticketsCollection
            .whereField("eventId", isEqualTo: eventId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ Ticket listener error: \(error.localizedDescription)")
                    return
                }
                let tickets = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Ticket.self)
                } ?? []
                self.eventTickets[eventId] = tickets
            }
        ticketListeners[eventId] = ticketListener
    }
    
    func stopListeningToTickets(for eventId: String) {
        ticketListeners[eventId]?.remove()
        ticketListeners.removeValue(forKey: eventId)
    }
    
    func fetchAttendanceLogs(for eventId: String) async {
        do {
            let ticketsSnap = try await firebase.ticketsCollection
                .whereField("eventId", isEqualTo: eventId)
                .getDocuments()
            
            let ticketIds = ticketsSnap.documents.map { $0.documentID }
            var allLogs: [AttendanceLog] = []
            
            for chunk in ticketIds.chunked(into: 10) {
                let logsSnap = try await Firestore.firestore()
                    .collection("attendance_logs")
                    .whereField("ticketId", in: chunk)
                    .order(by: "timestamp", descending: true)
                    .limit(to: 100)
                    .getDocuments()
                
                let logs = logsSnap.documents.compactMap { doc in
                    try? doc.data(as: AttendanceLog.self)
                }
                allLogs.append(contentsOf: logs)
            }
            
            eventAttendanceLogs[eventId] = allLogs.sorted {
                ($0.timestamp?.dateValue() ?? Date.distantPast) > ($1.timestamp?.dateValue() ?? Date.distantPast)
            }
        } catch {
            print("❌ Fetch attendance logs error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Dashboard Computed Properties
    
    func activeGuestCount(for eventId: String) -> Int { eventTickets[eventId]?.filter { $0.status == .active }.count ?? 0 }
    func pendingCount(for eventId: String) -> Int { eventTickets[eventId]?.filter { $0.status == .pending }.count ?? 0 }
    func expiredCount(for eventId: String) -> Int { eventTickets[eventId]?.filter { $0.status == .expired }.count ?? 0 }
    func totalTickets(for eventId: String) -> Int { eventTickets[eventId]?.count ?? 0 }
    func insideFenceCount(for eventId: String) -> Int { eventTickets[eventId]?.filter { $0.insideFence }.count ?? 0 }
    
    // MARK: - Toggle Event Active
    
    func toggleEventActive(event: Event) async {
        guard let eventId = event.id else { return }
        do {
            try await firebase.eventsCollection.document(eventId).updateData([
                "isActive": !event.isActive
            ])
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - Validation
    
    private func validate() -> Bool {
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Event title is required."
            showError = true
            return false
        }
        if polygonPoints.count < 3 {
            errorMessage = "Polygon geofence requires at least 3 points."
            showError = true
            return false
        }
        if capacity < 1 {
            errorMessage = "Capacity must be at least 1."
            showError = true
            return false
        }
        return true
    }
    
    private func resetForm() {
        title = ""
        description = ""
        polygonPoints.removeAll()
        capacity = 100
        ticketPrice = 0.0
        invitationURL = ""
        isActive = true
        selectedImageItem = nil
        selectedImageData = nil
    }
    
    deinit {
        listener?.remove()
        for (_, l) in ticketListeners { l.remove() }
    }
}

// MARK: - AttendanceLog Model

struct AttendanceLog: Codable, Identifiable {
    @DocumentID var id: String?
    let ticketId: String
    let type: String
    var detail: [String: AnyCodable]?
    var timestamp: Timestamp?
    
    var typeIcon: String {
        switch type {
        case "activated": return "checkmark.circle.fill"
        case "exited": return "arrow.right.circle.fill"
        case "expired": return "xmark.circle.fill"
        default: return "circle"
        }
    }
    
    var typeColor: String {
        switch type {
        case "activated": return "green"
        case "exited": return "orange"
        case "expired": return "red"
        default: return "gray"
        }
    }
}

struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) { value = bool }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let string = try? container.decode(String.self) { value = string }
        else { value = "" }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let bool = value as? Bool { try container.encode(bool) }
        else if let int = value as? Int { try container.encode(int) }
        else if let double = value as? Double { try container.encode(double) }
        else if let string = value as? String { try container.encode(string) }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
