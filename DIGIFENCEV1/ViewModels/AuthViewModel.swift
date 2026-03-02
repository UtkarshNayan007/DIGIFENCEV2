//
//  AuthViewModel.swift
//  DIGIFENCEV1
//
//  Handles email/password and Google sign-in, user document creation,
//  and Secure Enclave key generation on first sign-up.
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
    
    private let firebase = FirebaseManager.shared
    private let secureEnclave = SecureEnclaveManager.shared
    
    // MARK: - Email Sign Up
    
    func signUp() async {
        guard validate() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create Firebase Auth user
            let result = try await firebase.auth.createUser(withEmail: email, password: password)
            let uid = result.user.uid
            
            // Create user document
            try await firebase.createUserDocument(
                uid: uid,
                email: email,
                displayName: displayName.isEmpty ? email : displayName
            )
            
            // Generate Secure Enclave key and upload public key
            await generateAndUploadKey()
            
            // Request push notification permission
            Task {
                await PushManager.shared.requestPermission()
            }
            
        } catch {
            errorMessage = error.localizedDescription
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
            try await firebase.auth.signIn(withEmail: email, password: password)
            
            // Check if key exists, if not generate one
            if !secureEnclave.hasExistingKey() {
                await generateAndUploadKey()
            }
            
            // Request push notification permission
            Task {
                await PushManager.shared.requestPermission()
            }
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get CLIENT_ID from GoogleService-Info.plist
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                errorMessage = "Google Sign-In is not configured. Missing CLIENT_ID in GoogleService-Info.plist."
                showError = true
                isLoading = false
                return
            }
            
            // Use Google Sign-In via OAuthProvider
            let provider = OAuthProvider(providerID: "google.com")
            provider.customParameters = [
                "client_id": clientID,
                "prompt": "select_account"
            ]
            provider.scopes = ["email", "profile"]
            
            // Present the sign-in flow
            let result = try await provider.credential(with: nil)
            let authResult = try await firebase.auth.signIn(with: result)
            
            let user = authResult.user
            let email = user.email ?? ""
            let displayName = user.displayName ?? email
            
            // Check if user document exists, create if not
            let docSnapshot = try await firebase.usersCollection.document(user.uid).getDocument()
            if !docSnapshot.exists {
                try await firebase.createUserDocument(
                    uid: user.uid,
                    email: email,
                    displayName: displayName
                )
            }
            
            // Generate Secure Enclave key if needed
            if !secureEnclave.hasExistingKey() {
                await generateAndUploadKey()
            }
            
            // Request push notification permission
            Task {
                await PushManager.shared.requestPermission()
            }
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try firebase.signOut()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - Apple Sign In
    
    /// Current nonce used for Apple Sign-In (must be stored for verification)
    private var currentAppleNonce: String?
    
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let nonce = randomNonceString()
            currentAppleNonce = nonce
            let hashedNonce = sha256(nonce)
            
            // Use ASAuthorizationController via the helper
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
            
            // Check if user document exists, create if not
            let docSnapshot = try await firebase.usersCollection.document(user.uid).getDocument()
            if !docSnapshot.exists {
                try await firebase.createUserDocument(
                    uid: user.uid,
                    email: userEmail,
                    displayName: userName
                )
            }
            
            // Generate Secure Enclave key if needed
            if !secureEnclave.hasExistingKey() {
                await generateAndUploadKey()
            }
            
            Task { await PushManager.shared.requestPermission() }
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    /// Perform Apple Sign-In using ASAuthorizationController
    private func performAppleSignIn(hashedNonce: String) async throws -> AppleSignInResult {
        return try await withCheckedThrowingContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce
            
            let delegate = AppleSignInDelegate(continuation: continuation)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            
            // Hold strong reference to delegate
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            
            controller.performRequests()
        }
    }
    
    /// Generate a random nonce string
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
    
    /// SHA256 hash for Apple Sign-In nonce
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Key Generation
    
    private func generateAndUploadKey() async {
        do {
            let publicKeyBase64 = try secureEnclave.generateKeyPair()
            try await firebase.updatePublicKey(publicKeyBase64)
            print("🔐 Public key uploaded to Firestore")
        } catch {
            print("⚠️ Secure Enclave key generation failed: \(error.localizedDescription)")
            // Non-fatal — user can still use the app but will need manual verification
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
