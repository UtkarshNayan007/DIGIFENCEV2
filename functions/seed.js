/**
 * Seed script for DigiFence Firestore (Polygon-based geofencing).
 * Run with: node seed.js
 * 
 * By default connects to the emulator at localhost:8080.
 * Set FIRESTORE_EMULATOR_HOST=localhost:8080 if not auto-detected.
 */

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

// Initialize with default project (emulator auto-detects)
process.env.FIRESTORE_EMULATOR_HOST =
    process.env.FIRESTORE_EMULATOR_HOST || "localhost:8080";

initializeApp({ projectId: "digifence-c5243" });
const db = getFirestore();

async function seed() {
    console.log("🌱 Seeding Firestore...\n");

    // ─── Admin User ─────────────────────────────────────────────────────
    const adminId = "admin-user-001";
    await db.collection("users").doc(adminId).set({
        email: "admin@digifence.dev",
        displayName: "Admin User",
        role: "admin",
        publicKey: null,
        deviceId: null,
        createdAt: FieldValue.serverTimestamp(),
    });
    console.log("✅ Created admin user:", adminId);

    // ─── Regular User ───────────────────────────────────────────────────
    const userId = "test-user-001";
    await db.collection("users").doc(userId).set({
        email: "user@digifence.dev",
        displayName: "Test User",
        role: "user",
        publicKey: null,
        deviceId: null,
        createdAt: FieldValue.serverTimestamp(),
    });
    console.log("✅ Created test user:", userId);

    // ─── Events (Polygon-based) ─────────────────────────────────────────
    const event1Ref = db.collection("events").doc();
    await event1Ref.set({
        title: "TechConf 2026",
        description: "Annual technology conference at the convention center.",
        polygonCoordinates: [
            { lat: 37.7740, lng: -122.4210 },
            { lat: 37.7740, lng: -122.4178 },
            { lat: 37.7758, lng: -122.4178 },
            { lat: 37.7758, lng: -122.4210 },
        ],
        organizerId: adminId,
        capacity: 500,
        ticketsSold: 0,
        ticketPrice: 999,
        startsAt: new Date("2026-04-15T09:00:00Z"),
        endsAt: new Date("2026-04-15T18:00:00Z"),
        isActive: true,
        createdAt: FieldValue.serverTimestamp(),
    });
    console.log("✅ Created event:", event1Ref.id, "- TechConf 2026");

    const event2Ref = db.collection("events").doc();
    await event2Ref.set({
        title: "Music Festival",
        description: "Open-air music festival in Golden Gate Park.",
        polygonCoordinates: [
            { lat: 37.7680, lng: -122.4900 },
            { lat: 37.7680, lng: -122.4824 },
            { lat: 37.7708, lng: -122.4824 },
            { lat: 37.7708, lng: -122.4900 },
            { lat: 37.7694, lng: -122.4920 },
        ],
        organizerId: adminId,
        capacity: 2000,
        ticketsSold: 0,
        ticketPrice: 1500,
        startsAt: new Date("2026-05-01T12:00:00Z"),
        endsAt: new Date("2026-05-01T23:00:00Z"),
        isActive: true,
        createdAt: FieldValue.serverTimestamp(),
    });
    console.log("✅ Created event:", event2Ref.id, "- Music Festival");

    const event3Ref = db.collection("events").doc();
    await event3Ref.set({
        title: "Startup Demo Day",
        description: "Showcase of the latest startup innovations.",
        polygonCoordinates: [
            { lat: 37.3852, lng: -122.0855 },
            { lat: 37.3852, lng: -122.0823 },
            { lat: 37.3870, lng: -122.0823 },
            { lat: 37.3870, lng: -122.0855 },
        ],
        organizerId: adminId,
        capacity: 200,
        ticketsSold: 0,
        startsAt: new Date("2026-06-10T10:00:00Z"),
        endsAt: new Date("2026-06-10T17:00:00Z"),
        isActive: true,
        createdAt: FieldValue.serverTimestamp(),
    });
    console.log("✅ Created event:", event3Ref.id, "- Startup Demo Day");

    // ─── Sample Ticket (pending) ────────────────────────────────────────
    const ticket1Ref = db.collection("tickets").doc();
    await ticket1Ref.set({
        eventId: event1Ref.id,
        ownerId: userId,
        status: "pending",
        biometricVerified: false,
        insideFence: false,
        activatedAt: null,
        entryCode: null,
        createdAt: FieldValue.serverTimestamp(),
    });
    console.log("✅ Created ticket:", ticket1Ref.id, "for TechConf 2026");

    console.log("\n🎉 Seed complete!");
    process.exit(0);
}

seed().catch((err) => {
    console.error("Seed failed:", err);
    process.exit(1);
});
