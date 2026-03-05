//
//  TicketPurchaseService.swift
//  DIGIFENCEV1
//
//  Atomic ticket purchase using Firestore transactions to prevent
//  race conditions when multiple users buy tickets simultaneously.
//  Reads event capacity, creates ticket, and increments ticketsSold
//  in a single transaction — no partial tickets on failure.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

enum TicketPurchaseError: LocalizedError {
    case notAuthenticated
    case eventNotFound
    case soldOut
    case transactionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to purchase a ticket."
        case .eventNotFound:
            return "Event not found."
        case .soldOut:
            return "Sold out"
        case .transactionFailed(let message):
            return "Ticket purchase failed: \(message)"
        }
    }
}

final class TicketPurchaseService {

    static let shared = TicketPurchaseService()

    private let db = Firestore.firestore()
    private let firebase = FirebaseManager.shared

    private init() {}

    /// Atomically purchase a ticket for the given event.
    ///
    /// Uses `Firestore.runTransaction` to:
    /// 1. Read the event document and verify `ticketsSold < capacity`
    /// 2. Create a new ticket document with status `"pending"`
    /// 3. Increment the event's `ticketsSold` by 1
    ///
    /// - Parameter event: The event to purchase a ticket for.
    /// - Returns: The document ID of the newly created ticket.
    /// - Throws: `TicketPurchaseError` on auth, capacity, or transaction failure.
    @discardableResult
    func purchaseTicket(for event: Event) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw TicketPurchaseError.notAuthenticated
        }
        guard let eventId = event.id else {
            throw TicketPurchaseError.eventNotFound
        }

        let eventRef = firebase.eventsCollection.document(eventId)
        // Pre-create the ticket document reference so we can write it inside the transaction
        let ticketRef = firebase.ticketsCollection.document()

        do {
            try await db.runTransaction { transaction, errorPointer in
                // 1. Read the event document
                let eventSnapshot: DocumentSnapshot
                do {
                    eventSnapshot = try transaction.getDocument(eventRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                guard eventSnapshot.exists,
                      let data = eventSnapshot.data() else {
                    let err = NSError(
                        domain: "TicketPurchaseService",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Event not found."]
                    )
                    errorPointer?.pointee = err
                    return nil
                }

                let capacity = data["capacity"] as? Int ?? 0
                let ticketsSold = data["ticketsSold"] as? Int ?? 0

                // 2. Check capacity
                if ticketsSold >= capacity {
                    let err = NSError(
                        domain: "TicketPurchaseService",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Sold out"]
                    )
                    errorPointer?.pointee = err
                    return nil
                }

                // 3. Create ticket document
                let ticketData: [String: Any] = [
                    "eventId": eventId,
                    "ownerId": uid,
                    "status": "pending",
                    "biometricVerified": false,
                    "insideFence": false,
                    "activatedAt": NSNull(),
                    "entryCode": NSNull(),
                    "createdAt": FieldValue.serverTimestamp()
                ]
                transaction.setData(ticketData, forDocument: ticketRef)

                // 4. Increment ticketsSold
                transaction.updateData(
                    ["ticketsSold": FieldValue.increment(Int64(1))],
                    forDocument: eventRef
                )

                return nil
            }
        } catch {
            // Map known error messages to typed errors
            let message = error.localizedDescription
            if message.contains("Sold out") {
                throw TicketPurchaseError.soldOut
            }
            if message.contains("Event not found") {
                throw TicketPurchaseError.eventNotFound
            }
            throw TicketPurchaseError.transactionFailed(message)
        }

        return ticketRef.documentID
    }
}
