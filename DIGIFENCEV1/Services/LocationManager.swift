//
//  LocationManager.swift
//  DIGIFENCEV1
//
//  CLLocationManager delegate handling polygon-based geofence monitoring,
//  exit hysteresis, and 3-minute grace timer. Integrates with
//  PolygonGeofenceManager for polygon-based entry/exit detection.
//

import Foundation
import Combine
import SwiftUI
import CoreLocation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isInsideGeofence: [String: Bool] = [:] // eventId -> isInside
    @Published var locationError: String?
    
    /// Grace timers keyed by ticketId
    private var graceTimers: [String: Timer] = [:]
    
    /// Exit confirmation tracking (hysteresis)
    private var exitConfirmations: [String: Int] = [:] // eventId -> count of consecutive exits
    private let requiredExitConfirmations = 2
    
    /// Grace period duration (3 minutes)
    private let gracePeriodSeconds: TimeInterval = 180
    
    /// Callbacks
    var onEnterRegion: ((String) -> Void)? // eventId
    var onGracePeriodExpired: ((String, String) -> Void)? // eventId, ticketId
    var onExitWarning: ((String, String) -> Void)? // eventId, ticketId
    
    /// Persisted monitored event IDs for re-registration on relaunch
    private let monitoredEventsKey = "DigiFence_MonitoredEventIDs"
    
    /// Reference to PolygonGeofenceManager for polygon-based operations
    private let polygonManager = PolygonGeofenceManager.shared
    
    /// Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.showsBackgroundLocationIndicator = true
        authorizationStatus = locationManager.authorizationStatus
        enableBackgroundUpdatesIfAuthorized()
        syncPolygonGeofenceState()
    }
    
    /// Only enable background location updates when "Always" permission is granted
    private func enableBackgroundUpdatesIfAuthorized() {
        if locationManager.authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
        }
    }
    
    /// Subscribe to PolygonGeofenceManager's isInsideGeofence state
    private func syncPolygonGeofenceState() {
        polygonManager.$isInsideGeofence
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isInsideGeofence = state
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authorization
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    var hasAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }
    
    var hasLocationPermission: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }
    
    // MARK: - Current Location
    
    func requestCurrentLocation() {
        locationManager.requestLocation()
    }
    
    // MARK: - Polygon Geofence Monitoring
    
    /// Start monitoring a polygon geofence for an event.
    ///
    /// Delegates to PolygonGeofenceManager for polygon-based entry/exit
    /// detection with hysteresis and grace timers.
    func startPolygonMonitoring(for event: Event, ticketId: String) {
        guard event.polygonCoordinates.count >= 3 else {
            locationError = "Event polygon must have at least 3 vertices."
            return
        }
        
        guard let eventId = event.id else {
            locationError = "Event has no ID."
            return
        }
        
        polygonManager.startMonitoring(
            eventId: eventId,
            ticketId: ticketId,
            polygon: event.polygonCLCoordinates
        )
        
        // Wire callbacks
        polygonManager.onEnterPolygon = { [weak self] eventId in
            self?.onEnterRegion?(eventId)
        }
        polygonManager.onExitWarning = { [weak self] eventId, ticketId in
            self?.onExitWarning?(eventId, ticketId)
        }
        polygonManager.onGracePeriodExpired = { [weak self] eventId, ticketId in
            self?.onGracePeriodExpired?(eventId, ticketId)
        }
        
        // Persist monitored event IDs
        var monitoredIds = getMonitoredEventIds()
        let key = "\(eventId):\(ticketId)"
        if !monitoredIds.contains(key) {
            monitoredIds.append(key)
            saveMonitoredEventIds(monitoredIds)
        }
    }
    
    func stopMonitoring(for eventId: String, ticketId: String) {
        polygonManager.stopMonitoring(eventId: eventId)
        
        // Remove from persisted list
        var monitoredIds = getMonitoredEventIds()
        monitoredIds.removeAll { $0 == "\(eventId):\(ticketId)" }
        saveMonitoredEventIds(monitoredIds)
    }
    
    func stopAllMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        polygonManager.stopAllMonitoring()
        graceTimers.values.forEach { $0.invalidate() }
        graceTimers.removeAll()
        exitConfirmations.removeAll()
        saveMonitoredEventIds([])
    }
    
    // MARK: - Grace Timer Management
    
    func startGraceTimer(eventId: String, ticketId: String) {
        polygonManager.startGraceTimer(eventId: eventId, ticketId: ticketId)
    }
    
    func cancelGraceTimer(for ticketId: String) {
        polygonManager.cancelGraceTimer(for: ticketId)
    }
    
    var hasActiveGraceTimer: Bool {
        polygonManager.hasActiveGraceTimer
    }
    
    /// Whether a grace period countdown is currently active.
    var isGracePeriodActive: Bool {
        polygonManager.isGracePeriodActive
    }
    
    /// Remaining seconds on the grace period countdown.
    var gracePeriodRemainingSeconds: Int {
        polygonManager.gracePeriodRemainingSeconds
    }
    
    // MARK: - Persisted Region IDs
    
    private func getMonitoredEventIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: monitoredEventsKey) ?? []
    }
    
    private func saveMonitoredEventIds(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: monitoredEventsKey)
    }
    
    /// Re-register polygon regions on app launch.
    func reRegisterRegionsIfNeeded(events: [Event], tickets: [Ticket]) {
        let monitoredIds = getMonitoredEventIds()
        for idPair in monitoredIds {
            let parts = idPair.split(separator: ":")
            guard parts.count == 2 else { continue }
            let eventId = String(parts[0])
            let ticketId = String(parts[1])
            
            if let event = events.first(where: { $0.id == eventId }),
               let ticket = tickets.first(where: { $0.id == ticketId }),
               ticket.status != .expired {
                startPolygonMonitoring(for: event, ticketId: ticketId)
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            self.enableBackgroundUpdatesIfAuthorized()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            self.currentLocation = locations.last
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Logged for diagnostics; polygon monitoring does not depend on CLRegion
    }
    
    // MARK: - Haversine Distance (backward compatibility)
    
    static func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        Haversine.distance(from: from, to: to)
    }
}
