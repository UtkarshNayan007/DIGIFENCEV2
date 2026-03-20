//
//  EventDetailView.swift
//  DIGIFENCEV1
//
//  Premium event detail with immersive hero, map preview, and ticket purchase.
//

import SwiftUI
import MapKit
import FirebaseCore

struct EventDetailView: View {
    let event: Event
    @StateObject private var ticketVM = TicketViewModel()
    @State private var showTicketCreated = false
    @State private var cameraPosition: MapCameraPosition
    @State private var showPaymentSheet = false
    @State private var isProcessingPayment = false
    @State private var contentAppeared = false
    @State private var scrollOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    
    init(event: Event) {
        self.event = event
        let centroid = event.coordinate
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: centroid, latitudinalMeters: 600, longitudinalMeters: 600
        )))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                heroSection
                
                // Content
                VStack(alignment: .leading, spacing: DFSpacing.xl) {
                    // Title Section
                    titleSection
                    
                    // Quick Stats
                    quickStats
                    
                    // Details Card
                    detailsCard
                    
                    // Map Section
                    mapSection
                    
                    // Ticket Button
                    ticketButton
                }
                .padding(.horizontal, DFSpacing.lg)
                .padding(.top, DFSpacing.xl)
                .padding(.bottom, 120)
            }
            .opacity(contentAppeared ? 1 : 0)
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { contentAppeared = true }
        }
        .sheet(isPresented: $showPaymentSheet) {
            PaymentSimulationView(
                eventTitle: event.title,
                amount: event.ticketPrice ?? 0,
                isProcessing: $isProcessingPayment,
                onPaymentSuccess: {
                    showPaymentSheet = false
                    processTicketCreation()
                }
            )
        }
        .alert("Ticket Secured!", isPresented: $showTicketCreated) {
            Button("View My Passes") { dismiss() }
            Button("OK") {}
        } message: {
            Text("Your ticket is pending. Enter the event geofence to activate it with biometric verification.")
        }
        .alert("Error", isPresented: $ticketVM.showError) {
            Button("OK") {}
        } message: {
            Text(ticketVM.errorMessage ?? "")
        }
    }

    // MARK: - Hero Section
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Image
            Group {
                if let imageURLString = event.thumbnailURL, let url = URL(string: imageURLString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            heroPlaceholder
                                .overlay(ProgressView().controlSize(.regular).tint(.white))
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 320)
                                .clipped()
                        case .failure:
                            heroPlaceholder
                        @unknown default:
                            heroPlaceholder
                        }
                    }
                } else {
                    heroPlaceholder
                }
            }
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Status badge
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(event.isActive ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    
                    Text(event.isActive ? "Live Now" : "Event Ended")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.8))
                .clipShape(Capsule())
            }
            .padding(DFSpacing.lg)
        }
        .frame(height: 320)
    }
    
    private var heroPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.cyan.opacity(0.4), Color.blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 320)
            .overlay(
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.white.opacity(0.5))
            )
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: DFSpacing.sm) {
            Text(event.title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            if let description = event.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStats: some View {
        HStack(spacing: DFSpacing.md) {
            QuickStatItem(
                icon: "pentagon.fill",
                value: "\(event.polygonCoordinates.count)",
                label: "Points",
                color: .dfAccent
            )
            
            if let capacity = event.capacity {
                QuickStatItem(
                    icon: "person.3.fill",
                    value: "\(capacity)",
                    label: "Capacity",
                    color: .blue
                )
            }
            
            if let remaining = event.remainingTickets {
                QuickStatItem(
                    icon: "ticket.fill",
                    value: "\(remaining)",
                    label: "Left",
                    color: remaining > 10 ? .green : .orange
                )
            }
            
            QuickStatItem(
                icon: "indianrupeesign.circle.fill",
                value: event.ticketPrice != nil && event.ticketPrice! > 0 ? "₹\(Int(event.ticketPrice!))" : "Free",
                label: "Price",
                color: .green
            )
        }
    }

    // MARK: - Details Card
    
    private var detailsCard: some View {
        VStack(spacing: 0) {
            DFInfoRow(icon: "pentagon", iconColor: .dfAccent, label: "Geofence", value: "\(event.polygonCoordinates.count)-point polygon")
            DFDivider(leadingInset: 52)
            
            DFInfoRow(icon: "mappin", iconColor: .red, label: "Center", value: String(format: "%.4f, %.4f", event.coordinate.latitude, event.coordinate.longitude))
            
            if let startsAt = event.startsAt {
                DFDivider(leadingInset: 52)
                DFInfoRow(icon: "calendar", iconColor: .blue, label: "Starts", value: startsAt.dateValue().formatted(date: .long, time: .shortened))
            }
            
            if let endsAt = event.endsAt {
                DFDivider(leadingInset: 52)
                DFInfoRow(icon: "calendar.badge.clock", iconColor: .purple, label: "Ends", value: endsAt.dateValue().formatted(date: .long, time: .shortened))
            }
            
            DFDivider(leadingInset: 52)
            DFInfoRow(icon: "antenna.radiowaves.left.and.right", iconColor: event.isActive ? .green : .red, label: "Status", value: event.isActive ? "Active" : "Inactive")
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
    }
    
    // MARK: - Map Section
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.dfAccent)
                Text("Event Location")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Map(position: $cameraPosition) {
                Annotation(event.title, coordinate: event.coordinate) {
                    DFMapPin(color: .dfAccent)
                }
                
                MapPolygon(coordinates: event.polygonCLCoordinates)
                    .foregroundStyle(Color.dfAccent.opacity(0.15))
                    .stroke(Color.dfAccent.opacity(0.6), lineWidth: 2)
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
    }
    
    // MARK: - Ticket Button
    
    private var ticketButton: some View {
        let isSoldOut = event.remainingTickets != nil && event.remainingTickets == 0
        
        return DFPrimaryButton(
            title: buttonText(),
            icon: isSoldOut ? "xmark.circle" : "ticket",
            isLoading: ticketVM.isLoading,
            isDisabled: isSoldOut,
            colors: isSoldOut ? [.gray, .gray] : [.cyan, .blue]
        ) {
            if let price = event.ticketPrice, price > 0 {
                showPaymentSheet = true
            } else {
                processTicketCreation()
            }
        }
    }
    
    private func buttonText() -> String {
        if let remaining = event.remainingTickets, remaining <= 0 { return "Sold Out" }
        if let price = event.ticketPrice, price > 0 { return "Buy Ticket for ₹\(Int(price))" }
        return "Get Free Ticket"
    }
    
    private func processTicketCreation() {
        Task {
            if let _ = await ticketVM.createTicket(for: event) {
                HapticManager.shared.success()
                showTicketCreated = true
            }
        }
    }
}

// MARK: - Quick Stat Item

struct QuickStatItem: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .dfAccent
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
    }
}


// MARK: - Payment Simulation Sheet

struct PaymentSimulationView: View {
    let eventTitle: String
    let amount: Double
    @Binding var isProcessing: Bool
    var onPaymentSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: DFSpacing.xxl) {
                    Spacer()
                    
                    // Icon & Title
                    VStack(spacing: DFSpacing.lg) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 44, weight: .light))
                                .foregroundColor(.green)
                        }
                        .scaleEffect(appeared ? 1.0 : 0.5)
                        
                        VStack(spacing: 6) {
                            Text("Complete Payment")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            
                            Text("Purchasing a ticket for")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(eventTitle)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .opacity(appeared ? 1 : 0)
                    }
                    
                    // Amount Card
                    VStack(spacing: 8) {
                        Text("Amount to Pay")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        Text("₹\(Int(amount))")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DFSpacing.xxl)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
                    .padding(.horizontal, DFSpacing.xl)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    
                    Spacer()
                    
                    // Pay Button
                    DFPrimaryButton(
                        title: isProcessing ? "Processing..." : "Pay ₹\(Int(amount)) Securely",
                        icon: isProcessing ? nil : "lock.fill",
                        isLoading: isProcessing,
                        colors: [.green, .mint]
                    ) {
                        processPayment()
                    }
                    .padding(.horizontal, DFSpacing.xl)
                    .padding(.bottom, DFSpacing.xxl)
                    .opacity(appeared ? 1 : 0)
                }
            }
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isProcessing)
                }
            }
        }
        .interactiveDismissDisabled(isProcessing)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
    
    private func processPayment() {
        HapticManager.shared.medium()
        isProcessing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isProcessing = false
            HapticManager.shared.success()
            onPaymentSuccess()
        }
    }
}
