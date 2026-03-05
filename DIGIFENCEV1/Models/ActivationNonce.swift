//
//  ActivationNonce.swift
//  DIGIFENCEV1
//
//  DigiFence activation nonce model matching Firestore activation_nonces/{nonceId} schema.
//  Used for challenge-response biometric verification during ticket activation.
//

import Foundation
import FirebaseFirestore

struct ActivationNonce: Codable, Identifiable {
    @DocumentID var id: String?
    let ticketId: String
    let nonce: String
    let expiresAt: Timestamp
    var used: Bool

    /// Convenience init for programmatic construction and tests
    init(
        id: String? = nil,
        ticketId: String,
        nonce: String,
        expiresAt: Timestamp,
        used: Bool = false
    ) {
        self.ticketId = ticketId
        self.nonce = nonce
        self.expiresAt = expiresAt
        self.used = used
    }
}
