# Requirements Document

## Introduction

This document defines the requirements for the Admin Event Creation and Management flow in the DigiFence iOS application. The feature enables administrators to create geofence-bounded events, manage event lifecycles, and monitor real-time attendance. Users discover active events, purchase tickets, and activate passes through geofence entry combined with biometric verification. The system uses polygon-based geofencing, Firebase Authentication, Firestore, and Cloud Functions to deliver a secure, production-ready event pipeline.

## Glossary

- **Admin**: An authenticated user whose Firestore `users/{uid}` document has `role == "admin"`.
- **User**: An authenticated user whose Firestore `users/{uid}` document has `role == "user"`.
- **Event**: A Firestore document in `events/{eventId}` representing a geofence-bounded gathering with title, polygon coordinates, capacity, schedule, and lifecycle status.
- **Ticket**: A Firestore document in `tickets/{ticketId}` representing a user's pass to an event, with status lifecycle: `pending` → `active` → `expired`.
- **Geofence**: A polygon-based geographic boundary defined by an array of latitude/longitude coordinate vertices stored in the Event document.
- **AdminDashboardView**: The SwiftUI screen displaying the admin's events, real-time guest tracking, and management controls.
- **CreateEventView**: The SwiftUI screen where an admin inputs event details, draws a polygon geofence on a map, and publishes the event.
- **EventsListView**: The SwiftUI screen where users browse active events available for ticket purchase.
- **EventDetailView**: The SwiftUI screen displaying full event information and a ticket purchase action.
- **AdminViewModel**: The MVVM view model responsible for admin event CRUD, dashboard data, and real-time ticket listeners.
- **AuthViewModel**: The MVVM view model responsible for authentication state and role-based navigation.
- **EventsViewModel**: The MVVM view model responsible for fetching and presenting active events to users.
- **TicketPurchaseService**: A service class that handles atomic ticket creation and event counter updates via Firestore transactions.
- **LocationManager**: The singleton service managing CoreLocation permissions, polygon geofence monitoring, and grace timers.
- **CloudFunctionsService**: The service wrapper for Firebase Cloud Functions callable endpoints.
- **FirebaseManager**: The singleton managing Firestore references, Auth state, and user document CRUD.
- **Grace_Period**: A 3-minute countdown that begins when a user exits the geofence; if the user does not re-enter before expiry, the ticket is deactivated.
- **Activation**: The process of transitioning a ticket from `pending` to `active` via geofence entry, biometric verification, and server-side nonce validation.
- **Attendance_Log**: A Firestore document in `attendance_logs/{logId}` recording entry, exit, and activation events for audit purposes.

## Requirements

### Requirement 1: Admin Authentication and Role-Based Routing

**User Story:** As an admin, I want to log in and be routed to the admin dashboard based on my role, so that I can access event management features.

#### Acceptance Criteria

1. WHEN an authenticated user's Firestore document contains `role == "admin"`, THE AuthViewModel SHALL navigate the user to AdminDashboardView.
2. WHEN an authenticated user's Firestore document contains `role == "user"`, THE AuthViewModel SHALL navigate the user to the standard user interface (MainTabView).
3. IF the Firestore user document does not exist for the authenticated user, THEN THE AuthViewModel SHALL call the `onFirstLoginAssignRole` Cloud Function to create the document and assign the appropriate role.
4. WHILE the AuthViewModel is fetching the user document, THE LoginView SHALL display a loading indicator.

### Requirement 2: Admin Dashboard

**User Story:** As an admin, I want a dashboard that shows all my events with real-time attendance data, so that I can monitor and manage events effectively.

#### Acceptance Criteria

1. WHEN AdminDashboardView appears, THE AdminViewModel SHALL start a real-time Firestore listener on `events` where `organizerId` matches the current admin's UID, ordered by `createdAt` descending.
2. THE AdminDashboardView SHALL display each event with its title, description, active/inactive status, and ticket statistics (active guests, pending guests, guests inside geofence).
3. WHEN the admin taps an event card, THE AdminDashboardView SHALL navigate to EventGuestTrackerView showing detailed guest list and attendance logs for that event.
4. WHEN AdminDashboardView disappears, THE AdminViewModel SHALL remove all active Firestore listeners to prevent memory leaks.
5. THE AdminDashboardView SHALL provide a navigation path to CreateEventView for creating new events.

### Requirement 3: Event Creation Form

**User Story:** As an admin, I want to fill in event details including title, description, schedule, and capacity, so that I can define the event parameters before publishing.

#### Acceptance Criteria

1. THE CreateEventView SHALL provide input fields for: event title (required), event description (optional), start date/time, end date/time, and maximum ticket capacity (minimum value of 1).
2. THE CreateEventView SHALL provide an optional ticket price field and an optional invitation URL field.
3. THE CreateEventView SHALL provide an optional thumbnail image picker using PhotosUI.
4. IF the admin submits the form with an empty event title, THEN THE AdminViewModel SHALL display a validation error message "Event title is required."
5. IF the admin submits the form with a capacity less than 1, THEN THE AdminViewModel SHALL display a validation error message "Capacity must be at least 1."
6. THE CreateEventView SHALL default the start time to the current date/time and the end time to 8 hours after the current date/time.

### Requirement 4: Map-Based Polygon Geofence Drawing

**User Story:** As an admin, I want to draw a polygon geofence on a map by tapping points, so that I can define the event boundary precisely.

#### Acceptance Criteria

1. THE CreateEventView SHALL embed a MapKit map view that allows the admin to tap locations to add polygon vertices.
2. WHEN the admin taps on the map, THE AdminViewModel SHALL append the tapped coordinate to the `polygonPoints` array and display the updated polygon overlay on the map.
3. THE CreateEventView SHALL display the polygon as a filled overlay connecting all placed vertices in order.
4. THE CreateEventView SHALL provide an "Undo" control that removes the last placed polygon vertex.
5. THE CreateEventView SHALL provide a "Clear" control that removes all polygon vertices.
6. IF the admin submits the form with fewer than 3 polygon vertices, THEN THE AdminViewModel SHALL display a validation error message "Polygon geofence requires at least 3 points."
7. IF the polygon is self-intersecting, THEN THE AdminViewModel SHALL indicate the polygon is invalid and prevent submission.
8. THE CreateEventView SHALL provide a location search bar that uses MKLocalSearch to find and center the map on a searched location.
9. THE CreateEventView SHALL provide a "My Location" button that centers the map on the admin's current GPS position.

### Requirement 5: Event Preview and Confirmation

**User Story:** As an admin, I want to preview all event details including the geofence boundary before publishing, so that I can verify correctness.

#### Acceptance Criteria

1. WHEN the admin completes the event form and taps a "Preview" or "Create" action, THE CreateEventView SHALL display a confirmation showing: event title, description, map with polygon overlay, start time, end time, and ticket capacity.
2. THE CreateEventView SHALL require the admin to confirm before the event document is written to Firestore.

### Requirement 6: Event Publishing

**User Story:** As an admin, I want to publish an event so that it becomes visible to users and available for ticket purchases.

#### Acceptance Criteria

1. WHEN the admin confirms event creation, THE AdminViewModel SHALL create a Firestore document in `events/{eventId}` with fields: title, description, polygonCoordinates (array of {lat, lng}), organizerId (current admin UID), capacity, ticketsSold (initialized to 0), ticketPrice (if provided), invitationURL (if provided), startsAt, endsAt, isActive (set to true), and createdAt (server timestamp).
2. IF the admin selected a thumbnail image, THEN THE AdminViewModel SHALL upload the image to Firebase Storage and update the event document with the resulting `thumbnailURL`.
3. WHEN event creation succeeds, THE AdminViewModel SHALL display a success message and reset the form fields to default values.
4. IF event creation fails due to a network or Firestore error, THEN THE AdminViewModel SHALL display the error message to the admin.

### Requirement 7: Event Lifecycle Management

**User Story:** As an admin, I want to activate or deactivate my events, so that I can control event visibility and ticket availability.

#### Acceptance Criteria

1. WHEN the admin taps the activate/deactivate toggle for an event, THE AdminViewModel SHALL update the `isActive` field of the corresponding Firestore event document.
2. THE EventGuestTrackerView SHALL display the current active/inactive status of the event and provide the toggle control in the navigation toolbar.

### Requirement 8: Real-Time Guest Monitoring

**User Story:** As an admin, I want to see real-time guest counts and individual ticket statuses for my events, so that I can monitor attendance as it happens.

#### Acceptance Criteria

1. WHEN EventGuestTrackerView appears for an event, THE AdminViewModel SHALL start a real-time Firestore listener on `tickets` where `eventId` matches the selected event.
2. THE EventGuestTrackerView SHALL display computed counts for: active guests, pending guests, expired guests, and guests currently inside the geofence.
3. THE EventGuestTrackerView SHALL display a capacity progress bar showing tickets sold relative to maximum capacity.
4. THE EventGuestTrackerView SHALL display a scrollable list of individual tickets showing: owner ID (truncated), ticket status, inside-fence indicator, biometric verification indicator, and entry code (if assigned).
5. WHEN EventGuestTrackerView disappears, THE AdminViewModel SHALL remove the ticket listener for that event.

### Requirement 9: Attendance Log Viewing

**User Story:** As an admin, I want to view attendance logs for my events, so that I can audit entry, exit, and activation activity.

#### Acceptance Criteria

1. WHEN the admin selects the "Logs" tab in EventGuestTrackerView, THE AdminViewModel SHALL fetch attendance logs from `attendance_logs` collection for all tickets belonging to the selected event, ordered by timestamp descending, limited to 100 entries.
2. THE EventGuestTrackerView SHALL display each log entry with: log type (activated, exited, expired), associated ticket ID (truncated), and formatted timestamp.

### Requirement 10: User Event Discovery

**User Story:** As a user, I want to browse a list of active events, so that I can find events to attend.

#### Acceptance Criteria

1. WHEN EventsListView appears, THE EventsViewModel SHALL query Firestore for events where `isActive == true`.
2. THE EventsListView SHALL display each active event with its title, description, thumbnail (if available), start time, and remaining ticket count.
3. WHEN the user taps an event, THE EventsListView SHALL navigate to EventDetailView for the selected event.

### Requirement 11: Event Detail and Ticket Purchase

**User Story:** As a user, I want to view full event details and purchase a ticket, so that I can attend the event.

#### Acceptance Criteria

1. THE EventDetailView SHALL display: event title, description, map showing the polygon geofence boundary, start time, end time, ticket price (if applicable), and remaining ticket count.
2. WHEN the user taps "Buy Ticket", THE TicketPurchaseService SHALL execute a Firestore transaction that: (a) reads the event document to verify remaining capacity, (b) creates a new `tickets/{ticketId}` document with `eventId`, `ownerId` (current user UID), `status: "pending"`, `biometricVerified: false`, `insideFence: false`, and `createdAt` (server timestamp), and (c) increments the event's `ticketsSold` field by 1.
3. IF the event has reached maximum capacity (ticketsSold >= capacity), THEN THE TicketPurchaseService SHALL reject the purchase and display a "Sold out" message.
4. IF the Firestore transaction fails, THEN THE TicketPurchaseService SHALL display the error to the user and not create a partial ticket.
5. WHEN ticket purchase succeeds, THE EventDetailView SHALL display a confirmation and navigate the user to their ticket view.

### Requirement 12: Geofence Entry Detection and Ticket Activation

**User Story:** As a user, I want my ticket to activate automatically when I enter the event geofence and complete biometric verification, so that I can gain entry seamlessly.

#### Acceptance Criteria

1. WHEN the user purchases a ticket, THE LocationManager SHALL begin polygon geofence monitoring for the associated event using CoreLocation significant location changes.
2. WHEN the LocationManager detects the user has entered the event polygon geofence (confirmed by 2 consecutive inside readings for hysteresis), THE LocationManager SHALL trigger the `onEnterRegion` callback.
3. WHEN the enter-region callback fires, THE app SHALL prompt the user for FaceID/TouchID biometric authentication.
4. WHEN biometric authentication succeeds, THE app SHALL call `createActivationNonce` Cloud Function, sign the returned nonce using the Secure Enclave private key, and call `activateTicket` Cloud Function with the ticket ID, nonce ID, signature, and current GPS coordinates.
5. WHEN the `activateTicket` Cloud Function succeeds, THE ticket status SHALL transition to `active` with `biometricVerified: true`, `insideFence: true`, an assigned `entryCode`, and an `activatedAt` timestamp.
6. IF biometric authentication fails, THEN THE app SHALL display an error and not proceed with activation.
7. IF the `activateTicket` Cloud Function rejects the request (expired nonce, invalid signature, outside geofence), THEN THE app SHALL display the server error message to the user.

### Requirement 13: Geofence Exit Detection and Grace Period

**User Story:** As a user, I want a 3-minute grace period when I leave the event geofence, so that brief exits do not deactivate my ticket.

#### Acceptance Criteria

1. WHEN the LocationManager detects the user has exited the event polygon geofence (confirmed by 2 consecutive outside readings for hysteresis), THE LocationManager SHALL call the `sendExitWarningNotification` Cloud Function and start a 3-minute Grace_Period timer.
2. WHILE the Grace_Period timer is running, THE app SHALL display a countdown indicator to the user.
3. WHEN the user re-enters the geofence before the Grace_Period expires, THE LocationManager SHALL cancel the Grace_Period timer and restore the `insideFence` status.
4. WHEN the Grace_Period timer expires without the user re-entering, THE LocationManager SHALL call the `deactivateTicket` Cloud Function to set the ticket status to `expired`.
5. THE `handleHysteresis` scheduled Cloud Function SHALL run every minute and expire any active tickets that have been outside the geofence for 3 or more minutes, as a server-side safety net.

### Requirement 14: Event End Automation

**User Story:** As a platform operator, I want events to close automatically after their end time, so that expired events do not remain active.

#### Acceptance Criteria

1. THE `handleHysteresis` scheduled Cloud Function SHALL check for events where `endTime` has passed and set their `status` to closed (or `isActive` to false) and expire all associated active tickets.
2. WHEN an event is automatically closed, THE Cloud Function SHALL write an Attendance_Log entry for each expired ticket with reason "event_ended".

### Requirement 15: Security Enforcement

**User Story:** As a platform operator, I want strict security rules so that only authorized actions are permitted at each layer.

#### Acceptance Criteria

1. THE Firestore security rules SHALL allow only authenticated users whose document has `role == "admin"` to create, update, and delete event documents, with the constraint that `organizerId` matches the requesting user's UID.
2. THE Firestore security rules SHALL allow authenticated users to create ticket documents only with `ownerId` matching their UID, `status == "pending"`, `biometricVerified == false`, and `insideFence == false`.
3. THE Firestore security rules SHALL deny all client-side updates to ticket documents; only Cloud Functions using the Admin SDK SHALL modify ticket status, biometricVerified, insideFence, activatedAt, and entryCode fields.
4. THE Firestore security rules SHALL deny all client-side writes to `attendance_logs` and `activation_nonces` collections.
5. THE TicketPurchaseService SHALL use Firestore transactions to prevent race conditions when multiple users purchase tickets for the same event simultaneously.
