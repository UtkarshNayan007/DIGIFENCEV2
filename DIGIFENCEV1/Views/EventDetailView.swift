//
//  EventDetailView.swift
//  DIGIFENCEV1
//
//  Event info + polygon map preview + thumbnail + "Get Ticket" flow (with simulated payment).
//

import SwiftUI
import MapKit
import FirebaseCore

struct EventDetailView: View {
    let event: Event
    @StateObject private var ticketVM = TicketViewModel()
    @State private var showTicketCreated = false
    @State private var cameraPosition: MapCameraPosition
    
    // Payment Simulation State
    @State private var showPaymentSheet = false
    @State private var isProcessingPayment = false
    
    init(event: Event) {
        self.event = event
        // Calculate a region that fits the polygon centroid with a reasonable zoom
        let centroid = event.coordinate
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: centroid,
            latitudinalMeters: 600,
            longitudinalMeters: 600
        )))
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Thumbnail Image (if available)
                    if let imageURLString = event.thumbnailURL, let url = URL(string: imageURLString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 220)
                                    .overlay(ProgressView().tint(.white))
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 220)
                                    .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 220)
                                    .overlay(Image(systemName: "photo").foregroundColor(.white.opacity(0.5)))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        // Fallback gradient if no image
                        Rectangle()
                            .fill(LinearGradient(colors: [.indigo.opacity(0.5), .cyan.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 140)
                    }
                    
                    // Event Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text(event.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if let description = event.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        // Details grid
                        VStack(spacing: 12) {
                            DetailRow(icon: "pentagon", label: "Geofence", value: "\(event.polygonCoordinates.count)-point polygon")
                            
                            DetailRow(icon: "mappin", label: "Center", value: String(format: "%.4f, %.4f", event.coordinate.latitude, event.coordinate.longitude))
                            
                            if let startsAt = event.startsAt {
                                DetailRow(icon: "calendar", label: "Starts", value: startsAt.dateValue().formatted(date: .long, time: .shortened))
                            }
                            
                            if let endsAt = event.endsAt {
                                DetailRow(icon: "calendar.badge.clock", label: "Ends", value: endsAt.dateValue().formatted(date: .long, time: .shortened))
                            }
                            
                            DetailRow(icon: "antenna.radiowaves.left.and.right", label: "Status", value: event.isActive ? "Active" : "Inactive")
                            
                            if let capacity = event.capacity {
                                DetailRow(icon: "person.3.fill", label: "Capacity", value: "\(capacity)")
                            }
                            
                            if let remaining = event.remainingTickets {
                                DetailRow(icon: "ticket", label: "Remaining", value: "\(remaining)")
                            }
                            
                            if let price = event.ticketPrice, price > 0 {
                                DetailRow(icon: "indianrupeesign.circle", label: "Price", value: "₹\(Int(price))")
                            } else {
                                DetailRow(icon: "indianrupeesign.circle", label: "Price", value: "Free")
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 16)
                    
                    // Map with polygon overlay
                    Map(position: $cameraPosition) {
                        Annotation(event.title, coordinate: event.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.cyan)
                            }
                        }
                        
                        MapPolygon(coordinates: event.polygonCLCoordinates)
                            .foregroundStyle(.cyan.opacity(0.15))
                            .stroke(.cyan.opacity(0.5), lineWidth: 2)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 16)
                    
                    // Get Ticket / Buy Ticket Button
                    Button(action: {
                        if let price = event.ticketPrice, price > 0 {
                            showPaymentSheet = true
                        } else {
                            processTicketCreation()
                        }
                    }) {
                        HStack {
                            if ticketVM.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "ticket")
                                Text(buttonText())
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(ticketVM.isLoading || (event.remainingTickets != nil && event.remainingTickets == 0))
                    .padding(.horizontal, 16)
                    
                    Spacer().frame(height: 100)
                }
            }
            .ignoresSafeArea(edges: .top) // Let image bleed to top
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
            Button("View My Passes") {}
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
    
    private func buttonText() -> String {
        if let remaining = event.remainingTickets, remaining <= 0 {
            return "Sold Out"
        }
        if let price = event.ticketPrice, price > 0 {
            return "Buy Ticket for ₹\(Int(price))"
        }
        return "Get Free Ticket"
    }
    
    private func processTicketCreation() {
        Task {
            if let _ = await ticketVM.createTicket(for: event) {
                showTicketCreated = true
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Payment Simulation Sheet

struct PaymentSimulationView: View {
    let eventTitle: String
    let amount: Double
    @Binding var isProcessing: Bool
    var onPaymentSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.16).ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Complete Payment")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("You are purchasing a ticket for\n**\(eventTitle)**")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 4)
                }
                .padding(.top, 40)
                
                // Amount Box
                VStack(spacing: 4) {
                    Text("Amount to Pay")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                    Text("₹\(Int(amount))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Pay Button
                Button(action: processPayment) {
                    HStack {
                        if isProcessing {
                            ProgressView().tint(.white)
                            Text("Processing...")
                                .fontWeight(.semibold)
                        } else {
                            Image(systemName: "lock.fill")
                            Text("Pay ₹\(Int(amount)) Securely")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: isProcessing ? [.gray, .gray.opacity(0.8)] : [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isProcessing)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .interactiveDismissDisabled(isProcessing)
    }
    
    private func processPayment() {
        isProcessing = true
        // Simulate network delay for payment processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isProcessing = false
            onPaymentSuccess()
        }
    }
}
