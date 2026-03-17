# Implementation Checklist

This file turns the current product and implementation audit into a working backlog that can be revisited and updated over time.

Last reviewed: 2026-03-17

## How to use this file

- Treat this as the current implementation checklist for feature-complete product work.
- Update item status as work moves from not started to in progress to done.
- Re-run the audit when major frontend, backend, or admin flows change.
- Use the backend routers as source of truth when a documented frontend flow and implementation disagree.

Status key:

- `[ ]` not started
- `[~]` in progress
- `[x]` completed

## P0

These items are the most important product gaps because they block the core ride marketplace from working end to end.

### 1. Real rider booking flow

- [x] Replace the demo-only `Request Ride` action with a real backend-backed ride request flow.
- [x] Decide whether the user should first browse open rides, or whether route preview should search and then request from matching rides.
- [x] Wire the rider flow to `POST /rides/{ride_id}/request`.
- [~] Show request state clearly after submission: pending, accepted, rejected, cancelled if supported later.

Implementation note:

- Route preview now opens a matching-rides flow instead of jumping directly into a demo ride.
- Riders browse destination-compatible open rides from the route preview, then submit a real join request.
- Pending is shown immediately after submission, and later states are visible in the backend-backed activity/history flow.
- Remaining gap: there is still no dedicated request-status screen or rider-side cancellation action.

References:

- `frontend_flutter/lib/screens/home/ride_directions_screen.dart`
- `frontend_flutter/lib/services/api_service.dart`

### 2. Real driver create-ride flow

- [x] Add a proper create-ride screen or wizard from the driver dashboard.
- [x] Let drivers select one of their backend vehicles before ride creation.
- [x] Wire the flow to `POST /rides/`.
- [x] Confirm the ride appears in driver-owned views after creation.

References:

- `frontend_flutter/lib/screens/driver/driver_dashboard_screen.dart`
- `backend_fastapi/backend/app/routers/rides.py`

### 3. My rides and ride history

- [x] Add backend endpoints for driver-owned rides and user ride history.
- [x] Stop using `GET /rides/` as a catch-all source for history or dashboard data.
- [x] Update the activity/history screen to use a true current-user dataset.
- [x] Add proper states for active, completed, cancelled, and requested rides.

References:

- `frontend_flutter/lib/screens/rides/activity_history_screen.dart`
- `backend_fastapi/backend/app/routers/rides.py`

### 4. Production verification flow

- [x] Wire college email OTP send and verify into the verification UI.
- [x] Wire identity verification submission into the profile verification flow.
- [x] Wire driver licence verification submission and status checks.
- [x] Show current verification status in profile and settings.
- [x] Remove success-only snackbars that do not reflect backend state.

Implementation note:

- `VerificationScreen`, `CollegeVerificationScreen`, and `LicenseVerificationScreen` now call the real verification endpoints and refresh backend status after submit or verify actions.
- College email validation accepts `*@*.christuniversity.in`, matching the backend enforcement.
- Profile and settings now show live verification state from `/users/me` instead of hardcoded verified labels.
- Booking is now blocked server-side and client-side for users without college email verification.
- Vehicle addition and ride creation are now blocked server-side and client-side for users without approved driver verification.
- Remaining gap: there is still no backend vehicle-verification workflow, so “only verified vehicles can be added to rides” is not fully implemented yet and needs separate schema, review, and UI work.

References:

- `frontend_flutter/lib/screens/profile/verification_screen.dart`
- `frontend_flutter/lib/services/rides_api_service.dart`
- `backend_fastapi/backend/app/routers/verification.py`

### 5. Real ride-live state for actual rides

- [x] Use backend tracking data when `rideId` exists.
- [x] Wire driver location updates to `POST /tracking/{ride_id}/location`.
- [x] Wire status transitions to `PUT /rides/{ride_id}/status`.
- [x] Wire pickup verification to `POST /rides/{ride_id}/verify-otp`.
- [x] Keep simulation behavior only for explicit demo mode.

Implementation note:

- `RideLiveScreen` now treats a real `rideId` as the source of truth for ride status, driver location, and rider pickup state.
- Drivers stream location to the tracking endpoint during active ride phases and clear it when the ride ends.
- The screen now uses backend ride statuses for driver start, arrival, pickup confirmation, ongoing travel, and completion.
- Simulation remains available only when `demoMode` is explicitly enabled on the screen.

References:

- `frontend_flutter/lib/screens/home/ride_live_screen.dart`
- `backend_fastapi/backend/app/routers/tracking.py`
- `backend_fastapi/backend/app/routers/rides.py`

## P1

These items improve trust, safety, and data consistency once the core ride flow is working.

### 6. Backend-backed profile and vehicles

- [ ] Load profile data from `/users/me` in the main profile screen.
- [ ] Persist profile edits through `PUT /users/me`.
- [ ] Replace local vehicle-only state with `/vehicles/` CRUD-backed state.
- [ ] Align vehicle UI fields with the current backend schema or extend the backend schema intentionally.

References:

- `frontend_flutter/lib/screens/profile/user_profile.dart`
- `frontend_flutter/lib/services/api_service.dart`
- `backend_fastapi/backend/app/routers/users.py`
- `backend_fastapi/backend/app/routers/vehicles.py`

### 7. Saved addresses

- [ ] Decide whether saved places should live in backend persistence or remain local-only by product choice.
- [ ] If backend-backed, implement real address CRUD beyond the current placeholder.
- [ ] Connect the preferences and location-search flows to the same saved-address source.

References:

- `frontend_flutter/lib/screens/settings/preferences_screen.dart`
- `frontend_flutter/lib/screens/home/location_search_screen.dart`
- `backend_fastapi/backend/app/routers/addresses.py`

### 8. Safety center and reporting

- [ ] Turn “Safety Center” into a real screen.
- [ ] Wire emergency contacts CRUD into the app.
- [ ] Wire reporting flow for riders and drivers using `/reports/`.
- [ ] Make SOS history and emergency actions visible in the user-facing product.

References:

- `frontend_flutter/lib/screens/settings/settings_screen.dart`
- `frontend_flutter/lib/services/api_service.dart`
- `backend_fastapi/backend/app/routers/emergency_contacts.py`
- `backend_fastapi/backend/app/routers/reports.py`
- `backend_fastapi/backend/app/routers/sos.py`

### 9. Post-ride ratings in the real lifecycle

- [ ] Trigger the rating screen only from completed rides.
- [ ] Make sure the user can rate the right counterparty for the ride.
- [ ] Show rating history or summary where it helps trust decisions.

References:

- `frontend_flutter/lib/screens/rides/rate_ride_screen.dart`
- `frontend_flutter/lib/services/api_service.dart`
- `backend_fastapi/backend/app/routers/ratings.py`

### 10. Admin SOS resolution

- [ ] Add backend support for resolving or closing SOS alerts.
- [ ] Add an admin action in the web dashboard for triaging SOS alerts.
- [ ] Distinguish open versus resolved alerts in dashboard stats and tables.

References:

- `admin-web/app.js`
- `backend_fastapi/backend/app/routers/admin.py`
- `documentation/api-endpoints.md`

## P2

These items are lower risk but help with maintainability, operational readiness, and product clarity.

### 11. Admin detail and operations polish

- [ ] Use the existing admin user detail endpoint in the web UI.
- [ ] Add deeper inspection actions for support and moderation workflows.
- [ ] Replace hardcoded localhost assumptions with environment-based configuration.

References:

- `admin-web/app.js`
- `backend_fastapi/backend/app/routers/admin.py`

### 12. Canonical screens only

- [x] Decide which history and ride-detail screens are canonical.
- [x] Mark legacy or mock screens clearly in code and docs, or remove them.
- [x] Keep one primary verification flow; history is now consolidated to `ActivityHistoryScreen`, and verification is consolidated to `VerificationScreen`.

References:

- `documentation/frontend-pages.md`
- `frontend_flutter/lib/screens/activity/ride_history_screen.dart`
- `frontend_flutter/lib/screens/activity/ride_details_screen.dart`

### 13. API layer cleanup

- [ ] Consolidate overlapping Flutter service layers.
- [ ] Remove wrappers whose payloads drift from the backend contract.
- [ ] Keep one clear source of truth for mobile API usage.

References:

- `frontend_flutter/lib/services/api_service.dart`
- `frontend_flutter/lib/services/rides_api_service.dart`

## Suggested delivery order

1. Real ride marketplace flow: create, discover, request, accept, track, complete.
2. Verification and trust: student verification, identity review, driver verification.
3. Safety and support: emergency contacts, reporting, SOS center, admin resolve.
4. Data consistency: profile, vehicles, addresses, history.
5. Platform cleanup: admin config, API service consolidation, legacy-screen cleanup.

## Audit notes snapshot

The current audit found that the repository already contains most of the documented screens and backend endpoints, but several high-value product flows are still partial:

- rider booking is still mostly prototype-driven
- driver ride creation is not surfaced as a real in-app workflow
- verification is now largely backend-backed for email, identity, and driver licence flows
- history uses the wrong backend source
- live tracking still leans heavily on simulation
- profile, vehicles, and saved addresses are still not consistently persisted
- support and safety surfaces exist in UI but are not fully wired end to end

This file should be updated whenever those conclusions change.
