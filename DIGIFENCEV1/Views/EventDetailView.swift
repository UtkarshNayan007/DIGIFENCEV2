//
//  EventDetailView.swift
//  DIGIFENCEV1
//
//  Immersive event detail with hero, map, stats, and ticket purchase.
//

import SwiftUI
import MapKit
import FirebaseCore
import FirebaseFirestore
import EventKit

struct EventDetailView: View {
    let event: Event
    @StateObject private var ticketVM = TicketViewModel()
    @State private var liveEvent: Event?
    @State private var showTicketCreated = false
    @State private var cameraPosition: MapCameraPosition
    @State private var showPaymentSheet = false
    @State private var isProcessingPayment = false
    @State private var appeared = false
    @State private var calendarSaved = false
    @State private var showCalendarAlert = false
    @State private var calendarAlertMessage = ""
    @Environment(\.dismiss) private var dismiss

    private var displayEvent: Event { liveEvent ?? event }

    private var isEventExpired: Bool {
        guard let endsAt = displayEvent.endsAt else { return false }
        return endsAt.dateValue() <= Date()
    }

    private var hasNotStarted: Bool {
        guard let startsAt = displayEvent.startsAt else { return false }
        return startsAt.dateValue() > Date()
    }

    init(event: Event) {
        self.event = event
        let c = event.coordinate
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(center: c, latitudinalMeters: 600, longitudinalMeters: 600)))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection
                    VStack(alignment: .leading, spacing: DFSpacing.xl) {
                        titleSection
                        if isEventExpired { eventExpiredBanner }
                        quickStats
                        infoSection
                        if displayEvent.startsAt != nil {
                            calendarButton
                        }
                        mapSection
                    }
                    .padding(.horizontal, DFSpacing.lg)
                    .padding(.top, DFSpacing.xl)
                    .padding(.bottom, 110)
                }
                .opacity(appeared ? 1 : 0)
            }
            .ignoresSafeArea(edges: .top)
            stickyButton
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            listenToEvent()
        }
        .sheet(isPresented: $showPaymentSheet) {
            PaymentSimulationView(eventTitle: displayEvent.title, amount: displayEvent.ticketPrice ?? 0, isProcessing: $isProcessingPayment) {
                showPaymentSheet = false
                processTicket()
            }
        }
        .alert("Ticket Secured!", isPresented: $showTicketCreated) {
            Button("View My Passes") { dismiss() }
            Button("OK") {}
        } message: {
            Text("Your ticket is pending. Enter the geofence to activate with biometrics.")
        }
        .alert("Error", isPresented: $ticketVM.showError) {
            Button("OK") {}
        } message: { Text(ticketVM.errorMessage ?? "") }
    }

    private func listenToEvent() {
        guard let eventId = event.id else { return }
        FirebaseManager.shared.eventsCollection.document(eventId)
            .addSnapshotListener { snapshot, _ in
                if let snapshot, let updated = try? snapshot.data(as: Event.self) {
                    liveEvent = updated
                }
            }
    }

    private var eventExpiredBanner: some View {
        HStack(spacing: DFSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
            Text("This event has ended").font(.system(size: 14, weight: .semibold)).foregroundColor(.red)
        }
        .frame(maxWidth: .infinity)
        .padding(DFSpacing.md)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let urlStr = displayEvent.thumbnailURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill().frame(height: 280).clipped()
                        default: heroPlaceholder
                        }
                    }
                } else { heroPlaceholder }
            }
            LinearGradient(colors: [.clear, .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(displayEvent.isActive && !isEventExpired ? Color.green : Color.red).frame(width: 7, height: 7)
                    Text(isEventExpired ? "Ended" : displayEvent.isActive ? "Live" : "Inactive")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Capsule())

                if let s = displayEvent.startsAt {
                    Label(s.dateValue().formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(DFSpacing.lg)
        }
        .frame(height: 280)
    }

    private var heroPlaceholder: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: 280)
            .overlay(Image(systemName: "calendar.badge.plus").font(.system(size: 48, weight: .ultraLight)).foregroundColor(.white.opacity(0.35)))
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayEvent.title).font(.system(size: 26, weight: .bold, design: .rounded))
            if let code = displayEvent.eventCode, !code.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "ticket.fill").font(.system(size: 11))
                    Text("Code: \(code)").font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(.dfAccent)
            }
            if let desc = displayEvent.description, !desc.isEmpty {
                Text(desc).font(.system(size: 14)).foregroundColor(.secondary).lineSpacing(3)
            }
        }
    }

    // MARK: - Stats

    private var quickStats: some View {
        HStack(spacing: 10) {
            if let cap = displayEvent.capacity { StatPill(icon: "person.2.fill", value: "\(cap)", label: "Capacity", color: .blue) }
            if let rem = displayEvent.remainingTickets { StatPill(icon: "ticket.fill", value: "\(rem)", label: "Left", color: rem > 10 ? .green : .orange) }
            StatPill(icon: "indianrupeesign", value: displayEvent.ticketPrice != nil && displayEvent.ticketPrice! > 0 ? "₹\(safeIntFromDouble(displayEvent.ticketPrice!))" : "Free", label: "Price", color: .green)
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(spacing: 0) {
            if let s = displayEvent.startsAt {
                DFInfoRow(icon: "clock.fill", iconColor: .blue, label: "Starts", value: s.dateValue().formatted(date: .long, time: .shortened))
                DFDivider(leadingInset: 46)
            }
            if let e = displayEvent.endsAt {
                DFInfoRow(icon: "clock.badge.checkmark.fill", iconColor: .purple, label: "Ends", value: e.dateValue().formatted(date: .long, time: .shortened))
                DFDivider(leadingInset: 46)
            }
            if let code = displayEvent.eventCode, !code.isEmpty {
                DFInfoRow(icon: "ticket.fill", iconColor: .dfAccent, label: "Event Code", value: code)
                DFDivider(leadingInset: 46)
            }
            DFInfoRow(icon: "mappin.circle.fill", iconColor: .red, label: "Location", value: String(format: "%.4f, %.4f", displayEvent.coordinate.latitude, displayEvent.coordinate.longitude))
            DFDivider(leadingInset: 46)
            DFInfoRow(icon: "shield.checkered", iconColor: .dfAccent, label: "Geofence", value: "\(displayEvent.polygonCoordinates.count)-point polygon")
        }
        .padding(.vertical, 2)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
    }

    private var calendarButton: some View {
        Button {
            addToCalendar()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: calendarSaved ? "checkmark.circle.fill" : "calendar.badge.plus")
                    .font(.system(size: 15, weight: .medium))
                Text(calendarSaved ? "Added to Calendar" : "Add to Calendar")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(calendarSaved ? .green : .dfAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background((calendarSaved ? Color.green : Color.dfAccent).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
        }
        .disabled(calendarSaved)
        .buttonStyle(DFScaleButtonStyle())
        .alert("Calendar", isPresented: $showCalendarAlert) {
            Button("OK") {}
        } message: {
            Text(calendarAlertMessage)
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: DFSpacing.md) {
            Label("Event Location", systemImage: "map.fill")
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.dfAccent)
            Map(position: $cameraPosition) {
                Annotation(displayEvent.title, coordinate: displayEvent.coordinate) { DFMapPin(color: .dfAccent) }
                MapPolygon(coordinates: displayEvent.polygonCLCoordinates)
                    .foregroundStyle(Color.dfAccent.opacity(0.12))
                    .stroke(Color.dfAccent.opacity(0.5), lineWidth: 2)
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        }
    }

    // MARK: - Sticky Button

    private var stickyButton: some View {
        let soldOut = displayEvent.remainingTickets != nil && displayEvent.remainingTickets == 0
        let disabled = soldOut || isEventExpired || !displayEvent.isActive
        return VStack(spacing: 0) {
            LinearGradient(colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)], startPoint: .top, endPoint: .bottom)
                .frame(height: 16)
            DFPrimaryButton(
                title: buttonText(),
                icon: disabled ? "xmark.circle" : "ticket",
                isLoading: ticketVM.isLoading,
                isDisabled: disabled,
                colors: disabled ? [.gray, .gray] : [.cyan, .blue]
            ) {
                if let p = displayEvent.ticketPrice, p > 0 { showPaymentSheet = true }
                else { processTicket() }
            }
            .padding(.horizontal, DFSpacing.lg)
            .padding(.bottom, DFSpacing.xl)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func buttonText() -> String {
        if isEventExpired { return "Event Ended" }
        if !displayEvent.isActive { return "Event Inactive" }
        if let r = displayEvent.remainingTickets, r <= 0 { return "Sold Out" }
        if let p = displayEvent.ticketPrice, p > 0 { return "Buy Ticket — ₹\(safeIntFromDouble(p))" }
        return "Get Free Ticket"
    }

    private func addToCalendar() {
        let store = EKEventStore()
        
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    if granted {
                        saveCalendarEvent(store: store)
                    } else {
                        calendarAlertMessage = "Calendar access denied. Enable it in Settings → Privacy → Calendars."
                        showCalendarAlert = true
                    }
                }
            }
        } else {
            store.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    if granted {
                        saveCalendarEvent(store: store)
                    } else {
                        calendarAlertMessage = "Calendar access denied. Enable it in Settings → Privacy → Calendars."
                        showCalendarAlert = true
                    }
                }
            }
        }
    }

    private func saveCalendarEvent(store: EKEventStore) {
        let calEvent = EKEvent(eventStore: store)
        calEvent.title = "🎫 \(displayEvent.title)"
        
        if let startsAt = displayEvent.startsAt {
            calEvent.startDate = startsAt.dateValue()
        } else {
            calEvent.startDate = Date()
        }
        
        if let endsAt = displayEvent.endsAt {
            calEvent.endDate = endsAt.dateValue()
        } else {
            calEvent.endDate = calEvent.startDate.addingTimeInterval(3600)
        }
        
        // Build notes
        var notes = "DigiFence Event"
        if let desc = displayEvent.description, !desc.isEmpty {
            notes += "\n\(desc)"
        }
        if let code = displayEvent.eventCode {
            notes += "\nEvent Code: \(code)"
        }
        if let price = displayEvent.ticketPrice, price > 0 {
            notes += "\nTicket Price: ₹\(safeIntFromDouble(price))"
        }
        if let cap = displayEvent.capacity {
            notes += "\nCapacity: \(cap)"
        }
        notes += "\nLocation: \(String(format: "%.4f, %.4f", displayEvent.coordinate.latitude, displayEvent.coordinate.longitude))"
        calEvent.notes = notes
        
        calEvent.location = String(format: "%.4f, %.4f", displayEvent.coordinate.latitude, displayEvent.coordinate.longitude)
        calEvent.calendar = store.defaultCalendarForNewEvents
        
        // Add a reminder 30 minutes before
        let alarm = EKAlarm(relativeOffset: -1800)
        calEvent.addAlarm(alarm)
        
        // Add a reminder 1 hour before
        let alarm2 = EKAlarm(relativeOffset: -3600)
        calEvent.addAlarm(alarm2)
        
        do {
            try store.save(calEvent, span: .thisEvent)
            HapticManager.shared.success()
            calendarSaved = true
            calendarAlertMessage = "Event added to your calendar with reminders."
            showCalendarAlert = true
        } catch {
            HapticManager.shared.error()
            calendarAlertMessage = "Failed to save: \(error.localizedDescription)"
            showCalendarAlert = true
        }
    }

    private func processTicket() {
        Task {
            if let _ = await ticketVM.createTicket(for: event) {
                HapticManager.shared.success()
                showTicketCreated = true
            }
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String; let value: String; let label: String; var color: Color = .dfAccent
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundColor(color)
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(.secondary).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
    }
}

// MARK: - Payment Sheet

struct PaymentSimulationView: View {
    let eventTitle: String; let amount: Double
    @Binding var isProcessing: Bool
    var onPaymentSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: DFSpacing.xxl) {
                    Spacer()
                    VStack(spacing: DFSpacing.lg) {
                        DFIconBadge(icon: "creditcard.fill", color: .green, size: 80, iconSize: 36)
                            .scaleEffect(appeared ? 1 : 0.5)
                        VStack(spacing: 4) {
                            Text("Complete Payment").font(.system(size: 22, weight: .bold, design: .rounded))
                            Text(eventTitle).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                        }
                        .opacity(appeared ? 1 : 0)
                    }
                    VStack(spacing: 6) {
                        Text("AMOUNT").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary).tracking(0.5)
                        Text("₹\(safeIntFromDouble(amount))").font(.system(size: 48, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DFSpacing.xxl)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xl, style: .continuous))
                    .padding(.horizontal, DFSpacing.xl)
                    .opacity(appeared ? 1 : 0)
                    Spacer()
                    DFPrimaryButton(
                        title: isProcessing ? "Processing..." : "Pay ₹\(safeIntFromDouble(amount))",
                        icon: isProcessing ? nil : "lock.fill",
                        isLoading: isProcessing,
                        colors: [.green, .mint]
                    ) { processPayment() }
                    .padding(.horizontal, DFSpacing.xl)
                    .padding(.bottom, DFSpacing.xxl)
                    .opacity(appeared ? 1 : 0)
                }
            }
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isProcessing)
                }
            }
        }
        .interactiveDismissDisabled(isProcessing)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true } }
    }

    private func processPayment() {
        HapticManager.shared.medium()
        isProcessing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            isProcessing = false
            HapticManager.shared.success()
            onPaymentSuccess()
        }
    }
}
