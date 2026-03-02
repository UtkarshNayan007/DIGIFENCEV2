# 🔍 Debug Checklist - Event Creation Issue

## Current Status

✅ **Firestore Rules:** Correct - allow authenticated users to create events  
✅ **Event Creation Code:** Correct - sends all required fields  
❌ **App Check:** BLOCKING - debug tokens not registered  

## The Root Cause

```
12.10.0 - [FirebaseFirestore][I-FST000001] AppCheck failed: 
'App attestation failed' - HTTP 403
```

This error means:
1. Your app is trying to write to Firestore
2. App Check intercepts the request
3. App Check rejects it because the debug token isn't registered
4. The request NEVER reaches Firestore security rules
5. You see "Missing or insufficient permissions" (misleading error)

## What Your Event Creation Code Does (Correctly)

```swift
// From AdminViewModel.swift line 207-260
func createEvent() async {
    // ✅ Validates user is signed in
    // ✅ Creates polygon data with lat/lng
    // ✅ Includes all required fields:
    eventData = [
        "title": title,                          // ✅ Required
        "description": description,              // ✅ Optional but included
        "polygonCoordinates": polygonData,       // ✅ Required (≥3 points)
        "organizerId": uid,                      // ✅ Required (matches auth)
        "capacity": capacity,                    // ✅ Optional
        "ticketsSold": 0,                        // ✅ Good practice
        "startsAt": Timestamp(date: startsAt),   // ✅ Optional
        "endsAt": Timestamp(date: endsAt),       // ✅ Optional
        "isActive": isActive,                    // ✅ Required
        "createdAt": FieldValue.serverTimestamp() // ✅ Required
    ]
    
    // ✅ Writes to Firestore
    let docRef = try await firebase.eventsCollection.addDocument(data: eventData)
    
    // ✅ Uploads image if provided
    // ✅ Updates document with thumbnail URL
}
```

**This code is PERFECT.** The issue is not here.

## What Your Firestore Rules Allow (Correctly)

```javascript
// From firestore.rules line 35-45
match /events/{eventId} {
    allow read: if isAuthenticated();  // ✅ Any authenticated user can read
    
    allow create: if isAuthenticated() &&  // ✅ Must be signed in
        request.resource.data.keys().hasAll([
            'title',                    // ✅ Your code includes this
            'polygonCoordinates',       // ✅ Your code includes this
            'organizerId',              // ✅ Your code includes this
            'isActive',                 // ✅ Your code includes this
            'createdAt'                 // ✅ Your code includes this
        ]) &&
        request.resource.data.organizerId == request.auth.uid &&  // ✅ Matches
        request.resource.data.polygonCoordinates.size() >= 3;     // ✅ Validated
}
```

**These rules are PERFECT.** The issue is not here.

## The ACTUAL Problem

```
Request Flow:
┌─────────────┐
│  Swift App  │
└──────┬──────┘
       │ 1. Create event request
       ▼
┌─────────────────┐
│   App Check     │ ◄── 🚨 BLOCKS HERE with 403
└─────────────────┘
       │ 2. Should validate debug token
       │    BUT token not registered!
       ▼
   ❌ BLOCKED
   
   Never reaches:
   ┌─────────────────┐
   │ Firestore Rules │ ◄── Never evaluated
   └─────────────────┘
   ┌─────────────────┐
   │   Firestore DB  │ ◄── Never written
   └─────────────────┘
```

## The Fix (2 minutes)

### Option 1: Register Debug Tokens (RECOMMENDED)

1. Firebase Console → App Check → Your iOS app
2. Add debug tokens:
   - `ED2F8B6E-4131-4F20-9D4E-1DA7486FE0DB`
   - `90C31477-ABBE-4599-90B0-6481848C3B98`
3. Restart app
4. ✅ Event creation works

### Option 2: Temporarily Disable App Check (NOT RECOMMENDED)

Only use this for testing if you can't access Firebase Console:

```swift
// In DIGIFENCEV1App.swift, comment out App Check:
func application(...) -> Bool {
    FirebaseApp.configure()
    
    // #if DEBUG
    // AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
    // #endif
    
    // ... rest of code
}
```

⚠️ **Warning:** This disables security. Only use temporarily for testing.

## After Fix - Expected Behavior

### 1. Console Logs (Success)
```
🛠️ App Check Debug Provider configured
✅ Firestore document exists for UID: 4euBpeNrgoULlLP7sTYoZ7HYXib2
✅ Successfully decoded user: utkarshnayan007@gmail.com, role: admin
✅ Event created successfully!
```

### 2. Firebase Console
```
Firestore Database → events → {new-event-id}
{
  "title": "Your Event Name",
  "description": "...",
  "polygonCoordinates": [...],
  "organizerId": "4euBpeNrgoULlLP7sTYoZ7HYXib2",
  "isActive": true,
  "createdAt": "2024-03-02T10:30:00Z",
  ...
}
```

### 3. App Behavior
- ✅ Admin can create events
- ✅ Events appear in Events tab for all users
- ✅ Users can tap "Get Ticket"
- ✅ Tickets are created in Firestore
- ✅ Real-time updates work

## Verification Steps

After registering debug tokens and restarting:

### Step 1: Check App Check Status
```
Xcode Console should show:
✅ "🛠️ App Check Debug Provider configured"

Should NOT show:
❌ "AppCheck failed: 'App attestation failed'"
```

### Step 2: Try Creating Event
1. Fill in event details
2. Add at least 3 polygon points on map
3. Tap "Create Event"
4. Should see: "Event created successfully!"

### Step 3: Verify in Firestore
1. Firebase Console → Firestore Database
2. Navigate to `events` collection
3. Find your newly created event
4. Verify all fields are present

### Step 4: Test User Access
1. Sign out from admin account
2. Sign in as regular user
3. Go to Events tab
4. Your event should appear
5. Tap event to see details
6. "Get Ticket" button should be enabled

## Common Mistakes to Avoid

❌ **Don't** modify Firestore rules - they're already correct  
❌ **Don't** change event creation code - it's already correct  
❌ **Don't** disable App Check permanently - it's a security feature  
✅ **Do** register debug tokens in Firebase Console  
✅ **Do** restart app after registering tokens  
✅ **Do** verify user is authenticated before creating events  

## Summary

**Problem:** App Check blocking requests (403 error)  
**Solution:** Register debug tokens in Firebase Console  
**Time:** 2 minutes  
**Result:** Event creation works immediately  

Your code is correct. Your rules are correct. You just need to register the debug tokens.
