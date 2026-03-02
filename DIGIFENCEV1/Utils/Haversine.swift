//
//  Haversine.swift
//  DIGIFENCEV1
//
//  Haversine formula for great-circle distance between two geographic
//  coordinates on the WGS-84 ellipsoid (spherical approximation).
//

import Foundation
import CoreLocation

enum Haversine {
    
    /// Earth's mean radius in meters (WGS-84).
    private static let earthRadiusMeters: Double = 6_371_000.0
    
    /// Returns the great-circle distance in **meters** between two coordinates.
    ///
    /// Uses the Haversine formula which provides accuracy to within ~0.3%
    /// for distances up to several thousand kilometers — more than adequate
    /// for geofence calculations at the 10-meter scale.
    ///
    /// - Parameters:
    ///   - from: Origin coordinate.
    ///   - to: Destination coordinate.
    /// - Returns: Distance in meters.
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let dLat = (to.latitude - from.latitude).degreesToRadians
        let dLng = (to.longitude - from.longitude).degreesToRadians
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(from.latitude.degreesToRadians) *
                cos(to.latitude.degreesToRadians) *
                sin(dLng / 2) * sin(dLng / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * c
    }
}

// MARK: - Degree ↔ Radian Conversion

private extension Double {
    var degreesToRadians: Double { self * .pi / 180.0 }
}
