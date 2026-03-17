# Frontend Pages

This file maps the user-facing screens and admin UI surfaces that currently exist in the repository.

## Flutter app page map

## App entry and auth

### `AuthScreen`

File: `frontend_flutter/lib/screens/auth/login.dart`

Purpose:

- entrypoint for unauthenticated users
- toggles between login and sign-up
- sends phone OTP
- routes user into OTP verification, personal details, and optional driver onboarding

Navigation:

- to `OtpVerificationScreen`
- to `PersonalDetailsScreen`
- to `DriverDetailsScreen`
- to `HomeScreen` after successful auth

### `OtpVerificationScreen`

File: `frontend_flutter/lib/screens/auth/otp_verification.dart`

Purpose:

- handles 6-digit OTP entry
- supports resend countdown
- calls signup OTP verify or login OTP verify depending on flow

Notes:

- API-backed
- auto-submits when all digits are entered

### `PersonalDetailsScreen`

File: `frontend_flutter/lib/screens/auth/personal_details.dart`

Purpose:

- collects basic rider profile data during signup
- completes `/auth/register`

Collected UI fields:

- full name
- optional email
- optional address
- gender
- date of birth

Important note:

- only some of these fields are actually sent to the backend during registration
- date of birth and address are currently UI-only in this screen

### `DriverDetailsScreen`

File: `frontend_flutter/lib/screens/auth/driver_details.dart`

Purpose:

- optional onboarding step to become a driver
- collects vehicle model, license plate, and document uploads

Important note:

- mostly mock/prototype
- document selection is simulated
- save action is not wired to backend driver profile or verification APIs yet

## Rider journey pages

### `HomeScreen`

File: `frontend_flutter/lib/screens/home/home_screen.dart`

Purpose:

- authenticated landing page
- shows quick destinations
- shows current location on map
- primary CTA to find a UniPool ride
- top-level navigation into profile, driver dashboard, activity, and settings

Key UI sections:

- search bar
- profile avatar entry
- quick destination chips
- map preview
- UniPool feature card
- bottom navigation

### `LocationSearchScreen`

File: `frontend_flutter/lib/screens/home/location_search_screen.dart`

Purpose:

- collects pickup location and destination campus
- supports:
  - current GPS location
  - saved address
  - forward geocoded address search
  - pin-drop selection

Destination model:

- currently limited to predefined Christ University campuses

### `PinDropScreen`

File: `frontend_flutter/lib/screens/home/pin_drop_screen.dart`

Purpose:

- full-screen map for manually setting exact pickup point
- reverse geocodes selected point
- returns lat/lng/address back to the caller

### `RideDirectionsScreen`

File: `frontend_flutter/lib/screens/home/ride_directions_screen.dart`

Purpose:

- route preview between pickup and destination
- displays:
  - route polyline
  - estimated distance
  - estimated duration
  - estimated fare
- primary CTA: find matching rides for the selected route

Integrations:

- `RoutingService` for OSRM route
- `FareApiService` for fare estimate

### `AvailableRidesScreen`

File: `frontend_flutter/lib/screens/home/available_rides_screen.dart`

Purpose:

- lists destination-compatible open rides after route preview
- lets riders review ride options before sending a join request

Integrations:

- `GET /rides/`
- `POST /rides/{ride_id}/request`

### `RideLiveScreen`

File: `frontend_flutter/lib/screens/home/ride_live_screen.dart`

Purpose:

- live in-ride experience
- shows driver progress, pickup flow, OTP verification, and destination progress
- includes SOS action
- uses backend ride and tracking state for real rides

Important note:

- when `rideId` exists, the screen polls backend tracking data, updates driver
  location, updates ride status, and verifies pickup OTPs against the backend
- real rides no longer rely on the older client-side simulated OTP/live-state
  path
- simulation remains available only when `demoMode` is explicitly enabled

## Driver pages

### `DriverDashboardScreen`

File: `frontend_flutter/lib/screens/driver/driver_dashboard_screen.dart`

Purpose:

- driver-facing summary screen
- shows driver profile summary and rides list
- entrypoint to create rides and inspect ride requests

Current backend usage:

- fetches current driver profile
- fetches rides using the dedicated driver-owned rides endpoint

### `CreateRideScreen`

File: `frontend_flutter/lib/screens/driver/create_ride_screen.dart`

Purpose:

- create a new ride from the driver dashboard
- select one of the driver’s backend vehicles
- configure route, timing, seats, and rider restrictions

Integrations:

- `GET /vehicles/`
- `GET /users/me`
- `GET /fare/estimate`
- `POST /rides/`

### `RideRequestsScreen`

File: `frontend_flutter/lib/screens/driver/ride_requests_screen.dart`

Purpose:

- review pending passenger join requests
- approve/reject requests
- view confirmed passengers and their pickup state/OTP

Integrations:

- `GET /rides/{ride_id}/requests`
- `GET /rides/{ride_id}/participants`
- `PUT /rides/{ride_id}/requests/{request_id}`

## Profile and verification pages

### `UserProfileScreen`

File: `frontend_flutter/lib/screens/profile/user_profile.dart`

Purpose:

- profile hub
- shows avatar, basic account data, vehicles, and danger-zone actions

Current data sources:

- name/phone/email and verification flags from `/users/me` when available
- local fallback from `SharedPreferences` if the backend profile request fails
- vehicles are mostly local page state

Important note:

- the profile vehicle management UI is richer than the backend vehicle schema and is not fully synced to backend persistence
- opening the vehicle form is now locked until driver verification is approved

### `EditProfileScreen`

File: `frontend_flutter/lib/screens/profile/user_profile.dart`

Purpose:

- modal-style edit screen for account details

Important note:

- updates are mostly fed back to local UI state unless separately wired to backend elsewhere

### `AddVehicleScreen`

File: `frontend_flutter/lib/screens/profile/user_profile.dart`

Purpose:

- add/edit vehicle data from profile flow

Important note:

- currently behaves as local UI form state rather than a strict wrapper around `/vehicles/`

### `VerificationScreen`

File: `frontend_flutter/lib/screens/profile/verification_screen.dart`

Purpose:

- verification landing screen
- shows current email, identity, and driver verification state
- branches to student/college verification or driver licence verification

### `CollegeVerificationScreen`

File: `frontend_flutter/lib/screens/profile/verification_screen.dart`

Purpose:

- send OTP to a Christ University email address
- verify the email OTP
- submit college ID details and document image for review

Important note:

- uses `POST /verification/email/send-otp`
- uses `POST /verification/email/verify-otp`
- uses `POST /verification/identity/submit`
- uses `GET /verification/identity/status`
- accepts `*@*.christuniversity.in`

### `LicenseVerificationScreen`

File: `frontend_flutter/lib/screens/profile/verification_screen.dart`

Purpose:

- submit driving licence information and image
- show current driver verification review state and reviewer notes

Important note:

- uses `POST /verification/driver/submit`
- uses `GET /verification/driver/status`
- is locked until identity verification has been approved

## Activity and history pages

### `ActivityHistoryScreen`

File: `frontend_flutter/lib/screens/rides/activity_history_screen.dart`

Purpose:

- tabbed activity page for active vs past rides

Important note:

- now backed by a current-user history endpoint instead of the generic open-rides list
- supports active, requested, completed, and cancelled states across driver and rider roles

### `RideHistoryScreen`

File: `frontend_flutter/lib/screens/activity/ride_history_screen.dart`

Purpose:

- compatibility wrapper for older navigation paths that still reference the
  legacy history route

Status:

- delegates to `ActivityHistoryScreen` so the app uses one canonical
  backend-backed history flow

### `RideDetailsScreen`

File: `frontend_flutter/lib/screens/activity/ride_details_screen.dart`

Purpose:

- static or mock ride detail presentation with map placeholder, route timeline, vehicle/driver, and rating summary

Status:

- demo/mock screen

### `RateRideScreen`

File: `frontend_flutter/lib/screens/rides/rate_ride_screen.dart`

Purpose:

- post-ride rating submission UI

Observed role:

- intended to plug into ratings flow after ride completion

## Settings and preferences pages

### `SettingsScreen`

File: `frontend_flutter/lib/screens/settings/settings_screen.dart`

Purpose:

- settings hub
- shows profile summary, rider/driver mode toggle, activity shortcuts, preferences, safety/support options

Important note:

- this screen mixes real profile/rating calls with prototype navigation blocks and placeholder support actions

### `PreferencesScreen`

File: `frontend_flutter/lib/screens/settings/preferences_screen.dart`

Purpose:

- manage theme, notification permissions, location sharing, and saved places

Integrations:

- app theme notifier
- `permission_handler`

Important note:

- saved places here are UI-managed and not backed by the backend `saved_addresses` table yet

## Admin web UI map

## Auth page

### Login surface

Files:

- `admin-web/index.html`
- `admin-web/app.js`

Purpose:

- admin phone number entry
- OTP verification
- admin-access check after login

API usage:

- `/auth/login/send-otp`
- `/auth/login/verify-otp`
- `/users/me`

## Main dashboard surfaces

### Dashboard section

Purpose:

- stats cards for users, verifications, rides, and SOS

API usage:

- `/admin/stats`

### Users section

Purpose:

- search users
- view verification/activation state
- activate/deactivate accounts

API usage:

- `/admin/users`
- `/admin/users/{user_id}/activate`
- `/admin/users/{user_id}/deactivate`

### Verifications section

Purpose:

- review pending identity and driver verification requests
- approve or reject with optional notes

API usage:

- `/admin/verifications/identity/pending`
- `/admin/verifications/identity/{user_id}/approve`
- `/admin/verifications/identity/{user_id}/reject`
- `/admin/verifications/driver/pending`
- `/admin/verifications/driver/{user_id}/approve`
- `/admin/verifications/driver/{user_id}/reject`

### SOS section

Purpose:

- table of active SOS alerts
- map links to reported coordinates

API usage:

- `/admin/sos/active`

## Frontend implementation notes for future work

- There is a clear split between production-intent pages and prototype/demo pages.
- Profile vehicle management still needs backend alignment if it is meant to become a canonical product flow.
- The admin UI is functional but intentionally simple and hardcoded to localhost unless changed manually.
- History navigation is now consolidated to the backend-backed
  `ActivityHistoryScreen`.
