//
//  AdminMapView.swift
//  DIGIFENCEV1
//
//  Premium map-based event creation with Apple Maps-style search and draggable pins.
//

import SwiftUI
import MapKit
import PhotosUI
import Combine

struct AdminMapView: View {
    @StateObject private var viewModel = AdminViewModel()
    @StateObject private var searchCompleter = MapSearchCompleter()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
    )
    @State private var showCreateSheet = false
    @State private var mapSearchText = ""
    @State private var isSearchFocused = false
    @State private var selectedPinIndex: Int? = nil
    @State private var isDraggingPin = false

    var body: some View {
        ZStack {
            // Map
            mapView
            
            // Overlays
            VStack(spacing: 0) {
                // Search Bar
                searchBarOverlay
                
                Spacer()
                
                // Bottom Controls
                bottomControlsOverlay
            }
            
            // Location Button
            locationButton
            
            // Drag instruction overlay
            if selectedPinIndex != nil {
                dragInstructionOverlay
            }
        }
        .navigationTitle("Create Event")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startListeningToMyEvents()
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

    // MARK: - Map View
    
    private var mapView: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            // Existing events
            ForEach(viewModel.myEvents) { event in
                Annotation(event.title, coordinate: event.coordinate) {
                    ExistingEventPin(title: event.title)
                }

                MapPolygon(coordinates: event.polygonCLCoordinates)
                    .foregroundStyle(Color.dfAccent.opacity(0.1))
                    .stroke(Color.dfAccent.opacity(0.4), lineWidth: 1.5)
            }

            // New polygon points - draggable
            ForEach(Array(viewModel.polygonPoints.enumerated()), id: \.offset) { idx, point in
                Annotation("P\(idx + 1)", coordinate: point) {
                    DraggablePolygonMarker(
                        index: idx,
                        isSelected: selectedPinIndex == idx,
                        onTap: {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPinIndex = selectedPinIndex == idx ? nil : idx
                            }
                        },
                        onDrag: { newLocation in
                            viewModel.updatePolygonPoint(at: idx, to: newLocation)
                        }
                    )
                }
            }

            // Live polygon preview
            if viewModel.isPolygonValid {
                MapPolygon(coordinates: viewModel.polygonPoints)
                    .foregroundStyle(.green.opacity(0.15))
                    .stroke(.green.opacity(0.6), lineWidth: 2.5)
            } else if viewModel.polygonPoints.count == 2 {
                MapPolyline(coordinates: viewModel.polygonPoints)
                    .stroke(.green.opacity(0.5), lineWidth: 2)
            }

            // Center crosshair
            Annotation("", coordinate: CLLocationCoordinate2D(latitude: viewModel.latitude, longitude: viewModel.longitude)) {
                CrosshairMarker()
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onMapCameraChange { context in
            viewModel.latitude = context.region.center.latitude
            viewModel.longitude = context.region.center.longitude
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    // MARK: - Drag Instruction Overlay
    
    private var dragInstructionOverlay: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 16, weight: .medium))
                Text("Drag the pin to move it")
                    .font(.system(size: 14, weight: .medium))
                
                Button(action: {
                    HapticManager.shared.light()
                    withAnimation { selectedPinIndex = nil }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(.top, 80)
            
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Search Bar Overlay
    
    private var searchBarOverlay: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: DFSpacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSearchFocused ? .dfAccent : .secondary)

                TextField("Search places worldwide...", text: $mapSearchText, onEditingChanged: { editing in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchFocused = editing
                    }
                })
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .autocapitalization(.none)
                .onChange(of: mapSearchText) { _, newValue in
                    searchCompleter.search(query: newValue)
                }

                if !mapSearchText.isEmpty {
                    Button(action: {
                        HapticManager.shared.light()
                        mapSearchText = ""
                        searchCompleter.results = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
            }
            .padding(.horizontal, DFSpacing.lg)
            .frame(height: 52)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous)
                    .stroke(isSearchFocused ? Color.dfAccent.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
            .padding(.horizontal, DFSpacing.lg)
            .padding(.top, DFSpacing.sm)
            
            // Search Results using MKLocalSearchCompleter
            if !searchCompleter.results.isEmpty && !mapSearchText.isEmpty {
                searchResultsDropdown
            }
        }
    }
    
    // MARK: - Search Results Dropdown
    
    private var searchResultsDropdown: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(searchCompleter.results.enumerated()), id: \.offset) { index, result in
                    Button(action: {
                        selectSearchCompletion(result)
                    }) {
                        HStack(spacing: DFSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Color.dfAccent.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: result.subtitle.isEmpty ? "mappin.circle.fill" : "building.2.fill")
                                    .foregroundColor(.dfAccent)
                                    .font(.system(size: 18))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()
                            
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, DFSpacing.lg)
                        .padding(.vertical, DFSpacing.md)
                    }

                    if index < searchCompleter.results.count - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
        }
        .frame(maxHeight: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .padding(.horizontal, DFSpacing.lg)
        .padding(.top, DFSpacing.sm)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private func selectSearchCompletion(_ completion: MKLocalSearchCompletion) {
        HapticManager.shared.selection()
        
        // Perform search to get coordinates
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        Task {
            do {
                let response = try await search.start()
                if let item = response.mapItems.first {
                    let coord = item.placemark.coordinate
                    let lat = coord.latitude
                    let lon = coord.longitude
                    await MainActor.run {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            cameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), latitudinalMeters: 800, longitudinalMeters: 800))
                        }
                        mapSearchText = ""
                        searchCompleter.results = []
                        viewModel.latitude = lat
                        viewModel.longitude = lon
                        HapticManager.shared.success()
                    }
                }
            } catch {
                print("Search error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Location Button
    
    private var locationButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                Button(action: {
                    HapticManager.shared.light()
                    viewModel.centerOnUserLocation(cameraPosition: $cameraPosition)
                }) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.cyan.opacity(0.4), radius: 12, y: 6)
                }
                .buttonStyle(DFScaleButtonStyle())
                .padding(.trailing, DFSpacing.lg)
                .padding(.bottom, 220)
            }
        }
    }
    
    // MARK: - Bottom Controls Overlay
    
    private var bottomControlsOverlay: some View {
        VStack(spacing: DFSpacing.md) {
            // Polygon Controls
            HStack(spacing: DFSpacing.md) {
                // Drop Point Button
                Button(action: {
                    HapticManager.shared.medium()
                    viewModel.addPolygonPoint(
                        CLLocationCoordinate2D(
                            latitude: viewModel.latitude,
                            longitude: viewModel.longitude
                        )
                    )
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Drop Point")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(Color.green)
                    .clipShape(Capsule())
                }
                .buttonStyle(DFScaleButtonStyle())

                // Undo Button
                Button(action: {
                    HapticManager.shared.light()
                    viewModel.removeLastPolygonPoint()
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(width: 42, height: 42)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .disabled(viewModel.polygonPoints.isEmpty)
                .opacity(viewModel.polygonPoints.isEmpty ? 0.5 : 1)

                // Clear Button
                Button(action: {
                    HapticManager.shared.warning()
                    viewModel.clearPolygonPoints()
                    selectedPinIndex = nil
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 42, height: 42)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .disabled(viewModel.polygonPoints.isEmpty)
                .opacity(viewModel.polygonPoints.isEmpty ? 0.5 : 1)

                Spacer()

                // Points Counter
                HStack(spacing: 4) {
                    Image(systemName: "pentagon")
                        .font(.system(size: 12, weight: .medium))
                    Text("\(viewModel.polygonPoints.count)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(viewModel.isPolygonValid ? .green : .orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
            }

            // Warning Message
            if !viewModel.isPolygonValid && !viewModel.polygonPoints.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text(viewModel.isPolygonSelfIntersecting ? "Lines cannot cross" : "Need at least 3 points")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
            }
            
            // Tip for dragging
            if viewModel.polygonPoints.count > 0 && selectedPinIndex == nil {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 11))
                    Text("Tap a point to drag it")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
            }

            // Coordinates Display
            Text(String(format: "📍 %.5f, %.5f", viewModel.latitude, viewModel.longitude))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))

            // Create Event Button
            DFPrimaryButton(
                title: "Create Event",
                icon: "plus.circle.fill",
                isDisabled: !viewModel.isPolygonValid,
                colors: viewModel.isPolygonValid ? [.green, .cyan] : [.gray, .gray]
            ) {
                showCreateSheet = true
            }
        }
        .padding(DFSpacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, y: -4)
        .padding(.horizontal, DFSpacing.lg)
        .padding(.bottom, DFSpacing.sm)
    }
}


// MARK: - MKLocalSearchCompleter Wrapper

class MapSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    func search(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            DispatchQueue.main.async {
                self.results = []
            }
            return
        }
        completer.queryFragment = query
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
}

// MARK: - Draggable Polygon Marker

struct DraggablePolygonMarker: View {
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onDrag: (CLLocationCoordinate2D) -> Void
    
    @State private var appeared = false
    @State private var dragOffset: CGSize = .zero
    @GestureState private var isDragging = false
    
    var body: some View {
        ZStack {
            // Selection ring
            if isSelected {
                Circle()
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: 36, height: 36)
                    .scaleEffect(isDragging ? 1.2 : 1.0)
            }
            
            // Main marker
            ZStack {
                Circle()
                    .fill(isSelected ? Color.green : Color.green.opacity(0.9))
                    .frame(width: 24, height: 24)
                
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 24, height: 24)
                
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: .green.opacity(0.5), radius: isSelected ? 8 : 4, y: 2)
            .scaleEffect(appeared ? (isDragging ? 1.3 : 1.0) : 0.3)
        }
        .offset(dragOffset)
        .gesture(
            isSelected ?
            DragGesture()
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    // Calculate new coordinate based on drag
                    // This is a simplified approach - in production you'd convert screen points to coordinates
                    HapticManager.shared.medium()
                    dragOffset = .zero
                }
            : nil
        )
        .onTapGesture {
            onTap()
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
}

// MARK: - Map Markers

struct ExistingEventPin: View {
    let title: String
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.dfAccent.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.dfAccent)
            }
            .scaleEffect(appeared ? 1.0 : 0.3)
            
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
}

struct CrosshairMarker: View {
    @State private var pulsing = false
    
    var body: some View {
        ZStack {
            // Pulse ring
            Circle()
                .stroke(Color.dfAccent.opacity(0.3), lineWidth: 1)
                .frame(width: 50, height: 50)
                .scaleEffect(pulsing ? 1.2 : 1.0)
                .opacity(pulsing ? 0 : 0.5)
            
            Circle()
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                .frame(width: 44, height: 44)
            
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(.dfAccent)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}


// MARK: - Create Event Sheet

struct CreateEventSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // Image Picker
                imagePickerSection
                
                // Event Details
                Section("Event Details") {
                    TextField("Event Title", text: $viewModel.title)
                        .font(.system(size: 16))
                    
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(3...6)
                }

                // Tickets
                Section("Tickets") {
                    HStack {
                        Text("Capacity")
                        Spacer()
                        TextField("100", value: $viewModel.capacity, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Price (₹)")
                        Spacer()
                        TextField("0 = Free", value: $viewModel.ticketPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                // Optional
                Section("Optional") {
                    TextField("Invitation Card URL", text: $viewModel.invitationURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                // Schedule
                Section("Schedule") {
                    DatePicker("Starts", selection: $viewModel.startsAt)
                    DatePicker("Ends", selection: $viewModel.endsAt)
                }

                // Polygon Info
                Section {
                    HStack(spacing: DFSpacing.md) {
                        Image(systemName: "pentagon")
                            .foregroundColor(viewModel.isPolygonValid ? .green : .orange)
                        
                        Text("\(viewModel.polygonPoints.count) polygon points selected")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(viewModel.isPolygonValid ? .green : .orange)
                    }
                }

                // Create Button
                Section {
                    Button(action: {
                        HapticManager.shared.medium()
                        Task {
                            await viewModel.createEvent()
                            if viewModel.showSuccess {
                                HapticManager.shared.success()
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Create Event")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading || !viewModel.isPolygonValid)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Image Picker Section
    
    private var imagePickerSection: some View {
        Section {
            PhotosPicker(selection: $viewModel.selectedImageItem, matching: .images, photoLibrary: .shared()) {
                Group {
                    if let imageData = viewModel.selectedImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .padding(DFSpacing.sm)
                            }
                    } else {
                        HStack(spacing: DFSpacing.md) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(.dfAccent)
                            
                            Text("Add Event Photo")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DFSpacing.md)
                    }
                }
            }
        }
    }
}
