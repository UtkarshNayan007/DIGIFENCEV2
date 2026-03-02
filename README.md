# DigiFence — Location-Locked, Biometric-Bound Event Pass System

A production-ready iOS app (SwiftUI + MVVM) with Firebase backend that creates geofence-locked, biometric-verified event passes.

> **Firebase Project:** `digifence-c5243` | **Bundle ID:** `Utkarsh.DIGIFENCEV1`

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                iOS App (SwiftUI)                │
│  ┌──────────┐ ┌──────────┐ ┌───────────────┐   │
│  │  Views   │→│ViewModels│→│   Services    │   │
│  └──────────┘ └──────────┘ │               │   │
│                            │ Firebase Mgr  │   │
│                            │ CloudFunctions│   │
│                            │ SecureEnclave │   │
│                            │ LocationMgr   │   │
│                            │ PushManager   │   │
│                            └──────┬────────┘   │
└───────────────────────────────────┼─────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │     Firebase Cloud Functions    │
                    │  createActivationNonce          │
                    │  activateTicket (verify sig+loc)│
                    │  deactivateTicket               │
                    │  sendExitWarningNotification    │
                    │  revokePublicKey                │
                    └───────────────┬───────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │     Cloud Firestore            │
                    │  users │ events │ tickets      │
                    │  activation_nonces             │
                    │  attendance_logs               │
                    └───────────────────────────────┘
```

## Core Flow

1. **Sign Up** → Secure Enclave generates EC P-256 keypair → public key uploaded to Firestore
2. **Browse Events** → Real-time Firestore listener shows active events with geofence info
3. **Get Ticket** → Creates `pending` ticket → starts geofence monitoring
4. **Enter Geofence** → `didEnterRegion` triggers activation flow:
   - App calls `createActivationNonce(ticketId)` → gets nonce from server
   - Sign nonce with Secure Enclave key (triggers FaceID/TouchID)
   - Send signature + location to `activateTicket` Cloud Function
   - Server verifies: ECDSA signature ✓ | Haversine distance ✓ | nonce valid ✓
   - Ticket activated → entry code generated
5. **Exit Geofence** → 2x exit confirmation (hysteresis) → 3-min grace timer → FCM warning
6. **Grace Expired** → `deactivateTicket` → ticket set to `expired`

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Xcode | 15.0+ | Mac App Store |
| Node.js | 20.x | `brew install node@20` |
| Firebase CLI | Latest | `npm install -g firebase-tools` |
| Apple Developer Account | — | Required for push notifications & device testing |

---

## Quick Start

### 1. Clone & Setup Functions

```bash
cd /Volumes/SIMBA/workspace/DIGIFENCEV1/functions
npm install
```

### 2. Firebase Login & Project Select

```bash
firebase login
firebase use digifence-c5243
```

### 3. Deploy Firestore Rules & Indexes

```bash
cd /Volumes/SIMBA/workspace/DIGIFENCEV1
firebase deploy --only firestore:rules,firestore:indexes
```

### 4. Deploy Cloud Functions

```bash
cd /Volumes/SIMBA/workspace/DIGIFENCEV1
firebase deploy --only functions
```

### 5. Open Xcode Project

```bash
open DIGIFENCEV1.xcodeproj
```

### 6. Add Firebase SPM Packages in Xcode

1. In Xcode: **File → Add Package Dependencies**
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Set version to **11.0.0** (or latest)
4. Select these products:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseFunctions`
   - `FirebaseMessaging`
   - `FirebaseAppCheck`
5. Click **Add Package**

### 7. Add Source Files to Xcode

Since source files were created outside Xcode, you need to add them:

1. In Xcode Project Navigator, right-click the `DIGIFENCEV1` group
2. Select **Add Files to "DIGIFENCEV1"...**
3. Navigate to `DIGIFENCEV1/` source folder
4. Select these folders (with "Create groups" selected):
   - `Models/`
   - `Services/`
   - `ViewModels/`
   - `Views/`
   - `Tests/`
5. Ensure **"Add to target: DIGIFENCEV1"** is checked
6. Click **Add**

### 8. Configure Info.plist / Capabilities

Add these to your Xcode target:

**Capabilities (Signing & Capabilities tab):**
- Background Modes: ✅ Location updates, ✅ Remote notifications
- Push Notifications
- App Groups (optional)

**Info.plist keys (Info tab → Custom iOS Target Properties):**
```
NSLocationAlwaysAndWhenInUseUsageDescription = "DigiFence needs your location to activate event passes when you arrive at venues."
NSLocationWhenInUseUsageDescription = "DigiFence uses your location to verify you are at the event venue."
NSFaceIDUsageDescription = "DigiFence uses Face ID to secure your event passes with biometric verification."
```

### 9. Build & Run

- **Simulator**: Build (⌘B) and run (⌘R) — most features work except Secure Enclave biometrics and push notifications
- **Device**: Select your physical device, ensure signing is configured, run

---

## Local Development with Firebase Emulator

### Start Emulators

```bash
cd /Volumes/SIMBA/workspace/DIGIFENCEV1
firebase emulators:start --only firestore,functions,auth
```

Emulator UI: http://localhost:4000

### Seed Test Data

```bash
cd functions
node seed.js
```

This creates:
- Admin user (`admin@digifence.dev`)
- Test user (`user@digifence.dev`)
- 3 sample events (SF, Golden Gate Park, Mountain View)
- 1 pending ticket

### Point iOS App to Emulator

In your Xcode scheme, add this environment variable:
1. **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**
2. Add: `USE_FIREBASE_EMULATOR` = `1`

The app's `FirebaseManager` will automatically use localhost emulators.

---

## Run Cloud Functions Tests

```bash
cd /Volumes/SIMBA/workspace/DIGIFENCEV1/functions
npm test
```

Tests cover:
- Haversine distance calculation
- ECDSA P-256 signature verification (matching iOS Secure Enclave output)
- Entry code generation

---

## APNs Setup (Push Notifications)

Push notifications require a physical device and Apple Developer account:

1. **Apple Developer Portal** → Certificates, Identifiers & Profiles
2. Create an **APNs Key** (or certificate) for your App ID
3. **Firebase Console** → Project Settings → Cloud Messaging
4. Upload the APNs key (`.p8` file) with Key ID and Team ID
5. In Xcode: enable **Push Notifications** capability
6. Build and run on a physical device

---

## Firestore Schema

| Collection | Document Fields |
|---|---|
| `users/{uid}` | email, displayName, role, publicKey, deviceId, fcmToken, createdAt |
| `events/{eventId}` | title, description, geo{lat,lng}, radiusMeters, organizerId, startsAt, endsAt, isActive, createdAt |
| `tickets/{ticketId}` | eventId, ownerId, status, biometricVerified, insideFence, activatedAt, entryCode, createdAt |
| `activation_nonces/{nonceId}` | ticketId, nonce, expiresAt, used |
| `attendance_logs/{logId}` | ticketId, type, detail, timestamp |

---

## Security

### Firestore Rules
- `users/{uid}`: Read/write only by owner; role escalation blocked
- `events`: Public read; write only by admins (role check)
- `tickets`: Create only by owner with `pending` status; **all status updates denied client-side** — only Cloud Functions (Admin SDK) can change `status`, `biometricVerified`, `insideFence`, `activatedAt`, `entryCode`
- `activation_nonces`: Server-only read/write
- `attendance_logs`: Server-only write

### Anti-Spoofing
- **GPS spoofing**: Server verifies Haversine distance; suspicious attempts logged
- **Signature forgery**: ECDSA P-256 verification against enrolled public key
- **Nonce replay**: Single-use nonces with 60s expiry
- **Device loss**: Admin can revoke public key (expires all active tickets)

---

## Project Structure

```
DIGIFENCEV1/
├── firebase.json              # Firebase config
├── firestore.rules            # Firestore security rules
├── firestore.indexes.json     # Composite indexes
├── functions/
│   ├── package.json           # Node.js 20 project
│   ├── index.js               # Cloud Functions (5 callable + helpers)
│   ├── index.test.js          # Jest tests
│   └── seed.js                # Firestore seed data
├── DIGIFENCEV1/
│   ├── DIGIFENCEV1App.swift   # App entry + AppDelegate
│   ├── ContentView.swift      # Root routing view
│   ├── GoogleService-Info.plist
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Event.swift
│   │   └── Ticket.swift
│   ├── Services/
│   │   ├── FirebaseManager.swift
│   │   ├── CloudFunctionsService.swift
│   │   ├── SecureEnclaveManager.swift
│   │   ├── LocationManager.swift
│   │   └── PushManager.swift
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift
│   │   ├── OnboardingViewModel.swift
│   │   ├── EventsViewModel.swift
│   │   ├── AdminViewModel.swift
│   │   ├── TicketViewModel.swift
│   │   └── MyPassViewModel.swift
│   ├── Views/
│   │   ├── OnboardingView.swift
│   │   ├── LoginView.swift
│   │   ├── EventsListView.swift
│   │   ├── EventDetailView.swift
│   │   ├── AdminMapView.swift
│   │   ├── MyPassView.swift
│   │   └── MainTabView.swift
│   └── Tests/
│       ├── SecureEnclaveTests.swift
│       ├── DistanceCalculationTests.swift
│       └── ActivationFlowTests.swift
└── README.md
```

---

## Deployment Checklist

- [ ] `firebase deploy --only firestore:rules,firestore:indexes`
- [ ] `firebase deploy --only functions`
- [ ] Add Firebase SPM packages in Xcode
- [ ] Add source files to Xcode project
- [ ] Configure capabilities (Background Modes, Push Notifications)
- [ ] Add Info.plist keys (Location, Face ID usage descriptions)
- [ ] Upload APNs key to Firebase Console
- [ ] Enable Google Sign-In in Firebase Console (optional)
- [ ] Build and run on device

---

## Troubleshooting

| Issue | Solution |
|---|---|
| `FirebaseApp.configure()` crash | Ensure `GoogleService-Info.plist` is in the Xcode target |
| "No signing key found" | Complete onboarding or re-enroll biometrics in Profile |
| Location not working in simulator | Use Debug → Location → Custom Location in simulator |
| Geofence not triggering | Ensure "Always" location permission; check `CLLocationManager.isMonitoringAvailable` |
| Push notifications not received | Physical device only; ensure APNs key uploaded to Firebase Console |
| Cloud Functions 403 | Deploy latest functions; check auth token; verify Firestore rules |
| Emulator connection refused | Ensure `USE_FIREBASE_EMULATOR=1` set in scheme and emulators running |
| Nonce expired | Retry activation — nonces have 60s TTL |

---

## License

Proprietary — All rights reserved.
