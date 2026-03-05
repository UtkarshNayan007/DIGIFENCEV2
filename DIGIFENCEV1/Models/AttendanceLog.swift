//
//  AttendanceLog.swift
//  DIGIFENCEV1
//
//  DigiFence attendance log model matching Firestore attendance_logs/{logId} schema.
//  Records entry, exit, and activation events for audit purposes.
//

import Foundation
import FirebaseFirestore

struct AttendanceLog: Codable, Identifiable {
    @DocumentID var id: String?
    let ticketId: String
    let type: String
    var detail: [String: AnyCodable]?
    @ServerTimestamp var timestamp: Timestamp?

    var typeIcon: String {
        switch type {
        case "activated": return "checkmark.circle.fill"
        case "exited": return "arrow.right.circle.fill"
        case "expired": return "xmark.circle.fill"
        default: return "circle"
        }
    }

    var typeColor: String {
        switch type {
        case "activated": return "green"
        case "exited": return "orange"
        case "expired": return "red"
        default: return "gray"
        }
    }

    /// Convenience init for programmatic construction and tests
    init(
        id: String? = nil,
        ticketId: String,
        type: String,
        detail: [String: AnyCodable]? = nil,
        timestamp: Timestamp? = nil
    ) {
        self.ticketId = ticketId
        self.type = type
        self.detail = detail
    }
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) { value = bool }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let string = try? container.decode(String.self) { value = string }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let bool = value as? Bool { try container.encode(bool) }
        else if let int = value as? Int { try container.encode(int) }
        else if let double = value as? Double { try container.encode(double) }
        else if let string = value as? String { try container.encode(string) }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
