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
    
    /// Purchases a ticket using a Firestore transaction to atomically
    /// verify capacity, create the ticket, and increment ticketsSold.
    func createTicket(for event: Event) async -> String? {
        isLoading = true
        
        do {
            let ticketId = try await TicketPurchaseService.shared.purchaseTicket(for: event)
            
            // Start monitoring this event's geofence
            locationManager.startPolygonMonitoring(for: event, ticketId: ticketId)
            
            isLoading = false
            return ticketId
            
        } catch let error as TicketPurchaseError {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
            return nil
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
    /// 3. Send signature + location to server for verification
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
            
            // Step 3: Get current location
            locationManager.requestCurrentLocation()
            
            // Wait briefly for location update
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            guard let location = locationManager.currentLocation else {
                throw ActivationError.locationUnavailable
            }
            
            // Step 4: Call activate endpoint
            let result = try await cloudFunctions.activateTicket(
                ticketId: ticketId,
                nonceId: nonceResponse.nonceId,
                signatureBase64: signatureBase64,
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude
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
            // Network failure — attempt offline queue
            if let pending = pendingActivation,
               Date().timeIntervalSince(pending.timestamp) < 60 {
                // Already have a pending activation attempt
                errorMessage = "Activation pending. Will retry when connected."
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
        }
        
        isActivating = false
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
