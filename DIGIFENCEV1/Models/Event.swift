//
//  Event.swift
//  DIGIFENCEV1
//
//  DigiFence event model matching Firestore events/{eventId} schema.
//  Uses polygon-based geofencing (array of lat/lng vertices).
//

import Foundation
import FirebaseFirestore
import CoreLocation

struct Event: Codable, Identifiable {
    @DocumentID var id: String?
    let title: String
    var description: String?
    let polygonCoordinates: [GeoPoint_DF]
    let organizerId: String
    var capacity: Int?
    var ticketsSold: Int?
    var ticketPrice: Double?
    var thumbnailURL: String?
    var invitationURL: String?
    var startsAt: Timestamp?
    var endsAt: Timestamp?
    var isActive: Bool
    @ServerTimestamp var createdAt: Timestamp?
    
    /// Lightweight lat/lng pair for Firestore storage.
    struct GeoPoint_DF: Codable {
        let lat: Double
        let lng: Double
        
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }
    
    /// Array of CoreLocation coordinates for polygon math.
    var polygonCLCoordinates: [CLLocationCoordinate2D] {
        polygonCoordinates.map { $0.coordinate }
    }
    
    /// Centroid of the polygon — used for map camera positioning.
    var coordinate: CLLocationCoordinate2D {
        PolygonMath.centroid(of: polygonCLCoordinates)
    }
    
    /// Remaining ticket count (nil if capacity not set).
    var remainingTickets: Int? {
        guard let cap = capacity else { return nil }
        return max(0, cap - (ticketsSold ?? 0))
    }
    
    /// Convenience initializer for programmatic construction.
    init(
        id: String? = nil,
        title: String,
        description: String? = nil,
        polygonCoordinates: [GeoPoint_DF],
        organizerId: String,
        capacity: Int? = nil,
        ticketsSold: Int? = nil,
        ticketPrice: Double? = nil,
        thumbnailURL: String? = nil,
        invitationURL: String? = nil,
        startsAt: Timestamp? = nil,
        endsAt: Timestamp? = nil,
        isActive: Bool = true,
        createdAt: Timestamp? = nil
    ) {
        self.title = title
        self.description = description
        self.polygonCoordinates = polygonCoordinates
        self.organizerId = organizerId
        self.capacity = capacity
        self.ticketsSold = ticketsSold
        self.ticketPrice = ticketPrice
        self.thumbnailURL = thumbnailURL
        self.invitationURL = invitationURL
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isActive = isActive
    }
}
