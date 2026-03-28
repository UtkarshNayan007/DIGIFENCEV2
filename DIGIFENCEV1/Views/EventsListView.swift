//
//  EventsListView.swift
//  DIGIFENCEV1
//
//  Clean event list with search, sorting, and modern cards.
//

import SwiftUI
import FirebaseCore

struct EventsListView: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @StateObject private var viewModel = EventsViewModel()
    @State private var searchText = ""
    @State private var sortMode: SortMode = .all
    @State private var showProfile = false

    enum SortMode: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case upcoming = "Upcoming"
        case expired = "Expired"
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView().controlSize(.large).tint(.dfAccent)
            } else if viewModel.events.isEmpty {
                DFEmptyState(icon: "calendar.badge.exclamationmark", title: "No Events", message: "Check back later for upcoming events.")
            } else {
                VStack(spacing: 0) {
                    // Greeting header
                    greetingHeader
                        .padding(.horizontal, DFSpacing.lg)
                        .padding(.bottom, DFSpacing.md)

                    // Search bar
                    DFFloatingSearchBar(text: $searchText, placeholder: "Search events...")
                        .padding(.horizontal, DFSpacing.lg)
                        .padding(.bottom, DFSpacing.sm)

                    // Sort Picker
                    if viewModel.events.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DFSpacing.sm) {
                                ForEach(SortMode.allCases, id: \.self) { mode in
                                    Button {
                                        HapticManager.shared.selection()
                                        withAnimation(.spring(response: 0.3)) { sortMode = mode }
                                    } label: {
                                        Text(mode.rawValue)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(sortMode == mode ? .white : .secondary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(
                                                sortMode == mode
                                                    ? AnyShapeStyle(DFGradients.accentHorizontal)
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

                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(Array(sortedEvents.enumerated()), id: \.element.id) { index, event in
                                NavigationLink(destination: EventDetailView(event: event)) {
                                    EventCardView(event: event)
                                }
                                .buttonStyle(DFCardButtonStyle())
                                .entranceAnimation(index: index)
                            }
                        }
                        .padding(.horizontal, DFSpacing.lg)
                        .padding(.top, DFSpacing.sm)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        viewModel.startListening()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text("") }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { HapticManager.shared.light(); showProfile = true } label: {
                    ProfileAvatarButton(name: firebase.appUser?.displayName ?? "U")
                }
            }
        }
        .sheet(isPresented: $showProfile) { UserProfileSheet() }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 17 { return "Good afternoon" }
        else { return "Good evening" }
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greetingText + " 👋")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Text(firebase.appUser?.displayName ?? "User")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sortedEvents: [Event] {
        let filtered = viewModel.filteredEvents(searchText: searchText)
        let now = Date()
        switch sortMode {
        case .all: return filtered
        case .active:
            return filtered.filter { $0.isActive && ($0.endsAt == nil || $0.endsAt!.dateValue() > now) }
        case .upcoming:
            return filtered.filter { $0.startsAt != nil && $0.startsAt!.dateValue() > now }
        case .expired:
            return filtered.filter { !$0.isActive || ($0.endsAt != nil && $0.endsAt!.dateValue() <= now) }
        }
    }
}

// MARK: - User Profile Sheet (dynamic — animated header, member since, security status)

struct UserProfileSheet: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @StateObject private var authVM = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutConfirm = false
    @State private var appeared = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DFSpacing.xl) {
                    profileHeader
                    accountInfo
                    securityInfo

                    if firebase.appUser?.publicKey == nil { biometricEnrollCard }

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
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: DFSpacing.lg) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.cyan.opacity(0.2), .blue.opacity(0.15), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 90, height: 90)
                    .scaleEffect(appeared ? 1 : 0.5)
                Circle()
                    .stroke(LinearGradient(colors: [.cyan.opacity(0.5), .blue.opacity(0.3)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                    .frame(width: 90, height: 90)
                Text(String(firebase.appUser?.displayName.prefix(1).uppercased() ?? "?"))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .scaleEffect(appeared ? 1 : 0.3)
            }
            VStack(spacing: 6) {
                Text(firebase.appUser?.displayName ?? "User")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(firebase.appUser?.email ?? "")
                    .font(.system(size: 13)).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    DFStatusBadge(text: "USER", color: .dfAccent, size: .medium)
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



    private var accountInfo: some View {
        VStack(spacing: 0) {
            ProfileInfoRow(icon: "person.fill", iconColor: .blue, label: "Name", value: firebase.appUser?.displayName ?? "-")
            DFDivider(leadingInset: 50)
            ProfileInfoRow(icon: "envelope.fill", iconColor: .green, label: "Email", value: firebase.appUser?.email ?? "-")
            if let phone = firebase.appUser?.phoneNumber, !phone.isEmpty {
                DFDivider(leadingInset: 50)
                ProfileInfoRow(icon: "phone.fill", iconColor: .orange, label: "Phone", value: phone)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
    }

    private var securityInfo: some View {
        VStack(spacing: 0) {
            ProfileInfoRow(icon: "key.fill", iconColor: .orange, label: "Biometric Key", value: firebase.appUser?.publicKey != nil ? "Enrolled ✓" : "Not enrolled")
            DFDivider(leadingInset: 50)
            ProfileInfoRow(icon: "bell.fill", iconColor: .red, label: "Notifications", value: PushManager.shared.permissionGranted ? "Enabled" : "Disabled")
            DFDivider(leadingInset: 50)
            ProfileInfoRow(icon: "location.fill", iconColor: .blue, label: "Location", value: LocationManager.shared.hasLocationPermission ? "Granted" : "Not granted")
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
    }

    private var biometricEnrollCard: some View {
        VStack(spacing: DFSpacing.lg) {
            DFIconBadge(icon: "faceid", color: .dfAccent, size: 52, iconSize: 24)
            VStack(spacing: 4) {
                Text("Enable Biometric Security").font(.system(size: 16, weight: .semibold))
                Text("Secure your passes with Face ID").font(.subheadline).foregroundColor(.secondary)
            }
            DFPrimaryButton(title: "Enroll Now", icon: "faceid", height: 46) {
                Task {
                    do {
                        let pk = try SecureEnclaveManager.shared.generateKeyPair()
                        try await FirebaseManager.shared.updatePublicKey(pk)
                        HapticManager.shared.success()
                    } catch { HapticManager.shared.error() }
                }
            }.padding(.horizontal, DFSpacing.xl)
        }
        .padding(DFSpacing.xl).background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
    }
}



// MARK: - Event Card

struct EventCardView: View {
    let event: Event

    private var isExpired: Bool {
        guard let endsAt = event.endsAt else { return false }
        return endsAt.dateValue() <= Date()
    }
    
    private var isLive: Bool {
        return event.isActive && !isExpired
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            thumbnailSection

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let desc = event.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Circle()
                        .fill(isLive ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                }

                HStack(spacing: 12) {
                    if let startsAt = event.startsAt {
                        Label(startsAt.dateValue().formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let capacity = event.capacity {
                        Label("\(capacity)", systemImage: "person.3.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    priceLabel
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    @ViewBuilder
    private var thumbnailSection: some View {
        if let urlStr = event.thumbnailURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill().frame(height: 140).clipped()
                case .failure:
                    placeholderImage
                default:
                    Rectangle().fill(Color(.tertiarySystemGroupedBackground)).frame(height: 140)
                        .overlay(ProgressView().controlSize(.small))
                }
            }
            .id(urlStr)
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Color.dfAccent.opacity(0.12), Color.blue.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: 90)
            .overlay(
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 28)).foregroundStyle(.tertiary)
            )
    }

    @ViewBuilder
    private var priceLabel: some View {
        if let price = event.ticketPrice, price > 0 {
            Text("₹\(safeIntFromDouble(price))")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.green)
        } else {
            Text("Free")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.dfAccent)
        }
    }
}

