# Firebase Configuration Fix Guide

## Critical Issues Identified

### 1. App Check Debug Token Not Registered ❌

**Error:**
```
AppCheck failed: 'App attestation failed' - HTTP 403
```

**Your Debug Tokens:**
- `ED2F8B6E-4131-4F20-9D4E-1DA7486FE0DB`
- `90C31477-ABBE-4599-90B0-6481848C3B98`

**Fix Steps:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `digifence-c5243`
3. Navigate to: **Build** → **App Check**
4. Click on your iOS app: `1:695824750448:ios:2342f7d279ad81b7a0e1b5`
5. Scroll to **Debug tokens** section
6. Click **Add debug token**
7. Add both tokens:
   - `ED2F8B6E-4131-4F20-9D4E-1DA7486FE0DB`
   - `90C31477-ABBE-4599-90B0-6481848C3B98`
8. Click **Save**

### 2. Firebase In-App Messaging API Disabled ⚠️

**Error:**
```
Firebase In-App Messaging API has not been used in project 695824750448
```

**Fix Steps:**

1. Visit: https://console.developers.google.com/apis/api/firebaseinappmessaging.googleapis.com/overview?project=695824750448
2. Click **Enable API**
3. Wait 2-3 minutes for propagation

### 3. Firestore Rules Are Correct ✅

Your Firestore rules are properly configured:
- Authenticated users CAN create events
- Events require: title, polygonCoordinates (≥3 points), organizerId, isActive, createdAt
- organizerId must match the authenticated user's UID

The permission error is caused by App Check blocking requests, NOT the Firestore rules.

## Quick Test After Fixing

After registering the debug tokens:

1. **Restart your app** (completely quit and relaunch)
2. **Try creating an event again**
3. **Check console logs** - you should see:
   ```
   ✅ AppCheck token obtained successfully
   ```

## Deploy Updated Rules (Optional)

If you made any changes to firestore.rules:

```bash
firebase deploy --only firestore:rules
```

## Verify Event Creation

After fixing App Check, events should:
1. ✅ Be created in Firestore under `/events/{eventId}`
2. ✅ Be visible to all authenticated users
3. ✅ Allow ticket purchases by users
4. ✅ Show up in real-time for all users

## Still Having Issues?

If problems persist after registering debug tokens:

1. **Check user authentication:**
   ```
   User must be signed in with Firebase Auth
   ```

2. **Verify user document exists:**
   ```
   /users/{uid} must exist with 'role' field
   ```

3. **Check event data structure:**
   ```swift
   {
     "title": "Event Name",
     "description": "...",
     "polygonCoordinates": [
       {"latitude": 37.7749, "longitude": -122.4194},
       {"latitude": 37.7750, "longitude": -122.4195},
       {"latitude": 37.7751, "longitude": -122.4196}
     ],
     "organizerId": "user-uid-here",
     "isActive": true,
     "createdAt": Timestamp,
     "startTime": Timestamp,
     "endTime": Timestamp,
     "capacity": 100,
     "ticketsSold": 0,
     "price": 25.00
   }
   ```

## Next Steps

1. ✅ Register debug tokens in Firebase Console (CRITICAL - DO THIS FIRST)
2. ✅ Enable Firebase In-App Messaging API
3. ✅ Restart your app
4. ✅ Test event creation
5. ✅ Verify events appear for all users
