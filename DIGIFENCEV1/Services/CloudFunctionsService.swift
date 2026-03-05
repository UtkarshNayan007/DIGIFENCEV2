//
//  CloudFunctionsService.swift
//  DIGIFENCEV1
//
//  Wrapper around Firebase Cloud Functions httpsCallable calls.
//

import Foundation
import FirebaseFunctions

final class CloudFunctionsService {
    
    static let shared = CloudFunctionsService()
    
    private let functions: Functions
    
    private init() {
        self.functions = Functions.functions()
        
        #if DEBUG
        if ProcessInfo.processInfo.environment["USE_FIREBASE_EMULATOR"] == "1" {
            functions.useEmulator(withHost: "localhost", port: 5001)
        }
        #endif
    }
    
    // MARK: - Create Activation Nonce
    
    struct NonceResponse {
        let nonceId: String
        let nonce: String
    }
    
    func createActivationNonce(ticketId: String) async throws -> NonceResponse {
        let callable = functions.httpsCallable("createActivationNonce")
        let result = try await callable.call(["ticketId": ticketId])
        
        guard let data = result.data as? [String: Any],
              let nonceId = data["nonceId"] as? String,
              let nonce = data["nonce"] as? String else {
            throw CloudFunctionError.invalidResponse
        }
        
        return NonceResponse(nonceId: nonceId, nonce: nonce)
    }
    
    // MARK: - Activate Ticket
    
    struct ActivationResponse {
        let success: Bool
        let entryCode: String
    }
    
    func activateTicket(
        ticketId: String,
        nonceId: String,
        signatureBase64: String,
        lat: Double,
        lng: Double
    ) async throws -> ActivationResponse {
        let callable = functions.httpsCallable("activateTicket")
        let result = try await callable.call([
            "ticketId": ticketId,
            "nonceId": nonceId,
            "signatureBase64": signatureBase64,
            "lat": lat,
            "lng": lng
        ])
        
        guard let data = result.data as? [String: Any],
              let success = data["success"] as? Bool,
              let entryCode = data["entryCode"] as? String else {
            throw CloudFunctionError.invalidResponse
        }
        
        return ActivationResponse(success: success, entryCode: entryCode)
    }
    
    // MARK: - Deactivate Ticket
    
    func deactivateTicket(ticketId: String) async throws {
        let callable = functions.httpsCallable("deactivateTicket")
        _ = try await callable.call(["ticketId": ticketId])
    }
    
    // MARK: - Send Exit Warning
    
    func sendExitWarningNotification(ticketId: String) async throws {
        let callable = functions.httpsCallable("sendExitWarningNotification")
        _ = try await callable.call(["ticketId": ticketId])
    }
    
    // MARK: - On First Login Assign Role
    
    func onFirstLoginAssignRole() async throws {
        let callable = functions.httpsCallable("onFirstLoginAssignRole")
        _ = try await callable.call()
    }
    
    // MARK: - Revoke Public Key
    
    func revokePublicKey(targetUserId: String) async throws {
        let callable = functions.httpsCallable("revokePublicKey")
        _ = try await callable.call(["targetUserId": targetUserId])
    }
}

// MARK: - Errors

enum CloudFunctionError: LocalizedError {
    case invalidResponse
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server."
        case .serverError(let msg): return msg
        }
    }
}
