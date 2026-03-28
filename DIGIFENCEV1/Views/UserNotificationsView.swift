//
//  UserNotificationsView.swift
//  DIGIFENCEV1
//
//  User updates tab — real-time feed of ticket purchases, activations,
//  geofence exits, expirations, and event endings.
//

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - Notification Model

struct UserNotification: Identifiable {
    let id: String
    let type: String          // activated, exited, expired, purchased, event_ended
    let ticketId: String
    var eventTitle: String?
    var timestamp: Timestamp?

    var icon: String {
        switch type {
        case "activated": return "checkmark.circle.fill"
        case "exited": return "arrow.right.circle.fill"
        case "purchased": return "ticket.fill"
        case "expired": return "xmark.circle.fill"
        case "event_ended": return "flag.checkered"
        default: return "bell.fill"
        }
    }

    var color: Color {
        switch type {
        case "activated": return .green
        case "exited": return .orange
        case "purchased": return .dfAccent
        case "expired": return .red
        case "event_ended": return .purple
        default: return .blue
        }
    }

    var title: String {
        switch type {
        case "activated": return "Pass Activated"
        case "exited": return "Geofence Exit"
        case "purchased": return "Ticket Secured"
        case "expired": return "Pass Expired"
        case "event_ended": return "Event Over"
        default: return "Update"
        }
    }

    var message: String {
        switch type {
        case "activated": return "Your pass was verified and activated."
        case "exited": return "You exited the event geofence."
        case "purchased": return "Ready for biometric activation."
        case "expired": return "Your pass has been deactivated."
        case "event_ended": return "Hope you had a great time! 🎉"
        default: return "Update on your ticket."
        }
    }
}

// MARK: - ViewModel

@MainActor
final class UserNotificationsViewModel: ObservableObject {
    @Published var notifications: [UserNotification] = []
    @Published var isLoading = false
    @Published var hasLoaded = false

    private let firebase = FirebaseManager.shared

    func load() async {
        guard let uid = firebase.currentUser?.uid else { return }
        isLoading = true

        do {
            // 1. Fetch user's tickets
            let ticketSnap = try await firebase.ticketsCollection
                .whereField("ownerId", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            let tickets = ticketSnap.documents.compactMap { try? $0.data(as: Ticket.self) }

            // 2. Fetch associated events
            var events: [String: Event] = [:]
            let eventIds = Set(tickets.map { $0.eventId })
            for eid in eventIds {
                if let doc = try? await firebase.eventsCollection.document(eid).getDocument(),
                   let event = try? doc.data(as: Event.self) {
                    events[eid] = event
                }
            }

            // 3. Fetch attendance logs for user's tickets
            let ticketIds = tickets.compactMap { $0.id }
            var logs: [AttendanceLog] = []
            for chunk in ticketIds.chunked(into: 10) {
                let logSnap = try await Firestore.firestore()
                    .collection("attendance_logs")
                    .whereField("ticketId", in: chunk)
                    .order(by: "timestamp", descending: true)
                    .limit(to: 50)
                    .getDocuments()
                logs.append(contentsOf: logSnap.documents.compactMap { try? $0.data(as: AttendanceLog.self) })
            }

            // 4. Build notifications
            var all: [UserNotification] = []

            // A. From attendance logs
            for log in logs {
                let ticket = tickets.first { $0.id == log.ticketId }
                let event = ticket.flatMap { events[$0.eventId] }
                all.append(UserNotification(
                    id: log.id ?? UUID().uuidString,
                    type: log.type,
                    ticketId: log.ticketId,
                    eventTitle: event?.title,
                    timestamp: log.timestamp
                ))
            }

            // B. Virtual "purchased" for each ticket
            for ticket in tickets {
                guard let tid = ticket.id else { continue }
                let event = events[ticket.eventId]
                all.append(UserNotification(
                    id: "\(tid)_purchased",
                    type: "purchased",
                    ticketId: tid,
                    eventTitle: event?.title,
                    timestamp: ticket.createdAt
                ))
            }

            // C. Virtual "event_ended" for ended events (if no expired log exists)
            for ticket in tickets {
                guard let event = events[ticket.eventId],
                      let endsAt = event.endsAt,
                      endsAt.dateValue() < Date() else { continue }
                let tid = ticket.id ?? ""
                let hasExpiredLog = logs.contains { $0.ticketId == tid && $0.type == "expired" }
                if !hasExpiredLog {
                    all.append(UserNotification(
                        id: "\(tid)_event_ended",
                        type: "event_ended",
                        ticketId: tid,
                        eventTitle: event.title,
                        timestamp: endsAt
                    ))
                }
            }

            // Sort newest first
            notifications = all.sorted {
                ($0.timestamp?.dateValue() ?? .distantPast) > ($1.timestamp?.dateValue() ?? .distantPast)
            }
        } catch {
            print("❌ UserNotifications load error: \(error.localizedDescription)")
        }

        isLoading = false
        hasLoaded = true
    }
}

// MARK: - View

struct UserNotificationsView: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @StateObject private var viewModel = UserNotificationsViewModel()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if viewModel.isLoading && !viewModel.hasLoaded {
                VStack(spacing: DFSpacing.lg) {
                    ProgressView().controlSize(.large).tint(.dfAccent)
                    Text("Loading updates...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if viewModel.notifications.isEmpty {
                DFEmptyState(
                    icon: "bell.slash",
                    title: "No Updates Yet",
                    message: "Book an event to start seeing updates here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DFSpacing.sm) {
                        // Today / Earlier grouping
                        let grouped = groupedNotifications
                        ForEach(Array(grouped.keys.sorted().reversed()), id: \.self) { section in
                            if let items = grouped[section], !items.isEmpty {
                                // Section header
                                HStack {
                                    Text(section)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                        .tracking(0.5)
                                    Spacer()
                                }
                                .padding(.horizontal, DFSpacing.lg)
                                .padding(.top, DFSpacing.md)

                                ForEach(Array(items.enumerated()), id: \.element.id) { index, notif in
                                    NotificationCard(notification: notif)
                                        .entranceAnimation(index: index)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DFSpacing.lg)
                    .padding(.top, DFSpacing.sm)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .navigationTitle("Updates")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if !viewModel.hasLoaded {
                await viewModel.load()
            }
        }
    }

    // Group by "Today", "Yesterday", "Earlier"
    private var groupedNotifications: [String: [UserNotification]] {
        let calendar = Calendar.current
        var groups: [String: [UserNotification]] = [:]

        for notif in viewModel.notifications {
            let date = notif.timestamp?.dateValue() ?? .distantPast
            let key: String
            if calendar.isDateInToday(date) {
                key = "Today"
            } else if calendar.isDateInYesterday(date) {
                key = "Yesterday"
            } else {
                key = "Earlier"
            }
            groups[key, default: []].append(notif)
        }
        return groups
    }
}

// MARK: - Notification Card

private struct NotificationCard: View {
    let notification: UserNotification

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(notification.color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: notification.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(notification.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    if let ts = notification.timestamp {
                        Text(timeAgo(ts.dateValue()))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }

                if let eventTitle = notification.eventTitle, !eventTitle.isEmpty {
                    Text(eventTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.dfAccent)
                        .lineLimit(1)
                }

                Text(notification.message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 172800 { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
