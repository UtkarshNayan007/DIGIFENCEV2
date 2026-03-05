# Implementation Plan: Admin Event Creation and Management Flow

## Overview

Incremental implementation of the DigiFence admin event lifecycle: authentication with role-based routing, event CRUD with polygon geofencing, real-time guest monitoring, user-facing event discovery and ticket purchase, geofence-based activation with biometric verification, and grace period management. Each task builds on the previous, wiring components together progressively. Swift (SwiftUI + MVVM) for the iOS app, JavaScript/TypeScript for Cloud Functions.

## Tasks

- [ ] 1. Core data models and utility modules
  - [x] 1.1 Create Swift data models (Event, Ticket, AppUser, AttendanceLog, ActivationNonce)
    - Define `Codable` structs with `@DocumentID`, `@ServerTimestamp` annotations
    - Include computed properties: `Event.polygonCLCoordinates`, `Event.coordinate` (centroid), `Event.remainingTickets`, `Ticket.isActive/isPending/isExpired`, `Ticket.statusDisplayText/statusColor`
    - Define `GeoPoint_DF` struct with `lat`/`lng` fields
    - Define `UserRole` enum with `admin` and `user` cases
    - _Requirements: 6.1, 8.2, 11.1_

  - [x] 1.2 Implement PolygonMath utility module
    - Implement `isPointInsidePolygon` using ray-casting algorithm
    - Implement `distanceFromPointToSegment` and `distanceFromPointToPolygonEdge`
    - Implement `isPointInActivationZone`
    - Implement `centroid(of:)` for polygon centroid calculation
    - Implement `isPolygonSelfIntersecting` using edge-crossing detection
    - _Requirements: 4.7, 12.2, 13.1_

  - [x] 1.3 Implement Haversine distance utility
    - Implement `distance(from:to:)` returning great-circle distance in meters
    - _Requirements: 12.2, 13.1_

  - [ ] 1.4 Write property test for point-in-polygon correctness
    - **Property 17: Point-in-polygon correctness (ray casting)**
    - Generate random convex polygons; verify centroid returns `true`, far-outside points return `false`
    - **Validates: Requirements 12.2, 13.1**

  - [ ]* 1.5 Write property test for self-intersecting polygon detection
    - **Property 5: Self-intersecting polygon detection**
    - Generate known self-intersecting and simple polygons; verify `isPolygonSelfIntersecting` returns correct result
    - **Validates: Requirements 4.7**

- [ ] 2. Firebase infrastructure and authentication
  - [x] 2.1 Implement FirebaseManager singleton
    - Set up Auth state listener publishing `isLoggedIn` and `currentUser`
    - Expose Firestore collection references (`usersCollection`, `eventsCollection`, `ticketsCollection`, `attendanceLogsCollection`)
    - Implement user document CRUD: `fetchUser(uid:)`, `createUserDocument(uid:email:role:)`
    - Publish `appUser` as `@Published` property
    - _Requirements: 1.1, 1.2, 1.3_

  - [x] 2.2 Implement AuthViewModel with role-based routing
    - Implement `signIn()`, `signUp()`, `signInWithGoogle()`, `signInWithApple()`, `signOut()`
    - On successful auth, fetch user document from Firestore; if missing, call `onFirstLoginAssignRole` Cloud Function
    - Route to `AdminDashboardView` when `role == "admin"`, `MainTabView` when `role == "user"`
    - Manage `isLoading` state for loading indicator during document fetch
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [ ]* 2.3 Write property test for role-based routing correctness
    - **Property 1: Role-based routing correctness**
    - Generate random `UserRole` values; verify admin routes to admin dashboard, user routes to main tab view
    - **Validates: Requirements 1.1, 1.2**

  - [x] 2.4 Implement CloudFunctionsService singleton
    - Create callable wrappers for: `createActivationNonce`, `activateTicket`, `deactivateTicket`, `sendExitWarningNotification`, `onFirstLoginAssignRole`, `revokePublicKey`
    - _Requirements: 1.3, 12.4, 13.1, 13.4_

  - [x] 2.5 Implement FirebaseStorageManager singleton
    - Implement `uploadEventThumbnail(eventId:imageData:)` returning the download URL
    - _Requirements: 6.2_

- [x] 3. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. Admin event creation flow
  - [x] 4.1 Implement AdminViewModel — form state and validation
    - Define `@Published` form fields: `title`, `description`, `polygonPoints`, `capacity`, `ticketPrice`, `invitationURL`, `startsAt`, `endsAt`, `selectedImageItem`, `selectedImageData`
    - Default `startsAt` to current date/time, `endsAt` to 8 hours later
    - Implement `validate()`: reject empty title, capacity < 1, polygon < 3 vertices, self-intersecting polygon; set `errorMessage` accordingly
    - Implement `resetForm()` to restore all fields to defaults
    - _Requirements: 3.1, 3.2, 3.4, 3.5, 3.6, 4.6, 4.7, 6.3_

  - [ ]* 4.2 Write property test for event form validation
    - **Property 2: Event form validation rejects invalid input**
    - Generate invalid inputs (empty titles, bad capacity, few polygon points) and valid inputs; verify `validate()` returns correct result
    - **Validates: Requirements 3.4, 3.5, 4.6**

  - [ ]* 4.3 Write property test for form reset
    - **Property 7: Form reset clears all fields**
    - Generate random form states; verify `resetForm()` restores all defaults
    - **Validates: Requirements 6.3**

  - [x] 4.4 Implement AdminViewModel — polygon drawing operations
    - Implement `addPolygonPoint(_:)` appending coordinate to `polygonPoints`
    - Implement `removeLastPolygonPoint()` removing last element
    - Implement `clearPolygonPoints()` emptying the array
    - _Requirements: 4.2, 4.4, 4.5_

  - [ ]* 4.5 Write property test for polygon add/undo round-trip
    - **Property 3: Polygon point add/undo round-trip**
    - Generate random coordinate arrays and a new coordinate; verify add followed by undo restores original state
    - **Validates: Requirements 4.2, 4.4**

  - [ ]* 4.6 Write property test for polygon clear invariant
    - **Property 4: Polygon clear invariant**
    - Generate random non-empty coordinate arrays; verify `clearPolygonPoints()` results in empty array
    - **Validates: Requirements 4.5**

  - [x] 4.7 Implement AdminViewModel — event creation and publishing
    - Implement `createEvent()`: validate, build event data dictionary with all required fields (`title`, `description`, `polygonCoordinates`, `organizerId`, `capacity`, `ticketsSold: 0`, `ticketPrice`, `invitationURL`, `startsAt`, `endsAt`, `isActive: true`, `createdAt: serverTimestamp`), write to Firestore
    - If thumbnail selected, upload via `FirebaseStorageManager` and update document with `thumbnailURL`
    - On success, show success message and call `resetForm()`
    - On failure, set `errorMessage` with Firestore/network error
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [ ]* 4.8 Write property test for event document fields
    - **Property 6: Event document contains all required fields**
    - Generate valid event inputs; verify constructed data dictionary contains all required fields with correct initial values
    - **Validates: Requirements 6.1**

  - [x] 4.9 Implement AdminViewModel — map search and location
    - Implement `performSearch()` using `MKLocalSearch` to find and center map on searched location
    - Implement `centerOnUserLocation(cameraPosition:)` to center map on admin's current GPS position
    - _Requirements: 4.8, 4.9_

- [ ] 5. Admin event creation views
  - [x] 5.1 Build CreateEventSheet (form UI)
    - SwiftUI form with fields: title (required), description (optional), capacity (stepper/field, min 1), ticket price (optional), invitation URL (optional), start/end date pickers, thumbnail image picker via PhotosUI
    - Wire to AdminViewModel `@Published` properties
    - Display validation error messages from `errorMessage`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [x] 5.2 Build AdminMapView (map with polygon drawing)
    - Embed MapKit map view with tap gesture to add polygon vertices via `addPolygonPoint(_:)`
    - Render polygon overlay connecting all vertices in order as filled shape
    - Add "Undo" button wired to `removeLastPolygonPoint()`
    - Add "Clear" button wired to `clearPolygonPoints()`
    - Add search bar wired to `performSearch()`
    - Add "My Location" button wired to `centerOnUserLocation(cameraPosition:)`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.8, 4.9_

  - [x] 5.3 Build event preview and confirmation flow
    - Display confirmation view showing: title, description, map with polygon overlay, start/end times, capacity
    - Require admin confirmation before writing event to Firestore
    - _Requirements: 5.1, 5.2_

- [x] 6. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 7. Admin dashboard and guest monitoring
  - [x] 7.1 Implement AdminViewModel — real-time event listeners
    - Implement `startListeningToMyEvents()`: Firestore snapshot listener on `events` where `organizerId == currentUID`, ordered by `createdAt` descending; populate `myEvents`
    - Implement `stopListening()`: remove all active listeners
    - _Requirements: 2.1, 2.4_

  - [x] 7.2 Build AdminDashboardView
    - Display list of admin's events with title, description, active/inactive status, ticket stats (active guests, pending guests, inside geofence count)
    - Tap event card navigates to `EventGuestTrackerView`
    - Navigation path to `CreateEventView` for new events
    - Call `startListeningToMyEvents()` on appear, `stopListening()` on disappear
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 7.3 Implement AdminViewModel — ticket listeners and guest tracking
    - Implement `startListeningToTickets(for:)`: Firestore snapshot listener on `tickets` where `eventId` matches; populate `eventTickets`
    - Compute `activeGuestCount`, `pendingCount`, `expiredCount`, `insideFenceCount` from ticket list
    - Implement `stopListeningToTickets(for:)`: remove ticket listener
    - _Requirements: 8.1, 8.2, 8.5_

  - [ ]* 7.4 Write property test for ticket count computation
    - **Property 8: Ticket count computation correctness**
    - Generate random ticket lists; verify count partitioning (active + pending + expired == total, insideFence count correct)
    - **Validates: Requirements 8.2**

  - [x] 7.5 Implement AdminViewModel — event lifecycle toggle
    - Implement `toggleEventActive(event:)`: update `isActive` field on Firestore event document
    - _Requirements: 7.1, 7.2_

  - [x] 7.6 Build EventGuestTrackerView
    - Stats header: active guests, pending guests, expired guests, inside geofence count
    - Capacity progress bar: tickets sold / max capacity
    - Guest list tab: scrollable list of tickets showing owner ID (truncated), status, inside-fence indicator, biometric verified indicator, entry code
    - Activate/deactivate toggle in navigation toolbar
    - _Requirements: 7.2, 8.2, 8.3, 8.4_

  - [x] 7.7 Implement AdminViewModel — attendance log fetching
    - Implement `fetchAttendanceLogs(for:)`: query `attendance_logs` for tickets belonging to event, ordered by timestamp descending, limited to 100
    - _Requirements: 9.1_

  - [ ]* 7.8 Write property test for attendance log ordering
    - **Property 9: Attendance logs are ordered by timestamp descending**
    - Generate random log lists; verify descending timestamp order after sort
    - **Validates: Requirements 9.1**

  - [x] 7.9 Build attendance logs tab in EventGuestTrackerView
    - Display each log with: type (activated/exited/expired), ticket ID (truncated), formatted timestamp
    - Wire to `fetchAttendanceLogs(for:)` on tab selection
    - _Requirements: 9.1, 9.2_

- [x] 8. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. User event discovery and ticket purchase
  - [x] 9.1 Implement EventsViewModel
    - Implement `startListening()`: Firestore listener on `events` where `isActive == true`; populate `events`
    - Implement `stopListening()`: remove listener
    - Implement `filteredEvents(searchText:)` for search functionality
    - _Requirements: 10.1_

  - [x] 9.2 Build EventsListView
    - Display active events with title, description, thumbnail (if available), start time, remaining ticket count
    - Tap navigates to `EventDetailView`
    - Call `startListening()` on appear, `stopListening()` on disappear
    - _Requirements: 10.1, 10.2, 10.3_

  - [x] 9.3 Implement TicketPurchaseService
    - Implement Firestore transaction: read event to verify `ticketsSold < capacity`, create ticket document (`eventId`, `ownerId`, `status: "pending"`, `biometricVerified: false`, `insideFence: false`, `createdAt`), increment `ticketsSold` by 1
    - Reject with "Sold out" if capacity reached
    - On transaction failure, display error and ensure no partial ticket
    - _Requirements: 11.2, 11.3, 11.4, 15.5_

  - [ ]* 9.4 Write property test for ticket purchase capacity invariant
    - **Property 10: Ticket purchase maintains capacity invariant**
    - Generate events with varying capacity/ticketsSold; verify purchase succeeds when under capacity and rejects when at capacity
    - **Validates: Requirements 11.2, 11.3**

  - [x] 9.5 Build EventDetailView
    - Display: title, description, map with polygon geofence overlay, start/end times, ticket price, remaining tickets
    - "Buy Ticket" button wired to `TicketPurchaseService`
    - Show confirmation on success, navigate to ticket view
    - Show "Sold out" when capacity reached
    - _Requirements: 11.1, 11.2, 11.3, 11.5_

- [x] 10. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Geofence monitoring and ticket activation
  - [x] 11.1 Implement BatteryOptimizedLocationManager
    - Debounced location updates with adaptive accuracy based on proximity to polygon edges
    - Publish location updates for `PolygonGeofenceManager` to consume
    - _Requirements: 12.1_

  - [x] 11.2 Implement PolygonGeofenceManager
    - Subscribe to `BatteryOptimizedLocationManager` location updates
    - Evaluate all monitored polygons per update using `PolygonMath.isPointInsidePolygon`
    - Manage hysteresis counters: require 2 consecutive consistent readings for entry/exit
    - On entry (2 consecutive inside): fire `onEnterRegion` callback
    - On exit (2 consecutive outside): fire `onExitRegion` callback, start 3-minute grace timer
    - On re-entry during grace: cancel timer, restore `insideFence`
    - On grace expiry: fire `onGracePeriodExpired` callback
    - Publish `isInsideGeofence`, `distanceToEdge`, `isInActivationZone`
    - _Requirements: 12.1, 12.2, 13.1, 13.2, 13.3, 13.4_

  - [ ]* 11.3 Write property test for geofence hysteresis
    - **Property 11: Geofence state transitions require hysteresis confirmation**
    - Generate sequences of inside/outside readings; verify entry only after 2 consecutive inside, exit only after 2 consecutive outside
    - **Validates: Requirements 12.2, 13.1**

  - [ ]* 11.4 Write property test for grace timer cancellation on re-entry
    - **Property 13: Grace timer cancellation on re-entry**
    - Generate re-entry scenarios during grace period; verify timer cancelled and insideFence restored
    - **Validates: Requirements 13.3**

  - [ ]* 11.5 Write property test for grace timer expiry
    - **Property 14: Grace timer expiry triggers deactivation**
    - Generate timeout scenarios; verify `onGracePeriodExpired` fires and deactivation is triggered
    - **Validates: Requirements 13.4**

  - [x] 11.6 Implement LocationManager orchestration
    - Manage CLLocationManager delegate for permission requests
    - Orchestrate polygon monitoring via `PolygonGeofenceManager`
    - Persist monitored event IDs
    - On enter region: prompt biometric auth (FaceID/TouchID), on success call `createActivationNonce` then sign nonce with `SecureEnclaveManager`, then call `activateTicket`
    - On exit region: call `sendExitWarningNotification` Cloud Function
    - On grace expired: call `deactivateTicket` Cloud Function
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 13.1, 13.4_

  - [x] 11.7 Implement SecureEnclaveManager
    - Generate P-256 key pair in Secure Enclave
    - Implement `sign(data:)` for nonce signing
    - Implement `exportPublicKey()` for server-side verification
    - _Requirements: 12.4_

- [x] 12. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 13. Cloud Functions
  - [x] 13.1 Implement `onFirstLoginAssignRole` Cloud Function
    - Create user document with role based on admin email whitelist
    - _Requirements: 1.3_

  - [x] 13.2 Implement `createActivationNonce` Cloud Function
    - Generate 32-byte random nonce with 60-second TTL
    - Store in `activation_nonces` collection with `ticketId`, `nonce`, `expiresAt`, `used: false`
    - _Requirements: 12.4_

  - [x] 13.3 Implement `activateTicket` Cloud Function
    - Validate nonce (not expired, not used), verify ECDSA signature against stored public key, check user is inside polygon geofence
    - Transition ticket to `active`, set `biometricVerified: true`, `insideFence: true`, generate 6-char alphanumeric entry code, set `activatedAt`
    - Write attendance log with type `"activated"`
    - Mark nonce as used
    - _Requirements: 12.4, 12.5_

  - [ ]* 13.4 Write property test for ticket activation fields
    - **Property 12: Ticket activation sets all required fields**
    - Generate activation responses; verify `status == "active"`, `biometricVerified == true`, `insideFence == true`, `entryCode` is 6 alphanumeric chars, `activatedAt` non-null
    - **Validates: Requirements 12.5**

  - [ ]* 13.5 Write property test for entry code format
    - **Property 18: Entry code generation produces valid codes**
    - Generate entry codes; verify exactly 6 characters from set `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`
    - **Validates: Requirements 12.5**

  - [x] 13.6 Implement `deactivateTicket` Cloud Function
    - Set ticket status to `"expired"`, write attendance log with type `"expired"`
    - _Requirements: 13.4_

  - [x] 13.7 Implement `sendExitWarningNotification` Cloud Function
    - Set `insideFence: false` on ticket, send FCM push notification, write attendance log with type `"exited"`
    - _Requirements: 13.1_

  - [x] 13.8 Implement `handleHysteresis` scheduled Cloud Function
    - Run every 1 minute
    - Expire active tickets with `insideFence == false` whose exit log is ≥ 3 minutes old
    - Close events where `endsAt` has passed: set `isActive: false`, expire all active tickets, write attendance logs with reason `"event_ended"`
    - _Requirements: 13.5, 14.1, 14.2_

  - [ ]* 13.9 Write property test for server-side hysteresis expiry
    - **Property 15: Server-side hysteresis expires stale tickets**
    - Generate ticket sets with varying exit times; verify correct tickets are expired
    - **Validates: Requirements 13.5**

  - [ ]* 13.10 Write property test for event auto-close
    - **Property 16: Event auto-close on end time**
    - Generate events with varying end times; verify events past end time are closed and tickets expired
    - **Validates: Requirements 14.1, 14.2**

- [x] 14. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 15. Firestore security rules and auth routing views
  - [x] 15.1 Implement Firestore security rules
    - `users/{uid}`: read by owner or admin; create by owner with role "user"; update by owner (cannot change role); delete denied
    - `events/{eventId}`: read by any authenticated; create/update/delete by organizer only (organizerId == uid)
    - `tickets/{ticketId}`: read by owner or admin; create by authenticated (ownerId == uid, status "pending", biometric false, insideFence false); update/delete denied (server-only)
    - `activation_nonces`: all client operations denied
    - `attendance_logs`: read by any authenticated; all writes denied (server-only)
    - _Requirements: 15.1, 15.2, 15.3, 15.4_

  - [x] 15.2 Build ContentView with role-based routing
    - Root router: loading state → onboarding → login → admin dashboard or main tab view based on `appUser.role`
    - Wire to `AuthViewModel` and `FirebaseManager.isLoggedIn`
    - _Requirements: 1.1, 1.2_

  - [x] 15.3 Build LoginView
    - Email/password fields, Google sign-in button, Apple sign-in button
    - Display loading indicator while fetching user document
    - Wire to `AuthViewModel`
    - _Requirements: 1.4_

  - [x] 15.4 Build MainTabView for user navigation
    - Tab bar with events list, my pass/ticket, and profile tabs
    - _Requirements: 1.2_

- [ ] 16. Integration wiring and final verification
  - [x] 16.1 Wire navigation flow end-to-end
    - Connect ContentView → LoginView → AdminDashboardView / MainTabView
    - Connect AdminDashboardView → CreateEventView (AdminMapView + CreateEventSheet) → preview → publish
    - Connect AdminDashboardView → EventGuestTrackerView (guest list + logs tabs)
    - Connect MainTabView → EventsListView → EventDetailView → ticket purchase → ticket view
    - _Requirements: 1.1, 1.2, 2.3, 2.5, 10.3, 11.5_

  - [x] 16.2 Wire geofence monitoring to ticket purchase
    - After successful ticket purchase, start polygon geofence monitoring for the event via `LocationManager`
    - _Requirements: 12.1_

  - [x] 16.3 Wire grace period countdown UI
    - Display countdown indicator to user while grace period timer is running
    - _Requirements: 13.2_

  - [ ]* 16.4 Write integration tests
    - End-to-end event creation flow
    - Ticket purchase with capacity verification
    - Activation flow with mocked biometrics and Cloud Functions
    - Grace period flow with simulated geofence exit/re-entry
    - _Requirements: 6.1, 11.2, 12.4, 13.3_

- [x] 17. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests use SwiftCheck for Swift and fast-check for Cloud Functions (JavaScript)
- Checkpoints ensure incremental validation throughout implementation
- All ticket state mutations are server-side only via Cloud Functions
