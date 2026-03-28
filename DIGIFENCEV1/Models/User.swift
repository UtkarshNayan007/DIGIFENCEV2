//
//  User.swift
//  DIGIFENCEV1
//
//  DigiFence user model matching Firestore users/{uid} schema.
//

import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    let email: String
    var displayName: String
    var phoneNumber: String?
    var role: UserRole
    var publicKey: String?
    var deviceId: String?
    var fcmToken: String?
    var assignedEventId: String?
    var assignedEventIds: [String]?
    var createdByAdminId: String?
    @ServerTimestamp var createdAt: Timestamp?
    
    var uid: String { id ?? "" }
    var isAdmin: Bool { role == .admin }
    var isSecurity: Bool { role == .security }
    
    enum UserRole: String, Codable {
        case admin
        case user
        case security
    }
    
    enum CodingKeys: String, CodingKey {
        case id, email, displayName, phoneNumber, role, publicKey, deviceId, fcmToken, assignedEventId, assignedEventIds, createdByAdminId, createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decodeIfPresent(DocumentID<String>.self, forKey: .id) ?? DocumentID(wrappedValue: nil)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        role = try container.decodeIfPresent(UserRole.self, forKey: .role) ?? .user
        publicKey = try container.decodeIfPresent(String.self, forKey: .publicKey)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        fcmToken = try container.decodeIfPresent(String.self, forKey: .fcmToken)
        assignedEventId = try container.decodeIfPresent(String.self, forKey: .assignedEventId)
        assignedEventIds = try container.decodeIfPresent([String].self, forKey: .assignedEventIds)
        createdByAdminId = try container.decodeIfPresent(String.self, forKey: .createdByAdminId)
        _createdAt = try container.decodeIfPresent(ServerTimestamp<Timestamp>.self, forKey: .createdAt) ?? ServerTimestamp(wrappedValue: nil)
    }
    
    init(email: String, displayName: String, phoneNumber: String? = nil, role: UserRole = .user, publicKey: String? = nil) {
        self.email = email
        self.displayName = displayName
        self.phoneNumber = phoneNumber
        self.role = role
        self.publicKey = publicKey
    }
}
