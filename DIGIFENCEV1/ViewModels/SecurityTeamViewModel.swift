//
//  SecurityTeamViewModel.swift
//  DIGIFENCEV1
//
//  Manages CRUD operations for security personnel via Cloud Functions.
//

import Foundation
import Combine
import SwiftUI
import FirebaseFunctions
import FirebaseFirestore
import FirebaseAuth

struct SecurityPerson: Identifiable {
    let id: String // uid
    let email: String
    let name: String
    let assignedEventId: String?
    var assignedEventTitle: String?
}

@MainActor
final class SecurityTeamViewModel: ObservableObject {
    
    @Published var personnel: [SecurityPerson] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Create flow
    @Published var showCreateSheet = false
    @Published var newName = ""
    @Published var newEmail = ""
    @Published var newPassword = ""
    @Published var selectedEventId: String?
    @Published var isCreating = false
    @Published var showCreatedSuccess = false
    
    // Reset password flow
    @Published var resetPassword: String?
    @Published var showResetAlert = false
    
    // Available events (for assignment picker)
    @Published var availableEvents: [Event] = []
    
    private let functions = Functions.functions()
    private let db = Firestore.firestore()
    
    // MARK: - List
    
    func fetchPersonnel() async {
        isLoading = true
        do {
            let result = try await functions.httpsCallable("listSecurityPersonnel").call()
            guard let data = result.data as? [String: Any],
                  let list = data["personnel"] as? [[String: Any]] else {
                isLoading = false
                return
            }
            
            var items = list.compactMap { item -> SecurityPerson? in
                guard let uid = item["uid"] as? String,
                      let email = item["email"] as? String,
                      let name = item["name"] as? String else { return nil }
                return SecurityPerson(
                    id: uid,
                    email: email,
                    name: name,
                    assignedEventId: item["assignedEventId"] as? String
                )
            }
            
            // Resolve event titles
            for i in items.indices {
                if let eventId = items[i].assignedEventId, !eventId.isEmpty {
                    let eventDoc = try? await db.collection("events").document(eventId).getDocument()
                    items[i].assignedEventTitle = eventDoc?.data()?["title"] as? String
                }
            }
            
            personnel = items
        } catch {
            errorMessage = extractMessage(from: error)
            showError = true
        }
        isLoading = false
    }
    
    // MARK: - Fetch Events
    
    func fetchEvents() async {
        guard let uid = FirebaseManager.shared.currentUser?.uid else { return }
        do {
            let snapshot = try await db.collection("events")
                .whereField("organizerId", isEqualTo: uid)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            availableEvents = snapshot.documents.compactMap { try? $0.data(as: Event.self) }
        } catch {
            print("Failed to fetch events: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Create
    
    func createPerson() async {
        guard !newEmail.isEmpty, !newName.isEmpty else {
            errorMessage = "Name and email are required."
            showError = true
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            showError = true
            return
        }
        
        isCreating = true
        do {
            var payload: [String: Any] = [
                "email": newEmail.lowercased().trimmingCharacters(in: .whitespaces),
                "name": newName.trimmingCharacters(in: .whitespaces),
                "password": newPassword
            ]
            if let eventId = selectedEventId {
                payload["assignedEventId"] = eventId
            }
            
            let _ = try await functions.httpsCallable("createSecurityPersonnel").call(payload)
            
            showCreatedSuccess = true
            newName = ""
            newEmail = ""
            newPassword = ""
            selectedEventId = nil
            showCreateSheet = false
            await fetchPersonnel()
        } catch {
            errorMessage = extractMessage(from: error)
            showError = true
        }
        isCreating = false
    }
    
    // MARK: - Remove
    
    func removePerson(_ person: SecurityPerson) async {
        do {
            let _ = try await functions.httpsCallable("removeSecurityPersonnel").call([
                "securityUid": person.id
            ])
            HapticManager.shared.success()
            await fetchPersonnel()
        } catch {
            errorMessage = extractMessage(from: error)
            showError = true
        }
    }
    
    // MARK: - Reset Password
    
    func resetPasswordFor(_ person: SecurityPerson) async {
        do {
            let result = try await functions.httpsCallable("resetSecurityPassword").call([
                "securityUid": person.id
            ])
            if let data = result.data as? [String: Any],
               let newPw = data["newPassword"] as? String {
                resetPassword = newPw
                showResetAlert = true
            }
        } catch {
            errorMessage = extractMessage(from: error)
            showError = true
        }
    }
    
    // MARK: - Helper
    
    private func extractMessage(from error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == FunctionsErrorDomain {
            return nsError.localizedDescription
        }
        return error.localizedDescription
    }
}
