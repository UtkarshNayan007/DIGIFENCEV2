//
//  PolygonGeofenceManager.swift
//  DIGIFENCEV1
//
//  High-level polygon geofence orchestrator. Subscribes to
//  BatteryOptimizedLocationManager, determines entry/exit states
//  using PolygonMath, manages grace timers, and publishes per-event
//  inside/outside status.
//

import Foundation
import Combine
import CoreLocation

final class PolygonGeofenceManager: ObservableObject {
    
    static let shared = PolygonGeofenceManager()
    
    // MARK: - Published State
    
    /// Per-event inside/outside status.
    @Published var isInsideGeofence: [String: Bool] = [:]
    /// Per-event distance to nearest polygon edge (meters).
    @Published var distanceToEdge: [String: Double] = [:]
    /// Whether the user is in the activation zone for a given event.
    @Published var isInActivationZone: [String: Bool] = [:]
    /// Whether a grace period countdown is currently active.
    @Published var isGracePeriodActive: Bool = false
    /// Remaining seconds on the grace period countdown.
    @Published var gracePeriodRemainingSeconds: Int = 0
    
    // MARK: - Callbacks
    
    /// Fired when the user enters a polygon.
    var onEnterPolygon: ((String) -> Void)? // eventId
    /// Fired when the user exits a polygon (after hysteresis confirmation).
    var onExitPolygon: ((String, String) -> Void)? // eventId, ticketId
    /// Fired when the 3-minute grace period expires after exit.
    var onGracePeriodExpired: ((String, String) -> Void)? // eventId, ticketId
    /// Fired when exit is first detected (before hysteresis confirmation).
    var onExitWarning: ((String, String) -> Void)? // eventId, ticketId
    
    // MARK: - Configuration
    
    /// Activation buffer distance in meters (user must be within this
    /// distance outside the polygon edge to activate their pass).
    private let activationBuffer: Double = 10.0
    /// Number of consecutive "outside" readings required before confirming exit.
    private let requiredExitConfirmations: Int = 2
    /// Grace period duration after confirmed exit (seconds).
    private let gracePeriodSeconds: TimeInterval = 180.0
    
    // MARK: - Private State
    
    /// Monitored polygons keyed by eventId.
    private var polygons: [String: [CLLocationCoordinate2D]] = [:]
    /// Active ticket IDs keyed by eventId.
    private var activeTickets: [String: String] = [:]
    /// Consecutive "outside" readings per eventId.
    private var exitConfirmations: [String: Int] = [:]
    /// Active grace timers keyed by ticketId.
    private var graceTimers: [String: Timer] = [:]
    /// 1-second repeating countdown timer for UI display.
    private var countdownTimer: Timer?
    /// Previous inside state per eventId (for edge detection).
    private var previousInsideState: [String: Bool] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    private let batteryManager = BatteryOptimizedLocationManager.shared
    
    // MARK: - Init
    
    private init() {
        subscribeToLocationUpdates()
    }
    
    // MARK: - Public API
    
    /// Start monitoring a polygon geofence for an event with a specific ticket.
    ///
    /// - Parameters:
    ///   - eventId: The Firestore event document ID.
    ///   - ticketId: The Firestore ticket document ID.
    ///   - polygon: Ordered array of polygon vertices.
    func startMonitoring(eventId: String, ticketId: String, polygon: [CLLocationCoordinate2D]) {
        guard polygon.count >= 3 else { return }
        
        polygons[eventId] = polygon
        activeTickets[eventId] = ticketId
        exitConfirmations[eventId] = 0
        previousInsideState[eventId] = false
        
        batteryManager.addPolygon(eventId: eventId, coordinates: polygon)
    }
    
    /// Stop monitoring a specific event.
    func stopMonitoring(eventId: String) {
        if let ticketId = activeTickets[eventId] {
            cancelGraceTimer(for: ticketId)
        }
        polygons.removeValue(forKey: eventId)
        activeTickets.removeValue(forKey: eventId)
        exitConfirmations.removeValue(forKey: eventId)
        previousInsideState.removeValue(forKey: eventId)
        
        DispatchQueue.main.async {
            self.isInsideGeofence.removeValue(forKey: eventId)
            self.distanceToEdge.removeValue(forKey: eventId)
            self.isInActivationZone.removeValue(forKey: eventId)
        }
        
        batteryManager.removePolygon(eventId: eventId)
    }
    
    /// Stop all polygon monitoring.
    func stopAllMonitoring() {
        graceTimers.values.forEach { $0.invalidate() }
        graceTimers.removeAll()
        stopCountdown()
        exitConfirmations.removeAll()
        previousInsideState.removeAll()
        polygons.removeAll()
        activeTickets.removeAll()
        
        DispatchQueue.main.async {
            self.isInsideGeofence.removeAll()
            self.distanceToEdge.removeAll()
            self.isInActivationZone.removeAll()
        }
        
        batteryManager.stopMonitoring()
    }
    
    /// Whether any grace timer is active.
    var hasActiveGraceTimer: Bool {
        !graceTimers.isEmpty
    }
    
    // MARK: - Grace Timer Management
    
    /// Start the 3-minute grace timer for a ticket.
    func startGraceTimer(eventId: String, ticketId: String) {
        cancelGraceTimer(for: ticketId)
        
        // Start the main expiry timer
        let timer = Timer.scheduledTimer(withTimeInterval: gracePeriodSeconds, repeats: false) { [weak self] _ in
            self?.stopCountdown()
            self?.onGracePeriodExpired?(eventId, ticketId)
        }
        graceTimers[ticketId] = timer
        RunLoop.main.add(timer, forMode: .common)
        
        // Start 1-second countdown for UI
        gracePeriodRemainingSeconds = Int(gracePeriodSeconds)
        isGracePeriodActive = true
        startCountdown()
    }
    
    /// Cancel the grace timer for a ticket.
    func cancelGraceTimer(for ticketId: String) {
        graceTimers[ticketId]?.invalidate()
        graceTimers.removeValue(forKey: ticketId)
        
        // Reset countdown if no more grace timers are active
        if graceTimers.isEmpty {
            stopCountdown()
        }
    }
    
    // MARK: - Countdown Timer
    
    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.gracePeriodRemainingSeconds > 0 {
                self.gracePeriodRemainingSeconds -= 1
            } else {
                self.stopCountdown()
            }
        }
        if let countdownTimer {
            RunLoop.main.add(countdownTimer, forMode: .common)
        }
    }
    
    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isGracePeriodActive = false
        gracePeriodRemainingSeconds = 0
    }
    
    // MARK: - Location Subscription
    
    private func subscribeToLocationUpdates() {
        batteryManager.debouncedLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.evaluateAllPolygons(location: location)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Polygon Evaluation
    
    private func evaluateAllPolygons(location: CLLocation) {
        let coord = location.coordinate
        
        for (eventId, polygon) in polygons {
            let isInside = PolygonMath.isPointInsidePolygon(point: coord, polygon: polygon)
            let edgeDist = PolygonMath.distanceFromPointToPolygonEdge(point: coord, polygon: polygon)
            let inActivation = PolygonMath.isPointInActivationZone(
                point: coord,
                polygon: polygon,
                bufferMeters: activationBuffer
            )
            
            // Update published state
            isInsideGeofence[eventId] = isInside
            distanceToEdge[eventId] = edgeDist
            isInActivationZone[eventId] = inActivation
            
            // Edge detection: state transitions
            let wasInside = previousInsideState[eventId] ?? false
            
            if isInside && !wasInside {
                handleEntry(eventId: eventId)
            } else if !isInside && wasInside {
                handlePotentialExit(eventId: eventId)
            } else if isInside && wasInside {
                // Still inside — reset exit confirmations
                exitConfirmations[eventId] = 0
            }
            
            previousInsideState[eventId] = isInside
        }
    }
    
    // MARK: - Entry / Exit Handling
    
    private func handleEntry(eventId: String) {
        exitConfirmations[eventId] = 0
        
        // Cancel any active grace timer for this event's ticket
        if let ticketId = activeTickets[eventId] {
            cancelGraceTimer(for: ticketId)
        }
        
        onEnterPolygon?(eventId)
    }
    
    private func handlePotentialExit(eventId: String) {
        let count = (exitConfirmations[eventId] ?? 0) + 1
        exitConfirmations[eventId] = count
        
        if count >= requiredExitConfirmations {
            // Confirmed exit
            guard let ticketId = activeTickets[eventId] else { return }
            
            onExitWarning?(eventId, ticketId)
            startGraceTimer(eventId: eventId, ticketId: ticketId)
            onExitPolygon?(eventId, ticketId)
        } else {
            // Request fresh location to confirm
            batteryManager.requestCurrentLocation()
        }
    }
    
    deinit {
        graceTimers.values.forEach { $0.invalidate() }
        countdownTimer?.invalidate()
    }
}
