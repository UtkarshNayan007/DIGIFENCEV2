//
//  EventsViewModel.swift
//  DIGIFENCEV1
//
//  Real-time Firestore listener for active events with pagination.
//

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore

@MainActor
final class EventsViewModel: ObservableObject {
    
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var listener: ListenerRegistration?
    private let firebase = FirebaseManager.shared
    private let pageSize = 50
    
    // MARK: - Real-time Listener
    
    func startListening() {
        isLoading = true
        
        listener = firebase.eventsCollection
            .whereField("isActive", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("❌ Events listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.events = []
                    return
                }
                
                self.events = documents.compactMap { doc in
                    try? doc.data(as: Event.self)
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: - Search
    
    func filteredEvents(searchText: String) -> [Event] {
        if searchText.isEmpty { return events }
        return events.filter { event in
            event.title.localizedCaseInsensitiveContains(searchText) ||
            (event.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    deinit {
        listener?.remove()
    }
}
