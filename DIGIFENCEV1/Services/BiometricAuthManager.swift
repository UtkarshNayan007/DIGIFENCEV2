//
//  BiometricAuthManager.swift
//  DIGIFENCEV1
//
//  Login-time biometric MFA using LocalAuthentication.
//  Separate from SecureEnclaveManager (which handles cryptographic signing).
//

import Foundation
import LocalAuthentication

final class BiometricAuthManager {
    
    static let shared = BiometricAuthManager()
    
    private init() {}
    
    // MARK: - Biometric Type
    
    enum BiometricType {
        case faceID
        case touchID
        case none
    }
    
    /// The biometric type available on this device.
    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .none
        }
    }
    
    /// Whether biometric authentication is available on this device.
    var isBiometricAvailable: Bool {
        biometricType != .none
    }
    
    /// Human-readable name for the available biometric type.
    var biometricName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .none: return "Biometrics"
        }
    }
    
    // MARK: - Authentication
    
    /// Authenticate the user with FaceID/TouchID.
    /// Returns `true` on success, throws `BiometricAuthError` on failure.
    func authenticateUser() async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let laError = error {
                throw mapLAError(laError)
            }
            throw BiometricAuthError.notAvailable
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to securely access DigiFence."
            )
            return success
        } catch let laError as LAError {
            throw mapLAError(laError as NSError)
        } catch {
            throw BiometricAuthError.unknown(error.localizedDescription)
        }
    }
    
    // MARK: - Error Mapping
    
    private func mapLAError(_ error: NSError) -> BiometricAuthError {
        guard error.domain == LAError.errorDomain else {
            return .unknown(error.localizedDescription)
        }
        
        switch LAError.Code(rawValue: error.code) {
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancelled
        case .userFallback:
            return .userFallback
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryLockout:
            return .lockout
        case .passcodeNotSet:
            return .passcodeNotSet
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - Errors

enum BiometricAuthError: LocalizedError {
    case notAvailable
    case notEnrolled
    case authenticationFailed
    case userCancelled
    case userFallback
    case lockout
    case passcodeNotSet
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device."
        case .notEnrolled:
            return "No biometrics enrolled. Please set up Face ID or Touch ID in Settings."
        case .authenticationFailed:
            return "Biometric authentication failed. Please try again."
        case .userCancelled:
            return "Authentication was cancelled."
        case .userFallback:
            return "Biometric authentication was dismissed."
        case .lockout:
            return "Biometrics are locked due to too many failed attempts. Use your device passcode to unlock."
        case .passcodeNotSet:
            return "A device passcode is required to use biometric authentication."
        case .unknown(let msg):
            return msg
        }
    }
}
