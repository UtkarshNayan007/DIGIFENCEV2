//
//  AuthErrorHandler.swift
//  DIGIFENCEV1
//
//  Maps Firebase Auth and biometric errors to user-friendly messages.
//

import Foundation
import FirebaseAuth

enum AuthErrorHandler {
    
    /// Convert any authentication-related error to a user-friendly message.
    static func message(for error: Error) -> String {
        // Firebase Auth errors
        if let authError = error as NSError?,
           authError.domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: authError.code) {
            return firebaseAuthMessage(code: code)
        }
        
        // Biometric errors
        if let bioError = error as? BiometricAuthError {
            return bioError.localizedDescription
        }
        
        // SecureEnclave errors
        if let seError = error as? SecureEnclaveError {
            return seError.localizedDescription
        }
        
        return error.localizedDescription
    }
    
    // MARK: - Firebase Auth Error Messages
    
    private static func firebaseAuthMessage(code: AuthErrorCode) -> String {
        switch code {
        case .invalidEmail:
            return "The email address is invalid."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .wrongPassword, .invalidCredential:
            return "Incorrect email or password."
        case .userNotFound:
            return "No account found with this email."
        case .userDisabled:
            return "This account has been disabled."
        case .tooManyRequests:
            return "Too many attempts. Please wait a moment and try again."
        case .networkError:
            return "Network error. Please check your connection."
        case .requiresRecentLogin:
            return "Please sign in again to complete this action."
        default:
            return "Authentication failed. Please try again."
        }
    }
}
