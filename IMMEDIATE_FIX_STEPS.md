# 🚨 IMMEDIATE FIX - Event Creation Permission Error

## Problem Summary

Your app cannot create events because **Firebase App Check is blocking all Firestore requests** with a 403 error. This happens BEFORE your Firestore security rules are even evaluated.

**Error:** `App attestation failed - HTTP 403`

## ✅ SOLUTION (Takes 2 minutes)

### Step 1: Register Debug Tokens in Firebase Console

1. **Open Firebase Console:**
   - Go to: https://console.firebase.google.com/
   - Select project: **digifence-c5243**

2. **Navigate to App Check:**
   - Click **Build** in left sidebar
   - Click **App Check**

3. **Select your iOS app:**
   - Find: `1:695824750448:ios:2342f7d279ad81b7a0e1b5`
   - Click on it

4. **Add Debug Tokens:**
   - Scroll down to **"Debug tokens"** section
   - Click **"Add debug token"** button
   - Enter: `ED2F8B6E-4131-4F20-9D4E-1DA7486FE0DB`
   - Click **Save**
   - Click **"Add debug token"** again
   - Enter: `90C31477-ABBE-4599-90B0-6481848C3B98`
   - Click **Save**

### Step 2: Enable Firebase In-App Messaging API (Optional but recommended)

1. Visit: https://console.developers.google.com/apis/api/firebaseinappmessaging.googleapis.com/overview?project=695824750448
2. Click **"Enable"** button
3. Wait 2-3 minutes for the API to activate

### Step 3: Restart Your App

1. **Completely quit** your app (swipe up from app switcher)
2. **Relaunch** the app
3. **Try creating an event again**

## ✅ Expected Result

After registering the debug tokens, you should see:

```
✅ App Check token obtained successfully
✅ Event created successfully
✅ Event visible to all users
```

## 🔍 Verify It's Working

### In Xcode Console:
Look for these messages (NOT errors):
```
🛠️ App Check Debug Provider configured
✅ Successfully decoded user: utkarshnayan007@gmail.com, role: admin
```

### In Firebase Console:
1. Go to **Firestore Database**
2. Navigate to **events** collection
3. You should see your newly created event

### In Your App:
1. Create an event as admin
2. Sign in as a regular user (different account)
3. The event should appear in the Events tab
4. Users should be able to tap "Get Ticket"

## 🎯 Why This Fixes It

**Before Fix:**
```
App → Firestore Request → ❌ App Check blocks (403) → Never reaches Firestore rules
```

**After Fix:**
```
App → Firestore Request → ✅ App Check validates debug token → ✅ Firestore rules allow → ✅ Event created
```

Your Firestore security rules are **already correct**. They allow:
- ✅ Any authenticated user to create events
- ✅ All authenticated users to read events
- ✅ Event creators to update/delete their own events

The problem was App Check blocking requests before they reached your rules.

## 🚀 Next Steps After Fix

Once events are creating successfully:

1. **Test ticket purchase:**
   - Sign in as a regular user
   - Browse events
   - Click "Get Ticket"
   - Verify ticket appears in "My Pass"

2. **Test geofencing:**
   - Create an event with a polygon geofence
   - Purchase a ticket
   - Simulate location inside the geofence
   - Try activating the ticket

3. **Test admin features:**
   - View event statistics
   - Track guest attendance
   - Deactivate tickets

## ❓ Still Having Issues?

If you still see permission errors after registering debug tokens:

### Check 1: User is authenticated
```swift
// In your app, verify:
Auth.auth().currentUser != nil
```

### Check 2: User document exists
```
Firebase Console → Firestore → users → {your-uid}
Should have: email, role, createdAt
```

### Check 3: Event data is valid
```swift
// Event must have:
- title (string)
- polygonCoordinates (array with ≥3 points)
- organizerId (string, matches your UID)
- isActive (boolean)
- createdAt (timestamp)
```

### Check 4: App Check token is being sent
```
Xcode Console should show:
"🛠️ App Check Debug Provider configured"

Should NOT show:
"AppCheck failed: 'App attestation failed'"
```

## 📞 Need More Help?

If the issue persists after following these steps:

1. **Copy the FULL error message** from Xcode console
2. **Check Firebase Console** → Firestore → Rules tab
3. **Verify your user role** in Firestore → users → {your-uid} → role field
4. **Try signing out and back in** to refresh authentication

---

**TL;DR:** Register the two debug tokens in Firebase Console → App Check → Debug tokens, then restart your app. Event creation will work immediately.
