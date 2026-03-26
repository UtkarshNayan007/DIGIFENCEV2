//
//  MainTabView.swift
//  DIGIFENCEV1
//
//  Tab navigation — separate admin and user experiences, shared design language.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MainTabView: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if firebase.appUser?.isAdmin == true {
                AdminTabView(selectedTab: $selectedTab)
            } else if firebase.appUser?.isSecurity == true {
                SecurityTabView(selectedTab: $selectedTab)
            } else {
                UserTabView(selectedTab: $selectedTab)
            }
        }
        .tint(.dfAccent)
        .onChange(of: selectedTab) { HapticManager.shared.selection() }
    }
}

// MARK: - User Tabs

struct UserTabView: View {
    @Binding var selectedTab: Int
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { EventsListView() }
                .tabItem { Label("Events", systemImage: selectedTab == 0 ? "calendar.badge.plus" : "calendar") }
                .tag(0)
            NavigationStack { MyPassView() }
                .tabItem { Label("Passes", systemImage: selectedTab == 1 ? "ticket.fill" : "ticket") }
                .tag(1)
            NavigationStack { UserNotificationsView() }
                .tabItem { Label("Updates", systemImage: selectedTab == 2 ? "bell.badge.fill" : "bell") }
                .tag(2)
        }
    }
}

// MARK: - Admin Tabs (3 tabs: Home, Events, Team)

struct AdminTabView: View {
    @Binding var selectedTab: Int
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { AdminHomeView(selectedTab: $selectedTab) }
                .tabItem { Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house") }
                .tag(0)
            NavigationStack { AdminEventsView() }
                .tabItem { Label("Events", systemImage: selectedTab == 1 ? "calendar.badge.plus" : "calendar") }
                .tag(1)
            NavigationStack { SecurityTeamView() }
                .tabItem { Label("Team", systemImage: selectedTab == 2 ? "shield.lefthalf.filled" : "shield") }
                .tag(2)
        }
    }
}

// MARK: - Security Tabs (single Check-In tab)

struct SecurityTabView: View {
    @Binding var selectedTab: Int
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { QRScannerView() }
                .tabItem { Label("Check-In", systemImage: selectedTab == 0 ? "qrcode.viewfinder" : "qrcode") }
                .tag(0)
            NavigationStack { SecurityProfileView() }
                .tabItem { Label("Profile", systemImage: selectedTab == 1 ? "person.fill" : "person") }
                .tag(1)
        }
    }
}

// MARK: - Admin Home View

struct AdminHomeView: View {
    @Binding var selectedTab: Int
    @StateObject private var viewModel = AdminViewModel()
    @State private var showProfile = false
    @State private var showCreateEvent = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: DFSpacing.xl) {
                    // Greeting header
                    adminGreetingHeader
                    // Quick Stats
                    statsGrid
                    // Quick Actions
                    quickActions
                    // Recent Events
                    if !viewModel.allAdminEvents.isEmpty {
                        recentEvents
                    }
                }
                .padding(.horizontal, DFSpacing.lg)
                .padding(.top, DFSpacing.sm)
                .padding(.bottom, 100)
            }
            .refreshable {
                viewModel.stopListening()
                viewModel.startListeningToMyEvents()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text("") }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { HapticManager.shared.light(); showProfile = true } label: {
                    ProfileAvatarButton(name: FirebaseManager.shared.appUser?.displayName ?? "A")
                }
            }
        }
        .sheet(isPresented: $showProfile) { AdminProfileSheet() }
        .sheet(isPresented: $showCreateEvent) { NavigationStack { AdminMapView() } }
        .onAppear {
            viewModel.startListeningToMyEvents()
            withAnimation(.easeOut(duration: 0.3)) { appeared = true }
        }
        .onDisappear { viewModel.stopListening() }
    }

    private var adminGreetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 17 { return "Good afternoon" }
        else { return "Good evening" }
    }

    private var adminGreetingHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(adminGreetingText + " 👋")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Text(FirebaseManager.shared.appUser?.displayName ?? "Admin")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeEvents: [Event] {
        viewModel.allAdminEvents.filter { event in
            event.isActive && !(event.endsAt.map { $0.dateValue() <= Date() } ?? false)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DFSpacing.md) {
            NavigationLink(destination: AllEventsDetailView(viewModel: viewModel)) {
                AdminStatCard(value: "\(viewModel.allAdminEvents.count)", label: "Total Events", icon: "calendar", color: .blue)
            }
            .buttonStyle(.plain)
            NavigationLink(destination: ActiveEventsDetailView(viewModel: viewModel)) {
                AdminStatCard(value: "\(activeEvents.count)", label: "Active", icon: "bolt.fill", color: .green)
            }
            .buttonStyle(.plain)
            NavigationLink(destination: GuestsDetailView(viewModel: viewModel)) {
                AdminStatCard(value: "\(totalGuests)", label: "Guests", icon: "person.2.fill", color: .orange)
            }
            .buttonStyle(.plain)
            NavigationLink(destination: InsideFenceDetailView(viewModel: viewModel)) {
                AdminStatCard(value: "\(totalInsideFence)", label: "Inside Fence", icon: "location.fill", color: .purple)
            }
            .buttonStyle(.plain)
        }
        .opacity(appeared ? 1 : 0)
    }

    private var totalGuests: Int {
        activeEvents.reduce(0) { $0 + viewModel.totalTickets(for: $1.id ?? "") }
    }
    private var totalInsideFence: Int {
        activeEvents.reduce(0) { $0 + viewModel.insideFenceCount(for: $1.id ?? "") }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            DFSectionHeader(title: "Quick Actions", icon: "bolt.fill", iconColor: .orange)
            HStack(spacing: DFSpacing.md) {
                QuickActionCard(icon: "shield.lefthalf.filled", title: "Security Team", color: .blue) {
                    selectedTab = 2
                }
                QuickActionCard(icon: "plus.circle.fill", title: "New Event", color: .green) {
                    showCreateEvent = true
                }
            }
        }
    }

    private var recentEvents: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            DFSectionHeader(title: "Recent Events", icon: "clock.fill", iconColor: .gray)
            ForEach(Array(viewModel.allAdminEvents.prefix(3).enumerated()), id: \.element.id) { index, event in
                NavigationLink(destination: EventGuestTrackerView(event: event, viewModel: viewModel)) {
                    AdminEventRow(event: event, viewModel: viewModel)
                }
                .buttonStyle(DFCardButtonStyle())
                .entranceAnimation(index: index, baseDelay: 0.1)
            }
        }
    }
}


// MARK: - Admin Events View

struct AdminEventsView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var showCreateEvent = false
    @State private var searchText = ""

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if viewModel.allAdminEvents.isEmpty {
                DFEmptyState(icon: "calendar.badge.exclamationmark", title: "No Events", message: "Create your first event to get started.", actionTitle: "Create Event") {
                    showCreateEvent = true
                }
            } else {
                VStack(spacing: 0) {
                    DFFloatingSearchBar(text: $searchText, placeholder: "Search events...")
                        .padding(.horizontal, DFSpacing.lg)
                        .padding(.vertical, DFSpacing.sm)
                    ScrollView {
                        LazyVStack(spacing: DFSpacing.md) {
                            ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, event in
                                DashboardEventCard(event: event, viewModel: viewModel)
                                    .entranceAnimation(index: index)
                            }
                        }
                        .padding(.horizontal, DFSpacing.lg)
                        .padding(.top, DFSpacing.sm)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        viewModel.stopListening()
                        viewModel.startListeningToMyEvents()
                        for e in viewModel.allAdminEvents {
                            if let id = e.id { viewModel.startListeningToTickets(for: id) }
                        }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
            }
        }
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showCreateEvent = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.dfAccent)
                }
            }
        }
        .sheet(isPresented: $showCreateEvent) { NavigationStack { AdminMapView() } }
        .onAppear {
            viewModel.startListeningToMyEvents()
            for e in viewModel.allAdminEvents {
                if let id = e.id { viewModel.startListeningToTickets(for: id) }
            }
        }
        .onDisappear { viewModel.stopListening() }
    }

    private var filteredEvents: [Event] {
        if searchText.isEmpty { return viewModel.allAdminEvents }
        return viewModel.allAdminEvents.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Admin Event Row (compact)

struct AdminEventRow: View {
    let event: Event
    @ObservedObject var viewModel: AdminViewModel
    private var eventId: String { event.id ?? "" }

    private var isEventTimeOver: Bool {
        guard let endsAt = event.endsAt else { return false }
        return endsAt.dateValue() <= Date()
    }

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            // Thumbnail or icon
            ZStack {
                RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous)
                    .fill(event.isActive && !isEventTimeOver ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: event.isActive && !isEventTimeOver ? "bolt.fill" : isEventTimeOver ? "clock.badge.xmark" : "moon.fill")
                    .font(.system(size: 18))
                    .foregroundColor(event.isActive && !isEventTimeOver ? .green : .gray)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label("\(viewModel.totalTickets(for: eventId))", systemImage: "person.2.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Label("\(viewModel.insideFenceCount(for: eventId))", systemImage: "location.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        .onAppear { viewModel.startListeningToTickets(for: eventId) }
    }
}



// MARK: - User Notifications View

struct UserNotificationsView: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @State private var notifications: [UserNotification] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if isLoading {
                ProgressView().controlSize(.large).tint(.dfAccent)
            } else if notifications.isEmpty {
                DFEmptyState(icon: "bell.slash", title: "No Updates", message: "You'll see event updates and notifications here.")
            } else {
                ScrollView {
                    LazyVStack(spacing: DFSpacing.sm) {
                        ForEach(Array(notifications.enumerated()), id: \.element.id) { index, notif in
                            NotificationRow(notification: notif)
                                .entranceAnimation(index: index)
                        }
                    }
                    .padding(.horizontal, DFSpacing.lg)
                    .padding(.top, DFSpacing.sm)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await refreshNotifications()
                }
            }
        }
        .navigationTitle("Updates")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { loadNotifications() }
    }

    private func refreshNotifications() async {
        guard let uid = firebase.currentUser?.uid else { return }
        do {
            let ticketSnap = try await FirebaseManager.shared.ticketsCollection
                .whereField("ownerId", isEqualTo: uid)
                .getDocuments()
            
            // Build ticketId -> eventId mapping
            var ticketEventMap: [String: String] = [:]
            var eventIds: Set<String> = []
            for doc in ticketSnap.documents {
                let data = doc.data()
                if let eventId = data["eventId"] as? String {
                    ticketEventMap[doc.documentID] = eventId
                    eventIds.insert(eventId)
                }
            }
            
            // Fetch event titles
            var eventTitles: [String: String] = [:]
            for eventId in eventIds {
                let eventDoc = try await Firestore.firestore().collection("events").document(eventId).getDocument()
                if let title = eventDoc.data()?["title"] as? String {
                    eventTitles[eventId] = title
                }
            }
            
            let myTicketIds = Set(ticketSnap.documents.map { $0.documentID })
            var notifs: [UserNotification] = []
            for chunk in Array(myTicketIds).chunked(into: 10) {
                let snap = try await Firestore.firestore()
                    .collection("attendance_logs")
                    .whereField("ticketId", in: Array(chunk))
                    .order(by: "timestamp", descending: true)
                    .limit(to: 100)
                    .getDocuments()
                for doc in snap.documents {
                    let data = doc.data()
                    let ticketId = data["ticketId"] as? String ?? ""
                    let eventId = ticketEventMap[ticketId]
                    notifs.append(UserNotification(
                        id: doc.documentID,
                        type: data["type"] as? String ?? "update",
                        ticketId: ticketId,
                        detail: data["detail"] as? [String: Any],
                        timestamp: data["timestamp"] as? Timestamp,
                        eventTitle: eventId.flatMap { eventTitles[$0] }
                    ))
                }
            }
            notifications = notifs.sorted {
                ($0.timestamp?.dateValue() ?? .distantPast) > ($1.timestamp?.dateValue() ?? .distantPast)
            }
        } catch {
            print("❌ Refresh notifications error: \(error)")
        }
    }

    private func loadNotifications() {
        guard let uid = firebase.currentUser?.uid else { isLoading = false; return }
        Task {
            do {
                let ticketSnap = try await FirebaseManager.shared.ticketsCollection
                    .whereField("ownerId", isEqualTo: uid)
                    .getDocuments()
                
                // Build ticketId -> eventId mapping
                var ticketEventMap: [String: String] = [:]
                var eventIds: Set<String> = []
                for doc in ticketSnap.documents {
                    let data = doc.data()
                    if let eventId = data["eventId"] as? String {
                        ticketEventMap[doc.documentID] = eventId
                        eventIds.insert(eventId)
                    }
                }
                
                // Fetch event titles
                var eventTitles: [String: String] = [:]
                for eventId in eventIds {
                    let eventDoc = try await Firestore.firestore().collection("events").document(eventId).getDocument()
                    if let title = eventDoc.data()?["title"] as? String {
                        eventTitles[eventId] = title
                    }
                }
                
                let myTicketIds = Set(ticketSnap.documents.map { $0.documentID })
                var notifs: [UserNotification] = []
                for chunk in Array(myTicketIds).chunked(into: 10) {
                    let snap = try await Firestore.firestore()
                        .collection("attendance_logs")
                        .whereField("ticketId", in: Array(chunk))
                        .order(by: "timestamp", descending: true)
                        .limit(to: 100)
                        .getDocuments()
                    for doc in snap.documents {
                        let data = doc.data()
                        let ticketId = data["ticketId"] as? String ?? ""
                        let eventId = ticketEventMap[ticketId]
                        notifs.append(UserNotification(
                            id: doc.documentID,
                            type: data["type"] as? String ?? "update",
                            ticketId: ticketId,
                            detail: data["detail"] as? [String: Any],
                            timestamp: data["timestamp"] as? Timestamp,
                            eventTitle: eventId.flatMap { eventTitles[$0] }
                        ))
                    }
                }
                notifications = notifs.sorted {
                    ($0.timestamp?.dateValue() ?? .distantPast) > ($1.timestamp?.dateValue() ?? .distantPast)
                }
            } catch {
                print("❌ Load notifications error: \(error)")
            }
            isLoading = false
        }
    }
}

struct UserNotification: Identifiable {
    let id: String
    let type: String
    let ticketId: String
    var detail: [String: Any]?
    var timestamp: Timestamp?
    var eventTitle: String?

    var icon: String {
        switch type {
        case "activated": return "checkmark.circle.fill"
        case "exited": return "arrow.right.circle.fill"
        case "expired":
            if let reason = detail?["reason"] as? String, reason == "event_ended" {
                return "party.popper.fill"
            }
            return "xmark.circle.fill"
        default: return "bell.fill"
        }
    }
    var color: Color {
        switch type {
        case "activated": return .green
        case "exited": return .orange
        case "expired":
            if let reason = detail?["reason"] as? String, reason == "event_ended" {
                return .purple
            }
            return .red
        default: return .blue
        }
    }
    var message: String {
        switch type {
        case "activated": return "Your pass was activated"
        case "exited": return "You exited the geofence"
        case "expired":
            if let reason = detail?["reason"] as? String, reason == "event_ended" {
                return "Event is over! 🎉 Hope you enjoyed!"
            }
            return "Your pass has expired"
        default: return "Update on your ticket"
        }
    }
}


private struct NotificationRow: View {
    let notification: UserNotification
    var body: some View {
        HStack(spacing: DFSpacing.md) {
            DFIconBadge(icon: notification.icon, color: notification.color, size: 38, iconSize: 16)
            VStack(alignment: .leading, spacing: 3) {
                if let eventTitle = notification.eventTitle, !eventTitle.isEmpty {
                    Text(eventTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                Text(notification.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                if let ts = notification.timestamp {
                    Text(ts.dateValue().formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
    }
}

// MARK: - Admin Profile Sheet

struct AdminProfileSheet: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @StateObject private var authVM = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutConfirm = false
    @State private var appeared = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DFSpacing.xl) {
                    adminProfileHeader
                    adminAccountInfo
                    DFDestructiveButton(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right") {
                        showSignOutConfirm = true
                    }
                    Text("DigiFence v1.0").font(.footnote).foregroundColor(Color(.quaternaryLabel)).padding(.top, DFSpacing.sm)
                }
                .padding(.horizontal, DFSpacing.lg).padding(.top, DFSpacing.lg).padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
            .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { authVM.signOut(); dismiss() }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true } }
        }
    }

    private var adminProfileHeader: some View {
        VStack(spacing: DFSpacing.lg) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple.opacity(0.2), .blue.opacity(0.15), .cyan.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 90, height: 90)
                    .scaleEffect(appeared ? 1 : 0.5)
                Circle()
                    .stroke(LinearGradient(colors: [.purple.opacity(0.5), .cyan.opacity(0.3)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                    .frame(width: 90, height: 90)
                Text(String(firebase.appUser?.displayName.prefix(1).uppercased() ?? "A"))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .scaleEffect(appeared ? 1 : 0.3)
            }
            VStack(spacing: 6) {
                Text(firebase.appUser?.displayName ?? "Admin")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(firebase.appUser?.email ?? "")
                    .font(.system(size: 13)).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    DFStatusBadge(text: "ADMIN", color: .purple, size: .medium)
                    if let created = firebase.appUser?.createdAt {
                        Text("Since \(created.dateValue().formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, DFSpacing.xl)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
        .opacity(appeared ? 1 : 0)
    }

    private var adminAccountInfo: some View {
        VStack(spacing: 0) {
            ProfileInfoRow(icon: "person.fill", iconColor: .blue, label: "Name", value: firebase.appUser?.displayName ?? "-")
            DFDivider(leadingInset: 50)
            ProfileInfoRow(icon: "envelope.fill", iconColor: .green, label: "Email", value: firebase.appUser?.email ?? "-")
            DFDivider(leadingInset: 50)
            ProfileInfoRow(icon: "shield.fill", iconColor: .purple, label: "Role", value: "Administrator")
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
    }
}

// MARK: - Shared Components

struct AdminStatCard: View {
    let value: String; let label: String; let icon: String; let color: Color
    @State private var appeared = false
    var body: some View {
        VStack(spacing: DFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DFSpacing.xl)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appeared = true } }
    }
}

struct QuickActionCard: View {
    let icon: String; let title: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: { HapticManager.shared.medium(); action() }) {
            VStack(spacing: DFSpacing.md) {
                DFIconBadge(icon: icon, color: color, size: 48, iconSize: 22)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DFSpacing.xl)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        }
        .buttonStyle(DFScaleButtonStyle())
    }
}

struct ProfileAvatarButton: View {
    let name: String
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.cyan.opacity(0.2), .blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 34, height: 34)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.dfAccent)
        }
    }
}

struct ProfileInfoRow: View {
    let icon: String; let iconColor: Color; let label: String; let value: String
    var body: some View {
        HStack(spacing: DFSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 26)
            Text(label).font(.system(size: 14)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 14, weight: .medium)).lineLimit(1)
        }
        .padding(.horizontal, DFSpacing.lg).padding(.vertical, 11)
    }
}


struct InfoDisplayRow: View {
    let icon: String; let label: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: DFSpacing.md) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundColor(color).frame(width: 24)
            Text(label).font(.system(size: 13)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium))
        }
    }
}

// MARK: - All Events Detail View

struct AllEventsDetailView: View {
    @ObservedObject var viewModel: AdminViewModel

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if viewModel.allAdminEvents.isEmpty {
                DFEmptyState(icon: "calendar.badge.exclamationmark", title: "No Events", message: "You haven't created any events yet.")
            } else {
                ScrollView {
                    LazyVStack(spacing: DFSpacing.md) {
                        ForEach(Array(viewModel.allAdminEvents.enumerated()), id: \.element.id) { index, event in
                            DashboardEventCard(event: event, viewModel: viewModel)
                                .entranceAnimation(index: index)
                        }
                    }
                    .padding(.horizontal, DFSpacing.lg)
                    .padding(.top, DFSpacing.sm)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("All Events")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            for e in viewModel.allAdminEvents {
                if let id = e.id { viewModel.startListeningToTickets(for: id) }
            }
        }
    }
}

// MARK: - Active Events Detail View

struct ActiveEventsDetailView: View {
    @ObservedObject var viewModel: AdminViewModel

    private var activeEvents: [Event] {
        viewModel.allAdminEvents.filter { event in
            event.isActive && !(event.endsAt.map { $0.dateValue() <= Date() } ?? false)
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if activeEvents.isEmpty {
                DFEmptyState(icon: "bolt.slash", title: "No Active Events", message: "There are no currently active events.")
            } else {
                ScrollView {
                    LazyVStack(spacing: DFSpacing.md) {
                        ForEach(Array(activeEvents.enumerated()), id: \.element.id) { index, event in
                            DashboardEventCard(event: event, viewModel: viewModel)
                                .entranceAnimation(index: index)
                        }
                    }
                    .padding(.horizontal, DFSpacing.lg)
                    .padding(.top, DFSpacing.sm)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Active Events")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            for e in activeEvents {
                if let id = e.id { viewModel.startListeningToTickets(for: id) }
            }
        }
    }
}

// MARK: - Guests Detail View

struct GuestsDetailView: View {
    @ObservedObject var viewModel: AdminViewModel

    private var activeEvents: [Event] {
        viewModel.allAdminEvents.filter { event in
            event.isActive && !(event.endsAt.map { $0.dateValue() <= Date() } ?? false)
        }
    }

    private var totalGuests: Int {
        activeEvents.reduce(0) { $0 + viewModel.totalTickets(for: $1.id ?? "") }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if activeEvents.isEmpty {
                DFEmptyState(icon: "person.2.slash", title: "No Active Events", message: "Guest counts are shown for active events only.")
            } else {
                ScrollView {
                    VStack(spacing: DFSpacing.lg) {
                        // Summary card
                        VStack(spacing: DFSpacing.sm) {
                            Text("\(totalGuests)")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                                .contentTransition(.numericText())
                            Text("Total Guests Across Active Events")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DFSpacing.xl)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))

                        // Per-event breakdown
                        DFSectionHeader(title: "Guests Per Event", icon: "person.2.fill", iconColor: .orange)
                        ForEach(Array(activeEvents.enumerated()), id: \.element.id) { index, event in
                            let eventId = event.id ?? ""
                            NavigationLink(destination: EventGuestTrackerView(event: event, viewModel: viewModel)) {
                                DetailEventRow(
                                    eventTitle: event.title,
                                    value: viewModel.totalTickets(for: eventId),
                                    label: "guests",
                                    icon: "person.2.fill",
                                    color: .orange,
                                    isActive: event.isActive
                                )
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
        .navigationTitle("Guests")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            for e in activeEvents {
                if let id = e.id { viewModel.startListeningToTickets(for: id) }
            }
        }
    }
}

// MARK: - Inside Fence Detail View

struct InsideFenceDetailView: View {
    @ObservedObject var viewModel: AdminViewModel

    private var activeEvents: [Event] {
        viewModel.allAdminEvents.filter { event in
            event.isActive && !(event.endsAt.map { $0.dateValue() <= Date() } ?? false)
        }
    }

    private var totalInsideFence: Int {
        activeEvents.reduce(0) { $0 + viewModel.insideFenceCount(for: $1.id ?? "") }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if activeEvents.isEmpty {
                DFEmptyState(icon: "location.slash", title: "No Active Events", message: "Inside fence counts are shown for active events only.")
            } else {
                ScrollView {
                    VStack(spacing: DFSpacing.lg) {
                        // Summary card
                        VStack(spacing: DFSpacing.sm) {
                            Text("\(totalInsideFence)")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.purple)
                                .contentTransition(.numericText())
                            Text("Total Inside Fence Across Active Events")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DFSpacing.xl)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))

                        // Per-event breakdown
                        DFSectionHeader(title: "Inside Fence Per Event", icon: "location.fill", iconColor: .purple)
                        ForEach(Array(activeEvents.enumerated()), id: \.element.id) { index, event in
                            let eventId = event.id ?? ""
                            NavigationLink(destination: EventGuestTrackerView(event: event, viewModel: viewModel)) {
                                DetailEventRow(
                                    eventTitle: event.title,
                                    value: viewModel.insideFenceCount(for: eventId),
                                    label: "inside",
                                    icon: "location.fill",
                                    color: .purple,
                                    isActive: event.isActive
                                )
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
        .navigationTitle("Inside Fence")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            for e in activeEvents {
                if let id = e.id { viewModel.startListeningToTickets(for: id) }
            }
        }
    }
}

// MARK: - Detail Event Row (shared component for detail views)

struct DetailEventRow: View {
    let eventTitle: String
    let value: Int
    let label: String
    let icon: String
    let color: Color
    let isActive: Bool

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            // Status indicator
            ZStack {
                RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous)
                    .fill(isActive ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: isActive ? "bolt.fill" : "moon.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isActive ? .green : .gray)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(eventTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(color)
                    Text("\(value) \(label)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(color)
                }
            }
            Spacer()
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
    }
}
