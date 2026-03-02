//
//  DistanceCalculationTests.swift
//  DIGIFENCEV1Tests
//
//  Tests for Haversine distance and polygon math calculations.
//

#if canImport(XCTest)
import XCTest
import CoreLocation
@testable import DIGIFENCEV1

final class DistanceCalculationTests: XCTestCase {
    
    // MARK: - Haversine: Same Point
    
    func testSamePointReturnsZero() {
        let sf = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let distance = Haversine.distance(from: sf, to: sf)
        XCTAssertEqual(distance, 0, accuracy: 0.01, "Same point should return 0")
    }
    
    // MARK: - Haversine: Known Distances
    
    func testSFToMountainView() {
        let sf = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let mv = CLLocationCoordinate2D(latitude: 37.3861, longitude: -122.0839)
        let distance = Haversine.distance(from: sf, to: mv)
        
        XCTAssertGreaterThan(distance, 47000, "SF to MV should be > 47km")
        XCTAssertLessThan(distance, 50000, "SF to MV should be < 50km")
    }
    
    func testNearbyPoints100m() {
        let point1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let point2 = CLLocationCoordinate2D(latitude: 37.7749 + 0.0009, longitude: -122.4194)
        let distance = Haversine.distance(from: point1, to: point2)
        
        XCTAssertGreaterThan(distance, 90, "~100m apart should be > 90m")
        XCTAssertLessThan(distance, 110, "~100m apart should be < 110m")
    }
    
    func testNearbyPoints10m() {
        let point1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let point2 = CLLocationCoordinate2D(latitude: 37.7749 + 0.00009, longitude: -122.4194)
        let distance = Haversine.distance(from: point1, to: point2)
        
        XCTAssertGreaterThan(distance, 8, "~10m apart should be > 8m")
        XCTAssertLessThan(distance, 12, "~10m apart should be < 12m")
    }
    
    // MARK: - Haversine: Antipodal Points
    
    func testAntipodalPoints() {
        let point1 = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let point2 = CLLocationCoordinate2D(latitude: 0, longitude: 180)
        let distance = Haversine.distance(from: point1, to: point2)
        
        XCTAssertGreaterThan(distance, 20000000, "Antipodal should be > 20000km")
        XCTAssertLessThan(distance, 20100000, "Antipodal should be < 20100km")
    }
    
    // MARK: - Haversine: Symmetry
    
    func testDistanceIsSymmetric() {
        let sf = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let ny = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        
        let d1 = Haversine.distance(from: sf, to: ny)
        let d2 = Haversine.distance(from: ny, to: sf)
        
        XCTAssertEqual(d1, d2, accuracy: 0.01, "Distance should be symmetric")
    }
    
    // MARK: - Haversine: Backward Compatibility
    
    func testLocationManagerHaversineRedirect() {
        let p1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let p2 = CLLocationCoordinate2D(latitude: 37.3861, longitude: -122.0839)
        
        let d1 = Haversine.distance(from: p1, to: p2)
        let d2 = LocationManager.haversineDistance(from: p1, to: p2)
        
        XCTAssertEqual(d1, d2, accuracy: 0.001, "LocationManager delegate should match Haversine utility")
    }
    
    // MARK: - Point-in-Polygon: Triangle
    
    func testPointInsideTriangle() {
        let triangle: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.001),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0.0005),
        ]
        let inside = CLLocationCoordinate2D(latitude: 0.0003, longitude: 0.0005)
        
        XCTAssertTrue(PolygonMath.isPointInsidePolygon(point: inside, polygon: triangle))
    }
    
    func testPointOutsideTriangle() {
        let triangle: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.001),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0.0005),
        ]
        let outside = CLLocationCoordinate2D(latitude: 0.002, longitude: 0.002)
        
        XCTAssertFalse(PolygonMath.isPointInsidePolygon(point: outside, polygon: triangle))
    }
    
    // MARK: - Point-in-Polygon: Square
    
    func testPointInsideSquare() {
        // ~100m x ~100m square
        let square: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4200),
            CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4188),
            CLLocationCoordinate2D(latitude: 37.7754, longitude: -122.4188),
            CLLocationCoordinate2D(latitude: 37.7754, longitude: -122.4200),
        ]
        let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        XCTAssertTrue(PolygonMath.isPointInsidePolygon(point: center, polygon: square))
    }
    
    func testPointOutsideSquare() {
        let square: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4200),
            CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4188),
            CLLocationCoordinate2D(latitude: 37.7754, longitude: -122.4188),
            CLLocationCoordinate2D(latitude: 37.7754, longitude: -122.4200),
        ]
        let outside = CLLocationCoordinate2D(latitude: 37.7760, longitude: -122.4194)
        
        XCTAssertFalse(PolygonMath.isPointInsidePolygon(point: outside, polygon: square))
    }
    
    // MARK: - Point-in-Polygon: Edge Cases
    
    func testLessThan3PointsReturnsFalse() {
        let twoPoints: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]
        let point = CLLocationCoordinate2D(latitude: 0.5, longitude: 0.5)
        
        XCTAssertFalse(PolygonMath.isPointInsidePolygon(point: point, polygon: twoPoints))
    }
    
    // MARK: - Distance to Polygon Edge
    
    func testDistanceToPolygonEdge() {
        // Square centered around (0,0)
        let square: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: -0.001, longitude: -0.001),
            CLLocationCoordinate2D(latitude: -0.001, longitude: 0.001),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001),
            CLLocationCoordinate2D(latitude: 0.001, longitude: -0.001),
        ]
        
        // Point 50m north of the top edge
        let northOffset = 0.001 + (50.0 / 111320.0)
        let testPoint = CLLocationCoordinate2D(latitude: northOffset, longitude: 0)
        
        let distance = PolygonMath.distanceFromPointToPolygonEdge(point: testPoint, polygon: square)
        
        XCTAssertGreaterThan(distance, 40, "Should be > 40m from edge")
        XCTAssertLessThan(distance, 60, "Should be < 60m from edge")
    }
    
    // MARK: - Activation Zone
    
    func testActivationZoneWithinBuffer() {
        let square: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4200),
            CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4188),
            CLLocationCoordinate2D(latitude: 37.7754, longitude: -122.4188),
            CLLocationCoordinate2D(latitude: 37.7754, longitude: -122.4200),
        ]
        
        // Point ~8m north of top edge (outside polygon, within 10m buffer)
        let offset = 8.0 / 111320.0
        let nearPoint = CLLocationCoordinate2D(latitude: 37.7754 + offset, longitude: -122.4194)
        
        XCTAssertTrue(
            PolygonMath.isPointInActivationZone(point: nearPoint, polygon: square, bufferMeters: 10),
            "Point 8m outside should be in 10m activation zone"
        )
    }
    
    func testActivationZoneTooFarAway() {
        let square: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4200),
            CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4188),
            CLLocationCoordinate2D(latitude: 37.7754, longitude: -122.4188),
            CLLocationCoordinate2D(latitude: 37.7754, longitude: -122.4200),
        ]
        
        // Point ~50m north of top edge (too far for 10m buffer)
        let offset = 50.0 / 111320.0
        let farPoint = CLLocationCoordinate2D(latitude: 37.7754 + offset, longitude: -122.4194)
        
        XCTAssertFalse(
            PolygonMath.isPointInActivationZone(point: farPoint, polygon: square, bufferMeters: 10),
            "Point 50m outside should NOT be in 10m activation zone"
        )
    }
    
    func testActivationZoneInsidePolygonReturnsFalse() {
        let square: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4200),
            CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4188),
            CLLocationCoordinate2D(latitude: 37.7754, longitude: -122.4188),
            CLLocationCoordinate2D(latitude: 37.7754, longitude: -122.4200),
        ]
        
        let inside = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        XCTAssertFalse(
            PolygonMath.isPointInActivationZone(point: inside, polygon: square, bufferMeters: 10),
            "Point inside polygon should NOT be in activation zone"
        )
    }
    
    // MARK: - Centroid
    
    func testCentroidOfSquare() {
        let square: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 1),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
            CLLocationCoordinate2D(latitude: 1, longitude: 0),
        ]
        
        let centroid = PolygonMath.centroid(of: square)
        
        XCTAssertEqual(centroid.latitude, 0.5, accuracy: 0.001, "Centroid lat should be 0.5")
        XCTAssertEqual(centroid.longitude, 0.5, accuracy: 0.001, "Centroid lng should be 0.5")
    }
}

#endif
