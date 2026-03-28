//
//  AdminHomeView.swift
//  DIGIFENCEV1
//
//  Modern admin home with quick stats, recent activity, and navigation to events/team.
//

import SwiftUI
import FirebaseFirestore

struct AdminHomeView: View {
    @Binding var selectedTab: Int
    @ObservedObject var firebase = FirebaseManager.shared
    @StateObject private var viewModel = AdminViewModel()
    @State private var showProfile = false
    @State private var showCreateEvent = false
    @State private var appeared = false

    private var activeEvents: [Event] {
        viewModel.allAdminEvents.filter { event in
            event.isActive && !(event.endsAt.map { $0.dateValue() <= Date() } ?? false)
        }
    }

    private var totalGuests: Int {
        activeEvents.reduce(0) { $0 + viewModel.totalTickets(for: $1.id ?? "") }
    }

    private var totalCheckedIn: Int {
        activeEvents.reduce(0) { $0 + viewModel.activeGuestCount(for: $1.id ?? "") }
    }

    private var totalInsideFence: Int {
        activeEvents.reduce(0) { $0 + viewModel.insideFenceCount(for: $1.id ?? "") }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DFSpacing.xl) {
                    // Header
                    adminHeader

                    // Quick Stats
                    statsRow
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    // Quick Actions
                    quickActions

                    // Recent Activity Feed
                    if !activeEvents.isEmpty {
                        recentActivitySection
                    }

                    // Active Events Preview
                    if !activeEvents.isEmpty {
                        activeEventsSection
                    }

                    // Empty state
                    if viewModel.allAdminEvents.isEmpty {
                        VStack(spacing: DFSpacing.lg) {
                            DFIconBadge(icon: "calendar.badge.plus", color: .dfAccent, size: 64, iconSize: 28)
                            Text("No events yet")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Create your first event to get started")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            DFPrimaryButton(title: "Create Event", icon: "plus.circle.fill", height: 44) {
                                selectedTab = 1
                            }
                            .padding(.horizontal, DFSpacing.xxxl)
                        }
                        .padding(.vertical, DFSpacing.xxl)
                    }
                }
                .padding(.horizontal, DFSpacing.lg)
                .padding(.top, DFSpacing.sm)
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text("") }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { HapticManager.shared.light(); showProfile = true } label: {
                    AdminProfileAvatarButton(name: firebase.appUser?.displayName ?? "A")
                }
            }
        }
        .sheet(isPresented: $showProfile) { AdminProfileSheet() }
        .sheet(isPresented: $showCreateEvent) {
            NavigationStack { AdminMapView() }
        }
        .onAppear {
            viewModel.startListeningToMyEvents()
            for e in viewModel.allAdminEvents {
                if let id = e.id { viewModel.startListeningToTickets(for: id) }
            }
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
        .onDisappear { viewModel.stopListening() }
    }

    // MARK: - Header

    private var adminHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text((firebase.appUser?.displayName ?? "Admin").capitalized)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stats (2x2 Grid)

    private var statsRow: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DFSpacing.sm) {
            AdminAnimatedStatCard(value: "\(viewModel.allAdminEvents.count)", label: "Total Events", icon: "calendar", gradient: [.blue, .cyan])
            AdminAnimatedStatCard(value: "\(activeEvents.count)", label: "Active Now", icon: "bolt.fill", gradient: [.green, .mint])
            AdminAnimatedStatCard(value: "\(totalGuests)", label: "Total Guests", icon: "person.2.fill", gradient: [.orange, .yellow])
            AdminAnimatedStatCard(value: "\(totalInsideFence)", label: "Inside Fence", icon: "location.fill", gradient: [.purple, .pink])
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            Text("Quick Actions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: DFSpacing.md) {
                AdminActionCard(icon: "plus.circle.fill", title: "New Event", color: .dfAccent) {
                    showCreateEvent = true
                }
                AdminActionCard(icon: "shield.lefthalf.filled", title: "Team", color: .indigo) {
                    selectedTab = 2
                }
            }
        }
    }

    // MARK: - Active Events

    private var activeEventsSection: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            HStack {
                Text("Active Events")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Button {
                    selectedTab = 1
                } label: {
                    Text("See All")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.dfAccent)
                }
            }

            ForEach(Array(activeEvents.prefix(3).enumerated()), id: \.element.id) { index, event in
                NavigationLink(destination: EventGuestTrackerView(event: event, viewModel: viewModel)) {
                    AdminEventPreviewCard(event: event, viewModel: viewModel)
                }
                .buttonStyle(DFCardButtonStyle())
                .entranceAnimation(index: index, baseDelay: 0.1)
            }
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            HStack {
                Text("Recent Activity")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("Live").font(.system(size: 11, weight: .medium)).foregroundColor(.green)
            }

            VStack(spacing: DFSpacing.sm) {
                // Show live stats as activity items
                ForEach(activeEvents.prefix(3), id: \.id) { event in
                    let eid = event.id ?? ""
                    let inside = viewModel.insideFenceCount(for: eid)
                    let active = viewModel.activeGuestCount(for: eid)
                    HStack(spacing: DFSpacing.md) {
                        ZStack {
                            Circle().fill(Color.green.opacity(0.12)).frame(width: 36, height: 36)
                            Image(systemName: inside > 0 ? "location.fill" : "clock.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(inside > 0 ? .green : .orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text("\(active) checked in · \(inside) inside fence")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(DFSpacing.sm)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.sm, style: .continuous))
                }
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning 👋" }
        else if hour < 17 { return "Good afternoon 👋" }
        else { return "Good evening 👋" }
    }
}

// MARK: - Admin Animated Stat Card (2x2 grid)

struct AdminAnimatedStatCard: View {
    let value: String
    let label: String
    let icon: String
    let gradient: [Color]
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                Spacer()
            }
            HStack {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Spacer()
            }
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appeared = true } }
    }
}

// MARK: - Admin Mini Stat (kept for compatibility)

struct AdminMiniStat: View {
    let value: String
    let label: String
    let icon: String
    let gradient: [Color]

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
    }
}

// MARK: - Admin Action Card

struct AdminActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DFSpacing.lg)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
        }
        .buttonStyle(DFScaleButtonStyle())
    }
}

// MARK: - Admin Event Preview Card

struct AdminEventPreviewCard: View {
    let event: Event
    @ObservedObject var viewModel: AdminViewModel

    private var eventId: String { event.id ?? "" }

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            // Thumbnail
            Group {
                if let urlStr = event.thumbnailURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: thumbnailPlaceholder
                        }
                    }
                } else {
                    thumbnailPlaceholder
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                HStack(spacing: DFSpacing.md) {
                    Label("\(viewModel.totalTickets(for: eventId))", systemImage: "person.2.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                    Label("\(viewModel.activeGuestCount(for: eventId))", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                    Label("\(viewModel.insideFenceCount(for: eventId))", systemImage: "location.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
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

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.cyan.opacity(0.15), .blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Image(systemName: "calendar").font(.system(size: 18)).foregroundStyle(.tertiary))
    }
}

// MARK: - Admin Profile Avatar

struct AdminProfileAvatarButton: View {
    let name: String
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.indigo.opacity(0.2), .purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 34, height: 34)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.indigo)
        }
    }
}
