//
//  Ticket.swift
//  DIGIFENCEV1
//
//  DigiFence ticket model matching Firestore tickets/{ticketId} schema.
//

import Foundation
import FirebaseFirestore

struct Ticket: Codable, Identifiable {
    @DocumentID var id: String?
    let eventId: String
    let ownerId: String
    var status: TicketStatus
    var biometricVerified: Bool
    var insideFence: Bool
    var activatedAt: Timestamp?
    var entryCode: String?
    @ServerTimestamp var createdAt: Timestamp?
    
    enum TicketStatus: String, Codable {
        case pending
        case active
        case expired
    }
    
    var isActive: Bool { status == .active }
    var isPending: Bool { status == .pending }
    var isExpired: Bool { status == .expired }
    
    var statusDisplayText: String {
        switch status {
        case .pending: return "Pending Activation"
        case .active: return "Active"
        case .expired: return "Expired"
        }
    }
    
    var statusColor: String {
        switch status {
        case .pending: return "orange"
        case .active: return "green"
        case .expired: return "red"
        }
    }
    
    /// Convenience init for tests and programmatic construction
    init(
        id: String? = nil,
        eventId: String,
        ownerId: String,
        status: TicketStatus = .pending,
        biometricVerified: Bool = false,
        insideFence: Bool = false,
        activatedAt: Timestamp? = nil,
        entryCode: String? = nil,
        createdAt: Timestamp? = nil
    ) {
        self.eventId = eventId
        self.ownerId = ownerId
        self.status = status
        self.biometricVerified = biometricVerified
        self.insideFence = insideFence
        self.activatedAt = activatedAt
        self.entryCode = entryCode
    }
}
