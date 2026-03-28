//
//  AdminMapView.swift
//  DIGIFENCEV1
//
//  Clean map for event creation — fresh map with no existing fences.
//  Also used for editing an existing event's geofence.
//

import SwiftUI
import MapKit
import PhotosUI
import Combine
import FirebaseFirestore

struct AdminMapView: View {
    @StateObject private var viewModel = AdminViewModel()
    @StateObject private var searchCompleter = MapSearchCompleter()
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing event to edit its fence; nil = create new
    var editingEvent: Event? = nil

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
    )
    @State private var showCreateSheet = false
    @State private var isSatelliteView = false
    @State private var mapSearchText = ""
    @State private var isSearchFocused = false
    @State private var selectedPinIndex: Int? = nil

    var body: some View {
        ZStack {
            mapView

            VStack(spacing: 0) {
                searchBarOverlay
                Spacer()
                bottomControlsOverlay
            }

            locationButton

            if selectedPinIndex != nil {
                dragInstructionOverlay
            }
        }
        .navigationTitle(editingEvent != nil ? "Edit Fence" : "Create Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    HapticManager.shared.light()
                    dismiss()
                }
            }
        }
        .onAppear {
            if let event = editingEvent {
                // Load existing polygon for editing
                viewModel.polygonPoints = event.polygonCLCoordinates
                let center = event.coordinate
                cameraPosition = .region(MKCoordinateRegion(
                    center: center, latitudinalMeters: 1000, longitudinalMeters: 1000
                ))
                viewModel.latitude = center.latitude
                viewModel.longitude = center.longitude
            } else {
                viewModel.centerOnUserLocation(cameraPosition: $cameraPosition)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateEventSheet(viewModel: viewModel)
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text(viewModel.successMessage)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Map (fresh — no existing event fences)

    private var mapView: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            // Only show the new polygon being drawn — no existing events
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

            if viewModel.isPolygonValid {
                MapPolygon(coordinates: viewModel.polygonPoints)
                    .foregroundStyle(.green.opacity(0.15))
                    .stroke(.green.opacity(0.6), lineWidth: 2.5)
            } else if viewModel.polygonPoints.count == 2 {
                MapPolyline(coordinates: viewModel.polygonPoints)
                    .stroke(.green.opacity(0.5), lineWidth: 2)
            }
        }
        .mapStyle(isSatelliteView ? .hybrid(elevation: .realistic) : .standard(elevation: .realistic))
        .onMapCameraChange { context in
            viewModel.latitude = context.region.center.latitude
            viewModel.longitude = context.region.center.longitude
        }
        .overlay {
            CrosshairMarker()
                .allowsHitTesting(false)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Drag Instruction

    private var dragInstructionOverlay: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "hand.draw.fill").font(.system(size: 16, weight: .medium))
                Text("Drag the pin to move it").font(.system(size: 14, weight: .medium))
                Button {
                    HapticManager.shared.light()
                    withAnimation { selectedPinIndex = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(.top, 80)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Search Bar

    private var searchBarOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: DFSpacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSearchFocused ? .dfAccent : .secondary)

                TextField("Search places...", text: $mapSearchText, onEditingChanged: { editing in
                    withAnimation(.easeInOut(duration: 0.2)) { isSearchFocused = editing }
                })
                .font(.system(size: 16))
                .autocapitalization(.none)
                .onChange(of: mapSearchText) { _, newValue in
                    searchCompleter.search(query: newValue)
                }

                if !mapSearchText.isEmpty {
                    Button {
                        HapticManager.shared.light()
                        mapSearchText = ""
                        searchCompleter.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundColor(Color(.tertiaryLabel))
                    }
                }
            }
            .padding(.horizontal, DFSpacing.lg)
            .frame(height: 52)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous)
                    .stroke(isSearchFocused ? Color.dfAccent.opacity(0.4) : .clear, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
            .padding(.horizontal, DFSpacing.lg)
            .padding(.top, DFSpacing.sm)

            if !searchCompleter.results.isEmpty && !mapSearchText.isEmpty {
                searchResultsDropdown
            }
        }
    }

    private var searchResultsDropdown: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(searchCompleter.results.enumerated()), id: \.offset) { index, result in
                    Button { selectSearchCompletion(result) } label: {
                        HStack(spacing: DFSpacing.md) {
                            ZStack {
                                Circle().fill(Color.dfAccent.opacity(0.12)).frame(width: 40, height: 40)
                                Image(systemName: result.subtitle.isEmpty ? "mappin.circle.fill" : "building.2.fill")
                                    .foregroundColor(.dfAccent).font(.system(size: 18))
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.title).font(.system(size: 15, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle").font(.system(size: 16, weight: .medium)).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, DFSpacing.lg).padding(.vertical, DFSpacing.md)
                    }
                    if index < searchCompleter.results.count - 1 { Divider().padding(.leading, 64) }
                }
            }
        }
        .frame(maxHeight: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .padding(.horizontal, DFSpacing.lg).padding(.top, DFSpacing.sm)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func selectSearchCompletion(_ completion: MKLocalSearchCompletion) {
        HapticManager.shared.selection()
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        Task {
            do {
                let response = try await search.start()
                if let item = response.mapItems.first {
                    // Fix for iOS 26.0 deprecation: Use location if available
                    let coord = item.location.coordinate
                    await MainActor.run {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            cameraPosition = .region(MKCoordinateRegion(center: coord, latitudinalMeters: 800, longitudinalMeters: 800))
                        }
                        mapSearchText = ""
                        searchCompleter.results = []
                        viewModel.latitude = coord.latitude
                        viewModel.longitude = coord.longitude
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
                VStack(spacing: DFSpacing.md) {
                    Button {
                        HapticManager.shared.light()
                        isSatelliteView.toggle()
                    } label: {
                        Image(systemName: isSatelliteView ? "map.fill" : "globe.americas.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(Circle())
                            .shadow(color: .indigo.opacity(0.4), radius: 12, y: 6)
                    }
                    .buttonStyle(DFScaleButtonStyle())
                    
                    Button {
                        HapticManager.shared.light()
                        viewModel.centerOnUserLocation(cameraPosition: $cameraPosition)
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(Circle())
                            .shadow(color: .cyan.opacity(0.4), radius: 12, y: 6)
                    }
                    .buttonStyle(DFScaleButtonStyle())
                }
                .padding(.trailing, DFSpacing.lg)
                .padding(.bottom, 220)
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControlsOverlay: some View {
        VStack(spacing: DFSpacing.md) {
            HStack(spacing: DFSpacing.md) {
                Button {
                    HapticManager.shared.medium()
                    viewModel.addPolygonPoint(CLLocationCoordinate2D(latitude: viewModel.latitude, longitude: viewModel.longitude))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 14, weight: .semibold))
                        Text("Drop Point").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).frame(height: 42)
                    .background(Color.green).clipShape(Capsule())
                }
                .buttonStyle(DFScaleButtonStyle())

                Button { HapticManager.shared.light(); viewModel.removeLastPolygonPoint() } label: {
                    Image(systemName: "arrow.uturn.backward").font(.system(size: 14, weight: .semibold)).foregroundColor(.orange)
                        .frame(width: 42, height: 42).background(Color(.tertiarySystemGroupedBackground)).clipShape(Circle())
                }
                .disabled(viewModel.polygonPoints.isEmpty).opacity(viewModel.polygonPoints.isEmpty ? 0.5 : 1)

                Button { HapticManager.shared.warning(); viewModel.clearPolygonPoints(); selectedPinIndex = nil } label: {
                    Image(systemName: "trash").font(.system(size: 14, weight: .semibold)).foregroundColor(.red)
                        .frame(width: 42, height: 42).background(Color(.tertiarySystemGroupedBackground)).clipShape(Circle())
                }
                .disabled(viewModel.polygonPoints.isEmpty).opacity(viewModel.polygonPoints.isEmpty ? 0.5 : 1)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "pentagon").font(.system(size: 12, weight: .medium))
                    Text("\(viewModel.polygonPoints.count)").font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(viewModel.isPolygonValid ? .green : .orange)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.tertiarySystemGroupedBackground)).clipShape(Capsule())
            }

            if !viewModel.isPolygonValid && !viewModel.polygonPoints.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12))
                    Text(viewModel.isPolygonSelfIntersecting ? "Lines cannot cross" : "Need at least 3 points")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.orange).padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.orange.opacity(0.12)).clipShape(Capsule())
            }

            if viewModel.polygonPoints.count > 0 && selectedPinIndex == nil {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill").font(.system(size: 11))
                    Text("Tap a point to drag it").font(.system(size: 12, weight: .medium))
                }.foregroundColor(.secondary)
            }

            Text(String(format: "📍 %.5f, %.5f", viewModel.latitude, viewModel.longitude))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))

            if editingEvent != nil {
                // Save fence edit
                DFPrimaryButton(
                    title: "Save Fence",
                    icon: "checkmark.circle.fill",
                    isDisabled: !viewModel.isPolygonValid,
                    colors: viewModel.isPolygonValid ? [.green, .cyan] : [.gray, .gray]
                ) {
                    Task {
                        await saveFenceEdit()
                    }
                }
            } else {
                DFPrimaryButton(
                    title: "Create Event",
                    icon: "plus.circle.fill",
                    isDisabled: !viewModel.isPolygonValid,
                    colors: viewModel.isPolygonValid ? [.green, .cyan] : [.gray, .gray]
                ) { showCreateSheet = true }
            }
        }
        .padding(DFSpacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, y: -4)
        .padding(.horizontal, DFSpacing.lg).padding(.bottom, DFSpacing.sm)
    }

    private func saveFenceEdit() async {
        guard let eventId = editingEvent?.id else { return }
        viewModel.isLoading = true
        do {
            let polygonData = viewModel.polygonPoints.map { ["lat": $0.latitude, "lng": $0.longitude] }
            try await FirebaseManager.shared.eventsCollection.document(eventId).updateData([
                "polygonCoordinates": polygonData
            ])
            viewModel.successMessage = "Geofence updated."
            viewModel.showSuccess = true
        } catch {
            viewModel.errorMessage = error.localizedDescription
            viewModel.showError = true
        }
        viewModel.isLoading = false
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
            DispatchQueue.main.async { self.results = [] }
            return
        }
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { self.results = completer.results }
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

    @State private var dragOffset: CGSize = .zero
    @GestureState private var isDragging = false

    var body: some View {
        ZStack {
            if isSelected {
                Circle().stroke(Color.green, lineWidth: 3).frame(width: 36, height: 36)
                    .scaleEffect(isDragging ? 1.2 : 1.0)
            }
            ZStack {
                Circle().fill(isSelected ? Color.green : Color.green.opacity(0.9)).frame(width: 24, height: 24)
                Circle().stroke(Color.white, lineWidth: 3).frame(width: 24, height: 24)
                Text("\(index + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
            }
            .shadow(color: .green.opacity(0.5), radius: isSelected ? 8 : 4, y: 2)
            .scaleEffect(isDragging ? 1.3 : 1.0)
        }
        .offset(dragOffset)
        .gesture(
            isSelected ?
            DragGesture()
                .updating($isDragging) { _, state, _ in state = true }
                .onChanged { value in dragOffset = value.translation }
                .onEnded { _ in HapticManager.shared.medium(); dragOffset = .zero }
            : nil
        )
        .onTapGesture { onTap() }
    }
}

// MARK: - Map Markers

struct CrosshairMarker: View {
    @State private var pulsing = false
    var body: some View {
        ZStack {
            Circle().stroke(Color.dfAccent.opacity(0.3), lineWidth: 1).frame(width: 50, height: 50)
                .scaleEffect(pulsing ? 1.2 : 1.0).opacity(pulsing ? 0 : 0.5)
            Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1.5).frame(width: 44, height: 44)
            Image(systemName: "plus").font(.system(size: 22, weight: .light)).foregroundColor(.dfAccent)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) { pulsing = true }
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
                imagePickerSection

                Section("Event Details") {
                    TextField("Event Title", text: $viewModel.title).font(.system(size: 16))
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .font(.system(size: 16)).lineLimit(3...6)
                }

                Section("Tickets") {
                    HStack {
                        Text("Capacity"); Spacer()
                        TextField("100", value: $viewModel.capacity, format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("Price (₹)"); Spacer()
                        TextField("0 = Free", value: $viewModel.ticketPrice, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                }

                Section("Optional") {
                    TextField("Invitation Card URL", text: $viewModel.invitationURL)
                        .keyboardType(.URL).textInputAutocapitalization(.never)
                }

                Section("Schedule") {
                    DatePicker("Starts", selection: $viewModel.startsAt)
                    DatePicker("Ends", selection: $viewModel.endsAt)
                }

                Section {
                    HStack(spacing: DFSpacing.md) {
                        Image(systemName: "pentagon").foregroundColor(viewModel.isPolygonValid ? .green : .orange)
                        Text("\(viewModel.polygonPoints.count) polygon points")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(viewModel.isPolygonValid ? .green : .orange)
                    }
                }

                Section {
                    Button {
                        HapticManager.shared.medium()
                        Task {
                            await viewModel.createEvent()
                            if viewModel.showSuccess { HapticManager.shared.success(); dismiss() }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading { ProgressView().controlSize(.small) }
                            else { Text("Create Event").font(.system(size: 17, weight: .semibold)) }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading || !viewModel.isPolygonValid)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var imagePickerSection: some View {
        let currentImageData = viewModel.selectedImageData
        return Section {
            PhotosPicker(selection: $viewModel.selectedImageItem, matching: .images, photoLibrary: .shared()) {
                ImagePickerLabel(imageData: currentImageData)
            }
        }
    }
}

private struct ImagePickerLabel: View {
    let imageData: Data?
    var body: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage).resizable().scaledToFill().frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "photo.badge.plus").font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                        .padding(10).background(.ultraThinMaterial, in: Circle()).padding(DFSpacing.sm)
                }
        } else {
            HStack(spacing: DFSpacing.md) {
                Image(systemName: "photo.badge.plus").font(.system(size: 20)).foregroundColor(.dfAccent)
                Text("Add Event Photo").font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, DFSpacing.md)
        }
    }
}
