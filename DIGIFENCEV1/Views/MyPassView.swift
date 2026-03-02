//
//  MyPassView.swift
//  DIGIFENCEV1
//
//  Animated digital pass card showing status, entry code, real-time updates.
//

import SwiftUI

struct MyPassView: View {
    @StateObject private var viewModel = MyPassViewModel()
    @StateObject private var ticketVM = TicketViewModel()
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
                    .tint(.cyan)
                    .scaleEffect(1.2)
            } else if viewModel.tickets.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Active Passes
                        if !viewModel.activeTickets.isEmpty {
                            SectionHeader(title: "Active Passes", icon: "checkmark.shield.fill", color: .green)
                            ForEach(viewModel.activeTickets) { ticket in
                                PassCard(ticket: ticket, event: viewModel.event(for: ticket), ticketVM: ticketVM)
                            }
                        }
                        
                        // Pending Passes
                        if !viewModel.pendingTickets.isEmpty {
                            SectionHeader(title: "Pending Activation", icon: "clock.fill", color: .orange)
                            ForEach(viewModel.pendingTickets) { ticket in
                                PassCard(ticket: ticket, event: viewModel.event(for: ticket), ticketVM: ticketVM)
                            }
                        }
                        
                        // Expired Passes
                        if !viewModel.expiredTickets.isEmpty {
                            SectionHeader(title: "Expired", icon: "xmark.circle.fill", color: .red)
                            ForEach(viewModel.expiredTickets) { ticket in
                                PassCard(ticket: ticket, event: viewModel.event(for: ticket), ticketVM: ticketVM)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("My Passes")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.3))
            Text("No Passes Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            Text("Browse events and get your first ticket!")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.3))
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Pass Card

struct PassCard: View {
    let ticket: Ticket
    let event: Event?
    @ObservedObject var ticketVM: TicketViewModel
    @State private var showActivateConfirm = false
    @State private var pulseAnimation = false
    
    var statusGradient: [Color] {
        switch ticket.status {
        case .active: return [Color.green, Color.cyan]
        case .pending: return [Color.orange, Color.yellow]
        case .expired: return [Color.red.opacity(0.5), Color.gray]
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section — Event info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(event?.title ?? "Event")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Status badge
                    Text(ticket.statusDisplayText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: statusGradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                
                if let description = event?.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                HStack(spacing: 16) {
                    if ticket.biometricVerified {
                        Label("Biometric ✓", systemImage: "faceid")
                            .font(.system(size: 11))
                            .foregroundColor(.green.opacity(0.8))
                    }
                    if ticket.insideFence {
                        Label("Inside Zone", systemImage: "location.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.cyan.opacity(0.8))
                    }
                }
            }
            .padding(16)
            
            // Divider (dashed ticket style)
            HStack(spacing: 6) {
                ForEach(0..<30, id: \.self) { _ in
                    Circle()
                        .fill(Color(red: 0.05, green: 0.05, blue: 0.12))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Bottom section — Entry code or action
            VStack(spacing: 12) {
                if ticket.isActive, let entryCode = ticket.entryCode {
                    VStack(spacing: 4) {
                        Text("ENTRY CODE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(2)
                        
                        Text(entryCode)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                value: pulseAnimation
                            )
                            .onAppear { pulseAnimation = true }
                    }
                } else if ticket.isPending {
                    Button(action: { showActivateConfirm = true }) {
                        HStack {
                            if ticketVM.isActivating {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "faceid")
                                Text("Activate with Biometrics")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(
                                colors: [.orange, .yellow.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(ticketVM.isActivating)
                } else if ticket.isExpired {
                    Text("This pass has expired.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: statusGradient.map { $0.opacity(0.3) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .confirmationDialog(
            "Activate Pass",
            isPresented: $showActivateConfirm,
            titleVisibility: .visible
        ) {
            Button("Activate Now (Face ID)") {
                Task {
                    if let ticketId = ticket.id {
                        await ticketVM.activateTicket(ticketId)
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
}
