//
//  PolygonMath.swift
//  DIGIFENCEV1
//
//  Polygon geometry utilities for the DigiFence geofence system.
//  All algorithms run in O(n) where n = number of polygon vertices.
//

import Foundation
import CoreLocation

enum PolygonMath {
    
    // MARK: - Point-in-Polygon (Ray Casting)
    
    /// Determines whether a geographic point lies inside a polygon using
    /// the **ray casting** (crossing number) algorithm.
    ///
    /// Casts a horizontal ray from the test point to the right and counts
    /// how many polygon edges it crosses. An odd count → inside.
    ///
    /// - Parameters:
    ///   - point: The coordinate to test.
    ///   - polygon: Ordered array of polygon vertices (minimum 3). The
    ///     polygon is implicitly closed (last vertex connects to first).
    /// - Returns: `true` if the point is inside the polygon.
    static func isPointInsidePolygon(
        point: CLLocationCoordinate2D,
        polygon: [CLLocationCoordinate2D]
    ) -> Bool {
        guard polygon.count >= 3 else { return false }
        
        let px = point.longitude
        let py = point.latitude
        var inside = false
        
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude
            
            // Check if the ray crosses this edge
            let intersects = ((yi > py) != (yj > py)) &&
                             (px < (xj - xi) * (py - yi) / (yj - yi) + xi)
            if intersects {
                inside.toggle()
            }
            j = i
        }
        
        return inside
    }
    
    // MARK: - Distance from Point to Line Segment
    
    /// Returns the minimum distance in **meters** from a point to a line
    /// segment defined by two endpoints.
    ///
    /// Projects the point onto the infinite line through `segmentStart` and
    /// `segmentEnd`, clamps the projection parameter to [0,1], then computes
    /// haversine distance to the nearest point on the segment.
    ///
    /// - Parameters:
    ///   - point: The test coordinate.
    ///   - segmentStart: First endpoint of the segment.
    ///   - segmentEnd: Second endpoint of the segment.
    /// - Returns: Distance in meters.
    static func distanceFromPointToSegment(
        point: CLLocationCoordinate2D,
        segmentStart: CLLocationCoordinate2D,
        segmentEnd: CLLocationCoordinate2D
    ) -> Double {
        let dx = segmentEnd.longitude - segmentStart.longitude
        let dy = segmentEnd.latitude - segmentStart.latitude
        
        // Degenerate segment (two identical points)
        if dx == 0 && dy == 0 {
            return Haversine.distance(from: point, to: segmentStart)
        }
        
        // Parameter t of the projection of point onto the segment line.
        // t = dot(point - start, end - start) / |end - start|^2
        let t = max(0, min(1,
            ((point.longitude - segmentStart.longitude) * dx +
             (point.latitude  - segmentStart.latitude)  * dy) /
            (dx * dx + dy * dy)
        ))
        
        // Closest point on the segment
        let closest = CLLocationCoordinate2D(
            latitude:  segmentStart.latitude  + t * dy,
            longitude: segmentStart.longitude + t * dx
        )
        
        return Haversine.distance(from: point, to: closest)
    }
    
    // MARK: - Distance from Point to Polygon Edge
    
    /// Returns the minimum distance in **meters** from a point to the nearest
    /// edge of a polygon.
    ///
    /// Iterates over every edge of the polygon and returns the smallest
    /// point-to-segment distance.
    ///
    /// - Parameters:
    ///   - point: The test coordinate.
    ///   - polygon: Ordered array of polygon vertices (minimum 3).
    /// - Returns: Distance in meters to the nearest edge.
    static func distanceFromPointToPolygonEdge(
        point: CLLocationCoordinate2D,
        polygon: [CLLocationCoordinate2D]
    ) -> Double {
        guard polygon.count >= 3 else { return .greatestFiniteMagnitude }
        
        var minDistance = Double.greatestFiniteMagnitude
        
        for i in 0..<polygon.count {
            let j = (i + 1) % polygon.count
            let d = distanceFromPointToSegment(
                point: point,
                segmentStart: polygon[i],
                segmentEnd: polygon[j]
            )
            minDistance = min(minDistance, d)
        }
        
        return minDistance
    }
    
    // MARK: - Activation Zone Check
    
    /// Determines whether a user is in the **activation zone** — outside the
    /// polygon but within `bufferMeters` of the nearest edge.
    ///
    /// This is the pre-entry zone where ticket activation is permitted.
    ///
    /// - Parameters:
    ///   - point: The user's current coordinate.
    ///   - polygon: The event's polygon geofence vertices.
    ///   - bufferMeters: Maximum distance outside the polygon edge for
    ///     activation (default 10 meters).
    /// - Returns: `true` if the user is outside the polygon and within the
    ///   buffer distance.
    static func isPointInActivationZone(
        point: CLLocationCoordinate2D,
        polygon: [CLLocationCoordinate2D],
        bufferMeters: Double = 10.0
    ) -> Bool {
        // Must be OUTSIDE the polygon
        guard !isPointInsidePolygon(point: point, polygon: polygon) else {
            return false
        }
        // Must be within buffer distance of the nearest edge
        let edgeDistance = distanceFromPointToPolygonEdge(point: point, polygon: polygon)
        return edgeDistance <= bufferMeters
    }
    
    // MARK: - Self-Intersecting Polygon Detection
    
    /// Determines whether a polygon is self-intersecting by checking if any
    /// pair of non-adjacent edges cross each other.
    ///
    /// Uses the standard line-segment intersection test based on orientation
    /// (cross-product sign). Two edges are "adjacent" if they share a vertex,
    /// so we skip those pairs.
    ///
    /// - Parameter polygon: Ordered array of polygon vertices (minimum 3).
    /// - Returns: `true` if any two non-adjacent edges intersect.
    static func isPolygonSelfIntersecting(
        _ polygon: [CLLocationCoordinate2D]
    ) -> Bool {
        let n = polygon.count
        guard n >= 4 else { return false } // A triangle cannot self-intersect
        
        for i in 0..<n {
            let a1 = polygon[i]
            let a2 = polygon[(i + 1) % n]
            
            for j in (i + 2)..<n {
                // Skip adjacent edges (share a vertex)
                if i == 0 && j == n - 1 { continue }
                
                let b1 = polygon[j]
                let b2 = polygon[(j + 1) % n]
                
                if segmentsIntersect(a1, a2, b1, b2) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Segment Intersection Helper
    
    /// Tests whether two line segments (p1→p2) and (p3→p4) properly intersect.
    ///
    /// Uses the orientation (cross-product) method. Two segments intersect if
    /// and only if they straddle each other — i.e., the endpoints of each
    /// segment lie on opposite sides of the line containing the other segment.
    private static func segmentsIntersect(
        _ p1: CLLocationCoordinate2D,
        _ p2: CLLocationCoordinate2D,
        _ p3: CLLocationCoordinate2D,
        _ p4: CLLocationCoordinate2D
    ) -> Bool {
        let d1 = crossProduct(p3, p4, p1)
        let d2 = crossProduct(p3, p4, p2)
        let d3 = crossProduct(p1, p2, p3)
        let d4 = crossProduct(p1, p2, p4)
        
        if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
           ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) {
            return true
        }
        
        // Collinear cases: check if any endpoint lies on the other segment
        if d1 == 0 && onSegment(p3, p4, p1) { return true }
        if d2 == 0 && onSegment(p3, p4, p2) { return true }
        if d3 == 0 && onSegment(p1, p2, p3) { return true }
        if d4 == 0 && onSegment(p1, p2, p4) { return true }
        
        return false
    }
    
    /// Cross product of vectors (b - a) and (c - a).
    /// Positive → counter-clockwise, negative → clockwise, zero → collinear.
    private static func crossProduct(
        _ a: CLLocationCoordinate2D,
        _ b: CLLocationCoordinate2D,
        _ c: CLLocationCoordinate2D
    ) -> Double {
        (b.longitude - a.longitude) * (c.latitude - a.latitude) -
        (b.latitude - a.latitude) * (c.longitude - a.longitude)
    }
    
    /// Checks whether point `p` lies on the segment from `a` to `b`,
    /// assuming all three are collinear.
    private static func onSegment(
        _ a: CLLocationCoordinate2D,
        _ b: CLLocationCoordinate2D,
        _ p: CLLocationCoordinate2D
    ) -> Bool {
        min(a.longitude, b.longitude) <= p.longitude &&
        p.longitude <= max(a.longitude, b.longitude) &&
        min(a.latitude, b.latitude) <= p.latitude &&
        p.latitude <= max(a.latitude, b.latitude)
    }
    
    // MARK: - Polygon Centroid
    
    /// Computes the geometric centroid of a polygon.
    ///
    /// Uses the standard formula for the centroid of a simple polygon
    /// based on signed area. Falls back to arithmetic mean for degenerate cases.
    ///
    /// - Parameter polygon: Ordered array of polygon vertices.
    /// - Returns: The centroid coordinate.
    static func centroid(of polygon: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard polygon.count >= 3 else {
            if polygon.isEmpty {
                return CLLocationCoordinate2D(latitude: 0, longitude: 0)
            }
            // For 1-2 points, return arithmetic mean
            let lat = polygon.map(\.latitude).reduce(0, +) / Double(polygon.count)
            let lng = polygon.map(\.longitude).reduce(0, +) / Double(polygon.count)
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        
        var signedArea: Double = 0
        var cx: Double = 0
        var cy: Double = 0
        
        for i in 0..<polygon.count {
            let j = (i + 1) % polygon.count
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude
            
            let cross = xi * yj - xj * yi
            signedArea += cross
            cx += (xi + xj) * cross
            cy += (yi + yj) * cross
        }
        
        signedArea *= 0.5
        
        // Guard against degenerate polygon (zero area)
        guard abs(signedArea) > 1e-12 else {
            let lat = polygon.map(\.latitude).reduce(0, +) / Double(polygon.count)
            let lng = polygon.map(\.longitude).reduce(0, +) / Double(polygon.count)
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        
        let factor = 1.0 / (6.0 * signedArea)
        return CLLocationCoordinate2D(
            latitude: cy * factor,
            longitude: cx * factor
        )
    }
}
