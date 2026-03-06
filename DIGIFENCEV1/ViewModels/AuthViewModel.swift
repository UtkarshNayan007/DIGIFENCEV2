//
//  AuthViewModel.swift
//  DIGIFENCEV1
//
//  Handles email/password, Google, and Apple sign-in with:
//  • Email verification on signup
//  • Email-verified gate on login
//  • Biometric MFA (FaceID/TouchID) after login
//  • Secure Enclave key generation on first sign-up
//

import Foundation
import Combine
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: ObservableObject {
    
    @Published var email = ""
    @Published var password = ""
    @Published var displayName = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Email verification state
    @Published var showVerificationSent = false
    @Published var verificationMessage: String?
    
    private let firebase = FirebaseManager.shared
    private let secureEnclave = SecureEnclaveManager.shared
    private let biometricAuth = BiometricAuthManager.shared
    
    // MARK: - Email Sign Up
    
    func signUp() async {
        guard validate() else { return }
        
        isLoading = true
        errorMessage = nil
        showVerificationSent = false
        
        do {
            // Step 1: Create Firebase Auth user
            let result = try await firebase.auth.createUser(withEmail: email, password: password)
            let uid = result.user.uid
            
            // Step 2: Create user document in Firestore
            try await firebase.createUserDocument(
                uid: uid,
                email: email,
                displayName: displayName.isEmpty ? email : displayName
            )
            
            // Step 3: Send email verification
            try await result.user.sendEmailVerification()
            print("📧 Verification email sent to \(email)")
            
            // Step 4: Sign out — user must verify email before logging in
            try firebase.signOut()
            
            // Step 5: Show verification message
            verificationMessage = "Verification email sent to \(email). Please verify your email before logging in."
            showVerificationSent = true
            
        } catch {
            errorMessage = AuthErrorHandler.message(for: error)
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Email Sign In
    
    func signIn() async {
        guard validateSignIn() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Step 1: Firebase sign-in
            let result = try await firebase.auth.signIn(withEmail: email, password: password)
            
            // Step 2: Check email verification
            // Reload user to get fresh isEmailVerified status
            try await result.user.reload()
            
            guard result.user.isEmailVerified else {
                // Not verified — sign out and block
                try firebase.signOut()
                errorMessage = "Please verify your email before accessing DigiFence. Check your inbox for the verification link."
                showError = true
                isLoading = false
                return
            }
            
            // Step 3: Biometric MFA
            let biometricPassed = await performBiometricMFA()
            guard biometricPassed else {
                // Biometric failed — sign out
                try firebase.signOut()
                isLoading = false
                return
            }
            
            // Step 4: Mark biometric authenticated
            firebase.isBiometricAuthenticated = true
            
            // Step 5: Generate Secure Enclave key if needed
            if !secureEnclave.hasExistingKey() {
                await generateAndUploadKey()
            }
            
            // Step 6: Request push notification permission
            Task { await PushManager.shared.requestPermission() }
            
        } catch {
            errorMessage = AuthErrorHandler.message(for: error)
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                errorMessage = "Google Sign-In is not configured. Missing CLIENT_ID in GoogleService-Info.plist."
                showError = true
                isLoading = false
                return
            }
            
            let provider = OAuthProvider(providerID: "google.com")
            provider.customParameters = [
                "client_id": clientID,
                "prompt": "select_account"
            ]
            provider.scopes = ["email", "profile"]
            
            let result = try await provider.credential(with: nil)
            let authResult = try await firebase.auth.signIn(with: result)
            
            let user = authResult.user
            let userEmail = user.email ?? ""
            let userName = user.displayName ?? userEmail
            
            // Create user document if first login
            let docSnapshot = try await firebase.usersCollection.document(user.uid).getDocument()
            if !docSnapshot.exists {
                try await firebase.createUserDocument(
                    uid: user.uid,
                    email: userEmail,
                    displayName: userName
                )
            }
            
            // Biometric MFA (OAuth emails are pre-verified)
            let biometricPassed = await performBiometricMFA()
            guard biometricPassed else {
                try firebase.signOut()
                isLoading = false
                return
            }
            
            firebase.isBiometricAuthenticated = true
            
            if !secureEnclave.hasExistingKey() {
                await generateAndUploadKey()
            }
            
            Task { await PushManager.shared.requestPermission() }
            
        } catch {
            errorMessage = AuthErrorHandler.message(for: error)
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Apple Sign In
    
    private var currentAppleNonce: String?
    
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let nonce = randomNonceString()
            currentAppleNonce = nonce
            let hashedNonce = sha256(nonce)
            
            let appleResult = try await performAppleSignIn(hashedNonce: hashedNonce)
            
            guard let appleIDToken = appleResult.identityToken,
                  let tokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Unable to get Apple ID token."
                showError = true
                isLoading = false
                return
            }
            
            let credential = OAuthProvider.credential(
                providerID: .apple,
                idToken: tokenString,
                rawNonce: nonce
            )
            
            let authResult = try await firebase.auth.signIn(with: credential)
            let user = authResult.user
            let userEmail = user.email ?? appleResult.email ?? ""
            let userName = appleResult.fullName ?? user.displayName ?? userEmail
            
            // Create user document if first login
            let docSnapshot = try await firebase.usersCollection.document(user.uid).getDocument()
            if !docSnapshot.exists {
                try await firebase.createUserDocument(
                    uid: user.uid,
                    email: userEmail,
                    displayName: userName
                )
            }
            
            // Biometric MFA (OAuth emails are pre-verified)
            let biometricPassed = await performBiometricMFA()
            guard biometricPassed else {
                try firebase.signOut()
                isLoading = false
                return
            }
            
            firebase.isBiometricAuthenticated = true
            
            if !secureEnclave.hasExistingKey() {
                await generateAndUploadKey()
            }
            
            Task { await PushManager.shared.requestPermission() }
            
        } catch {
            errorMessage = AuthErrorHandler.message(for: error)
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try firebase.signOut()
        } catch {
            errorMessage = AuthErrorHandler.message(for: error)
            showError = true
        }
    }
    
    // MARK: - Resend Verification Email
    
    func resendVerificationEmail() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Sign in temporarily just to resend
            let result = try await firebase.auth.signIn(withEmail: email, password: password)
            try await result.user.sendEmailVerification()
            try firebase.signOut()
            
            verificationMessage = "Verification email resent to \(email)."
            showVerificationSent = true
        } catch {
            errorMessage = AuthErrorHandler.message(for: error)
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Biometric MFA
    
    /// Perform biometric authentication. Returns true on success, false on failure (error already shown).
    private func performBiometricMFA() async -> Bool {
        guard biometricAuth.isBiometricAvailable else {
            // Biometrics not available — allow through with warning
            print("⚠️ Biometrics not available on this device, skipping MFA")
            return true
        }
        
        do {
            let success = try await biometricAuth.authenticateUser()
            if success {
                print("✅ Biometric MFA passed")
            }
            return success
        } catch let error as BiometricAuthError {
            switch error {
            case .userCancelled:
                errorMessage = "Authentication cancelled. You must authenticate to access DigiFence."
            default:
                errorMessage = error.localizedDescription
            }
            showError = true
            return false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    // MARK: - Biometric Unlock (for returning users / app relaunch)
    
    func unlockWithBiometrics() async {
        let passed = await performBiometricMFA()
        if passed {
            firebase.isBiometricAuthenticated = true
        }
    }
    
    // MARK: - Key Generation
    
    private func generateAndUploadKey() async {
        do {
            let publicKeyBase64 = try secureEnclave.generateKeyPair()
            try await firebase.updatePublicKey(publicKeyBase64)
            print("🔐 Public key uploaded to Firestore")
        } catch {
            print("⚠️ Secure Enclave key generation failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Validation
    
    private func validate() -> Bool {
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Please enter your email."
            showError = true
            return false
        }
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            showError = true
            return false
        }
        return true
    }
    
    private func validateSignIn() -> Bool {
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Please enter your email."
            showError = true
            return false
        }
        if password.isEmpty {
            errorMessage = "Please enter your password."
            showError = true
            return false
        }
        return true
    }
    
    // MARK: - Apple Sign-In Helpers
    
    private func performAppleSignIn(hashedNonce: String) async throws -> AppleSignInResult {
        return try await withCheckedThrowingContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce
            
            let delegate = AppleSignInDelegate(continuation: continuation)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            
            controller.performRequests()
        }
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed.")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Apple Sign-In Helpers

struct AppleSignInResult {
    let identityToken: Data?
    let email: String?
    let fullName: String?
}

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let continuation: CheckedContinuation<AppleSignInResult, Error>
    
    init(continuation: CheckedContinuation<AppleSignInResult, Error>) {
        self.continuation = continuation
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation.resume(throwing: NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Apple credential"]))
            return
        }
        
        let fullName: String? = {
            if let nameComponents = credential.fullName {
                let parts = [nameComponents.givenName, nameComponents.familyName].compactMap { $0 }
                return parts.isEmpty ? nil : parts.joined(separator: " ")
            }
            return nil
        }()
        
        let result = AppleSignInResult(
            identityToken: credential.identityToken,
            email: credential.email,
            fullName: fullName
        )
        continuation.resume(returning: result)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}
