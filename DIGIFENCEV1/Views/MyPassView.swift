//
//  MyPassView.swift
//  DIGIFENCEV1
//
//  Premium digital passes with animated cards and real-time status.
//

import SwiftUI

struct MyPassView: View {
    @StateObject private var viewModel = MyPassViewModel()
    @StateObject private var ticketVM = TicketViewModel()
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                loadingView
            } else if viewModel.tickets.isEmpty {
                DFEmptyState(
                    icon: "ticket",
                    title: "No Passes Yet",
                    message: "Browse events and get your first ticket to see it here."
                )
            } else {
                passesScrollView
            }
        }
        .navigationTitle("My Passes")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: DFSpacing.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(.dfAccent)
            
            Text("Loading passes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Passes Scroll View
    
    private var passesScrollView: some View {
        ScrollView {
            VStack(spacing: DFSpacing.lg) {
                // Active Passes
                if !viewModel.activeTickets.isEmpty {
                    passSection(
                        title: "Active Passes",
                        icon: "checkmark.shield.fill",
                        iconColor: .green,
                        tickets: viewModel.activeTickets
                    )
                }
                
                // Pending Passes
                if !viewModel.pendingTickets.isEmpty {
                    passSection(
                        title: "Pending Activation",
                        icon: "clock.fill",
                        iconColor: .orange,
                        tickets: viewModel.pendingTickets
                    )
                }
                
                // Expired Passes
                if !viewModel.expiredTickets.isEmpty {
                    passSection(
                        title: "Expired",
                        icon: "xmark.circle.fill",
                        iconColor: .red,
                        tickets: viewModel.expiredTickets
                    )
                }
            }
            .padding(.horizontal, DFSpacing.lg)
            .padding(.top, DFSpacing.sm)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Pass Section
    
    private func passSection(title: String, icon: String, iconColor: Color, tickets: [Ticket]) -> some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            DFSectionHeader(title: title, icon: icon, iconColor: iconColor)
            
            ForEach(Array(tickets.enumerated()), id: \.element.id) { index, ticket in
                PassCard(
                    ticket: ticket,
                    event: viewModel.event(for: ticket),
                    ticketVM: ticketVM
                )
                .entranceAnimation(index: index)
            }
        }
    }
}


// MARK: - Pass Card

struct PassCard: View {
    let ticket: Ticket
    let event: Event?
    @ObservedObject var ticketVM: TicketViewModel
    @State private var showActivateConfirm = false
    @State private var pulseAnimation = false
    @State private var cardAppeared = false
    
    var statusColor: Color {
        switch ticket.status {
        case .active: return .green
        case .pending: return .orange
        case .expired: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Section
            topSection
            
            // Dashed Divider
            dashedDivider
            
            // Bottom Section
            bottomSection
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DFCornerRadius.xxl, style: .continuous)
                .stroke(statusColor.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: statusColor.opacity(0.1), radius: 16, y: 8)
        .scaleEffect(cardAppeared ? 1.0 : 0.95)
        .opacity(cardAppeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                cardAppeared = true
            }
        }
        .confirmationDialog("Activate Pass", isPresented: $showActivateConfirm, titleVisibility: .visible) {
            Button("Activate Now (Face ID)") {
                Task {
                    if let ticketId = ticket.id {
                        await ticketVM.activateTicket(ticketId)
                        if ticketVM.activationSuccess { HapticManager.shared.success() }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will verify your biometrics and location to activate your event pass.")
        }
        .alert("Error", isPresented: $ticketVM.showError) {
            Button("OK") {}
        } message: {
            Text(ticketVM.errorMessage ?? "")
        }
    }
    
    // MARK: - Top Section
    
    private var topSection: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event?.title ?? "Event")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if let description = event?.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                DFStatusBadge(text: ticket.statusDisplayText, color: statusColor, size: .medium)
            }
            
            // Status Indicators
            HStack(spacing: DFSpacing.lg) {
                if ticket.biometricVerified {
                    StatusIndicator(icon: "faceid", text: "Verified", color: .green)
                }
                
                if ticket.insideFence {
                    StatusIndicator(icon: "location.fill", text: "Inside Zone", color: .dfAccent)
                }
            }
        }
        .padding(DFSpacing.xl)
    }
    
    // MARK: - Dashed Divider
    
    private var dashedDivider: some View {
        HStack(spacing: 0) {
            // Left notch
            Circle()
                .fill(Color(.systemGroupedBackground))
                .frame(width: 24, height: 24)
                .offset(x: -12)
            
            // Dashed line
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundColor(Color(.separator))
            }
            .frame(height: 24)
            
            // Right notch
            Circle()
                .fill(Color(.systemGroupedBackground))
                .frame(width: 24, height: 24)
                .offset(x: 12)
        }
    }

    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: DFSpacing.lg) {
            if ticket.isActive {
                // QR Code Display
                VStack(spacing: 16) {
                    // Real QR Code
                    if let qrToken = ticket.qrToken {
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white)
                                    .frame(width: 180, height: 180)
                                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                                
                                QRCodeView(token: qrToken, size: 160)
                            }
                            .scaleEffect(pulseAnimation ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                            .onAppear { pulseAnimation = true }
                            
                            Text("SCAN TO ENTER")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(.tertiaryLabel))
                                .tracking(2)
                        }
                    }
                    
                    // Entry Code (if available)
                    if let entryCode = ticket.entryCode {
                        VStack(spacing: 6) {
                            Text("ENTRY CODE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(.tertiaryLabel))
                                .tracking(2)
                            
                            Text(entryCode)
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(.dfAccent)
                        }
                        .padding(.top, 8)
                    }
                    
                    // Scanned indicator
                    if ticket.qrScanned == true {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Entry Verified")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    } else {
                        Text("Show this QR code at entry")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            } else if ticket.isPending {
                // Activate Button
                VStack(spacing: DFSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "faceid")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.orange)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Ready to activate?")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Verify your identity to unlock this pass")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    DFPrimaryButton(
                        title: "Activate with Face ID",
                        icon: "faceid",
                        isLoading: ticketVM.isActivating,
                        colors: [.orange, .yellow],
                        height: 50
                    ) {
                        showActivateConfirm = true
                    }
                }
            } else if ticket.isExpired {
                // Expired Message
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    
                    Text("This pass has expired")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
        }
        .padding(DFSpacing.xl)
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let icon: String
    let text: String
    var color: Color = .dfAccent
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}
