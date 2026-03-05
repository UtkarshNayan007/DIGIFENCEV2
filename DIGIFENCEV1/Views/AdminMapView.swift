//
//  AdminMapView.swift
//  DIGIFENCEV1
//
//  Admin creates events by tapping polygon points on a map.
//  Added UI for event thumbnails.
//

import SwiftUI
import MapKit
import PhotosUI

struct AdminMapView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
    )
    @State private var showCreateSheet = false
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.4))
                    
                    TextField("", text: $viewModel.searchText, prompt: Text("Search venue/area...").foregroundColor(.white.opacity(0.3)))
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .onChange(of: viewModel.searchText) { _ in
                            viewModel.performSearch()
                        }
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                ZStack(alignment: .top) {
                    // Map
                    Map(position: $cameraPosition, interactionModes: .all) {
                        // Existing events — polygon overlays
                        ForEach(viewModel.myEvents) { event in
                            Annotation(event.title, coordinate: event.coordinate) {
                                VStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.cyan)
                                    Text(event.title)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Capsule())
                                }
                            }
                            
                            MapPolygon(coordinates: event.polygonCLCoordinates)
                                .foregroundStyle(.cyan.opacity(0.1))
                                .stroke(.cyan.opacity(0.4), lineWidth: 1)
                        }
                        
                        // New polygon points being placed
                        ForEach(Array(viewModel.polygonPoints.enumerated()), id: \.offset) { idx, point in
                            Annotation("P\(idx + 1)", coordinate: point) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 14, height: 14)
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(width: 14, height: 14)
                                    Text("\(idx + 1)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        // Live polygon preview
                        if viewModel.isPolygonValid {
                            MapPolygon(coordinates: viewModel.polygonPoints)
                                .foregroundStyle(.green.opacity(0.15))
                                .stroke(.green.opacity(0.5), lineWidth: 2)
                        } else if viewModel.polygonPoints.count == 2 {
                            MapPolyline(coordinates: viewModel.polygonPoints)
                                .stroke(.green.opacity(0.5), lineWidth: 2)
                        }
                        
                        // Center crosshair marker
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: viewModel.latitude, longitude: viewModel.longitude)) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .onMapCameraChange { context in
                        viewModel.latitude = context.region.center.latitude
                        viewModel.longitude = context.region.center.longitude
                    }
                    .frame(maxHeight: .infinity)
                    
                    // Search Results Dropdown
                    if !viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(viewModel.searchResults, id: \.self) { item in
                                    Button(action: {
                                        let coord = item.placemark.coordinate
                                        cameraPosition = .region(MKCoordinateRegion(center: coord, latitudinalMeters: 1000, longitudinalMeters: 1000))
                                        viewModel.searchText = ""
                                        viewModel.searchResults = []
                                        viewModel.latitude = coord.latitude
                                        viewModel.longitude = coord.longitude
                                    }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name ?? "Unknown Venue")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                            if let address = item.placemark.title {
                                                Text(address)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.5))
                                                    .lineLimit(1)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.black.opacity(0.85))
                                    }
                                    Divider().background(Color.white.opacity(0.1))
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .shadow(radius: 10)
                    }
                    
                    // Current Location Button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { viewModel.centerOnUserLocation(cameraPosition: $cameraPosition) }) {
                                Image(systemName: "location.fill")
                                    .padding()
                                    .background(Color.cyan)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                            }
                            .padding(20)
                        }
                    }
                }
                
                // Bottom panel
                VStack(spacing: 12) {
                    // Polygon point controls
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.addPolygonPoint(
                                CLLocationCoordinate2D(
                                    latitude: viewModel.latitude,
                                    longitude: viewModel.longitude
                                )
                            )
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                Text("Drop Point")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background(Color.green.opacity(0.8))
                            .clipShape(Capsule())
                        }
                        
                        Button(action: { viewModel.removeLastPolygonPoint() }) {
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundColor(.orange)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .disabled(viewModel.polygonPoints.isEmpty)
                        
                        Button(action: { viewModel.clearPolygonPoints() }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .disabled(viewModel.polygonPoints.isEmpty)
                        
                        Spacer()
                        
                        Text("\(viewModel.polygonPoints.count) pts")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(viewModel.isPolygonValid ? .green : .orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    
                    if !viewModel.isPolygonValid && !viewModel.polygonPoints.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 11))
                            Text(viewModel.isPolygonSelfIntersecting ? "Lines cannot cross (self-intersecting)" : "Need at least 3 points for a valid polygon")
                                .font(.system(size: 11))
                                .foregroundColor(.orange.opacity(0.8))
                        }
                    }
                    
                    Text(String(format: "📍 %.5f, %.5f", viewModel.latitude, viewModel.longitude))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Button(action: { showCreateSheet = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Event")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: viewModel.isPolygonValid ? [.green, .cyan] : [.gray, .gray.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!viewModel.isPolygonValid)
                }
                .padding(16)
                .background(
                    Color(red: 0.08, green: 0.08, blue: 0.16)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .navigationTitle("Admin: Events")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { 
            viewModel.startListeningToMyEvents() 
            // Auto-center on user location when tab appears
            viewModel.centerOnUserLocation(cameraPosition: $cameraPosition)
        }
        .onDisappear { viewModel.stopListening() }
        .sheet(isPresented: $showCreateSheet) {
            CreateEventSheet(viewModel: viewModel)
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK") {}
        } message: {
            Text(viewModel.successMessage)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Create Event Sheet

struct CreateEventSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmation = false
    
    private var confirmationMessage: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var lines: [String] = []
        lines.append("Title: \(viewModel.title)")
        if !viewModel.description.isEmpty {
            lines.append("Description: \(viewModel.description)")
        }
        lines.append("Capacity: \(viewModel.capacity)")
        lines.append("Polygon Points: \(viewModel.polygonPoints.count)")
        lines.append("Starts: \(dateFormatter.string(from: viewModel.startsAt))")
        lines.append("Ends: \(dateFormatter.string(from: viewModel.endsAt))")
        if viewModel.ticketPrice > 0 {
            lines.append("Price: ₹\(String(format: "%.2f", viewModel.ticketPrice))")
        }
        return lines.joined(separator: "\n")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.12)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Image Picker
                        PhotosPicker(selection: $viewModel.selectedImageItem, matching: .images, photoLibrary: .shared()) {
                            if let imageData = viewModel.selectedImageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .overlay(
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Spacer()
                                                Image(systemName: "photo.badge.plus")
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                                    .padding(8)
                                            }
                                        }
                                    )
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                        .frame(height: 140)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                        )
                                    
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 32))
                                            .foregroundColor(.cyan)
                                        Text("Add Event Photo")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                            }
                        }
                        
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Event Title")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            TextField("", text: $viewModel.title, prompt: Text("Enter event title").foregroundColor(.white.opacity(0.3)))
                                .foregroundColor(.white)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            TextField("", text: $viewModel.description, prompt: Text("Enter description").foregroundColor(.white.opacity(0.3)), axis: .vertical)
                                .foregroundColor(.white)
                                .lineLimit(3...6)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Capacity & Price
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Capacity")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                TextField("", value: $viewModel.capacity, format: .number)
                                    .keyboardType(.numberPad)
                                    .foregroundColor(.white)
                                    .padding(14)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Ticket Price (₹)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                TextField("", value: $viewModel.ticketPrice, format: .number, prompt: Text("0 = Free").foregroundColor(.white.opacity(0.3)))
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(.white)
                                    .padding(14)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        // Invitation URL
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Invitation Card URL (optional)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            TextField("", text: $viewModel.invitationURL, prompt: Text("https://...").foregroundColor(.white.opacity(0.3)))
                                .foregroundColor(.white)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Date pickers
                        VStack(alignment: .leading, spacing: 12) {
                            DatePicker("Starts", selection: $viewModel.startsAt)
                                .foregroundColor(.white)
                                .tint(.cyan)
                            DatePicker("Ends", selection: $viewModel.endsAt)
                                .foregroundColor(.white)
                                .tint(.cyan)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Polygon info
                        HStack {
                            Image(systemName: "pentagon")
                                .foregroundColor(viewModel.isPolygonValid ? .green : .orange)
                            Text("\(viewModel.polygonPoints.count) polygon points selected")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(viewModel.isPolygonValid ? .green.opacity(0.8) : .orange.opacity(0.8))
                        }
                        
                        // Create button — triggers confirmation first
                        Button(action: {
                            showConfirmation = true
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Create Event")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: viewModel.isPolygonValid ? [.green, .cyan] : [.gray, .gray.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(viewModel.isLoading || !viewModel.isPolygonValid)
                        .alert("Confirm Event Creation", isPresented: $showConfirmation) {
                            Button("Confirm", role: nil) {
                                Task {
                                    await viewModel.createEvent()
                                    if viewModel.showSuccess {
                                        dismiss()
                                    }
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text(confirmationMessage)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
