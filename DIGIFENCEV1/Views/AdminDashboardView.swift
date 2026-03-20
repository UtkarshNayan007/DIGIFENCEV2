//
//  AdminDashboardView.swift
//  DIGIFENCEV1
//
//  Premium admin dashboard with real-time analytics and event management.
//

import SwiftUI
import FirebaseFirestore

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DFSpacing.xl) {
                    // Quick Stats
                    statsSection
                    
                    // Active Events
                    if !activeEvents.isEmpty {
                        eventsSection(title: "Active Events", icon: "bolt.fill", iconColor: .green, events: activeEvents)
                    }
                    
                    // Inactive Events
                    if !inactiveEvents.isEmpty {
                        eventsSection(title: "Past Events", icon: "clock.fill", iconColor: .gray, events: inactiveEvents)
                    }
                    
                    // Empty State
                    if viewModel.allAdminEvents.isEmpty {
                        emptyState
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
            // Start listening to tickets for all events
            for event in viewModel.allAdminEvents {
                if let eventId = event.id {
                    viewModel.startListeningToTickets(for: eventId)
                }
            }
            withAnimation(.easeOut(duration: 0.3)) { appeared = true }
        }
        .onDisappear { viewModel.stopListening() }
    }
    
    private var activeEvents: [Event] {
        viewModel.allAdminEvents.filter { $0.isActive }
    }
    
    private var inactiveEvents: [Event] {
        viewModel.allAdminEvents.filter { !$0.isActive }
    }

    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            DFSectionHeader(title: "Overview", icon: "chart.pie.fill", iconColor: .dfAccent)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DFSpacing.md) {
                DashboardStatCard(
                    value: "\(viewModel.allAdminEvents.count)",
                    label: "Total Events",
                    icon: "calendar",
                    color: .blue
                )
                
                DashboardStatCard(
                    value: "\(activeEvents.count)",
                    label: "Active Events",
                    icon: "bolt.fill",
                    color: .green
                )
                
                DashboardStatCard(
                    value: "\(totalGuests)",
                    label: "Total Guests",
                    icon: "person.2.fill",
                    color: .orange
                )
                
                DashboardStatCard(
                    value: "\(totalCheckedIn)",
                    label: "Checked In",
                    icon: "checkmark.circle.fill",
                    color: .purple
                )
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }
    
    private var totalGuests: Int {
        viewModel.allAdminEvents.reduce(0) { sum, event in
            sum + viewModel.totalTickets(for: event.id ?? "")
        }
    }
    
    private var totalCheckedIn: Int {
        viewModel.allAdminEvents.reduce(0) { sum, event in
            sum + viewModel.activeGuestCount(for: event.id ?? "")
        }
    }
    
    // MARK: - Events Section
    
    private func eventsSection(title: String, icon: String, iconColor: Color, events: [Event]) -> some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            DFSectionHeader(title: title, icon: icon, iconColor: iconColor)
            
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                DashboardEventCard(event: event, viewModel: viewModel)
                    .entranceAnimation(index: index, baseDelay: 0.1)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        DFEmptyState(
            icon: "chart.bar.xaxis",
            title: "No Events Yet",
            message: "Create your first event from the Events tab to see analytics here."
        )
    }
}


// MARK: - Dashboard Stat Card

struct DashboardStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .contentTransition(.numericText())
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(DFSpacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

// MARK: - Dashboard Event Card

struct DashboardEventCard: View {
    let event: Event
    @ObservedObject var viewModel: AdminViewModel
    @State private var isToggling = false
    
    var eventId: String { event.id ?? "" }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: DFSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if let code = event.eventCode {
                            HStack(spacing: 6) {
                                Image(systemName: "ticket.fill")
                                    .font(.system(size: 11))
                                Text("Code: \(code)")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            }
                            .foregroundColor(.dfAccent)
                        }
                    }
                    
                    Spacer()
                    
                    DFStatusBadge(
                        text: event.isActive ? "LIVE" : "OFF",
                        color: event.isActive ? .green : .red,
                        size: .medium
                    )
                }
                
                // Stats Row
                HStack(spacing: DFSpacing.lg) {
                    EventStatItem(icon: "person.2.fill", value: viewModel.totalTickets(for: eventId), label: "Guests", color: .blue)
                    EventStatItem(icon: "checkmark.circle.fill", value: viewModel.activeGuestCount(for: eventId), label: "Active", color: .green)
                    EventStatItem(icon: "location.fill", value: viewModel.insideFenceCount(for: eventId), label: "Inside", color: .orange)
                }
            }
            .padding(DFSpacing.lg)

            Divider()
            
            // Action Buttons
            HStack(spacing: DFSpacing.md) {
                // Toggle Active Button
                Button(action: {
                    toggleEventStatus()
                }) {
                    HStack(spacing: 6) {
                        if isToggling {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: event.isActive ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 16))
                        }
                        Text(event.isActive ? "Deactivate" : "Activate")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(event.isActive ? .red : .green)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        (event.isActive ? Color.red : Color.green).opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
                }
                .disabled(isToggling)
                .buttonStyle(DFScaleButtonStyle())
                
                // View Attendees Button
                NavigationLink(destination: EventGuestTrackerView(event: event, viewModel: viewModel)) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 14))
                        Text("Attendees")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.dfAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.dfAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
                }
                .buttonStyle(DFScaleButtonStyle())
            }
            .padding(DFSpacing.lg)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
        .onAppear {
            viewModel.startListeningToTickets(for: eventId)
        }
    }
    
    private func toggleEventStatus() {
        HapticManager.shared.medium()
        isToggling = true
        Task {
            await viewModel.toggleEventActive(event: event)
            isToggling = false
            HapticManager.shared.success()
        }
    }
}

// MARK: - Event Stat Item

struct EventStatItem: View {
    let icon: String
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
                
                Text("\(value)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
            }
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}


// MARK: - Helper to map AttendanceLog.typeColor string → Color

private func logColor(from name: String) -> Color {
    switch name {
    case "green":  return .green
    case "orange": return .orange
    case "red":    return .red
    case "gray":   return .gray
    default:       return .gray
    }
}

// MARK: - Event Guest Tracker

struct EventGuestTrackerView: View {
    let event: Event
    @ObservedObject var viewModel: AdminViewModel
    @State private var selectedTab = 0
    @State private var isToggling = false

    var eventId: String { event.id ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            // Stats Header
            statsHeader
            
            // Capacity Progress
            if let capacity = event.capacity, capacity > 0 {
                capacityProgress(capacity: capacity)
            }

            Divider()

            // Tab Selector
            Picker("View", selection: $selectedTab) {
                Text("Guests").tag(0)
                Text("Activity").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DFSpacing.lg)
            .padding(.vertical, DFSpacing.md)
            .onChange(of: selectedTab) {
                HapticManager.shared.selection()
            }

            // Content
            if selectedTab == 0 {
                guestListView
            } else {
                attendanceLogsView
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    toggleEventStatus()
                } label: {
                    if isToggling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(event.isActive ? "Deactivate" : "Activate")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(event.isActive ? .red : .green)
                    }
                }
                .disabled(isToggling)
            }
        }
        .onAppear {
            viewModel.startListeningToTickets(for: eventId)
            Task { await viewModel.fetchAttendanceLogs(for: eventId) }
        }
        .onDisappear {
            viewModel.stopListeningToTickets(for: eventId)
        }
    }
    
    private func toggleEventStatus() {
        HapticManager.shared.medium()
        isToggling = true
        Task {
            await viewModel.toggleEventActive(event: event)
            isToggling = false
            HapticManager.shared.success()
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        HStack(spacing: 0) {
            GuestStatTile(value: viewModel.activeGuestCount(for: eventId), label: "Active", color: .green)
            GuestStatTile(value: viewModel.pendingCount(for: eventId), label: "Pending", color: .orange)
            GuestStatTile(value: viewModel.insideFenceCount(for: eventId), label: "Inside", color: .blue)
            GuestStatTile(value: viewModel.expiredCount(for: eventId), label: "Expired", color: .red)
        }
        .padding(.horizontal, DFSpacing.lg)
        .padding(.vertical, DFSpacing.lg)
    }

    // MARK: - Capacity Progress
    
    private func capacityProgress(capacity: Int) -> some View {
        VStack(alignment: .leading, spacing: DFSpacing.sm) {
            HStack {
                Text("Capacity")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(viewModel.totalTickets(for: eventId)) / \(capacity)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            DFProgressBar(
                progress: Double(viewModel.totalTickets(for: eventId)) / Double(capacity),
                height: 8,
                foregroundColors: [.cyan, .green]
            )
        }
        .padding(.horizontal, DFSpacing.lg)
        .padding(.bottom, DFSpacing.lg)
    }

    // MARK: - Guest List

    private var guestListView: some View {
        let tickets = viewModel.eventTickets[eventId] ?? []

        return Group {
            if tickets.isEmpty {
                DFEmptyState(icon: "person.2.slash", title: "No guests yet", message: "Guests will appear here when they get tickets.")
            } else {
                ScrollView {
                    LazyVStack(spacing: DFSpacing.sm) {
                        ForEach(Array(tickets.enumerated()), id: \.element.id) { index, ticket in
                            GuestRow(ticket: ticket)
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

    // MARK: - Attendance Logs

    private var attendanceLogsView: some View {
        let logs = viewModel.eventAttendanceLogs[eventId] ?? []

        return Group {
            if logs.isEmpty {
                DFEmptyState(icon: "doc.text", title: "No activity logs", message: "Activity will be recorded here.")
            } else {
                ScrollView {
                    LazyVStack(spacing: DFSpacing.xs) {
                        ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                            LogRow(log: log)
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
}

// MARK: - Guest Row

private struct GuestRow: View {
    let ticket: Ticket

    var statusIcon: String {
        switch ticket.status {
        case .active:  return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .expired: return "xmark.circle.fill"
        }
    }

    var statusColor: Color {
        switch ticket.status {
        case .active:  return .green
        case .pending: return .orange
        case .expired: return .red
        }
    }

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(ticket.ownerId.prefix(12) + "...")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)

                HStack(spacing: DFSpacing.sm) {
                    Text(ticket.statusDisplayText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(statusColor)

                    if ticket.insideFence {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                            Text("Inside")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.blue)
                    }

                    if ticket.biometricVerified {
                        HStack(spacing: 3) {
                            Image(systemName: "faceid")
                                .font(.system(size: 9))
                            Text("Verified")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            if let entryCode = ticket.entryCode {
                Text(entryCode)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.dfAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.dfAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
    }
}


// MARK: - Log Row

private struct LogRow: View {
    let log: AttendanceLog

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            ZStack {
                Circle()
                    .fill(logColor(from: log.typeColor).opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: log.typeIcon)
                    .foregroundColor(logColor(from: log.typeColor))
                    .font(.system(size: 13, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(log.type.capitalized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(log.ticketId.prefix(16) + "...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))
            }

            Spacer()

            if let ts = log.timestamp {
                Text(ts.dateValue().formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(.horizontal, DFSpacing.md)
        .padding(.vertical, DFSpacing.sm)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.sm, style: .continuous))
    }
}

// MARK: - Guest Stat Tile

private struct GuestStatTile: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: value)
            
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}
