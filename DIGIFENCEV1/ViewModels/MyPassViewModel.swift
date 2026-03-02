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
                
                // Fetch associated events
                Task { await self.fetchEvents() }
            }
    }
    
    func stopListening() {
        ticketListener?.remove()
        ticketListener = nil
    }
    
    // MARK: - Fetch Events for Tickets
    
    private func fetchEvents() async {
        let eventIds = Set(tickets.map { $0.eventId })
        
        for eventId in eventIds {
            if ticketEvents[eventId] != nil { continue }
            
            do {
                let doc = try await firebase.eventsCollection.document(eventId).getDocument()
                if let event = try? doc.data(as: Event.self) {
                    ticketEvents[eventId] = event
                }
            } catch {
                print("❌ Failed to fetch event \(eventId): \(error.localizedDescription)")
            }
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
    }
}
