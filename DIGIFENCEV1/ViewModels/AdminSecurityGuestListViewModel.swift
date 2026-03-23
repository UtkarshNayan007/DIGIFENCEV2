//
//  AdminSecurityGuestListViewModel.swift
//  DIGIFENCEV1
//
//  Fetches and manages the list of guests scanned by a specific security person.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class AdminSecurityGuestListViewModel: ObservableObject {
    
    @Published var guests: [AppUser] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    func listenForScannedGuests(securityUid: String, eventId: String?) {
        isLoading = true
        listener?.remove()
        
        var query: Query = db.collection("tickets")
            .whereField("scannedBy", isEqualTo: securityUid)
            .whereField("insideFence", isEqualTo: true)
        
        if let eventId = eventId, !eventId.isEmpty {
            query = query.whereField("eventId", isEqualTo: eventId)
        }
        
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
                return
            }
            
            guard let snapshot = snapshot else {
                self.isLoading = false
                return
            }
            
            Task {
                var fetchedUsers: [AppUser] = []
                for doc in snapshot.documents {
                    if let ticket = try? doc.data(as: Ticket.self) {
                        do {
                            let userDoc = try await self.db.collection("users").document(ticket.ownerId).getDocument()
                            if let user = try? userDoc.data(as: AppUser.self) {
                                fetchedUsers.append(user)
                            }
                        } catch {
                            print("Error fetching user for ticket \(doc.documentID): \(error)")
                        }
                    }
                }
                
                await MainActor.run {
                    self.guests = fetchedUsers
                    self.isLoading = false
                }
            }
        }
    }
    
    deinit {
        listener?.remove()
    }
}
