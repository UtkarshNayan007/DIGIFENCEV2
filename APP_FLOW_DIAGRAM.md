# 📊 Complete DigiFence App Flow

## Event Creation Flow (With Images & Coordinates)

```
┌─────────────────────────────────────────────────────────────┐
│                     ADMIN CREATES EVENT                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  1. Fill Form                                                │
│     • Title: "Summer Music Festival"                         │
│     • Description: "Amazing outdoor concert"                 │
│     • Start Date: June 15, 2024                             │
│     • End Date: June 16, 2024                               │
│     • Capacity: 500                                          │
│     • Price: $50                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Select Image                                             │
│     • Tap "Select Image" button                              │
│     • Choose from photo library                              │
│     • Image stored in memory as Data                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Draw Polygon on Map                                      │
│     • Tap map to add points                                  │
│     • Point 1: (37.7749, -122.4194)                         │
│     • Point 2: (37.7750, -122.4195)                         │
│     • Point 3: (37.7751, -122.4193)                         │
│     • Point 4: (37.7748, -122.4192)                         │
│     • Polygon drawn on map                                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Tap "Create Event"                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  5. App Validates Data                                       │
│     ✓ Title not empty                                        │
│     ✓ Polygon has ≥3 points                                  │
│     ✓ Dates are valid                                        │
│     ✓ User is authenticated                                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  6. Create Firestore Document                                │
│                                                              │
│  POST /firestore/events                                      │
│  {                                                           │
│    "title": "Summer Music Festival",                         │
│    "description": "Amazing outdoor concert",                 │
│    "polygonCoordinates": [                                   │
│      {"lat": 37.7749, "lng": -122.4194},                    │
│      {"lat": 37.7750, "lng": -122.4195},                    │
│      {"lat": 37.7751, "lng": -122.4193},                    │
│      {"lat": 37.7748, "lng": -122.4192}                     │
│    ],                                                        │
│    "organizerId": "4euBpeNrgoULlLP7sTYoZ7HYXib2",           │
│    "capacity": 500,                                          │
│    "ticketsSold": 0,                                         │
│    "ticketPrice": 50.0,                                      │
│    "startsAt": Timestamp(2024-06-15),                        │
│    "endsAt": Timestamp(2024-06-16),                          │
│    "isActive": true,                                         │
│    "createdAt": ServerTimestamp                              │
│  }                                                           │
│                                                              │
│  Response: Document ID = "abc123xyz"                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  7. Upload Image to Firebase Storage                         │
│                                                              │
│  PUT /storage/events/abc123xyz/thumbnail.jpg                 │
│  Content-Type: image/jpeg                                    │
│  Body: [image data]                                          │
│                                                              │
│  Response: Download URL                                      │
│  https://firebasestorage.googleapis.com/.../thumbnail.jpg    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  8. Update Document with Image URL                           │
│                                                              │
│  PATCH /firestore/events/abc123xyz                           │
│  {                                                           │
│    "thumbnailURL": "https://firebasestorage.../thumb.jpg"   │
│  }                                                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  9. Success! Event Created                                   │
│     • Show success message                                   │
│     • Reset form                                             │
│     • Event appears in admin's event list                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  10. Real-Time Updates                                       │
│      • All users' apps receive update                        │
│      • Event appears in Events tab                           │
│      • Image loads from Storage URL                          │
│      • Polygon displayed on map                              │
└─────────────────────────────────────────────────────────────┘
```

## User Ticket Purchase Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   USER BROWSES EVENTS                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Events Tab                                                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 🎵 Summer Music Festival                             │  │
│  │ [Event Image]                                         │  │
│  │ June 15-16, 2024                                      │  │
│  │ $50 • 500 capacity • 0 sold                          │  │
│  │                                                       │  │
│  │ [Get Ticket]                                          │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  User Taps "Get Ticket"                                      │
│  • Payment simulation (2 seconds)                            │
│  • Create ticket in Firestore                                │
│  • Navigate to My Pass                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Ticket Created in Firestore                                 │
│  {                                                           │
│    "eventId": "abc123xyz",                                   │
│    "ownerId": "user-uid",                                    │
│    "status": "pending",                                      │
│    "biometricVerified": false,                               │
│    "insideFence": false,                                     │
│    "createdAt": Timestamp                                    │
│  }                                                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Geofence Monitoring Starts                                  │
│  • App monitors user location                                │
│  • Checks if inside polygon                                  │
│  • Waits for user to arrive at venue                         │
└─────────────────────────────────────────────────────────────┘
```

## Ticket Activation Flow (At Venue)

```
┌─────────────────────────────────────────────────────────────┐
│  User Arrives at Venue                                       │
│  • GPS: (37.7749, -122.4194)                                │
│  • Inside polygon: YES                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  App Detects Entry                                           │
│  • Ray casting algorithm confirms inside                     │
│  • Triggers activation flow                                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Request Activation Nonce                                    │
│  Cloud Function: createActivationNonce                       │
│  • Generates 32-byte random nonce                            │
│  • 60-second expiration                                      │
│  • Returns nonceId and nonce                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Biometric Authentication                                    │
│  • Prompt FaceID/TouchID                                     │
│  • User authenticates                                        │
│  • Secure Enclave signs nonce                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Activate Ticket                                             │
│  Cloud Function: activateTicket                              │
│  • Verify signature                                          │
│  • Verify location                                           │
│  • Verify nonce not expired                                  │
│  • Update ticket status to "active"                          │
│  • Generate entry code                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Success! Ticket Activated                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ ✅ ACTIVE                                             │  │
│  │                                                       │  │
│  │ Entry Code: ABC123                                    │  │
│  │                                                       │  │
│  │ Summer Music Festival                                 │  │
│  │ Activated: 2:30 PM                                    │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Data Storage Structure

```
Firebase Firestore:
├── events/
│   └── abc123xyz/
│       ├── title: "Summer Music Festival"
│       ├── description: "Amazing outdoor concert"
│       ├── polygonCoordinates: [
│       │     {lat: 37.7749, lng: -122.4194},
│       │     {lat: 37.7750, lng: -122.4195},
│       │     {lat: 37.7751, lng: -122.4193},
│       │     {lat: 37.7748, lng: -122.4192}
│       │   ]
│       ├── thumbnailURL: "https://firebasestorage.../thumbnail.jpg"
│       ├── organizerId: "4euBpeNrgoULlLP7sTYoZ7HYXib2"
│       ├── capacity: 500
│       ├── ticketsSold: 0
│       ├── ticketPrice: 50.0
│       ├── startsAt: Timestamp
│       ├── endsAt: Timestamp
│       ├── isActive: true
│       └── createdAt: Timestamp
│
├── tickets/
│   └── ticket123/
│       ├── eventId: "abc123xyz"
│       ├── ownerId: "user-uid"
│       ├── status: "active"
│       ├── biometricVerified: true
│       ├── insideFence: true
│       ├── entryCode: "ABC123"
│       ├── activatedAt: Timestamp
│       └── createdAt: Timestamp
│
└── users/
    └── user-uid/
        ├── email: "user@example.com"
        ├── role: "user"
        ├── publicKey: "base64-encoded-key"
        ├── fcmToken: "fcm-token"
        └── createdAt: Timestamp

Firebase Storage:
└── events/
    └── abc123xyz/
        └── thumbnail.jpg  (uploaded image)
```

## Summary

✅ **Images:** Uploaded to Storage, URL saved in Firestore  
✅ **Coordinates:** Saved as array of lat/lng objects  
✅ **Events:** Created with all data in Firestore  
✅ **Tickets:** Created when users purchase  
✅ **Activation:** Biometric + geofence verification  
✅ **Real-time:** All updates propagate instantly  

**Everything works! Just register the App Check debug tokens.**
