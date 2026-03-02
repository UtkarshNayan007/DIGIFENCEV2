/**
 * DigiFence Cloud Functions — Unit Tests
 * Tests haversine, polygon math, signature verification, and entry code generation.
 */

const {
    haversineDistance,
    isPointInsidePolygon,
    distanceFromPointToSegment,
    distanceFromPointToPolygonEdge,
    verifySignature,
    generateEntryCode,
} = require("./index")._testHelpers;
const crypto = require("crypto");

describe("haversineDistance", () => {
    test("same point returns 0", () => {
        expect(haversineDistance(37.7749, -122.4194, 37.7749, -122.4194)).toBe(0);
    });

    test("SF to Mountain View ≈ 48-53km", () => {
        const dist = haversineDistance(37.7749, -122.4194, 37.3861, -122.0839);
        expect(dist).toBeGreaterThan(47000);
        expect(dist).toBeLessThan(54000);
    });

    test("nearby points (100m apart)", () => {
        const lat1 = 37.7749;
        const lng1 = -122.4194;
        const lat2 = lat1 + 0.0009;
        const dist = haversineDistance(lat1, lng1, lat2, lng1);
        expect(dist).toBeGreaterThan(90);
        expect(dist).toBeLessThan(110);
    });

    test("antipodal points ≈ 20000km", () => {
        const dist = haversineDistance(0, 0, 0, 180);
        expect(dist).toBeGreaterThan(20000000);
        expect(dist).toBeLessThan(20100000);
    });
});

// ─── Polygon Math Tests ────────────────────────────────────────────────────

describe("isPointInsidePolygon", () => {
    const square = [
        { lat: 0, lng: 0 },
        { lat: 0, lng: 1 },
        { lat: 1, lng: 1 },
        { lat: 1, lng: 0 },
    ];

    test("point inside square returns true", () => {
        expect(isPointInsidePolygon({ lat: 0.5, lng: 0.5 }, square)).toBe(true);
    });

    test("point outside square returns false", () => {
        expect(isPointInsidePolygon({ lat: 2, lng: 2 }, square)).toBe(false);
    });

    test("returns false for < 3 points", () => {
        expect(isPointInsidePolygon({ lat: 0.5, lng: 0.5 }, [{ lat: 0, lng: 0 }])).toBe(false);
    });

    test("works with triangle", () => {
        const triangle = [
            { lat: 0, lng: 0 },
            { lat: 0, lng: 0.001 },
            { lat: 0.001, lng: 0.0005 },
        ];
        expect(isPointInsidePolygon({ lat: 0.0003, lng: 0.0005 }, triangle)).toBe(true);
        expect(isPointInsidePolygon({ lat: 0.002, lng: 0.002 }, triangle)).toBe(false);
    });

    test("works with complex polygon (pentagon)", () => {
        const pentagon = [
            { lat: 0, lng: 0.5 },
            { lat: 0.4, lng: 0 },
            { lat: 0.3, lng: 0.8 },
            { lat: -0.3, lng: 0.8 },
            { lat: -0.4, lng: 0 },
        ];
        // Center should be inside
        expect(isPointInsidePolygon({ lat: 0, lng: 0.4 }, pentagon)).toBe(true);
        // Far away point should be outside
        expect(isPointInsidePolygon({ lat: 5, lng: 5 }, pentagon)).toBe(false);
    });
});

describe("distanceFromPointToPolygonEdge", () => {
    test("returns distance in meters to nearest edge", () => {
        const square = [
            { lat: -0.001, lng: -0.001 },
            { lat: -0.001, lng: 0.001 },
            { lat: 0.001, lng: 0.001 },
            { lat: 0.001, lng: -0.001 },
        ];
        // Point 50m north of top edge
        const northOffset = 0.001 + 50.0 / 111320.0;
        const dist = distanceFromPointToPolygonEdge(
            { lat: northOffset, lng: 0 },
            square
        );
        expect(dist).toBeGreaterThan(40);
        expect(dist).toBeLessThan(60);
    });

    test("returns Infinity for invalid polygon", () => {
        expect(distanceFromPointToPolygonEdge({ lat: 0, lng: 0 }, [])).toBe(Infinity);
    });
});

describe("distanceFromPointToSegment", () => {
    test("perpendicular projection on segment", () => {
        const dist = distanceFromPointToSegment(
            { lat: 0.001, lng: 0 },
            { lat: 0, lng: -0.001 },
            { lat: 0, lng: 0.001 }
        );
        // Should be ~111m (0.001 degree latitude)
        expect(dist).toBeGreaterThan(100);
        expect(dist).toBeLessThan(120);
    });

    test("degenerate segment (two identical points)", () => {
        const dist = distanceFromPointToSegment(
            { lat: 0.001, lng: 0 },
            { lat: 0, lng: 0 },
            { lat: 0, lng: 0 }
        );
        expect(dist).toBeGreaterThan(100);
        expect(dist).toBeLessThan(120);
    });
});

// ─── Entry Code Tests ──────────────────────────────────────────────────────

describe("generateEntryCode", () => {
    test("returns string of specified length", () => {
        const code = generateEntryCode(6);
        expect(code).toHaveLength(6);
    });

    test("only contains allowed characters", () => {
        const allowed = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        for (let i = 0; i < 100; i++) {
            const code = generateEntryCode(6);
            for (const ch of code) {
                expect(allowed).toContain(ch);
            }
        }
    });

    test("generates unique codes", () => {
        const codes = new Set();
        for (let i = 0; i < 1000; i++) {
            codes.add(generateEntryCode(6));
        }
        expect(codes.size).toBe(1000);
    });
});

// ─── Signature Verification Tests ──────────────────────────────────────────

describe("verifySignature", () => {
    test("valid ECDSA P-256 signature verifies", () => {
        const { publicKey, privateKey } = crypto.generateKeyPairSync("ec", {
            namedCurve: "prime256v1",
        });

        const nonce = crypto.randomBytes(32);
        const nonceBase64 = nonce.toString("base64");

        const signer = crypto.createSign("SHA256");
        signer.update(nonce);
        const signature = signer.sign(privateKey);
        const signatureBase64 = signature.toString("base64");

        const rawPublicKey = publicKey.export({ type: "spki", format: "der" });
        const uncompressedPoint = rawPublicKey.slice(-65);
        const publicKeyBase64 = uncompressedPoint.toString("base64");

        expect(verifySignature(publicKeyBase64, nonceBase64, signatureBase64)).toBe(
            true
        );
    });

    test("invalid signature fails", () => {
        const { publicKey } = crypto.generateKeyPairSync("ec", {
            namedCurve: "prime256v1",
        });

        const nonce = crypto.randomBytes(32);
        const nonceBase64 = nonce.toString("base64");
        const fakeSignature = crypto.randomBytes(64).toString("base64");

        const rawPublicKey = publicKey.export({ type: "spki", format: "der" });
        const uncompressedPoint = rawPublicKey.slice(-65);
        const publicKeyBase64 = uncompressedPoint.toString("base64");

        expect(verifySignature(publicKeyBase64, nonceBase64, fakeSignature)).toBe(
            false
        );
    });

    test("wrong nonce fails", () => {
        const { publicKey, privateKey } = crypto.generateKeyPairSync("ec", {
            namedCurve: "prime256v1",
        });

        const nonce = crypto.randomBytes(32);
        const wrongNonce = crypto.randomBytes(32).toString("base64");

        const signer = crypto.createSign("SHA256");
        signer.update(nonce);
        const signature = signer.sign(privateKey);
        const signatureBase64 = signature.toString("base64");

        const rawPublicKey = publicKey.export({ type: "spki", format: "der" });
        const uncompressedPoint = rawPublicKey.slice(-65);
        const publicKeyBase64 = uncompressedPoint.toString("base64");

        expect(verifySignature(publicKeyBase64, wrongNonce, signatureBase64)).toBe(
            false
        );
    });
});
