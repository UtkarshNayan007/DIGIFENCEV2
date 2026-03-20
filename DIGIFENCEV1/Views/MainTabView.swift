//
//  MainTabView.swift
//  DIGIFENCEV1
//
//  Premium tab navigation with separate admin and user experiences.
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if firebase.appUser?.isAdmin == true {
                AdminTabView(selectedTab: $selectedTab)
            } else {
                UserTabView(selectedTab: $selectedTab)
            }
        }
        .tint(.dfAccent)
        .onChange(of: selectedTab) {
            HapticManager.shared.selection()
        }
    }
}

// MARK: - User Tab View

struct UserTabView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { EventsListView() }
                .tabItem {
                    Label("Events", systemImage: selectedTab == 0 ? "calendar.badge.plus" : "calendar")
                }
                .tag(0)
            
            NavigationStack { MyPassView() }
                .tabItem {
                    Label("Passes", systemImage: selectedTab == 1 ? "ticket.fill" : "ticket")
                }
                .tag(1)
            
            NavigationStack { ProfileView() }
                .tabItem {
                    Label("Profile", systemImage: selectedTab == 2 ? "person.circle.fill" : "person.circle")
                }
                .tag(2)
        }
    }
}

// MARK: - Admin Tab View (Home, Events, Scanner, Dashboard)

struct AdminTabView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { AdminHomeView() }
                .tabItem {
                    Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)
            
            NavigationStack { AdminEventsView() }
                .tabItem {
                    Label("Events", systemImage: selectedTab == 1 ? "calendar.badge.plus" : "calendar")
                }
                .tag(1)
            
            NavigationStack { AdminCheckInView() }
                .tabItem {
                    Label("Check-In", systemImage: selectedTab == 2 ? "qrcode.viewfinder" : "qrcode")
                }
                .tag(2)
            
            NavigationStack { AdminDashboardView() }
                .tabItem {
                    Label("Dashboard", systemImage: selectedTab == 3 ? "chart.bar.fill" : "chart.bar")
                }
                .tag(3)
        }
    }
}

// MARK: - Admin Home View

struct AdminHomeView: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @StateObject private var viewModel = AdminViewModel()
    @State private var showProfile = false
    @State private var appeared = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: DFSpacing.xl) {
                // Welcome Header
                welcomeHeader
                
                // Quick Stats
                quickStatsSection
                
                // Quick Actions
                quickActionsSection
                
                // Recent Events
                recentEventsSection
            }
            .padding(.horizontal, DFSpacing.lg)
            .padding(.top, DFSpacing.sm)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("DigiFence")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    HapticManager.shared.light()
                    showProfile = true
                }) {
                    ProfileAvatarButton(name: firebase.appUser?.displayName ?? "A")
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            AdminProfileSheet()
        }
        .onAppear {
            viewModel.startListeningToMyEvents()
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
        .onDisappear { viewModel.stopListening() }
    }

    // MARK: - Welcome Header
    
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: DFSpacing.sm) {
            Text("Welcome back,")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            Text(firebase.appUser?.displayName ?? "Admin")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DFSpacing.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            DFSectionHeader(title: "Overview", icon: "chart.pie.fill", iconColor: .dfAccent)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DFSpacing.md) {
                AdminStatCard(
                    value: "\(viewModel.allAdminEvents.count)",
                    label: "Total Events",
                    icon: "calendar",
                    color: .blue
                )
                
                AdminStatCard(
                    value: "\(viewModel.allAdminEvents.filter { $0.isActive }.count)",
                    label: "Active Events",
                    icon: "bolt.fill",
                    color: .green
                )
                
                AdminStatCard(
                    value: "\(totalGuests)",
                    label: "Total Guests",
                    icon: "person.2.fill",
                    color: .orange
                )
                
                AdminStatCard(
                    value: "\(totalCheckedIn)",
                    label: "Checked In",
                    icon: "checkmark.circle.fill",
                    color: .purple
                )
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)
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

    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            DFSectionHeader(title: "Quick Actions", icon: "bolt.fill", iconColor: .orange)
            
            HStack(spacing: DFSpacing.md) {
                QuickActionCard(
                    icon: "qrcode.viewfinder",
                    title: "Scan Pass",
                    color: .cyan
                ) {
                    // Navigate to scanner tab
                }
                
                QuickActionCard(
                    icon: "plus.circle.fill",
                    title: "New Event",
                    color: .green
                ) {
                    // Navigate to events tab
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)
    }
    
    // MARK: - Recent Events Section
    
    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            DFSectionHeader(title: "Recent Events", icon: "clock.fill", iconColor: .purple)
            
            if viewModel.allAdminEvents.isEmpty {
                EmptyRecentEventsCard()
            } else {
                ForEach(viewModel.allAdminEvents.prefix(3)) { event in
                    RecentEventRow(event: event, viewModel: viewModel)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
    }
}

// MARK: - Admin Stat Card

struct AdminStatCard: View {
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
                .font(.system(size: 28, weight: .bold, design: .rounded))
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


// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            VStack(spacing: DFSpacing.md) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DFSpacing.lg)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        }
        .buttonStyle(DFScaleButtonStyle())
    }
}

// MARK: - Profile Avatar Button

struct ProfileAvatarButton: View {
    let name: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.cyan.opacity(0.3), .blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
            
            Text(String(name.prefix(1).uppercased()))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Recent Event Row

struct RecentEventRow: View {
    let event: Event
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
        HStack(spacing: DFSpacing.md) {
            // Event Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(event.isActive ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: event.isActive ? "calendar.badge.checkmark" : "calendar")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(event.isActive ? .green : .gray)
            }
            
            // Event Info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: DFSpacing.sm) {
                    Text("\(viewModel.totalTickets(for: event.id ?? "")) guests")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(event.isActive ? "Active" : "Inactive")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(event.isActive ? .green : .gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.quaternaryLabel))
        }
        .padding(DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
    }
}


// MARK: - Empty Recent Events Card

struct EmptyRecentEventsCard: View {
    var body: some View {
        VStack(spacing: DFSpacing.md) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.secondary)
            
            Text("No events yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DFSpacing.xxl)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
    }
}

// MARK: - Admin Profile Sheet

struct AdminProfileSheet: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @StateObject private var authVM = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutConfirm = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DFSpacing.xl) {
                    // Profile Header
                    profileHeader
                    
                    // Account Info
                    accountInfoSection
                    
                    // Sign Out
                    signOutButton
                }
                .padding(.horizontal, DFSpacing.lg)
                .padding(.top, DFSpacing.lg)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    authVM.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: DFSpacing.lg) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.3), .blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                
                Text(String(firebase.appUser?.displayName.prefix(1).uppercased() ?? "A"))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 6) {
                Text(firebase.appUser?.displayName ?? "Admin")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                
                DFStatusBadge(text: "ADMIN", color: .dfAccent, size: .medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DFSpacing.xl)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
    }

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DFSectionHeader(title: "Account", icon: "person.fill", iconColor: .dfAccent)
                .padding(.horizontal, DFSpacing.xs)
                .padding(.bottom, DFSpacing.md)
            
            VStack(spacing: 0) {
                ProfileInfoRow(
                    icon: "person.fill",
                    iconColor: .blue,
                    label: "Name",
                    value: firebase.appUser?.displayName ?? "-"
                )
                
                DFDivider(leadingInset: 52)
                
                ProfileInfoRow(
                    icon: "envelope.fill",
                    iconColor: .green,
                    label: "Email",
                    value: firebase.appUser?.email ?? "-"
                )
                
                DFDivider(leadingInset: 52)
                
                ProfileInfoRow(
                    icon: "shield.fill",
                    iconColor: .purple,
                    label: "Role",
                    value: firebase.appUser?.role.rawValue.capitalized ?? "Admin"
                )
                
                if let phone = firebase.appUser?.phoneNumber, !phone.isEmpty {
                    DFDivider(leadingInset: 52)
                    
                    ProfileInfoRow(
                        icon: "phone.fill",
                        iconColor: .orange,
                        label: "Phone",
                        value: phone
                    )
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        }
    }
    
    private var signOutButton: some View {
        Button(action: {
            HapticManager.shared.warning()
            showSignOutConfirm = true
        }) {
            HStack(spacing: DFSpacing.md) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                Text("Sign Out")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        }
        .buttonStyle(DFScaleButtonStyle())
    }
}

// MARK: - Admin Events View

struct AdminEventsView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var showCreateEvent = false
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if viewModel.allAdminEvents.isEmpty {
                DFEmptyState(
                    icon: "calendar.badge.plus",
                    title: "No Events",
                    message: "Create your first event to get started.",
                    actionTitle: "Create Event"
                ) {
                    showCreateEvent = true
                }
            } else {
                eventsList
            }
        }
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    HapticManager.shared.light()
                    showCreateEvent = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.dfAccent)
                }
            }
        }
        .sheet(isPresented: $showCreateEvent) {
            NavigationStack { AdminMapView() }
        }
        .onAppear { viewModel.startListeningToMyEvents() }
        .onDisappear { viewModel.stopListening() }
    }

    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: DFSpacing.md) {
                ForEach(Array(viewModel.allAdminEvents.enumerated()), id: \.element.id) { index, event in
                    NavigationLink(destination: EventGuestTrackerView(event: event, viewModel: viewModel)) {
                        AdminEventRow(event: event, viewModel: viewModel)
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

// MARK: - Admin Event Row

struct AdminEventRow: View {
    let event: Event
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let desc = event.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                DFStatusBadge(
                    text: event.isActive ? "LIVE" : "OFF",
                    color: event.isActive ? .green : .gray,
                    size: .small
                )
            }
            
            HStack(spacing: DFSpacing.lg) {
                EventStatPill(icon: "person.2.fill", value: "\(viewModel.totalTickets(for: event.id ?? ""))", color: .blue)
                EventStatPill(icon: "checkmark.circle.fill", value: "\(viewModel.activeGuestCount(for: event.id ?? ""))", color: .green)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(.quaternaryLabel))
            }
        }
        .padding(DFSpacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        .onAppear {
            viewModel.startListeningToTickets(for: event.id ?? "")
        }
    }
}

// MARK: - Event Stat Pill

struct EventStatPill: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}


// MARK: - Admin Check-In View

struct AdminCheckInView: View {
    @StateObject private var viewModel = QRScannerViewModel()
    @State private var showManualEntry = false
    @State private var manualCode = ""
    @State private var selectedMode: CheckInMode = .scanner
    
    enum CheckInMode: String, CaseIterable {
        case scanner = "Scanner"
        case manual = "Manual"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Mode Picker
            Picker("Mode", selection: $selectedMode) {
                ForEach(CheckInMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DFSpacing.lg)
            .padding(.vertical, DFSpacing.md)
            .onChange(of: selectedMode) {
                HapticManager.shared.selection()
            }
            
            if selectedMode == .scanner {
                scannerView
            } else {
                manualEntryView
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Check-In")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedMode == .scanner {
                viewModel.startScanning()
            }
        }
        .onDisappear { viewModel.stopScanning() }
    }
    
    // MARK: - Scanner View
    
    private var scannerView: some View {
        ZStack {
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea(edges: .bottom)
            
            // Scanner Overlay
            VStack {
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.8), lineWidth: 3)
                        .frame(width: 260, height: 260)
                    
                    if viewModel.isScanning {
                        ScanningLine()
                    }
                }
                
                Spacer()
                
                Text("Position QR code within frame")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.bottom, 40)
            }
            
            // Result Overlay
            if viewModel.scanResult != nil {
                checkInResultOverlay
            }
        }
    }

    // MARK: - Manual Entry View
    
    private var manualEntryView: some View {
        ScrollView {
            VStack(spacing: DFSpacing.xl) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.dfAccent.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "keyboard")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.dfAccent)
                }
                .padding(.top, DFSpacing.xxl)
                
                // Instructions
                VStack(spacing: DFSpacing.sm) {
                    Text("Manual Check-In")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    
                    Text("Enter the attendee's pass code to verify entry")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Input Field
                VStack(alignment: .leading, spacing: DFSpacing.sm) {
                    Text("Pass Code")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Enter pass code...", text: $manualCode)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .padding(DFSpacing.lg)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, DFSpacing.lg)
                
                // Verify Button
                DFPrimaryButton(
                    title: "Verify Pass",
                    icon: "checkmark.shield.fill",
                    isDisabled: manualCode.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    Task {
                        await viewModel.verifyCode(manualCode)
                    }
                }
                .padding(.horizontal, DFSpacing.lg)
                
                Spacer()
            }
            .padding(.bottom, 100)
        }
        .overlay {
            if viewModel.scanResult != nil {
                checkInResultOverlay
            }
        }
    }
    
    // MARK: - Check-In Result Overlay
    
    private var checkInResultOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: DFSpacing.xl) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(viewModel.scanResult?.isValid == true ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: viewModel.scanResult?.isValid == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(viewModel.scanResult?.isValid == true ? .green : .red)
                }
                
                // Result Text
                VStack(spacing: DFSpacing.sm) {
                    Text(viewModel.scanResult?.isValid == true ? "Check-in Successful" : "Invalid Pass")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(viewModel.scanResult?.message ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Attendee Info (if valid)
                if let result = viewModel.scanResult, result.isValid {
                    VStack(spacing: DFSpacing.md) {
                        if let eventTitle = result.eventTitle {
                            InfoDisplayRow(label: "Event", value: eventTitle, icon: "calendar", color: .blue)
                        }
                        
                        if let userName = result.userName {
                            InfoDisplayRow(label: "Attendee", value: userName, icon: "person.fill", color: .green)
                        }
                        
                        if let entryCode = result.entryCode {
                            InfoDisplayRow(label: "Entry Code", value: entryCode, icon: "number", color: .orange)
                        }
                    }
                    .padding(DFSpacing.lg)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
                }
                
                // Action Button
                DFPrimaryButton(
                    title: viewModel.scanResult?.isValid == true ? "Next Check-In" : "Try Again",
                    icon: viewModel.scanResult?.isValid == true ? "arrow.right.circle.fill" : "arrow.counterclockwise",
                    colors: viewModel.scanResult?.isValid == true ? [.green, .cyan] : [.cyan, .blue]
                ) {
                    manualCode = ""
                    viewModel.resetScan()
                    if selectedMode == .scanner {
                        viewModel.startScanning()
                    }
                }
                .padding(.horizontal, DFSpacing.lg)
            }
            .padding(DFSpacing.xl)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xxl, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, y: -10)
            .padding(.horizontal, DFSpacing.lg)
            .padding(.bottom, DFSpacing.lg)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.scanResult != nil)
    }
}

// MARK: - Info Display Row

struct InfoDisplayRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DFSpacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}


// MARK: - Profile View (for regular users)

struct ProfileView: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @StateObject private var authVM = AuthViewModel()
    @State private var showSignOutConfirm = false
    @State private var headerAppeared = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: DFSpacing.xl) {
                profileHeader
                    .padding(.top, DFSpacing.lg)
                
                securitySection
                
                if firebase.appUser?.publicKey == nil {
                    biometricEnrollmentCard
                }
                
                signOutSection
                
                versionFooter
            }
            .padding(.horizontal, DFSpacing.lg)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { authVM.signOut() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                headerAppeared = true
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: DFSpacing.lg) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Text(String(firebase.appUser?.displayName.prefix(1).uppercased() ?? "?"))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .scaleEffect(headerAppeared ? 1.0 : 0.5)
            .opacity(headerAppeared ? 1.0 : 0)
            
            VStack(spacing: 6) {
                Text(firebase.appUser?.displayName ?? "User")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(firebase.appUser?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .opacity(headerAppeared ? 1.0 : 0)
            .offset(y: headerAppeared ? 0 : 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DFSpacing.xl)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
    }
    
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DFSectionHeader(title: "Security", icon: "shield.fill", iconColor: .dfAccent)
                .padding(.horizontal, DFSpacing.xs)
                .padding(.bottom, DFSpacing.md)
            
            VStack(spacing: 0) {
                ProfileInfoRow(icon: "key.fill", iconColor: .orange, label: "Biometric Key", value: firebase.appUser?.publicKey != nil ? "Enrolled ✓" : "Not enrolled")
                DFDivider(leadingInset: 52)
                ProfileInfoRow(icon: "bell.fill", iconColor: .red, label: "Push Notifications", value: PushManager.shared.permissionGranted ? "Enabled" : "Disabled")
                DFDivider(leadingInset: 52)
                ProfileInfoRow(icon: "location.fill", iconColor: .blue, label: "Location Access", value: LocationManager.shared.hasLocationPermission ? "Granted" : "Not granted")
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        }
    }

    private var biometricEnrollmentCard: some View {
        VStack(spacing: DFSpacing.lg) {
            DFIconBadge(icon: "faceid", color: .dfAccent, size: 56, iconSize: 26)
            
            VStack(spacing: 6) {
                Text("Enable Biometric Security")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Secure your passes with Face ID or Touch ID")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            DFPrimaryButton(title: "Enroll Now", icon: "faceid", height: 48) {
                Task {
                    do {
                        let publicKey = try SecureEnclaveManager.shared.generateKeyPair()
                        try await FirebaseManager.shared.updatePublicKey(publicKey)
                        HapticManager.shared.success()
                    } catch {
                        HapticManager.shared.error()
                    }
                }
            }
            .padding(.horizontal, DFSpacing.xl)
        }
        .padding(DFSpacing.xl)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
    }
    
    private var signOutSection: some View {
        Button(action: {
            HapticManager.shared.warning()
            showSignOutConfirm = true
        }) {
            HStack(spacing: DFSpacing.md) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                Text("Sign Out")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        }
        .buttonStyle(DFScaleButtonStyle())
    }
    
    private var versionFooter: some View {
        Text("DigiFence v1.0")
            .font(.footnote)
            .foregroundColor(Color(.quaternaryLabel))
            .frame(maxWidth: .infinity)
            .padding(.top, DFSpacing.lg)
    }
}

// MARK: - Profile Info Row

struct ProfileInfoRow: View {
    let icon: String
    var iconColor: Color = .dfAccent
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: DFSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, DFSpacing.lg)
        .padding(.vertical, DFSpacing.md)
    }
}

// MARK: - Scanning Line Animation

private struct ScanningLine: View {
    @State private var offset: CGFloat = -120
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .dfAccent.opacity(0.8), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 240, height: 3)
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    offset = 120
                }
            }
    }
}
