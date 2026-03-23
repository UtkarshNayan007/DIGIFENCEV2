//
//  MyPassView.swift
//  DIGIFENCEV1
//
//  Apple Wallet-style passes with event info, large QR, auto-brightness, pull-to-refresh.
//

import SwiftUI
import FirebaseCore
import UIKit

struct MyPassView: View {
    @StateObject private var viewModel = MyPassViewModel()
    @StateObject private var ticketVM = TicketViewModel()
    @State private var selectedFilter: PassFilter = .all
    @State private var expandedPassId: String? = nil

    enum PassFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case pending = "Pending"
        case expired = "Expired"
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if viewModel.isLoading && viewModel.tickets.isEmpty {
                VStack(spacing: DFSpacing.lg) {
                    ProgressView().controlSize(.large).tint(.dfAccent)
                    Text("Loading passes...").font(.subheadline).foregroundColor(.secondary)
                }
            } else if viewModel.tickets.isEmpty {
                DFEmptyState(icon: "ticket", title: "No Passes Yet", message: "Browse events and get your first ticket.")
            } else {
                VStack(spacing: 0) {
                    if viewModel.tickets.count > 1 { filterChips }
                    passesScrollView
                }
            }
        }
        .navigationTitle("My Passes")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.startListening() }
        .onDisappear {
            viewModel.stopListening()
            restoreBrightness()
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DFSpacing.sm) {
                ForEach(PassFilter.allCases, id: \.self) { filter in
                    let count = ticketCount(for: filter)
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.3)) { selectedFilter = filter }
                    } label: {
                        HStack(spacing: 4) {
                            Text(filter.rawValue)
                            if count > 0 && filter != .all {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(selectedFilter == filter ? Color.white.opacity(0.25) : Color(.tertiaryLabel).opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selectedFilter == filter ? .white : .secondary)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(
                            selectedFilter == filter
                                ? AnyShapeStyle(DFGradients.accentHorizontal)
                                : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, DFSpacing.lg).padding(.vertical, DFSpacing.sm)
        }
    }

    private var passesScrollView: some View {
        ScrollView {
            LazyVStack(spacing: DFSpacing.md) {
                ForEach(Array(filteredTickets.enumerated()), id: \.element.id) { index, ticket in
                    let isExpanded = expandedPassId == ticket.id
                    PassCard(
                        ticket: ticket,
                        event: viewModel.event(for: ticket),
                        ticketVM: ticketVM,
                        isExpanded: isExpanded,
                        onTap: {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if isExpanded {
                                    expandedPassId = nil
                                    restoreBrightness()
                                } else {
                                    expandedPassId = ticket.id
                                    if ticket.isActive { boostBrightness() }
                                }
                            }
                        }
                    )
                    .entranceAnimation(index: index)
                }
            }
            .padding(.horizontal, DFSpacing.lg)
            .padding(.top, DFSpacing.sm)
            .padding(.bottom, 100)
        }
        .refreshable {
            viewModel.stopListening()
            viewModel.startListening()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private func isEventOver(for ticket: Ticket) -> Bool {
        guard let event = viewModel.event(for: ticket) else { return false }
        if !event.isActive { return true }
        if let endsAt = event.endsAt, endsAt.dateValue() <= Date() { return true }
        return false
    }

    private var filteredTickets: [Ticket] {
        switch selectedFilter {
        case .all: return viewModel.tickets
        case .active: return viewModel.tickets.filter { $0.status == .active && !isEventOver(for: $0) }
        case .pending: return viewModel.tickets.filter { $0.status == .pending && !isEventOver(for: $0) }
        case .expired: return viewModel.tickets.filter { $0.status == .expired || isEventOver(for: $0) }
        }
    }

    private func ticketCount(for filter: PassFilter) -> Int {
        switch filter {
        case .all: return viewModel.tickets.count
        case .active: return viewModel.tickets.filter { $0.status == .active && !isEventOver(for: $0) }.count
        case .pending: return viewModel.tickets.filter { $0.status == .pending && !isEventOver(for: $0) }.count
        case .expired: return viewModel.tickets.filter { $0.status == .expired || isEventOver(for: $0) }.count
        }
    }

    private func boostBrightness() {
        BrightnessManager.shared.boost()
    }
    private func restoreBrightness() {
        BrightnessManager.shared.restore()
    }
}

// MARK: - Brightness Manager

final class BrightnessManager {
    static let shared = BrightnessManager()
    private var savedBrightness: CGFloat?

    func boost() {
        if savedBrightness == nil {
            savedBrightness = UIScreen.main.brightness
        }
        UIScreen.main.brightness = 1.0
    }

    func restore() {
        if let saved = savedBrightness {
            UIScreen.main.brightness = saved
            savedBrightness = nil
        }
    }
}


// MARK: - Pass Card (Collapsible with event info)

struct PassCard: View {
    let ticket: Ticket
    let event: Event?
    @ObservedObject var ticketVM: TicketViewModel
    let isExpanded: Bool
    let onTap: () -> Void

    @State private var showActivateConfirm = false

    private var statusColor: Color {
        switch ticket.status {
        case .active: return .green
        case .pending: return .orange
        case .expired: return .red
        }
    }

    private var isEventExpired: Bool {
        if let event = event, !event.isActive { return true }
        guard let endsAt = event?.endsAt else { return false }
        return endsAt.dateValue() <= Date()
    }

    /// Effective status: treats active tickets as expired if event ended/deactivated
    private var effectivelyExpired: Bool {
        ticket.isExpired || (isEventExpired && !ticket.isExpired)
    }

    private var effectiveStatusColor: Color {
        if effectivelyExpired { return .red }
        return statusColor
    }

    var body: some View {
        VStack(spacing: 0) {
            compactHeader
            if isExpanded {
                dashedDivider
                expandedContent
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous)
                .stroke(effectiveStatusColor.opacity(isExpanded ? 0.25 : 0.1), lineWidth: 1.5)
        )
        .shadow(color: statusColor.opacity(0.06), radius: 8, y: 4)
        .opacity(ticket.isExpired || effectivelyExpired ? 0.7 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .confirmationDialog("Activate Pass", isPresented: $showActivateConfirm, titleVisibility: .visible) {
            Button("Activate Now (Face ID)") {
                Task {
                    if let id = ticket.id {
                        await ticketVM.activateTicket(id)
                        if ticketVM.activationSuccess { HapticManager.shared.success() }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Verify biometrics and location to activate.")
        }
        .alert("Error", isPresented: $ticketVM.showError) {
            Button("OK") {}
        } message: { Text(ticketVM.errorMessage ?? "") }
    }

    // MARK: - Compact Header

    private var compactHeader: some View {
        HStack(spacing: DFSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(effectiveStatusColor.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: effectivelyExpired ? "xmark.circle.fill" : ticket.isActive ? "checkmark.seal.fill" : ticket.isPending ? "clock.fill" : "xmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(effectiveStatusColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(event?.title ?? "Event")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if effectivelyExpired && !ticket.isExpired {
                        Text("Pass Terminated")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                    } else if ticket.isExpired {
                        if isEventExpired {
                            Text("Event Over – Pass Expired")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.red)
                        } else {
                            Text(ticket.statusDisplayText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(statusColor)
                        }
                    } else {
                        Text(ticket.statusDisplayText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(statusColor)
                    }
                    if ticket.insideFence && ticket.isActive && !isEventExpired {
                        Label("Inside", systemImage: "location.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.dfAccent)
                    }
                }
            }
            Spacer()
            if let code = ticket.entryCode, ticket.isActive, !isEventExpired {
                Text(code)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.dfAccent)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.dfAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(DFSpacing.lg)
    }

    private var dashedDivider: some View {
        HStack(spacing: 0) {
            Circle().fill(Color(.systemGroupedBackground)).frame(width: 22, height: 22).offset(x: -11)
            GeometryReader { geo in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                .foregroundColor(Color(.separator).opacity(0.5))
            }
            .frame(height: 22)
            Circle().fill(Color(.systemGroupedBackground)).frame(width: 22, height: 22).offset(x: 11)
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(spacing: DFSpacing.lg) {
            // Event info
            eventInfoSection

            // Status indicators
            HStack(spacing: DFSpacing.md) {
                if ticket.biometricVerified && !isEventExpired {
                    StatusIndicator(icon: "faceid", text: "Verified", color: .green)
                }
                if ticket.insideFence && ticket.isActive && !isEventExpired {
                    StatusIndicator(icon: "location.fill", text: "Inside Zone", color: .dfAccent)
                }
                if isEventExpired {
                    StatusIndicator(icon: "clock.badge.xmark", text: "Event Ended", color: .red)
                }
            }

            if isEventExpired {
                // Event is over — show expired state regardless of ticket status
                eventExpiredContent
            } else if ticket.isActive {
                activeContent
            } else if ticket.isPending {
                pendingContent
            } else {
                expiredContent
            }
        }
        .padding(.horizontal, DFSpacing.xl)
        .padding(.bottom, DFSpacing.xl)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var eventInfoSection: some View {
        VStack(spacing: DFSpacing.sm) {
            if let startsAt = event?.startsAt, let endsAt = event?.endsAt {
                HStack(spacing: 6) {
                    Image(systemName: "calendar").font(.system(size: 11)).foregroundColor(.blue)
                    Text(startsAt.dateValue().formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    Text("→").font(.system(size: 10)).foregroundColor(Color(.tertiaryLabel))
                    Text(endsAt.dateValue().formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                }
            }
        }
    }

    private var activeContent: some View {
        VStack(spacing: DFSpacing.lg) {
            // Show "Entry Verified" if admin scanned, otherwise show "Awaiting Check-In"
            if ticket.qrScanned == true {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 14))
                    Text("Entry Verified by Admin").font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.green)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark").font(.system(size: 14))
                    Text("Awaiting Check-In").font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }

            if let qrToken = ticket.qrToken {
                // Large stable QR
                VStack(spacing: DFSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 220, height: 220)
                            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                        QRCodeView(token: qrToken, size: 200)
                    }
                    Text("SCAN TO ENTER")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(Color(.tertiaryLabel)).tracking(2)
                }
            }

            if let code = ticket.entryCode {
                VStack(spacing: 4) {
                    Text("ENTRY CODE").font(.system(size: 9, weight: .bold)).foregroundColor(Color(.tertiaryLabel)).tracking(2)
                    Text(code).font(.system(size: 34, weight: .bold, design: .monospaced)).foregroundColor(.dfAccent)
                }
            }
        }
    }

    private var pendingContent: some View {
        VStack(spacing: DFSpacing.lg) {
            DFIconBadge(icon: "faceid", color: .orange, size: 64, iconSize: 30)
            VStack(spacing: 3) {
                Text("Ready to activate?").font(.system(size: 15, weight: .semibold))
                Text("Verify identity to unlock this pass").font(.system(size: 12)).foregroundColor(.secondary)
            }
            DFPrimaryButton(title: "Activate with Face ID", icon: "faceid",
                isLoading: ticketVM.isActivating, colors: [.orange, .yellow], height: 48
            ) { showActivateConfirm = true }
        }
    }

    private var expiredContent: some View {
        VStack(spacing: 10) {
            DFIconBadge(icon: "clock.badge.xmark", color: .red, size: 56, iconSize: 26)
            Text("This pass has expired").font(.system(size: 14, weight: .medium)).foregroundColor(Color(.tertiaryLabel))
        }
    }

    private var eventExpiredContent: some View {
        VStack(spacing: DFSpacing.md) {
            DFIconBadge(icon: "party.popper.fill", color: .purple, size: 64, iconSize: 28)
            VStack(spacing: 6) {
                Text("Event is Over! 🎉")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Hope you had an amazing time!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Text("Your pass and entry code have been terminated.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.tertiaryLabel))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, DFSpacing.md)
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let icon: String; let text: String; var color: Color = .dfAccent
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .medium))
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(color).padding(.horizontal, 9).padding(.vertical, 5)
        .background(color.opacity(0.1)).clipShape(Capsule())
    }
}
