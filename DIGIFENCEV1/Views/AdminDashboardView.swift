//
//  AdminDashboardView.swift
//  DIGIFENCEV1
//
//  Admin dashboard with analytics, event controls, and guest management.
//

import SwiftUI
import FirebaseFirestore

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: DFSpacing.xl) {
                    statsGrid
                    if !activeEvents.isEmpty {
                        eventsSection(title: "Active Events", icon: "bolt.fill", iconColor: .green, events: activeEvents)
                    }
                    if !inactiveEvents.isEmpty {
                        eventsSection(title: "Past Events", icon: "clock.fill", iconColor: .gray, events: inactiveEvents)
                    }
                    if viewModel.allAdminEvents.isEmpty {
                        DFEmptyState(icon: "chart.bar.xaxis", title: "No Events Yet", message: "Create your first event to see analytics.")
                    }
                }
                .padding(.horizontal, DFSpacing.lg)
                .padding(.top, DFSpacing.sm)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.startListeningToMyEvents()
            for e in viewModel.allAdminEvents { if let id = e.id { viewModel.startListeningToTickets(for: id) } }
            withAnimation(.easeOut(duration: 0.3)) { appeared = true }
        }
        .onDisappear { viewModel.stopListening() }
    }

    private var activeEvents: [Event] {
        viewModel.allAdminEvents.filter { event in
            event.isActive && !(event.endsAt.map { $0.dateValue() <= Date() } ?? false)
        }
    }
    private var inactiveEvents: [Event] {
        viewModel.allAdminEvents.filter { event in
            !event.isActive || (event.endsAt.map { $0.dateValue() <= Date() } ?? false)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DFSpacing.md) {
            AdminStatCard(value: "\(viewModel.allAdminEvents.count)", label: "Total Events", icon: "calendar", color: .blue)
            AdminStatCard(value: "\(activeEvents.count)", label: "Active", icon: "bolt.fill", color: .green)
            AdminStatCard(value: "\(totalGuests)", label: "Guests", icon: "person.2.fill", color: .orange)
            AdminStatCard(value: "\(totalCheckedIn)", label: "Checked In", icon: "checkmark.circle.fill", color: .purple)
        }
        .opacity(appeared ? 1 : 0)
    }

    private var totalGuests: Int {
        viewModel.allAdminEvents.filter { event in
            event.isActive && !(event.endsAt.map { $0.dateValue() <= Date() } ?? false)
        }.reduce(0) { $0 + viewModel.totalTickets(for: $1.id ?? "") }
    }
    private var totalCheckedIn: Int {
        viewModel.allAdminEvents.filter { event in
            event.isActive && !(event.endsAt.map { $0.dateValue() <= Date() } ?? false)
        }.reduce(0) { $0 + viewModel.activeGuestCount(for: $1.id ?? "") }
    }

    private func eventsSection(title: String, icon: String, iconColor: Color, events: [Event]) -> some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            DFSectionHeader(title: title, icon: icon, iconColor: iconColor)
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                DashboardEventCard(event: event, viewModel: viewModel)
                    .entranceAnimation(index: index, baseDelay: 0.1)
            }
        }
    }
}

// MARK: - Dashboard Event Card

struct DashboardEventCard: View {
    let event: Event
    @ObservedObject var viewModel: AdminViewModel
    @State private var isToggling = false
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    private var eventId: String { event.id ?? "" }

    private var isEventTimeOver: Bool {
        guard let endsAt = event.endsAt else { return false }
        return endsAt.dateValue() <= Date()
    }

    private var eventStatusText: String {
        if !event.isActive && isEventTimeOver { return "ENDED" }
        if !event.isActive { return "OFF" }
        if isEventTimeOver { return "ENDED" }
        return "LIVE"
    }

    private var eventStatusColor: Color {
        if eventStatusText == "ENDED" { return .gray }
        if !event.isActive { return .red }
        return .green
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: DFSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        if let code = event.eventCode {
                            HStack(spacing: 5) {
                                Image(systemName: "ticket.fill").font(.system(size: 10))
                                Text("Code: \(code)").font(.system(size: 12, weight: .semibold, design: .monospaced))
                            }
                            .foregroundColor(.dfAccent)
                        }
                    }
                    Spacer()
                    DFStatusBadge(
                        text: eventStatusText,
                        color: eventStatusColor,
                        size: .medium
                    )
                }

                // Stats
                HStack(spacing: DFSpacing.lg) {
                    EventStatItem(icon: "person.2.fill", value: viewModel.totalTickets(for: eventId), label: "Guests", color: .blue)
                    EventStatItem(icon: "checkmark.circle.fill", value: viewModel.activeGuestCount(for: eventId), label: "Active", color: .green)
                    EventStatItem(icon: "location.fill", value: viewModel.insideFenceCount(for: eventId), label: "Inside", color: .orange)
                }

                if !event.isActive || isEventTimeOver {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text("All passes terminated")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.sm, style: .continuous))
                }
            }
            .padding(DFSpacing.lg)

            Divider()

            // Action Buttons
            HStack(spacing: DFSpacing.sm) {
                // Toggle
                Button {
                    toggleStatus()
                } label: {
                    HStack(spacing: 5) {
                        if isToggling { ProgressView().controlSize(.mini) }
                        else { Image(systemName: event.isActive ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 14)) }
                        Text(event.isActive ? "Deactivate" : "Activate").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(event.isActive ? .red : .green)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background((event.isActive ? Color.red : Color.green).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
                }
                .disabled(isToggling)
                .buttonStyle(DFScaleButtonStyle())

                // Edit
                Button {
                    HapticManager.shared.light()
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                        .frame(width: 40, height: 40)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
                }
                .buttonStyle(DFScaleButtonStyle())

                // Attendees
                NavigationLink(destination: EventGuestTrackerView(event: event, viewModel: viewModel)) {
                    HStack(spacing: 5) {
                        Image(systemName: "person.3.fill").font(.system(size: 12))
                        Text("Guests").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.dfAccent)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(Color.dfAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
                }
                .buttonStyle(DFScaleButtonStyle())

                // Delete
                Button {
                    HapticManager.shared.warning()
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 40, height: 40)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
                }
                .buttonStyle(DFScaleButtonStyle())
            }
            .padding(DFSpacing.lg)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
        .onAppear { viewModel.startListeningToTickets(for: eventId) }
        .confirmationDialog("Delete Event?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteEvent(eventId: eventId) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(event.title)\" and cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            EditEventSheet(event: event, viewModel: viewModel)
        }
    }

    private func toggleStatus() {
        HapticManager.shared.medium()
        isToggling = true
        Task { await viewModel.toggleEventActive(event: event); isToggling = false; HapticManager.shared.success() }
    }
}

struct EventStatItem: View {
    let icon: String; let value: Int; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 11, weight: .medium)).foregroundColor(color)
                Text("\(value)").font(.system(size: 15, weight: .bold, design: .monospaced)).contentTransition(.numericText())
            }
            Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
        }
    }
}

// MARK: - Event Guest Tracker (Full Rewrite)

enum GuestSortTab: Int, CaseIterable {
    case active = 0
    case pending = 1
    case deactivated = 2

    var title: String {
        switch self {
        case .active: return "Active"
        case .pending: return "Pending"
        case .deactivated: return "Deactivated"
        }
    }
    var icon: String {
        switch self {
        case .active: return "bolt.fill"
        case .pending: return "clock.fill"
        case .deactivated: return "xmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .active: return .green
        case .pending: return .orange
        case .deactivated: return .red
        }
    }
    var explanation: String {
        switch self {
        case .active: return "Users whose entry has been verified by admin via check-in. The admin has scanned their QR code or verified their entry code."
        case .pending: return "Users who have registered for the event but haven't activated their pass yet. They need to complete biometric verification and enter the geofence."
        case .deactivated: return "Users whose passes have been manually deactivated by an admin or expired. Their access has been revoked."
        }
    }
}

struct EventGuestTrackerView: View {
    let event: Event
    @ObservedObject var viewModel: AdminViewModel
    @State private var selectedSort: GuestSortTab = .active
    @State private var guestSearch = ""
    @State private var showEditSheet = false
    @State private var showInfoPopover = false
    @State private var selectedGuest: Ticket?
    @State private var namesLoaded = false

    private var eventId: String { event.id ?? "" }

    private var isEventOver: Bool {
        if !event.isActive { return true }
        if let endsAt = event.endsAt, endsAt.dateValue() <= Date() { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            if isEventOver {
                eventOverBanner
            }
            statsHeader
            if let cap = event.capacity, cap > 0 { capacityBar(capacity: cap) }
            Divider()
            sortTabs
            searchBar
            guestListView
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button { HapticManager.shared.light(); showEditSheet = true } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditEventSheet(event: event, viewModel: viewModel)
        }
        .sheet(item: $selectedGuest) { ticket in
            GuestDetailSheet(ticket: ticket, viewModel: viewModel, eventTitle: event.title)
        }
        .alert(selectedSort.title, isPresented: $showInfoPopover) {
            Button("Got it") {}
        } message: {
            Text(selectedSort.explanation)
        }
        .onAppear {
            viewModel.startListeningToTickets(for: eventId)
            Task {
                await viewModel.fetchAttendanceLogs(for: eventId)
                await viewModel.fetchOwnerNamesForEvent(eventId: eventId)
                namesLoaded = true
            }
        }
        .onDisappear { viewModel.stopListeningToTickets(for: eventId) }
        .onChange(of: viewModel.eventTickets[eventId]?.count) {
            if namesLoaded {
                Task { await viewModel.fetchOwnerNamesForEvent(eventId: eventId) }
            }
        }
    }

    private var eventOverBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
            Text("Event Over — All Passes Terminated")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.orange)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
    }

    private var statsHeader: some View {
        HStack(spacing: 0) {
            GuestStatTile(value: isEventOver ? 0 : viewModel.insideFenceCount(for: eventId), label: "Inside", color: isEventOver ? .gray : .blue)
            GuestStatTile(value: isEventOver ? 0 : viewModel.activeGuestCount(for: eventId), label: "Checked In", color: isEventOver ? .gray : .green)
            GuestStatTile(value: isEventOver ? 0 : viewModel.pendingCount(for: eventId), label: "Pending", color: isEventOver ? .gray : .orange)
            GuestStatTile(value: viewModel.expiredCount(for: eventId) + (isEventOver ? viewModel.activeGuestCount(for: eventId) + viewModel.pendingCount(for: eventId) : 0), label: "Expired", color: .red)
        }
        .padding(.horizontal, DFSpacing.lg)
        .padding(.vertical, DFSpacing.lg)
    }

    private func capacityBar(capacity: Int) -> some View {
        VStack(alignment: .leading, spacing: DFSpacing.sm) {
            HStack {
                Text("Capacity").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text("\(viewModel.totalTickets(for: eventId)) / \(capacity)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            DFProgressBar(progress: Double(viewModel.totalTickets(for: eventId)) / Double(capacity), height: 7, foregroundColors: [.cyan, .green])
        }
        .padding(.horizontal, DFSpacing.lg)
        .padding(.bottom, DFSpacing.lg)
    }

    private var sortTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DFSpacing.sm) {
                ForEach(GuestSortTab.allCases, id: \.self) { tab in
                    Button {
                        if selectedSort == tab {
                            HapticManager.shared.light()
                            showInfoPopover = true
                        } else {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.3)) { selectedSort = tab }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon).font(.system(size: 11, weight: .semibold))
                            Text(tab.title).font(.system(size: 13, weight: .semibold))
                            Text("\(countForTab(tab))").font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(selectedSort == tab ? .white : .secondary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            selectedSort == tab
                                ? AnyShapeStyle(tab.color)
                                : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, DFSpacing.lg)
            .padding(.vertical, DFSpacing.sm)
        }
    }

    private var searchBar: some View {
        DFFloatingSearchBar(text: $guestSearch, placeholder: "Search by name or email...")
            .padding(.horizontal, DFSpacing.lg)
            .padding(.bottom, DFSpacing.sm)
    }

    private var guestListView: some View {
        let tickets = filteredTickets
        return Group {
            if tickets.isEmpty {
                VStack {
                    Spacer()
                    DFEmptyState(icon: "person.2.slash", title: "No guests", message: "No guests match this filter.")
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: DFSpacing.sm) {
                        ForEach(Array(tickets.enumerated()), id: \.element.id) { index, ticket in
                            Button {
                                HapticManager.shared.light()
                                selectedGuest = ticket
                            } label: {
                                GuestRowNew(ticket: ticket, ownerName: viewModel.ticketOwnerNames[ticket.ownerId], isDeactivated: isEventOver || viewModel.deactivatedTicketIds.contains(ticket.id ?? ""))
                            }
                            .buttonStyle(DFCardButtonStyle())
                            .entranceAnimation(index: index)
                        }
                    }
                    .padding(.horizontal, DFSpacing.lg)
                    .padding(.top, DFSpacing.sm)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    private var filteredTickets: [Ticket] {
        let allTickets = viewModel.eventTickets[eventId] ?? []
        // If event is over, treat ALL tickets as deactivated
        if isEventOver {
            if guestSearch.isEmpty { return allTickets }
            return allTickets.filter { ticket in
                let name = viewModel.ticketOwnerNames[ticket.ownerId] ?? ""
                let email = viewModel.ticketOwnerEmails[ticket.ownerId] ?? ""
                return name.localizedCaseInsensitiveContains(guestSearch)
                    || email.localizedCaseInsensitiveContains(guestSearch)
                    || ticket.ownerId.localizedCaseInsensitiveContains(guestSearch)
            }
        }
        let tabFiltered: [Ticket]
        switch selectedSort {
        case .active:
            tabFiltered = allTickets.filter { $0.status == .active && $0.qrScanned == true }
        case .pending:
            tabFiltered = allTickets.filter { $0.status == .pending || ($0.status == .active && $0.qrScanned != true) }
        case .deactivated:
            tabFiltered = allTickets.filter { $0.status == .expired }
        }
        if guestSearch.isEmpty { return tabFiltered }
        return tabFiltered.filter { ticket in
            let name = viewModel.ticketOwnerNames[ticket.ownerId] ?? ""
            let email = viewModel.ticketOwnerEmails[ticket.ownerId] ?? ""
            return name.localizedCaseInsensitiveContains(guestSearch)
                || email.localizedCaseInsensitiveContains(guestSearch)
                || ticket.ownerId.localizedCaseInsensitiveContains(guestSearch)
        }
    }

    private func countForTab(_ tab: GuestSortTab) -> Int {
        let allTickets = viewModel.eventTickets[eventId] ?? []
        if isEventOver {
            // When event is over, all guests are in deactivated state
            switch tab {
            case .active: return 0
            case .pending: return 0
            case .deactivated: return allTickets.count
            }
        }
        switch tab {
        case .active: return allTickets.filter { $0.status == .active && $0.qrScanned == true }.count
        case .pending: return allTickets.filter { $0.status == .pending || ($0.status == .active && $0.qrScanned != true) }.count
        case .deactivated: return allTickets.filter { $0.status == .expired }.count
        }
    }
}

// MARK: - Guest Row (shows name)

private struct GuestRowNew: View {
    let ticket: Ticket
    let ownerName: String?
    let isDeactivated: Bool

    private var statusColor: Color {
        if isDeactivated { return .red }
        switch ticket.status { case .active: return .green; case .pending: return .orange; case .expired: return .red }
    }
    private var statusIcon: String {
        if isDeactivated { return "xmark.circle.fill" }
        switch ticket.status { case .active: return "checkmark.circle.fill"; case .pending: return "clock.fill"; case .expired: return "xmark.circle.fill" }
    }

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 42, height: 42)
                Text(String((ownerName ?? "?").prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(statusColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(ownerName ?? "Loading...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: statusIcon).font(.system(size: 10)).foregroundColor(statusColor)
                    Text(isDeactivated ? "Deactivated" : ticket.statusDisplayText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(statusColor)
                    if ticket.insideFence && ticket.status == .active {
                        Label("Inside", systemImage: "location.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    if ticket.biometricVerified && ticket.status == .active {
                        Label("Bio ✓", systemImage: "faceid")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
    }
}

// MARK: - Guest Detail Sheet

struct GuestDetailSheet: View {
    let ticket: Ticket
    @ObservedObject var viewModel: AdminViewModel
    let eventTitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var showDeactivateConfirm = false
    @State private var isDeactivating = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DFSpacing.xl) {
                    guestHeader
                    ticketInfo
                    statusInfo
                    if ticket.status != .expired {
                        deactivateSection
                    }
                }
                .padding(.horizontal, DFSpacing.lg)
                .padding(.top, DFSpacing.lg)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Guest Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .confirmationDialog("Deactivate Pass?", isPresented: $showDeactivateConfirm, titleVisibility: .visible) {
                Button("Deactivate", role: .destructive) { deactivatePass() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will revoke \(viewModel.ticketOwnerNames[ticket.ownerId] ?? "this user")'s access to \"\(eventTitle)\". They will no longer be able to enter the geofence.")
            }
        }
    }

    private var guestHeader: some View {
        VStack(spacing: DFSpacing.lg) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.cyan.opacity(0.2), .blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                Text(String((viewModel.ticketOwnerNames[ticket.ownerId] ?? "?").prefix(1)).uppercased())
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.dfAccent)
            }
            VStack(spacing: 4) {
                Text(viewModel.ticketOwnerNames[ticket.ownerId] ?? ticket.ownerId)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                if let email = viewModel.ticketOwnerEmails[ticket.ownerId], !email.isEmpty {
                    Text(email)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    statusBadge
                    if ticket.insideFence && ticket.status == .active {
                        DFStatusBadge(text: "INSIDE FENCE", color: .blue, size: .small)
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DFSpacing.xl)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
    }

    @ViewBuilder
    private var statusBadge: some View {
        if viewModel.deactivatedTicketIds.contains(ticket.id ?? "") {
            DFStatusBadge(text: "DEACTIVATED", color: .red, size: .small)
        } else {
            switch ticket.status {
            case .active: DFStatusBadge(text: "ACTIVE", color: .green, size: .small)
            case .pending: DFStatusBadge(text: "PENDING", color: .orange, size: .small)
            case .expired: DFStatusBadge(text: "EXPIRED", color: .red, size: .small)
            }
        }
    }

    private var ticketInfo: some View {
        VStack(spacing: 0) {
            ProfileInfoRow(icon: "calendar", iconColor: .blue, label: "Event", value: eventTitle)
            DFDivider(leadingInset: 50)
            if let code = ticket.entryCode {
                ProfileInfoRow(icon: "number", iconColor: .purple, label: "Entry Code", value: code)
                DFDivider(leadingInset: 50)
            }
            ProfileInfoRow(icon: "person.text.rectangle", iconColor: .orange, label: "User ID", value: String(ticket.ownerId.prefix(16)) + "...")
            DFDivider(leadingInset: 50)
            if let created = ticket.createdAt {
                ProfileInfoRow(icon: "clock", iconColor: .gray, label: "Registered", value: created.dateValue().formatted(date: .abbreviated, time: .shortened))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
    }

    private var statusInfo: some View {
        VStack(spacing: 0) {
            if ticket.status == .active {
                ProfileInfoRow(icon: "faceid", iconColor: .green, label: "Biometric", value: ticket.biometricVerified ? "Verified ✓" : "Not verified")
                DFDivider(leadingInset: 50)
                ProfileInfoRow(icon: "location.fill", iconColor: .blue, label: "Inside Fence", value: ticket.insideFence ? "Yes" : "No")
                DFDivider(leadingInset: 50)
            }
            ProfileInfoRow(icon: "qrcode", iconColor: .purple, label: "QR Scanned", value: (ticket.qrScanned ?? false) ? "Yes" : "No")
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
    }

    private var deactivateSection: some View {
        DFDestructiveButton(title: "Deactivate Pass", icon: "xmark.shield.fill", isLoading: isDeactivating) {
            showDeactivateConfirm = true
        }
    }

    private func deactivatePass() {
        guard let ticketId = ticket.id else { return }
        isDeactivating = true
        Task {
            await viewModel.deactivateTicket(ticketId: ticketId)
            isDeactivating = false
            dismiss()
        }
    }
}

// MARK: - Guest Stat Tile

private struct GuestStatTile: View {
    let value: Int; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 5) {
            Text("\(value)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: value)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Log Row

private struct LogRow: View {
    let log: AttendanceLog
    private var color: Color {
        switch log.typeColor { case "green": return .green; case "orange": return .orange; case "red": return .red; default: return .gray }
    }
    var body: some View {
        HStack(spacing: DFSpacing.md) {
            DFIconBadge(icon: log.typeIcon, color: color, size: 30, iconSize: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(log.type.capitalized).font(.system(size: 13, weight: .semibold))
                Text(String(log.ticketId.prefix(16)) + "...").font(.system(size: 9, design: .monospaced)).foregroundColor(Color(.tertiaryLabel))
            }
            Spacer()
            if let ts = log.timestamp {
                Text(ts.dateValue().formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .medium)).foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(.horizontal, DFSpacing.md).padding(.vertical, DFSpacing.sm)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.sm, style: .continuous))
    }
}

// MARK: - Edit Event Sheet

struct EditEventSheet: View {
    let event: Event
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editTitle: String = ""
    @State private var editDescription: String = ""
    @State private var editStartsAt: Date = Date()
    @State private var editEndsAt: Date = Date()
    @State private var editIsActive: Bool = true
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $editTitle)
                        .font(.system(size: 16))
                    TextField("Description", text: $editDescription, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(3...6)
                }

                Section("Schedule") {
                    DatePicker("Starts", selection: $editStartsAt)
                    DatePicker("Ends", selection: $editEndsAt)
                    if editEndsAt <= editStartsAt {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                            Text("End date must be after start date").font(.system(size: 13)).foregroundColor(.orange)
                        }
                    }
                }

                Section("Status") {
                    Toggle("Active", isOn: $editIsActive)
                }

                Section("Geofence") {
                    NavigationLink {
                        AdminMapView(editingEvent: event)
                    } label: {
                        HStack(spacing: DFSpacing.md) {
                            Image(systemName: "pentagon.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                            Text("Edit Fence")
                                .font(.system(size: 16))
                            Spacer()
                            Text("\(event.polygonCoordinates.count) pts")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Button(action: save) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Save Changes")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving || editTitle.trimmingCharacters(in: .whitespaces).isEmpty || editEndsAt <= editStartsAt)
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                editTitle = event.title
                editDescription = event.description ?? ""
                editStartsAt = event.startsAt?.dateValue() ?? Date()
                editEndsAt = event.endsAt?.dateValue() ?? Date()
                editIsActive = event.isActive
            }
        }
    }

    private func save() {
        HapticManager.shared.medium()
        isSaving = true
        Task {
            await viewModel.updateEvent(
                eventId: event.id ?? "",
                title: editTitle,
                description: editDescription,
                startsAt: editStartsAt,
                endsAt: editEndsAt,
                isActive: editIsActive
            )
            isSaving = false
            if viewModel.showSuccess {
                HapticManager.shared.success()
                dismiss()
            }
        }
    }
}
