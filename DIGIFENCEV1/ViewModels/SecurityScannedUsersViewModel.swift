//
//  SecurityScannedUsersViewModel.swift
//  DIGIFENCEV1
//
//  Real-time list of users scanned/checked-in by the current security person.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

/// Represents a scanned guest with ticket + user info.
struct ScannedGuest: Identifiable {
    let id: String          // ticketId
    let userName: String
    let userEmail: String
    let eventTitle: String
    let scannedAt: Date?
    let insideFence: Bool
    let ticketStatus: String
}

@MainActor
final class SecurityScannedUsersViewModel: ObservableObject {

    @Published var guests: [ScannedGuest] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var showError = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    /// Start real-time listener for tickets scanned by the current security user.
    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        listener?.remove()

        listener = db.collection("tickets")
            .whereField("scannedBy", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                    return
                }
                guard let snapshot else {
                    self.isLoading = false
                    return
                }

                Task { await self.resolveGuests(from: snapshot.documents) }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Resolve ticket docs into ScannedGuest models

    private func resolveGuests(from docs: [QueryDocumentSnapshot]) async {
        var result: [ScannedGuest] = []

        // Cache event titles to avoid repeated fetches
        var eventCache: [String: String] = [:]

        for doc in docs {
            guard let ticket = try? doc.data(as: Ticket.self) else { continue }

            // Fetch user info
            let userDoc = try? await db.collection("users").document(ticket.ownerId).getDocument()
            let userName = userDoc?.data()?["displayName"] as? String ?? "Unknown"
            let userEmail = userDoc?.data()?["email"] as? String ?? ""

            // Fetch event title (cached)
            let eventTitle: String
            if let cached = eventCache[ticket.eventId] {
                eventTitle = cached
            } else {
                let eventDoc = try? await db.collection("events").document(ticket.eventId).getDocument()
                let title = eventDoc?.data()?["title"] as? String ?? "Unknown Event"
                eventCache[ticket.eventId] = title
                eventTitle = title
            }

            result.append(ScannedGuest(
                id: doc.documentID,
                userName: userName,
                userEmail: userEmail,
                eventTitle: eventTitle,
                scannedAt: ticket.scannedAt?.dateValue(),
                insideFence: ticket.insideFence,
                ticketStatus: ticket.status.rawValue
            ))
        }

        // Sort newest first
        result.sort { ($0.scannedAt ?? .distantPast) > ($1.scannedAt ?? .distantPast) }

        await MainActor.run {
            self.guests = result
            self.isLoading = false
        }
    }

    deinit {
        listener?.remove()
    }
}
