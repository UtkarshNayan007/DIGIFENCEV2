//
//  AdminDashboardView.swift
//  DIGIFENCEV1
//
//  Admin event dashboard with real-time guest tracking and attendance logs.
//

import SwiftUI
import FirebaseFirestore

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminViewModel()
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()
            
            if viewModel.allAdminEvents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No Events Yet")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Create your first event from the Admin tab.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.allAdminEvents) { event in
                            NavigationLink(destination: EventGuestTrackerView(event: event, viewModel: viewModel)) {
                                AdminEventCard(event: event, viewModel: viewModel)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { viewModel.startListeningToMyEvents() }
        .onDisappear { viewModel.stopListening() }
    }
}

// MARK: - Admin Event Card

struct AdminEventCard: View {
    let event: Event
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let desc = event.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Status indicator
                Text(event.isActive ? "LIVE" : "OFF")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(event.isActive ? Color.green : Color.red.opacity(0.6))
                    .clipShape(Capsule())
            }
            
            // Stats row
            HStack(spacing: 16) {
                StatBadge(
                    icon: "person.fill",
                    label: "Active",
                    count: viewModel.activeGuestCount(for: event.id ?? ""),
                    color: .green
                )
                
                StatBadge(
                    icon: "clock.fill",
                    label: "Pending",
                    count: viewModel.pendingCount(for: event.id ?? ""),
                    color: .orange
                )
                
                StatBadge(
                    icon: "location.fill",
                    label: "Inside",
                    count: viewModel.insideFenceCount(for: event.id ?? ""),
                    color: .cyan
                )
                
                Spacer()
                
                if let cap = event.capacity {
                    Text("\(viewModel.totalTickets(for: event.id ?? ""))/\(cap)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .onAppear {
            if let eventId = event.id {
                viewModel.startListeningToTickets(for: eventId)
            }
        }
    }
}

struct StatBadge: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text("\(count)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Event Guest Tracker

struct EventGuestTrackerView: View {
    let event: Event
    @ObservedObject var viewModel: AdminViewModel
    @State private var selectedTab = 0
    
    var eventId: String { event.id ?? "" }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Stats header
                HStack(spacing: 0) {
                    GuestStatTile(value: viewModel.activeGuestCount(for: eventId), label: "Active", color: .green)
                    GuestStatTile(value: viewModel.pendingCount(for: eventId), label: "Pending", color: .orange)
                    GuestStatTile(value: viewModel.insideFenceCount(for: eventId), label: "Inside", color: .cyan)
                    GuestStatTile(value: viewModel.expiredCount(for: eventId), label: "Expired", color: .red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Capacity bar
                if let capacity = event.capacity, capacity > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Capacity")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text("\(viewModel.totalTickets(for: eventId)) / \(capacity)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [.cyan, .green],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geo.size.width * min(1.0, Double(viewModel.totalTickets(for: eventId)) / Double(capacity)),
                                        height: 6
                                    )
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Guests").tag(0)
                    Text("Logs").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Content
                if selectedTab == 0 {
                    guestListView
                } else {
                    attendanceLogsView
                }
            }
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await viewModel.toggleEventActive(event: event) }
                } label: {
                    Text(event.isActive ? "Deactivate" : "Activate")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(event.isActive ? .red : .green)
                }
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
    
    // MARK: - Guest List
    
    private var guestListView: some View {
        let tickets = viewModel.eventTickets[eventId] ?? []
        
        return Group {
            if tickets.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No guests yet")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(tickets) { ticket in
                            GuestRow(ticket: ticket)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
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
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No activity logs")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(logs) { log in
                            LogRow(log: log)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
    }
}

// MARK: - Guest Row

struct GuestRow: View {
    let ticket: Ticket
    
    var statusIcon: String {
        switch ticket.status {
        case .active: return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .expired: return "xmark.circle.fill"
        }
    }
    
    var statusColor: Color {
        switch ticket.status {
        case .active: return .green
        case .pending: return .orange
        case .expired: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.ownerId.prefix(12) + "...")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                HStack(spacing: 8) {
                    Text(ticket.statusDisplayText)
                        .font(.system(size: 11))
                        .foregroundColor(statusColor)
                    
                    if ticket.insideFence {
                        Label("Inside", systemImage: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                    }
                    
                    if ticket.biometricVerified {
                        Label("Bio ✓", systemImage: "faceid")
                            .font(.system(size: 10))
                            .foregroundColor(.green.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            if let entryCode = ticket.entryCode {
                Text(entryCode)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Log Row

struct LogRow: View {
    let log: AttendanceLog
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: log.typeIcon)
                .foregroundColor(Color(log.typeColor))
                .font(.system(size: 14))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(log.type.capitalized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Text(log.ticketId.prefix(16) + "...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            Spacer()
            
            if let ts = log.timestamp {
                Text(ts.dateValue().formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Guest Stat Tile

struct GuestStatTile: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
}
