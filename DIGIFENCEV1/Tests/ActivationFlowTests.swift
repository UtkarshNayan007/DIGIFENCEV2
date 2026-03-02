//
//  ActivationFlowTests.swift
//  DIGIFENCEV1Tests
//
//  Tests for the activation flow logic.
//

#if canImport(XCTest)
import XCTest
import CoreLocation
@testable import DIGIFENCEV1

final class ActivationFlowTests: XCTestCase {
    
    // MARK: - Ticket Model Tests
    
    func testTicketStatusDisplay() {
        let pendingTicket = Ticket(
            eventId: "event1",
            ownerId: "user1",
            status: .pending,
            biometricVerified: false,
            insideFence: false
        )
        XCTAssertTrue(pendingTicket.isPending)
        XCTAssertFalse(pendingTicket.isActive)
        XCTAssertFalse(pendingTicket.isExpired)
        XCTAssertEqual(pendingTicket.statusDisplayText, "Pending Activation")
    }
    
    func testActiveTicketProperties() {
        let activeTicket = Ticket(
            eventId: "event1",
            ownerId: "user1",
            status: .active,
            biometricVerified: true,
            insideFence: true,
            entryCode: "AB3XY7"
        )
        XCTAssertTrue(activeTicket.isActive)
        XCTAssertTrue(activeTicket.biometricVerified)
        XCTAssertTrue(activeTicket.insideFence)
        XCTAssertEqual(activeTicket.entryCode, "AB3XY7")
        XCTAssertEqual(activeTicket.statusDisplayText, "Active")
    }
    
    func testExpiredTicketProperties() {
        let expiredTicket = Ticket(
            eventId: "event1",
            ownerId: "user1",
            status: .expired,
            biometricVerified: false,
            insideFence: false
        )
        XCTAssertTrue(expiredTicket.isExpired)
        XCTAssertEqual(expiredTicket.statusDisplayText, "Expired")
    }
    
    // MARK: - Event Model Tests (Polygon)
    
    func testEventPolygonCoordinates() {
        let event = Event(
            title: "Test Event",
            polygonCoordinates: [
                Event.GeoPoint_DF(lat: 37.7745, lng: -122.4200),
                Event.GeoPoint_DF(lat: 37.7745, lng: -122.4188),
                Event.GeoPoint_DF(lat: 37.7754, lng: -122.4188),
                Event.GeoPoint_DF(lat: 37.7754, lng: -122.4200),
            ],
            organizerId: "admin1",
            isActive: true
        )
        
        XCTAssertEqual(event.polygonCoordinates.count, 4)
        XCTAssertEqual(event.polygonCLCoordinates.count, 4)
        
        // Centroid should be near the center of the square
        let centroid = event.coordinate
        XCTAssertEqual(centroid.latitude, 37.77495, accuracy: 0.001)
        XCTAssertEqual(centroid.longitude, -122.4194, accuracy: 0.001)
    }
    
    func testEventRemainingTickets() {
        let event = Event(
            title: "Capacity Test",
            polygonCoordinates: [
                Event.GeoPoint_DF(lat: 0, lng: 0),
                Event.GeoPoint_DF(lat: 0, lng: 1),
                Event.GeoPoint_DF(lat: 1, lng: 0),
            ],
            organizerId: "admin1",
            capacity: 100,
            ticketsSold: 30,
            isActive: true
        )
        
        XCTAssertEqual(event.remainingTickets, 70)
    }
    
    // MARK: - Location Manager Tests
    
    func testGraceTimerManagement() {
        let locationManager = LocationManager.shared
        
        XCTAssertFalse(locationManager.hasActiveGraceTimer)
        
        locationManager.startGraceTimer(eventId: "event1", ticketId: "ticket1")
        XCTAssertTrue(locationManager.hasActiveGraceTimer)
        
        locationManager.cancelGraceTimer(for: "ticket1")
        XCTAssertFalse(locationManager.hasActiveGraceTimer)
    }
    
    func testStopAllMonitoringClearsTimers() {
        let locationManager = LocationManager.shared
        
        locationManager.startGraceTimer(eventId: "event1", ticketId: "ticket1")
        locationManager.startGraceTimer(eventId: "event2", ticketId: "ticket2")
        XCTAssertTrue(locationManager.hasActiveGraceTimer)
        
        locationManager.stopAllMonitoring()
        XCTAssertFalse(locationManager.hasActiveGraceTimer)
    }
    
    // MARK: - Secure Enclave Error Tests
    
    func testSecureEnclaveErrors() {
        let error1 = SecureEnclaveError.keyNotFound
        XCTAssertTrue(error1.localizedDescription.contains("No signing key"))
        
        let error2 = SecureEnclaveError.invalidNonceData
        XCTAssertTrue(error2.localizedDescription.contains("Invalid nonce"))
        
        let error3 = SecureEnclaveError.secureEnclaveNotAvailable
        XCTAssertTrue(error3.localizedDescription.contains("not available"))
    }
    
    // MARK: - User Model Tests
    
    func testUserRoles() {
        let admin = AppUser(
            email: "admin@test.com",
            displayName: "Admin",
            role: .admin
        )
        XCTAssertTrue(admin.isAdmin)
        
        let user = AppUser(
            email: "user@test.com",
            displayName: "User",
            role: .user
        )
        XCTAssertFalse(user.isAdmin)
    }
    
    // MARK: - Nonce Validation (Simulated)
    
    func testNonceBase64Encoding() {
        var nonceBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, nonceBytes.count, &nonceBytes)
        
        let nonceBase64 = Data(nonceBytes).base64EncodedString()
        XCTAssertFalse(nonceBase64.isEmpty)
        
        let decoded = Data(base64Encoded: nonceBase64)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 32)
    }
}

#endif
