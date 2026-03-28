//
//  MyPassViewModel.swift
//  DIGIFENCEV1
//
//  Real-time listener on user's tickets, pass display state.
//

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class MyPassViewModel: ObservableObject {
    
    @Published var tickets: [Ticket] = []
    @Published var ticketEvents: [String: Event] = [:] // eventId -> Event
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var ticketListener: ListenerRegistration?
    private var eventListeners: [String: ListenerRegistration] = [:]
    private let firebase = FirebaseManager.shared
    
    // MARK: - Real-time Listener
    
    func startListening() {
        guard let uid = firebase.currentUser?.uid else { return }
        isLoading = true
        
        ticketListener = firebase.ticketsCollection
            .whereField("ownerId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.tickets = []
                    return
                }
                
                self.tickets = documents.compactMap { doc in
                    try? doc.data(as: Ticket.self)
                }
                
                // Listen to associated events (live updates)
                self.listenToEvents()
            }
    }
    
    func stopListening() {
        ticketListener?.remove()
        ticketListener = nil
        for (_, listener) in eventListeners { listener.remove() }
        eventListeners.removeAll()
    }
    
    // MARK: - Live Event Listeners
    
    private func listenToEvents() {
        let eventIds = Set(tickets.map { $0.eventId })
        
        // Remove listeners for events no longer needed
        for (eid, listener) in eventListeners where !eventIds.contains(eid) {
            listener.remove()
            eventListeners.removeValue(forKey: eid)
        }
        
        // Add listeners for new events
        for eventId in eventIds {
            if eventListeners[eventId] != nil { continue }
            let listener = firebase.eventsCollection.document(eventId)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self, let snapshot = snapshot else { return }
                    if let event = try? snapshot.data(as: Event.self) {
                        self.ticketEvents[eventId] = event
                    }
                }
            eventListeners[eventId] = listener
        }
    }
    
    // MARK: - Computed Properties
    
    var activeTickets: [Ticket] {
        tickets.filter { $0.status == .active }
    }
    
    var pendingTickets: [Ticket] {
        tickets.filter { $0.status == .pending }
    }
    
    var expiredTickets: [Ticket] {
        tickets.filter { $0.status == .expired }
    }
    
    func event(for ticket: Ticket) -> Event? {
        ticketEvents[ticket.eventId]
    }
    
    deinit {
        ticketListener?.remove()
        for (_, listener) in eventListeners { listener.remove() }
    }
}
