/**
 * DigiFence Cloud Functions
 *
 * Callable functions for the location-locked, biometric-bound event pass system.
 * All critical state mutations happen server-side via Admin SDK.
 * Uses polygon-based geofencing (ray casting + edge distance).
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const crypto = require("crypto");

initializeApp();
const db = getFirestore();

// ─── Helpers ────────────────────────────────────────────────────────────────

/**
 * Haversine distance between two lat/lng points in meters.
 */
function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371000; // Earth radius in meters
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Ray casting algorithm: determine if a point is inside a polygon.
 * @param {{lat: number, lng: number}} point - Test point
 * @param {{lat: number, lng: number}[]} polygon - Polygon vertices (min 3)
 * @returns {boolean} true if point is inside the polygon
 */
function isPointInsidePolygon(point, polygon) {
  if (!polygon || polygon.length < 3) return false;

  const px = point.lng;
  const py = point.lat;
  let inside = false;

  let j = polygon.length - 1;
  for (let i = 0; i < polygon.length; i++) {
    const xi = polygon[i].lng;
    const yi = polygon[i].lat;
    const xj = polygon[j].lng;
    const yj = polygon[j].lat;

    const intersects =
      yi > py !== yj > py && px < ((xj - xi) * (py - yi)) / (yj - yi) + xi;
    if (intersects) {
      inside = !inside;
    }
    j = i;
  }

  return inside;
}

/**
 * Minimum distance in meters from a point to a line segment.
 * @param {{lat: number, lng: number}} point
 * @param {{lat: number, lng: number}} segStart
 * @param {{lat: number, lng: number}} segEnd
 * @returns {number} Distance in meters
 */
function distanceFromPointToSegment(point, segStart, segEnd) {
  const dx = segEnd.lng - segStart.lng;
  const dy = segEnd.lat - segStart.lat;

  if (dx === 0 && dy === 0) {
    return haversineDistance(point.lat, point.lng, segStart.lat, segStart.lng);
  }

  const t = Math.max(
    0,
    Math.min(
      1,
      ((point.lng - segStart.lng) * dx + (point.lat - segStart.lat) * dy) /
      (dx * dx + dy * dy)
    )
  );

  const closestLat = segStart.lat + t * dy;
  const closestLng = segStart.lng + t * dx;

  return haversineDistance(point.lat, point.lng, closestLat, closestLng);
}

/**
 * Minimum distance in meters from a point to the nearest polygon edge.
 * @param {{lat: number, lng: number}} point
 * @param {{lat: number, lng: number}[]} polygon
 * @returns {number} Distance in meters
 */
function distanceFromPointToPolygonEdge(point, polygon) {
  if (!polygon || polygon.length < 3) return Infinity;

  let minDist = Infinity;
  for (let i = 0; i < polygon.length; i++) {
    const j = (i + 1) % polygon.length;
    const d = distanceFromPointToSegment(point, polygon[i], polygon[j]);
    if (d < minDist) minDist = d;
  }
  return minDist;
}

/**
 * Verify an ECDSA P-256 (secp256r1) signature produced by iOS Secure Enclave.
 *
 * iOS SecKeyCreateSignature with .ecdsaSignatureMessageX962SHA256 produces a
 * DER-encoded ECDSA signature over the SHA-256 hash of the message.
 * The public key from iOS is the X9.62 uncompressed point (04 || x || y).
 *
 * We convert the raw public key bytes into a SubjectPublicKeyInfo (SPKI) DER
 * structure that Node.js crypto can consume.
 */
function verifySignature(publicKeyBase64, nonceBase64, signatureBase64) {
  try {
    const rawKey = Buffer.from(publicKeyBase64, "base64");
    const signature = Buffer.from(signatureBase64, "base64");
    const nonce = Buffer.from(nonceBase64, "base64");

    // Build SPKI DER wrapper for EC P-256 uncompressed public key (65 bytes)
    const spkiHeader = Buffer.from(
      "3059301306072a8648ce3d020106082a8648ce3d030107034200",
      "hex"
    );

    let keyBuffer;
    if (rawKey.length === 65 && rawKey[0] === 0x04) {
      keyBuffer = Buffer.concat([spkiHeader, rawKey]);
    } else if (rawKey.length > 65) {
      keyBuffer = rawKey;
    } else {
      throw new Error(`Unexpected public key length: ${rawKey.length}`);
    }

    const publicKey = crypto.createPublicKey({
      key: keyBuffer,
      format: "der",
      type: "spki",
    });

    const verifier = crypto.createVerify("SHA256");
    verifier.update(nonce);
    return verifier.verify(publicKey, signature);
  } catch (err) {
    console.error("Signature verification error:", err.message);
    return false;
  }
}

/**
 * Generate a cryptographically secure alphanumeric entry code.
 */
function generateEntryCode(length = 6) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // No 0/O/1/I to avoid confusion
  let code = "";
  const bytes = crypto.randomBytes(length);
  for (let i = 0; i < length; i++) {
    code += chars[bytes[i] % chars.length];
  }
  return code;
}

// ─── createActivationNonce ──────────────────────────────────────────────────

exports.createActivationNonce = onCall(async (request) => {
  // Auth check
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const uid = request.auth.uid;
  const { ticketId } = request.data;

  if (!ticketId) {
    throw new HttpsError("invalid-argument", "ticketId is required.");
  }

  // Validate ticket
  const ticketRef = db.collection("tickets").doc(ticketId);
  const ticketSnap = await ticketRef.get();

  if (!ticketSnap.exists) {
    throw new HttpsError("not-found", "Ticket not found.");
  }

  const ticket = ticketSnap.data();

  if (ticket.ownerId !== uid) {
    throw new HttpsError("permission-denied", "You do not own this ticket.");
  }

  if (ticket.status === "active") {
    throw new HttpsError("failed-precondition", "Ticket is already active.");
  }

  // Generate 32-byte cryptographic nonce
  const nonce = crypto.randomBytes(32).toString("base64");
  const expiresAt = new Date(Date.now() + 60 * 1000); // 60 seconds from now

  const nonceRef = db.collection("activation_nonces").doc();
  await nonceRef.set({
    ticketId,
    nonce,
    expiresAt,
    used: false,
  });

  return { nonceId: nonceRef.id, nonce };
});

// ─── activateTicket ─────────────────────────────────────────────────────────

exports.activateTicket = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const uid = request.auth.uid;
  const { ticketId, nonceId, signatureBase64, lat, lng } = request.data;

  if (!ticketId || !nonceId || !signatureBase64 || lat == null || lng == null) {
    throw new HttpsError(
      "invalid-argument",
      "ticketId, nonceId, signatureBase64, lat, and lng are all required."
    );
  }

  let result;
  try {
    // Use a transaction for atomicity
    result = await db.runTransaction(async (tx) => {
      const ticketRef = db.collection("tickets").doc(ticketId);
      const nonceRef = db.collection("activation_nonces").doc(nonceId);
      const ticketSnap = await tx.get(ticketRef);
      const nonceSnap = await tx.get(nonceRef);

      // Validate ticket
      if (!ticketSnap.exists) {
        throw new HttpsError("not-found", "Ticket not found.");
      }
      const ticket = ticketSnap.data();
      if (ticket.ownerId !== uid) {
        throw new HttpsError("permission-denied", "You do not own this ticket.");
      }

      // Validate nonce
      if (!nonceSnap.exists) {
        throw new HttpsError("not-found", "Nonce not found.");
      }
      const nonceData = nonceSnap.data();
      if (nonceData.used) {
        throw new HttpsError("failed-precondition", "Nonce already used.");
      }
      if (nonceData.ticketId !== ticketId) {
        throw new HttpsError("invalid-argument", "Nonce does not match ticket.");
      }

      const expiresAt = nonceData.expiresAt.toDate
        ? nonceData.expiresAt.toDate()
        : new Date(nonceData.expiresAt);
      if (expiresAt < new Date()) {
        throw new HttpsError("deadline-exceeded", "Nonce has expired.");
      }

      // Load event to check polygon geofence
      const eventRef = db.collection("events").doc(ticket.eventId);
      const eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) {
        throw new HttpsError("not-found", "Event not found.");
      }
      const event = eventSnap.data();

      // Polygon-based geofence validation
      const userPoint = { lat, lng };
      const polygon = event.polygonCoordinates;

      if (!polygon || polygon.length < 3) {
        throw new HttpsError(
          "failed-precondition",
          "Event has invalid polygon geofence."
        );
      }

      const isInside = isPointInsidePolygon(userPoint, polygon);
      const edgeDistance = distanceFromPointToPolygonEdge(userPoint, polygon);
      const activationBuffer = 10; // 10 meters

      // User must be OUTSIDE polygon but within 10m of nearest edge
      // OR already inside (allow activation from inside too for edge cases)
      if (!isInside && edgeDistance > activationBuffer) {
        // Log suspicious attempt
        const logRef = db.collection("attendance_logs").doc();
        tx.set(logRef, {
          ticketId,
          type: "activated",
          detail: {
            success: false,
            reason: "outside_activation_zone",
            edgeDistance: Math.round(edgeDistance),
            maxAllowed: activationBuffer,
            userLat: lat,
            userLng: lng,
            isInside,
          },
          timestamp: FieldValue.serverTimestamp(),
        });
        throw new HttpsError(
          "failed-precondition",
          `Outside activation zone. Distance to geofence: ${Math.round(edgeDistance)}m, allowed: ${activationBuffer}m.`
        );
      }

      // Verify signature
      const userRef = db.collection("users").doc(uid);
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "User profile not found.");
      }
      const user = userSnap.data();
      if (!user.publicKey) {
        throw new HttpsError(
          "failed-precondition",
          "No public key registered. Enroll biometrics first."
        );
      }

      const signatureValid = verifySignature(
        user.publicKey,
        nonceData.nonce,
        signatureBase64
      );
      if (!signatureValid) {
        // Log suspicious attempt
        const logRef = db.collection("attendance_logs").doc();
        tx.set(logRef, {
          ticketId,
          type: "activated",
          detail: {
            success: false,
            reason: "invalid_signature",
          },
          timestamp: FieldValue.serverTimestamp(),
        });
        throw new HttpsError(
          "unauthenticated",
          "Biometric signature verification failed."
        );
      }

      // All checks passed — activate ticket
      const entryCode = generateEntryCode();

      tx.update(ticketRef, {
        status: "active",
        biometricVerified: true,
        insideFence: true,
        activatedAt: FieldValue.serverTimestamp(),
        entryCode,
      });

      // Mark nonce as used
      tx.update(nonceRef, { used: true });

      // Write attendance log
      const logRef = db.collection("attendance_logs").doc();
      tx.set(logRef, {
        ticketId,
        type: "activated",
        detail: {
          success: true,
          edgeDistance: Math.round(edgeDistance),
          isInside,
          entryCode,
        },
        timestamp: FieldValue.serverTimestamp(),
      });

      return { entryCode };
    });
  } catch (err) {
    // Re-throw HttpsError as-is; wrap unexpected errors with descriptive message
    if (err instanceof HttpsError) {
      throw err;
    }
    console.error("activateTicket unexpected error:", err.message, err.stack);
    throw new HttpsError(
      "internal",
      `Activation failed: ${err.message || "Unknown server error. Please try again."}`
    );
  }

  return { success: true, entryCode: result.entryCode };
});

// ─── deactivateTicket ───────────────────────────────────────────────────────

exports.deactivateTicket = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const uid = request.auth.uid;
  const { ticketId } = request.data;

  if (!ticketId) {
    throw new HttpsError("invalid-argument", "ticketId is required.");
  }

  await db.runTransaction(async (tx) => {
    const ticketRef = db.collection("tickets").doc(ticketId);
    const ticketSnap = await tx.get(ticketRef);

    if (!ticketSnap.exists) {
      throw new HttpsError("not-found", "Ticket not found.");
    }
    const ticket = ticketSnap.data();

    // Allow owner or admin
    if (ticket.ownerId !== uid) {
      // Check if requester is admin
      const userRef = db.collection("users").doc(uid);
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists || userSnap.data().role !== "admin") {
        throw new HttpsError("permission-denied", "Not authorized.");
      }
    }

    tx.update(ticketRef, {
      status: "expired",
      insideFence: false,
      biometricVerified: false,
    });

    const logRef = db.collection("attendance_logs").doc();
    tx.set(logRef, {
      ticketId,
      type: "expired",
      detail: { deactivatedBy: uid },
      timestamp: FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

// ─── sendExitWarningNotification ────────────────────────────────────────────

exports.sendExitWarningNotification = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const uid = request.auth.uid;
  const { ticketId } = request.data;

  if (!ticketId) {
    throw new HttpsError("invalid-argument", "ticketId is required.");
  }

  // Validate ticket ownership
  const ticketSnap = await db.collection("tickets").doc(ticketId).get();
  if (!ticketSnap.exists) {
    throw new HttpsError("not-found", "Ticket not found.");
  }
  const ticket = ticketSnap.data();
  if (ticket.ownerId !== uid) {
    throw new HttpsError("permission-denied", "Not authorized.");
  }

  // Update insideFence to false
  await db.collection("tickets").doc(ticketId).update({
    insideFence: false,
  });

  // Get user's FCM token
  const userSnap = await db.collection("users").doc(uid).get();
  const user = userSnap.data();

  if (user && user.fcmToken) {
    try {
      await getMessaging().send({
        token: user.fcmToken,
        notification: {
          title: "⚠️ Leaving Event Zone",
          body: "You left the event zone. Return within 3 minutes to keep your pass active.",
        },
        data: {
          ticketId,
          type: "exit_warning",
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              "content-available": 1,
            },
          },
        },
      });
    } catch (fcmErr) {
      console.error("FCM send failed:", fcmErr.message);
      // Don't throw — notification failure shouldn't block the flow
    }
  }

  // Log the exit event
  await db.collection("attendance_logs").doc().set({
    ticketId,
    type: "exited",
    detail: { warningsSent: true },
    timestamp: FieldValue.serverTimestamp(),
  });

  return { success: true };
});

// ─── revokePublicKey ────────────────────────────────────────────────────────

exports.revokePublicKey = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const uid = request.auth.uid;
  const { targetUserId } = request.data;

  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "targetUserId is required.");
  }

  // Only admins can revoke other users' keys; users can revoke their own
  if (targetUserId !== uid) {
    const adminSnap = await db.collection("users").doc(uid).get();
    if (!adminSnap.exists || adminSnap.data().role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only admins can revoke other users' keys."
      );
    }
  }

  await db.collection("users").doc(targetUserId).update({
    publicKey: null,
  });

  // Expire all active tickets for this user
  const ticketsSnap = await db
    .collection("tickets")
    .where("ownerId", "==", targetUserId)
    .where("status", "==", "active")
    .get();

  const batch = db.batch();
  ticketsSnap.docs.forEach((doc) => {
    batch.update(doc.ref, {
      status: "expired",
      biometricVerified: false,
      insideFence: false,
    });
    const logRef = db.collection("attendance_logs").doc();
    batch.set(logRef, {
      ticketId: doc.id,
      type: "expired",
      detail: { reason: "public_key_revoked", revokedBy: uid },
      timestamp: FieldValue.serverTimestamp(),
    });
  });
  await batch.commit();

  return { success: true, ticketsExpired: ticketsSnap.size };
});

// ─── onFirstLoginAssignRole ─────────────────────────────────────────────────

const { onSchedule } = require("firebase-functions/v2/scheduler");

const ADMIN_EMAILS = [
  "utkarshnayan007@gmail.com",
  "shashwatbhatt18@gmail.com",
];

/**
 * Callable function: ensures user document exists with correct role.
 * Called by the iOS app after sign-up / first sign-in.
 */
exports.onFirstLoginAssignRole = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const uid = request.auth.uid;
  const email = (request.auth.token.email || "").toLowerCase().trim();

  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();

  if (userSnap.exists) {
    // User doc already exists — return current role
    return { role: userSnap.data().role, existing: true };
  }

  const displayName = request.data.displayName || email;
  const role = ADMIN_EMAILS.includes(email) ? "admin" : "user";

  await userRef.set({
    email,
    displayName,
    role,
    publicKey: null,
    deviceId: null,
    fcmToken: null,
    createdAt: FieldValue.serverTimestamp(),
  });

  console.log(`User ${email} assigned role: ${role}`);
  return { role, existing: false };
});

// ─── handleHysteresis ───────────────────────────────────────────────────────

/**
 * Check how many minutes have elapsed since a ticket's insideFence went false.
 */
async function getMinutesSinceExit(ticketId) {
  const logsSnap = await db
    .collection("attendance_logs")
    .where("ticketId", "==", ticketId)
    .where("type", "==", "exited")
    .orderBy("timestamp", "desc")
    .limit(1)
    .get();

  if (logsSnap.empty) return -1;

  const exitTimestamp = logsSnap.docs[0].data().timestamp;
  if (!exitTimestamp) return -1;

  const exitDate = exitTimestamp.toDate
    ? exitTimestamp.toDate()
    : new Date(exitTimestamp);
  return (Date.now() - exitDate.getTime()) / 60000;
}

/**
 * Scheduled every minute. Finds active tickets that are outside the geofence
 * and have been outside for >= 3 minutes, then expires them.
 */
exports.handleHysteresis = onSchedule("every 1 minutes", async () => {
  const ticketsSnap = await db
    .collection("tickets")
    .where("status", "==", "active")
    .where("insideFence", "==", false)
    .get();

  if (ticketsSnap.empty) {
    console.log("handleHysteresis: no active tickets outside fence.");
    return;
  }

  const batch = db.batch();
  let expiredCount = 0;

  for (const doc of ticketsSnap.docs) {
    const ticketId = doc.id;
    const minutesSinceExit = await getMinutesSinceExit(ticketId);

    if (minutesSinceExit >= 3) {
      batch.update(doc.ref, {
        status: "expired",
        biometricVerified: false,
      });

      const logRef = db.collection("attendance_logs").doc();
      batch.set(logRef, {
        ticketId,
        type: "expired",
        detail: {
          reason: "hysteresis_timeout",
          minutesOutside: Math.round(minutesSinceExit),
        },
        timestamp: FieldValue.serverTimestamp(),
      });
      expiredCount++;
    }
  }

  if (expiredCount > 0) {
    await batch.commit();
    console.log(
      `handleHysteresis: expired ${expiredCount} ticket(s) after 3-min timeout.`
    );
  }
});

// Export helpers for testing
exports._testHelpers = {
  haversineDistance,
  isPointInsidePolygon,
  distanceFromPointToSegment,
  distanceFromPointToPolygonEdge,
  verifySignature,
  generateEntryCode,
  getMinutesSinceExit,
};
