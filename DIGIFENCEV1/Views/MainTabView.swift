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
                .tabItem { Label("Explore", systemImage: selectedTab == 0 ? "square.grid.2x2.fill" : "square.grid.2x2") }
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

// MARK: - Security Tabs (Check-In + Users)

struct SecurityTabView: View {
    @Binding var selectedTab: Int
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                QRScannerView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            SecurityProfileButton()
                        }
                    }
            }
            .tabItem { Label("Check-In", systemImage: selectedTab == 0 ? "qrcode.viewfinder" : "qrcode") }
            .tag(0)
            NavigationStack {
                SecurityScannedUsersView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            SecurityProfileButton()
                        }
                    }
            }
            .tabItem { Label("Users", systemImage: selectedTab == 1 ? "person.2.fill" : "person.2") }
            .tag(1)
        }
    }
}

// MARK: - Security Profile Button (toolbar)

private struct SecurityProfileButton: View {
    @State private var showProfile = false

    var body: some View {
        Button {
            HapticManager.shared.light()
            showProfile = true
        } label: {
            ProfileAvatarButton(name: FirebaseManager.shared.appUser?.displayName ?? "S")
        }
        .sheet(isPresented: $showProfile) {
            SecurityProfileSheet()
        }
    }
}

// MARK: - Security Profile Sheet

struct SecurityProfileSheet: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @StateObject private var authVM = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutConfirm = false
    @State private var appeared = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DFSpacing.xl) {
                    VStack(spacing: DFSpacing.lg) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.dfAccent.opacity(0.2), .blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 90, height: 90)
                                .scaleEffect(appeared ? 1 : 0.5)
                            Circle()
                                .stroke(LinearGradient(colors: [.dfAccent.opacity(0.5), .blue.opacity(0.3)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                                .frame(width: 90, height: 90)
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.dfAccent)
                                .scaleEffect(appeared ? 1 : 0.3)
                        }
                        VStack(spacing: 6) {
                            Text(firebase.appUser?.displayName ?? "Security")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                            Text(firebase.appUser?.email ?? "")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                DFStatusBadge(text: "SECURITY", color: .dfAccent, size: .medium)
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

                    VStack(spacing: 0) {
                        ProfileInfoRow(icon: "person.fill", iconColor: .blue, label: "Name", value: firebase.appUser?.displayName ?? "-")
                        DFDivider(leadingInset: 50)
                        ProfileInfoRow(icon: "envelope.fill", iconColor: .green, label: "Email", value: firebase.appUser?.email ?? "-")
                        DFDivider(leadingInset: 50)
                        ProfileInfoRow(icon: "shield.fill", iconColor: .dfAccent, label: "Role", value: "Security Personnel")
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))

                    DFDestructiveButton(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right") { showSignOutConfirm = true }
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
                    DFDestructiveButton(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right") { showSignOutConfirm = true }
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
