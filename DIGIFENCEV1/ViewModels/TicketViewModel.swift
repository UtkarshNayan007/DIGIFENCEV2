//
//  TicketViewModel.swift
//  DIGIFENCEV1
//
//  Manages ticket purchase, full activation flow orchestration
//  (nonce → biometric sign → server activate), and status tracking.
//

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import CoreLocation

@MainActor
final class TicketViewModel: ObservableObject {
    
    @Published var isLoading = false
    @Published var isActivating = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var activationSuccess = false
    @Published var entryCode: String?
    
    private let firebase = FirebaseManager.shared
    private let cloudFunctions = CloudFunctionsService.shared
    private let secureEnclave = SecureEnclaveManager.shared
    private let locationManager = LocationManager.shared
    
    // Offline retry queue
    private var pendingActivation: PendingActivation?
    
    struct PendingActivation {
        let ticketId: String
        let nonceId: String
        let signatureBase64: String
        let nonce: String
        let timestamp: Date
    }
    
    // MARK: - Create / Buy Ticket
    
    func createTicket(for event: Event) async -> String? {
        guard let uid = firebase.currentUser?.uid,
              let eventId = event.id else {
            errorMessage = "You must be signed in."
            showError = true
            return nil
        }
        
        isLoading = true
        
        do {
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
            
            let docRef = try await firebase.ticketsCollection.addDocument(data: ticketData)
            
            // Start monitoring this event's geofence
            locationManager.startPolygonMonitoring(for: event, ticketId: docRef.documentID)
            
            isLoading = false
            return docRef.documentID
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
            return nil
        }
    }
    
    // MARK: - Full Activation Flow
    
    /// Complete activation flow:
    /// 1. Request nonce from server
    /// 2. Sign nonce with Secure Enclave (triggers biometric)
    /// 3. Get location with retry
    /// 4. Send signature + location to server for verification
    func activateTicket(_ ticketId: String) async {
        isActivating = true
        errorMessage = nil
        activationSuccess = false
        
        do {
            // Step 1: Request nonce
            let nonceResponse = try await cloudFunctions.createActivationNonce(ticketId: ticketId)
            print("✅ Got nonce: \(nonceResponse.nonceId)")
            
            // Step 2: Sign nonce with Secure Enclave (triggers FaceID/TouchID)
            let signatureBase64 = try secureEnclave.signNonce(nonceResponse.nonce)
            print("✅ Nonce signed with biometrics")
            
            // Step 3: Get current location with retry (up to 5 seconds)
            locationManager.requestCurrentLocation()
            
            var location: CLLocation?
            for _ in 0..<10 {
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                if let loc = locationManager.currentLocation {
                    location = loc
                    break
                }
                // Re-request in case the first one didn't fire
                locationManager.requestCurrentLocation()
            }
            
            guard let finalLocation = location else {
                throw ActivationError.locationUnavailable
            }
            print("✅ Got location: \(finalLocation.coordinate.latitude), \(finalLocation.coordinate.longitude)")
            
            // Step 4: Call activate endpoint
            let result = try await cloudFunctions.activateTicket(
                ticketId: ticketId,
                nonceId: nonceResponse.nonceId,
                signatureBase64: signatureBase64,
                lat: finalLocation.coordinate.latitude,
                lng: finalLocation.coordinate.longitude
            )
            
            if result.success {
                activationSuccess = true
                entryCode = result.entryCode
                print("✅ Ticket activated! Entry code: \(result.entryCode)")
            }
            
        } catch let error as SecureEnclaveError {
            errorMessage = error.localizedDescription
            showError = true
        } catch let error as ActivationError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            // Extract meaningful message from Firebase Functions errors
            let message = Self.extractErrorMessage(from: error)
            print("❌ Activation error: \(error)")
            
            if let pending = pendingActivation,
               Date().timeIntervalSince(pending.timestamp) < 60 {
                errorMessage = "Activation pending. Will retry when connected."
            } else {
                errorMessage = message
            }
            showError = true
        }
        
        isActivating = false
    }
    
    /// Extract a human-readable message from Firebase Functions errors.
    /// Firebase wraps server errors as NSError with domain "com.firebase.functions"
    /// and the actual message in localizedDescription or userInfo.
    private static func extractErrorMessage(from error: Error) -> String {
        let nsError = error as NSError
        
        // Check for Firebase Functions error with a descriptive message
        if nsError.domain == FunctionsErrorDomain {
            // The server message is usually in localizedDescription
            let desc = nsError.localizedDescription
            // If it's just a generic code name, try userInfo
            if desc.isEmpty || desc == "INTERNAL" || desc == "internal" {
                if let details = nsError.userInfo["details"] as? String, !details.isEmpty {
                    return details
                }
                if let message = nsError.userInfo[NSLocalizedDescriptionKey] as? String, !message.isEmpty {
                    return message
                }
                return "Server error. Please try again."
            }
            return desc
        }
        
        return error.localizedDescription
    }
    
    // MARK: - Deactivate Ticket
    
    func deactivateTicket(_ ticketId: String) async {
        isLoading = true
        do {
            try await cloudFunctions.deactivateTicket(ticketId: ticketId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    // MARK: - Send Exit Warning
    
    func sendExitWarning(_ ticketId: String) async {
        do {
            try await cloudFunctions.sendExitWarningNotification(ticketId: ticketId)
        } catch {
            print("⚠️ Failed to send exit warning: \(error.localizedDescription)")
        }
    }
}

// MARK: - Errors

enum ActivationError: LocalizedError {
    case locationUnavailable
    case alreadyActive
    
    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Unable to determine your location. Please ensure location services are enabled."
        case .alreadyActive:
            return "This ticket is already active."
        }
    }
}
