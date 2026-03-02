# 📱 Firebase Console - Step-by-Step Visual Guide

## 🎯 Goal
Register App Check debug tokens so your app can create events

## ⏱️ Time Required
2 minutes

## 📋 Step-by-Step Instructions

### Step 1: Open Firebase Console

1. Go to: **https://console.firebase.google.com/**
2. Sign in with your Google account
3. You should see your projects list

### Step 2: Select Your Project

1. Find and click: **digifence-c5243**
2. You'll be taken to the project overview page

### Step 3: Navigate to App Check

1. Look at the **left sidebar**
2. Find the **"Build"** section
3. Click on **"App Check"**

```
Left Sidebar:
├── 🏠 Project Overview
├── 📊 Analytics
├── 🔨 Build
│   ├── Authentication
│   ├── Firestore Database
│   ├── Storage
│   ├── Hosting
│   ├── Functions
│   ├── Machine Learning
│   └── 🎯 App Check  ← CLICK HERE
├── 🚀 Release & Monitor
└── ⚙️ Project settings
```

### Step 4: Find Your iOS App

On the App Check page, you'll see a list of your apps:

```
Apps:
┌─────────────────────────────────────────────────┐
│ 📱 iOS App                                      │
│ Bundle ID: com.digifence.DIGIFENCEV1            │
│ App ID: 1:695824750448:ios:2342f7d279ad81b7... │
│                                                 │
│ [Configure] [Manage]                            │
└─────────────────────────────────────────────────┘
```

1. Find your iOS app (Bundle ID: com.digifence.DIGIFENCEV1)
2. Click on it to expand details

### Step 5: Scroll to Debug Tokens Section

After clicking your app, scroll down to find:

```
┌─────────────────────────────────────────────────┐
│ Debug tokens                                    │
│                                                 │
│ Debug tokens allow you to test App Check       │
│ integration in debug builds.                    │
│                                                 │
│ [+ Add debug token]                             │
│                                                 │
│ No debug tokens registered yet                  │
└─────────────────────────────────────────────────┘
```

### Step 6: Add First Debug Token

1. Click the **"+ Add debug token"** button
2. A dialog will appear:

```
┌─────────────────────────────────────────────────┐
│ Add debug token                                 │
│                                                 │
│ Token name (optional):                          │
│ ┌─────────────────────────────────────────────┐ │
│ │ Utkarsh's iPhone                            │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ Token:                                          │
│ ┌─────────────────────────────────────────────┐ │
│ │ ED2F8B6E-4131-4F20-9D4E-1DA7486FE0DB        │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│         [Cancel]              [Add]             │
└─────────────────────────────────────────────────┘
```

3. **Token name:** Enter `Utkarsh's iPhone` (or any name you want)
4. **Token:** Paste `ED2F8B6E-4131-4F20-9D4E-1DA7486FE0DB`
5. Click **"Add"** button

### Step 7: Add Second Debug Token

1. Click **"+ Add debug token"** again
2. In the dialog:
   - **Token name:** Enter `Simulator` (or any name)
   - **Token:** Paste `90C31477-ABBE-4599-90B0-6481848C3B98`
3. Click **"Add"** button

### Step 8: Verify Tokens Are Added

You should now see:

```
┌─────────────────────────────────────────────────┐
│ Debug tokens                                    │
│                                                 │
│ [+ Add debug token]                             │
│                                                 │
│ ┌─────────────────────────────────────────────┐ │
│ │ 📱 Utkarsh's iPhone                         │ │
│ │ ED2F8B6E-4131-4F20-9D4E-1DA7486FE0DB        │ │
│ │ Added: Just now                             │ │
│ │                                    [Delete]  │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ ┌─────────────────────────────────────────────┐ │
│ │ 📱 Simulator                                │ │
│ │ 90C31477-ABBE-4599-90B0-6481848C3B98        │ │
│ │ Added: Just now                             │ │
│ │                                    [Delete]  │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

✅ **Success!** Both tokens are now registered.

### Step 9: Enable Firebase In-App Messaging API (Optional)

This fixes the other warning in your logs:

1. Open this URL in a new tab:
   ```
   https://console.developers.google.com/apis/api/firebaseinappmessaging.googleapis.com/overview?project=695824750448
   ```

2. You'll see:

```
┌─────────────────────────────────────────────────┐
│ Firebase In-App Messaging API                   │
│                                                 │
│ This API is currently disabled                  │
│                                                 │
│              [ENABLE]                           │
└─────────────────────────────────────────────────┘
```

3. Click the **"ENABLE"** button
4. Wait 2-3 minutes for the API to activate

### Step 10: Restart Your App

1. **On your iPhone/Simulator:**
   - Swipe up to see all open apps
   - Swipe up on your DigiFence app to close it completely
   - Tap the app icon to relaunch

2. **In Xcode:**
   - Stop the app (⌘+.)
   - Run again (⌘+R)

### Step 11: Test Event Creation

1. **Sign in** as admin (utkarshnayan007@gmail.com)
2. **Go to Admin tab**
3. **Fill in event details:**
   - Title: "Test Event"
   - Description: "Testing after App Check fix"
   - Add 3+ polygon points on map
   - Set capacity, price, dates
4. **Tap "Create Event"**
5. **Expected result:** "Event created successfully!" ✅

### Step 12: Verify Event is Live

1. **In Firebase Console:**
   - Go to **Firestore Database**
   - Click on **events** collection
   - You should see your new event

2. **In your app (as regular user):**
   - Sign out from admin
   - Sign in as regular user
   - Go to **Events tab**
   - Your event should appear
   - Tap event → "Get Ticket" should work

## 🎉 Success Indicators

After completing these steps, you should see:

### ✅ In Xcode Console:
```
🛠️ App Check Debug Provider configured
✅ Firestore document exists for UID: 4euBpeNrgoULlLP7sTYoZ7HYXib2
✅ Successfully decoded user: utkarshnayan007@gmail.com, role: admin
```

### ✅ NOT seeing these errors anymore:
```
❌ AppCheck failed: 'App attestation failed'
❌ WriteStream error: 'Permission denied'
❌ Write at events/... failed: Missing or insufficient permissions
```

### ✅ In Firebase Console:
- Events collection has your new event
- All fields are populated correctly
- thumbnailURL is set (if you uploaded an image)

### ✅ In Your App:
- Admin can create events without errors
- Events appear immediately in Events tab
- All users can see the events
- Users can purchase tickets
- Real-time updates work

## 🆘 Troubleshooting

### Can't find App Check in Firebase Console?

Make sure you're looking in the **"Build"** section, not "Release & Monitor"

### Don't see your iOS app listed?

1. Go to **Project settings** (gear icon)
2. Scroll to **"Your apps"** section
3. Verify your iOS app is registered
4. If not, click **"Add app"** → **iOS**

### Tokens added but still getting errors?

1. **Completely quit and restart your app** (not just rebuild)
2. **Wait 1-2 minutes** after adding tokens
3. **Check you're using the correct Firebase project** in GoogleService-Info.plist
4. **Verify you're signed in** before creating events

### Still seeing "Missing or insufficient permissions"?

1. Check **Firestore Rules** are deployed:
   ```bash
   firebase deploy --only firestore:rules
   ```

2. Verify **user document exists**:
   - Firebase Console → Firestore → users → {your-uid}
   - Should have: email, role, createdAt

3. Check **user is authenticated**:
   - Xcode console should show: "✅ Successfully decoded user: ..."

## 📞 Need More Help?

If you're still stuck after following these steps:

1. Take a screenshot of the App Check page showing your registered tokens
2. Copy the FULL error message from Xcode console
3. Check if the error still mentions "App attestation failed"
4. Verify the token in the error matches one you registered

---

**Remember:** The fix is simple - just register the two debug tokens in Firebase Console, then restart your app. Everything else is already configured correctly!
