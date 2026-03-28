//
//  AdminEventsView.swift
//  DIGIFENCEV1
//
//  Admin event management — create, list, toggle, delete events with improved UI.
//

import SwiftUI
import FirebaseFirestore

struct AdminEventsView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var showCreateEvent = false
    @State private var searchText = ""
    @State private var filterMode: AdminEventFilter = .all
    @State private var appeared = false

    enum AdminEventFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case ended = "Ended"
    }

    private var filteredEvents: [Event] {
        let events: [Event]
        switch filterMode {
        case .all: events = viewModel.allAdminEvents
        case .active: events = viewModel.allAdminEvents.filter { $0.isActive && !isEventOver($0) }
        case .ended: events = viewModel.allAdminEvents.filter { !$0.isActive || isEventOver($0) }
        }
        if searchText.isEmpty { return events }
        return events.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private func isEventOver(_ event: Event) -> Bool {
        event.endsAt.map { $0.dateValue() <= Date() } ?? false
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if viewModel.allAdminEvents.isEmpty && !viewModel.isLoading {
                VStack(spacing: DFSpacing.xl) {
                    DFEmptyState(icon: "calendar.badge.plus", title: "No Events", message: "Create your first event to get started.")
                    DFPrimaryButton(title: "Create Event", icon: "plus.circle.fill", height: 46) {
                        showCreateEvent = true
                    }
                    .padding(.horizontal, DFSpacing.xxxl)
                }
            } else {
                VStack(spacing: 0) {
                    // Search
                    DFFloatingSearchBar(text: $searchText, placeholder: "Search events...")
                        .padding(.horizontal, DFSpacing.lg)
                        .padding(.vertical, DFSpacing.sm)

                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DFSpacing.sm) {
                            ForEach(AdminEventFilter.allCases, id: \.self) { filter in
                                Button {
                                    HapticManager.shared.selection()
                                    withAnimation(.spring(response: 0.3)) { filterMode = filter }
                                } label: {
                                    Text(filter.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(filterMode == filter ? .white : .secondary)
                                        .padding(.horizontal, 14).padding(.vertical, 7)
                                        .background(
                                            filterMode == filter
                                                ? AnyShapeStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                                                : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, DFSpacing.lg)
                        .padding(.bottom, DFSpacing.sm)
                    }

                    // Events list
                    ScrollView {
                        LazyVStack(spacing: DFSpacing.md) {
                            ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, event in
                                AdminEventRow(event: event, viewModel: viewModel)
                                    .entranceAnimation(index: index)
                            }
                        }
                        .padding(.horizontal, DFSpacing.lg)
                        .padding(.top, DFSpacing.sm)
                        .padding(.bottom, 100)
                    }
                    .refreshable { viewModel.startListeningToMyEvents() }
                }
            }

            // FAB
            DFFloatingActionButton(icon: "plus", colors: [.indigo, .purple]) {
                showCreateEvent = true
            }
            .padding(.trailing, DFSpacing.xl)
            .padding(.bottom, DFSpacing.xxl)
        }
        .navigationTitle("My Events")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showCreateEvent) {
            NavigationStack { AdminMapView() }
        }
        .onAppear {
            viewModel.startListeningToMyEvents()
            for e in viewModel.allAdminEvents {
                if let id = e.id { viewModel.startListeningToTickets(for: id) }
            }
        }
        .onDisappear { viewModel.stopListening() }
    }
}

// MARK: - Admin Event Row (Improved)

struct AdminEventRow: View {
    let event: Event
    @ObservedObject var viewModel: AdminViewModel
    @State private var isToggling = false
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    private var eventId: String { event.id ?? "" }

    private var isEventTimeOver: Bool {
        event.endsAt.map { $0.dateValue() <= Date() } ?? false
    }

    private var statusText: String {
        if !event.isActive && isEventTimeOver { return "ENDED" }
        if !event.isActive { return "OFF" }
        if isEventTimeOver { return "ENDED" }
        return "LIVE"
    }

    private var statusColor: Color {
        if statusText == "ENDED" { return .gray }
        if !event.isActive { return .red }
        return .green
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top section with thumbnail
            HStack(spacing: DFSpacing.md) {
                // Thumbnail
                Group {
                    if let urlStr = event.thumbnailURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default: rowPlaceholder
                            }
                        }
                    } else {
                        rowPlaceholder
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(event.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        Spacer()
                        DFStatusBadge(text: statusText, color: statusColor, size: .small)
                    }
                    if let code = event.eventCode {
                        HStack(spacing: 4) {
                            Image(systemName: "ticket.fill").font(.system(size: 9))
                            Text(code).font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(.dfAccent)
                    }
                    // Stats inline
                    HStack(spacing: DFSpacing.md) {
                        Label("\(viewModel.totalTickets(for: eventId))", systemImage: "person.2.fill")
                            .font(.system(size: 11, weight: .medium)).foregroundColor(.blue)
                        Label("\(viewModel.activeGuestCount(for: eventId))", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .medium)).foregroundColor(.green)
                        Label("\(viewModel.insideFenceCount(for: eventId))", systemImage: "location.fill")
                            .font(.system(size: 11, weight: .medium)).foregroundColor(.orange)
                    }
                }
            }
            .padding(DFSpacing.md)

            Divider().padding(.horizontal, DFSpacing.md)

            // Action row
            HStack(spacing: 0) {
                // Toggle
                Button {
                    toggleStatus()
                } label: {
                    HStack(spacing: 4) {
                        if isToggling { ProgressView().controlSize(.mini) }
                        else { Image(systemName: event.isActive ? "pause.fill" : "play.fill").font(.system(size: 12)) }
                        Text(event.isActive ? "Pause" : "Start").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(event.isActive ? .orange : .green)
                    .frame(maxWidth: .infinity).frame(height: 36)
                }
                .disabled(isToggling)

                Divider().frame(height: 20)

                // Guests
                NavigationLink(destination: EventGuestTrackerView(event: event, viewModel: viewModel)) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.3.fill").font(.system(size: 11))
                        Text("Guests").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.dfAccent)
                    .frame(maxWidth: .infinity).frame(height: 36)
                }

                Divider().frame(height: 20)

                // Edit
                Button {
                    HapticManager.shared.light()
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.indigo)
                        .frame(width: 44, height: 36)
                }

                Divider().frame(height: 20)

                // Delete
                Button {
                    HapticManager.shared.warning()
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 44, height: 36)
                }
            }
            .padding(.horizontal, DFSpacing.sm)
            .padding(.vertical, DFSpacing.xs)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        .onAppear { viewModel.startListeningToTickets(for: eventId) }
        .confirmationDialog("Delete Event?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await viewModel.deleteEvent(eventId: eventId) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(event.title)\" and cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            EditEventSheet(event: event, viewModel: viewModel)
        }
    }

    private var rowPlaceholder: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.indigo.opacity(0.12), .purple.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Image(systemName: "calendar").font(.system(size: 20)).foregroundStyle(.tertiary))
    }

    private func toggleStatus() {
        HapticManager.shared.medium()
        isToggling = true
        Task { await viewModel.toggleEventActive(event: event); isToggling = false; HapticManager.shared.success() }
    }
}
