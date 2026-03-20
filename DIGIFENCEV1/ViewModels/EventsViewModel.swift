//
//  EventsViewModel.swift
//  DIGIFENCEV1
//
//  Real-time Firestore listener for active events with pagination and code validation.
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
    @Published var showError = false
    
    // Event code validation
    @Published var isValidatingCode = false
    @Published var validatedEvent: Event?
    @Published var codeValidationError: String?
    
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
    
    // MARK: - Event Code Validation
    
    func validateEventCode(_ code: String) async -> Event? {
        let trimmedCode = code.trimmingCharacters(in: .whitespaces).uppercased()
        
        guard !trimmedCode.isEmpty else {
            codeValidationError = "Please enter an event code."
            return nil
        }
        
        isValidatingCode = true
        codeValidationError = nil
        validatedEvent = nil
        
        do {
            let snapshot = try await firebase.eventsCollection
                .whereField("eventCode", isEqualTo: trimmedCode)
                .limit(to: 1)
                .getDocuments()
            
            guard let doc = snapshot.documents.first else {
                codeValidationError = "Invalid Event Code. Please check and try again."
                isValidatingCode = false
                return nil
            }
            
            let event = try doc.data(as: Event.self)
            
            // Check if event is active
            guard event.isActive else {
                codeValidationError = "This event is currently inactive."
                isValidatingCode = false
                return nil
            }
            
            validatedEvent = event
            isValidatingCode = false
            return event
            
        } catch {
            codeValidationError = "Unable to verify code. Please try again."
            print("❌ Event code validation error: \(error.localizedDescription)")
            isValidatingCode = false
            return nil
        }
    }
    
    func resetValidation() {
        validatedEvent = nil
        codeValidationError = nil
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
