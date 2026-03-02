//
//  BatteryOptimizedLocationManager.swift
//  DIGIFENCEV1
//
//  Dynamic-accuracy CLLocationManager wrapper that switches between
//  idle, significant-change, region-approach, and high-accuracy modes
//  based on proximity to event polygons. Publishes location via Combine.
//

import Foundation
import Combine
import CoreLocation

final class BatteryOptimizedLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    static let shared = BatteryOptimizedLocationManager()
    
    // MARK: - Published State
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var monitoringState: MonitoringState = .idle
    @Published var locationError: String?
    
    /// Current monitoring state — drives accuracy and update frequency.
    enum MonitoringState: String, CustomStringConvertible {
        /// Location services off. No updates.
        case idle
        /// Using significant location changes only. Minimal battery impact.
        case significantMonitoring
        /// Within ~200m of an event polygon. Medium accuracy.
        case regionApproach
        /// Near event boundary (< 50m). Maximum accuracy for geofence precision.
        case highAccuracy
        
        var description: String { rawValue }
    }
    
    // MARK: - Configuration
    
    /// Distance from polygon edge at which we switch to region approach mode.
    private let regionApproachThreshold: Double = 200.0 // meters
    /// Distance from polygon edge at which we switch to high accuracy mode.
    private let highAccuracyThreshold: Double = 50.0 // meters
    /// Minimum distance change to emit a new location (meters).
    private let minimumDistanceFilter: Double = 5.0
    /// Minimum interval between Firestore writes when inside event.
    let insideWriteInterval: TimeInterval = 15.0
    /// Minimum interval between Firestore writes when outside event.
    let outsideWriteInterval: TimeInterval = 30.0
    
    // MARK: - Private State
    
    private let locationManager = CLLocationManager()
    
    /// Raw location subject — all delegate updates feed here.
    private let rawLocationSubject = PassthroughSubject<CLLocation, Never>()
    /// Debounced location publisher (filters by distance threshold).
    private(set) lazy var debouncedLocation: AnyPublisher<CLLocation, Never> = {
        rawLocationSubject
            .removeDuplicates { [weak self] prev, next in
                guard let self = self else { return false }
                return next.distance(from: prev) < self.minimumDistanceFilter
            }
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }()
    
    /// Polygons we are currently monitoring, keyed by eventId.
    private var monitoredPolygons: [String: [CLLocationCoordinate2D]] = [:]
    /// Last Firestore write timestamp per eventId.
    private var lastWriteTimestamps: [String: Date] = [:]
    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()
    /// Last location used for state evaluation.
    private var lastEvaluatedLocation: CLLocation?
    
    // MARK: - Callbacks
    
    /// Called when a Firestore location write is permitted (throttled).
    var onThrottledLocationUpdate: ((CLLocation, String, Bool) -> Void)?
    
    // MARK: - Init
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.activityType = .fitness
        authorizationStatus = locationManager.authorizationStatus
        setupDebouncedLocationSubscription()
    }
    
    // MARK: - Authorization
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    var hasAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }
    
    var hasLocationPermission: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }
    
    // MARK: - Monitoring Control
    
    /// Begin monitoring the user's proximity to event polygons.
    ///
    /// Starts with significant location changes to conserve battery,
    /// automatically escalating accuracy as the user approaches an event.
    ///
    /// - Parameter polygons: Dictionary of `eventId → polygon vertices`.
    func startMonitoring(polygons: [String: [CLLocationCoordinate2D]]) {
        monitoredPolygons = polygons
        guard !polygons.isEmpty else {
            stopMonitoring()
            return
        }
        transitionTo(.significantMonitoring)
    }
    
    /// Add or update a single event polygon to monitor.
    func addPolygon(eventId: String, coordinates: [CLLocationCoordinate2D]) {
        monitoredPolygons[eventId] = coordinates
        if monitoringState == .idle {
            transitionTo(.significantMonitoring)
        }
    }
    
    /// Remove a polygon from monitoring.
    func removePolygon(eventId: String) {
        monitoredPolygons.removeValue(forKey: eventId)
        lastWriteTimestamps.removeValue(forKey: eventId)
        if monitoredPolygons.isEmpty {
            stopMonitoring()
        }
    }
    
    /// Stop all location monitoring and return to idle.
    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        monitoredPolygons.removeAll()
        lastWriteTimestamps.removeAll()
        lastEvaluatedLocation = nil
        DispatchQueue.main.async {
            self.monitoringState = .idle
        }
    }
    
    /// Request a single location update.
    func requestCurrentLocation() {
        locationManager.requestLocation()
    }
    
    // MARK: - State Transitions
    
    private func transitionTo(_ newState: MonitoringState) {
        guard newState != monitoringState else { return }
        
        // Tear down previous state
        switch monitoringState {
        case .idle:
            break
        case .significantMonitoring:
            locationManager.stopMonitoringSignificantLocationChanges()
        case .regionApproach, .highAccuracy:
            locationManager.stopUpdatingLocation()
        }
        
        // Set up new state
        switch newState {
        case .idle:
            break
        case .significantMonitoring:
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 100
            locationManager.pausesLocationUpdatesAutomatically = true
            configureBgUpdates()
            locationManager.startMonitoringSignificantLocationChanges()
            
        case .regionApproach:
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 10
            locationManager.pausesLocationUpdatesAutomatically = true
            configureBgUpdates()
            locationManager.startUpdatingLocation()
            
        case .highAccuracy:
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager.distanceFilter = 5
            locationManager.pausesLocationUpdatesAutomatically = false
            configureBgUpdates()
            locationManager.startUpdatingLocation()
        }
        
        DispatchQueue.main.async {
            self.monitoringState = newState
        }
    }
    
    private func configureBgUpdates() {
        if authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
        }
    }
    
    // MARK: - Proximity Evaluation
    
    /// Evaluate which monitoring state is appropriate based on current location.
    private func evaluateProximity(location: CLLocation) {
        guard !monitoredPolygons.isEmpty else { return }
        
        // Find minimum distance to any monitored polygon edge
        var minDistance = Double.greatestFiniteMagnitude
        var nearestEventId: String?
        var isInsideAny = false
        
        let coord = location.coordinate
        
        for (eventId, polygon) in monitoredPolygons {
            if PolygonMath.isPointInsidePolygon(point: coord, polygon: polygon) {
                isInsideAny = true
                nearestEventId = eventId
                minDistance = 0
                break
            }
            let dist = PolygonMath.distanceFromPointToPolygonEdge(point: coord, polygon: polygon)
            if dist < minDistance {
                minDistance = dist
                nearestEventId = eventId
            }
        }
        
        // Determine target state
        let targetState: MonitoringState
        if isInsideAny || minDistance <= highAccuracyThreshold {
            targetState = .highAccuracy
        } else if minDistance <= regionApproachThreshold {
            targetState = .regionApproach
        } else {
            targetState = .significantMonitoring
        }
        
        transitionTo(targetState)
        
        // Fire throttled write callback if applicable
        if let eventId = nearestEventId {
            fireThrottledWriteIfNeeded(location: location, eventId: eventId, isInside: isInsideAny)
        }
    }
    
    // MARK: - Throttled Writes
    
    private func fireThrottledWriteIfNeeded(location: CLLocation, eventId: String, isInside: Bool) {
        let interval = isInside ? insideWriteInterval : outsideWriteInterval
        let now = Date()
        
        if let lastWrite = lastWriteTimestamps[eventId],
           now.timeIntervalSince(lastWrite) < interval {
            return // Throttled
        }
        
        lastWriteTimestamps[eventId] = now
        onThrottledLocationUpdate?(location, eventId, isInside)
    }
    
    // MARK: - Combine Subscription
    
    private func setupDebouncedLocationSubscription() {
        debouncedLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.evaluateProximity(location: location)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            self.configureBgUpdates()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
        }
        rawLocationSubject.send(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        // Ignore location-unknown errors (transient)
        if nsError.domain == kCLErrorDomain && nsError.code == CLError.locationUnknown.rawValue {
            return
        }
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
        }
    }
}
