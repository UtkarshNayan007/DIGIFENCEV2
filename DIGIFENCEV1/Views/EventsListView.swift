//
//  EventsListView.swift
//  DIGIFENCEV1
//
//  BookMyShow-style event discovery with location bar, search, category icons,
//  auto-scrolling featured carousel, and "Recommended For You" vertical list.
//

import SwiftUI
import FirebaseCore

// MARK: - Event Category

enum EventCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case concerts = "Concerts"
    case sports = "Sports"
    case comedy = "Comedy"
    case workshops = "Workshops"
    case conferences = "Conferences"
    case festivals = "Festivals"
    case meetups = "Meetups"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .concerts: return "music.mic"
        case .sports: return "sportscourt.fill"
        case .comedy: return "theatermasks.fill"
        case .workshops: return "hammer.fill"
        case .conferences: return "person.3.fill"
        case .festivals: return "party.popper.fill"
        case .meetups: return "bubble.left.and.bubble.right.fill"
        }
    }

    var color: Color {
        switch self {
        case .all: return .dfAccent
        case .concerts: return .purple
        case .sports: return .green
        case .comedy: return .orange
        case .workshops: return .blue
        case .conferences: return .indigo
        case .festivals: return .pink
        case .meetups: return .teal
        }
    }
}

// MARK: - Events List View

struct EventsListView: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @StateObject private var viewModel = EventsViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: EventCategory = .all
    @State private var showProfile = false
    @State private var carouselIndex = 0

    // Timer for auto-scroll
    @State private var carouselTimer: Timer?

    private var allEvents: [Event] {
        let searched = viewModel.filteredEvents(searchText: searchText)
        if selectedCategory == .all { return searched }
        return searched.filter { ($0.category ?? "All") == selectedCategory.rawValue }
    }

    // Featured = first 5 events for carousel
    private var featuredEvents: [Event] {
        Array(allEvents.prefix(5))
    }

    // Remaining events for "Recommended" list
    private var recommendedEvents: [Event] {
        if allEvents.count > 5 { return Array(allEvents.dropFirst(5)) }
        if allEvents.count > 1 { return Array(allEvents.dropFirst(1)) }
        return allEvents
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView().controlSize(.large).tint(.dfAccent)
            } else if viewModel.events.isEmpty {
                DFEmptyState(icon: "calendar.badge.exclamationmark", title: "No Events", message: "Check back later for upcoming events.")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 1. Location + Profile row
                        locationRow
                            .padding(.horizontal, DFSpacing.lg)
                            .padding(.top, DFSpacing.xs)
                            .padding(.bottom, DFSpacing.sm)

                        // 2. Search bar
                        searchBar
                            .padding(.horizontal, DFSpacing.lg)
                            .padding(.bottom, DFSpacing.lg)

                        // 3. Category icons (horizontal scroll)
                        categorySection
                            .padding(.bottom, DFSpacing.xl)

                        // 4. Featured carousel (auto-scrolling)
                        if featuredEvents.count > 0 {
                            featuredCarousel
                                .padding(.bottom, DFSpacing.xl)
                        }

                        // 5. "Recommended For You" section
                        if !recommendedEvents.isEmpty {
                            recommendedSection
                        }
                    }
                    .padding(.bottom, 100)
                }
                .refreshable { viewModel.startListening() }
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
        .onAppear {
            viewModel.startListening()
            startAutoScroll()
        }
        .onDisappear {
            viewModel.stopListening()
            carouselTimer?.invalidate()
        }
    }

    // MARK: - 1. Location Row

    private var locationRow: some View {
        HStack(spacing: DFSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(greetingText.replacingOccurrences(of: ",", with: ""))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("👋")
                        .font(.system(size: 13))
                }
                Text((firebase.appUser?.displayName ?? "User").capitalized)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    // MARK: - 2. Search Bar

    private var searchBar: some View {
        HStack(spacing: DFSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            TextField("Search for Events, Concerts, Activities...", text: $searchText)
                .font(.system(size: 14))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
        }
        .padding(.horizontal, DFSpacing.md)
        .frame(height: 42)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - 3. Category Section

    private var categorySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(EventCategory.allCases) { category in
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.3)) { selectedCategory = category }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(
                                        selectedCategory == category
                                            ? LinearGradient(colors: [category.color, category.color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            : LinearGradient(colors: [category.color.opacity(0.12), category.color.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 56, height: 56)
                                    .shadow(color: selectedCategory == category ? category.color.opacity(0.3) : .clear, radius: 6, y: 3)
                                Image(systemName: category.icon)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(selectedCategory == category ? .white : category.color)
                            }
                            Text(category.rawValue)
                                .font(.system(size: 10, weight: selectedCategory == category ? .bold : .medium))
                                .foregroundColor(selectedCategory == category ? category.color : .secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 68)
                    }
                }
            }
            .padding(.horizontal, DFSpacing.lg)
        }
    }

    // MARK: - 4. Featured Carousel

    private var featuredCarousel: some View {
        VStack(spacing: DFSpacing.md) {
            TabView(selection: $carouselIndex) {
                ForEach(Array(featuredEvents.enumerated()), id: \.element.id) { index, event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        FeaturedBannerCard(event: event)
                    }
                    .buttonStyle(DFCardButtonStyle())
                    .tag(index)
                    .padding(.horizontal, DFSpacing.lg)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200)

            // Page dots
            if featuredEvents.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<featuredEvents.count, id: \.self) { i in
                        Circle()
                            .fill(i == carouselIndex ? Color.dfAccent : Color(.systemGray4))
                            .frame(width: i == carouselIndex ? 8 : 6, height: i == carouselIndex ? 8 : 6)
                            .animation(.spring(response: 0.3), value: carouselIndex)
                    }
                }
            }
        }
    }

    private func startAutoScroll() {
        carouselTimer?.invalidate()
        carouselTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            guard featuredEvents.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                carouselIndex = (carouselIndex + 1) % featuredEvents.count
            }
        }
    }

    // MARK: - 5. Recommended Section

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            HStack {
                Text("Recommended For You")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
                Text("\(allEvents.count) events")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, DFSpacing.lg)

            LazyVStack(spacing: DFSpacing.md) {
                ForEach(Array(recommendedEvents.enumerated()), id: \.element.id) { index, event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        BMSEventCard(event: event)
                    }
                    .buttonStyle(DFCardButtonStyle())
                    .entranceAnimation(index: index)
                }
            }
            .padding(.horizontal, DFSpacing.lg)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning," }
        else if hour < 17 { return "Good afternoon," }
        else { return "Good evening," }
    }
}

// MARK: - Featured Banner Card

struct FeaturedBannerCard: View {
    let event: Event

    private var isExpired: Bool {
        guard let endsAt = event.endsAt else { return false }
        return endsAt.dateValue() <= Date()
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            Group {
                if let urlStr = event.thumbnailURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            bannerPlaceholder
                        }
                    }
                } else {
                    bannerPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )

            // Content overlay
            VStack(alignment: .leading, spacing: 6) {
                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(event.isActive && !isExpired ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(isExpired ? "ENDED" : event.isActive ? "LIVE" : "INACTIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(event.isActive && !isExpired ? .green : .red)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Capsule())

                Text(event.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: DFSpacing.md) {
                    if let startsAt = event.startsAt {
                        Label(startsAt.dateValue().formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    // Price badge
                    if let price = event.ticketPrice, price > 0 {
                        Text("₹\(safeIntFromDouble(price))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.green.opacity(0.85))
                            .clipShape(Capsule())
                    } else {
                        Text("FREE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.dfAccent.opacity(0.85))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(DFSpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
    }

    private var bannerPlaceholder: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.cyan.opacity(0.4), .blue.opacity(0.3), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Image(systemName: "star.fill")
                    .font(.system(size: 40, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.15))
            )
    }
}

// MARK: - BMS Event Card (Poster style — 2:3 aspect ratio left, info right)

struct BMSEventCard: View {
    let event: Event

    private var isExpired: Bool {
        guard let endsAt = event.endsAt else { return false }
        return endsAt.dateValue() <= Date()
    }

    private var isLive: Bool { event.isActive && !isExpired }

    var body: some View {
        HStack(spacing: 0) {
            // Left: Poster thumbnail (2:3 ratio)
            posterView
                .frame(width: 110, height: 165)
                .clipped()
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: DFCornerRadius.lg,
                        bottomLeadingRadius: DFCornerRadius.lg,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

            // Right: Info
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text(event.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 4)

                // Description
                if let desc = event.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.bottom, 6)
                }

                Spacer()

                // Date/time
                if let startsAt = event.startsAt {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10, weight: .medium))
                        Text(startsAt.dateValue().formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                }

                // Location
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 10, weight: .medium))
                    Text("Geofenced Venue")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 8)

                // Bottom: Status + Price + Book
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isLive ? Color.green : (isExpired ? Color.red : Color.orange))
                            .frame(width: 6, height: 6)
                        Text(isExpired ? "Ended" : isLive ? "Live" : "Inactive")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(isLive ? .green : (isExpired ? .red : .orange))
                    }

                    Spacer()

                    // Price
                    if let price = event.ticketPrice, price > 0 {
                        Text("₹\(safeIntFromDouble(price))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                    } else {
                        Text("Free")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.dfAccent)
                    }

                    // Book button
                    Text("Book")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color.dfAccent)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(height: 165)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    @ViewBuilder
    private var posterView: some View {
        if let urlStr = event.thumbnailURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    posterPlaceholder
                default:
                    Rectangle().fill(Color(.tertiarySystemGroupedBackground))
                        .overlay(ProgressView().controlSize(.small))
                }
            }
            .id(urlStr)
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Color.dfAccent.opacity(0.15), Color.blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                }
            )
    }
}

// MARK: - User Profile Sheet

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
            .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true } }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: DFSpacing.lg) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.cyan.opacity(0.2), .blue.opacity(0.15), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 90, height: 90).scaleEffect(appeared ? 1 : 0.5)
                Circle()
                    .stroke(LinearGradient(colors: [.cyan.opacity(0.5), .blue.opacity(0.3)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                    .frame(width: 90, height: 90)
                Text(String(firebase.appUser?.displayName.prefix(1).uppercased() ?? "?"))
                    .font(.system(size: 36, weight: .bold, design: .rounded)).scaleEffect(appeared ? 1 : 0.3)
            }
            VStack(spacing: 6) {
                Text(firebase.appUser?.displayName ?? "User").font(.system(size: 22, weight: .bold, design: .rounded))
                Text(firebase.appUser?.email ?? "").font(.system(size: 13)).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    DFStatusBadge(text: "USER", color: .dfAccent, size: .medium)
                    if let created = firebase.appUser?.createdAt {
                        Text("Since \(created.dateValue().formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 10, weight: .medium)).foregroundColor(Color(.tertiaryLabel))
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
