//
//  FirebaseManager.swift
//  DIGIFENCEV1
//
//  Singleton managing Firestore references, Auth state, and user doc CRUD.
//

import Foundation
import Combine
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

final class FirebaseManager: ObservableObject {
    
    static let shared = FirebaseManager()
    
    let auth: Auth
    let db: Firestore
    
    @Published var currentUser: FirebaseAuth.User?
    @Published var appUser: AppUser?
    @Published var isLoggedIn = false
    @Published var isLoading = true
    @Published var isBiometricAuthenticated = false
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?
    
    // MARK: - Collection References
    var usersCollection: CollectionReference { db.collection("users") }
    var eventsCollection: CollectionReference { db.collection("events") }
    var ticketsCollection: CollectionReference { db.collection("tickets") }
    
    private init() {
        self.auth = Auth.auth()
        self.db = Firestore.firestore()
        
        // Check for emulator (set this in scheme environment variables for debug)
        #if DEBUG
        if ProcessInfo.processInfo.environment["USE_FIREBASE_EMULATOR"] == "1" {
            auth.useEmulator(withHost: "localhost", port: 9099)
            let settings = db.settings
            settings.host = "localhost:8080"
            settings.cacheSettings = MemoryCacheSettings()
            settings.isSSLEnabled = false
            db.settings = settings
        }
        #endif
        
        listenToAuthState()
    }
    
    // MARK: - Auth State
    
    private func listenToAuthState() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.currentUser = user
                // isLoggedIn requires both Firebase auth AND biometric verification
                self.isLoggedIn = user != nil && self.isBiometricAuthenticated
                if let user = user {
                    self.listenToUserDoc(uid: user.uid)
                } else {
                    self.userListener?.remove()
                    self.userListener = nil
                    self.appUser = nil
                    self.isBiometricAuthenticated = false
                }
                self.isLoading = false
            }
        }
    }
    
    private func listenToUserDoc(uid: String) {
        print("🔍 Listening to Firestore document for UID: \(uid)")
        userListener?.remove()
        userListener = usersCollection.document(uid).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ User doc listener error: \(error.localizedDescription)")
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                print("⚠️ Firestore document does not exist for UID: \(uid)")
                DispatchQueue.main.async { self.appUser = nil }
                return
            }
            print("✅ Firestore document exists for UID: \(uid)")
            do {
                let user = try snapshot.data(as: AppUser.self)
                print("✅ Successfully decoded user: \(user.email), role: \(user.role)")
                DispatchQueue.main.async { self.appUser = user }
            } catch {
                print("❌ Failed to decode user: \(error)")
                print("📄 Raw document data: \(snapshot.data() ?? [:])")
            }
        }
    }
    
    // MARK: - User Document CRUD
    
    func createUserDocument(uid: String, email: String, displayName: String) async throws {
        let userData: [String: Any] = [
            "email": email,
            "displayName": displayName,
            "role": "user",
            "publicKey": NSNull(),
            "deviceId": NSNull(),
            "fcmToken": NSNull(),
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await usersCollection.document(uid).setData(userData)
    }
    
    func updatePublicKey(_ publicKey: String) async throws {
        guard let uid = currentUser?.uid else { throw FirebaseError.notAuthenticated }
        try await usersCollection.document(uid).updateData([
            "publicKey": publicKey
        ])
    }
    
    func updateFCMToken(_ token: String) async throws {
        guard let uid = currentUser?.uid else { return }
        try await usersCollection.document(uid).updateData([
            "fcmToken": token
        ])
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        isBiometricAuthenticated = false
        isLoggedIn = false
        try auth.signOut()
    }
    
    deinit {
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
        userListener?.remove()
    }
}

// MARK: - Errors

enum FirebaseError: LocalizedError {
    case notAuthenticated
    case documentNotFound
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in."
        case .documentNotFound: return "Document not found."
        case .unknown(let msg): return msg
        }
    }
}
