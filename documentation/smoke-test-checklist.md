# Smoke Test Checklist

Last reviewed: 2026-03-19

This checklist is for high-signal manual verification after major app changes.

## Preconditions

- Backend server is running with the latest migrations applied.
- Flutter app is pointed at the intended backend environment.
- At least 3 test accounts exist:
  - unverified student
  - email-and-identity-verified rider
  - driver-verified user with at least one backend vehicle
- At least one active ride can be created for rider/driver interaction tests.
- Location permission, camera access, and image picking work on the test device.

## 1. Auth and app entry

- Launch the app logged out and verify the auth screen renders without layout overflow on a small device.
- Switch between `Log In` and `Sign Up` tabs and confirm the primary CTA changes correctly.
- Send login OTP for an existing user and verify successful login.
- Send signup OTP for a new user and verify the user can continue to registration.
- Complete registration and confirm the app lands on the authenticated home flow.
- Log out and confirm tokens are cleared and auth screen returns.

## 2. Rider marketplace flow

- Open location search, set a pickup and destination, and confirm route preview loads.
- From route preview, open the available rides list and confirm only open rides are shown.
- Send a ride request and verify a pending confirmation is shown.
- Open activity/history and confirm the new request appears under `Requested`.
- As the driver, accept the request and verify the rider now sees the ride in the appropriate state.

## 3. Driver ride flow

- Open the driver dashboard and confirm driver-owned rides load from `GET /rides/mine`.
- Create a ride using a backend vehicle and verify it appears in the driver dashboard immediately.
- Open ride requests for that ride and verify pending requests load.
- Accept and reject sample requests and confirm the UI refreshes correctly.

## 4. Live ride flow

- Start a real ride as the driver and confirm ride status updates from the live screen.
- Verify driver location updates are reflected through backend tracking.
- Confirm rider live view loads tracking data when `rideId` exists.
- Verify pickup OTP works and updates the ride/participant state.
- Complete the ride and confirm both rider and driver see the ride as completed in history.

## 5. Verification and trust

- Open verification center as an unverified user and confirm current statuses load from backend.
- Send college email OTP using a valid Christ email and verify success.
- Submit identity verification and confirm status changes to submitted.
- Submit driver verification after identity approval and confirm status changes to submitted.
- Verify booking is blocked for users without verified college email.
- Verify vehicle add and ride creation are blocked for users without driver approval.

## 6. Profile, vehicles, and addresses

- Open profile and confirm `/users/me` data loads.
- Edit profile fields and confirm changes persist after refresh.
- Add, edit, and delete a vehicle and confirm the backend-backed list updates.
- Add, edit, and delete saved addresses from preferences and confirm they appear in location search.

## 7. Safety and support

- Open Safety Center and confirm emergency contacts, SOS history, and report history load.
- Add and delete an emergency contact.
- Trigger SOS from an active ride and confirm it appears in user SOS history.
- Report a driver as a rider and report a rider as a driver.
- Confirm reports appear in the user-facing report history.

## 8. Ratings and history

- Complete a ride as a rider and confirm `Rate Driver` appears only on the completed history card.
- Complete a ride as a driver and confirm `Rate Rider` opens confirmed rider selection.
- Submit a rating and confirm duplicate submission is blocked.
- Confirm trust summary appears on the rating screen.

## 9. Admin console

- Log in as an admin via phone OTP.
- Verify dashboard stats load, including SOS open/resolved/closed counts.
- Open the user drawer from the users table and inspect verification/activity context.
- Open the same user drawer from verification review and SOS desk.
- Open the SOS desk, filter incidents by status, and inspect incident detail.
- Resolve and close SOS alerts with notes and verify stats and tables update.

## 10. Regression checks

- Confirm the app still launches on logged-out and logged-in paths.
- Confirm no screen still depends on the removed `rides_api_service.dart`.
- Re-run `flutter analyze`, `flutter test`, and any integration tests after major changes.
