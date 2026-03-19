# API Endpoints

Last reviewed: 2026-03-19

Base app: FastAPI in `backend_fastapi/backend/app/main.py`

Public utility endpoints:

- `GET /`
  Health-style root response with app name and version.
- `GET /health`
  Load balancer / uptime check.

## Authentication

### Registration

- `POST /auth/phone/send-otp`
  Send OTP to an unregistered Indian phone number.
  Input: `phone`
  Output: `session_token`, `expires_at`, message
  Notes: rate-limited, cooldown enforced, rejects already-registered phone numbers.

- `POST /auth/phone/verify-otp`
  Verify signup OTP.
  Input: `session_token`, `otp`
  Output: `phone_verified_token`, `phone`

- `POST /auth/register`
  Complete registration after phone verification.
  Input: `phone_verified_token`, `full_name`, `gender`, optional `community`
  Output: `access_token`, `refresh_token`, `user`

### Login

- `POST /auth/login/send-otp`
  Send login OTP to registered phone number.
  Input: `phone`
  Output: `session_token`, `expires_at`

- `POST /auth/login/verify-otp`
  Verify login OTP and issue tokens.
  Input: `session_token`, `otp`
  Output: `access_token`, `refresh_token`, `user`

### Session management

- `POST /auth/refresh`
  Rotate refresh token and issue a new access token.
  Input: `refresh_token`
  Output: `access_token`, `refresh_token`

- `POST /auth/logout`
  Revoke refresh token.
  Input: `refresh_token`
  Output: success message

## Users

Auth: bearer token required

- `GET /users/me`
  Returns the current authenticated user profile.

- `PUT /users/me`
  Updates selected profile fields.
  Supported fields:
  - `full_name`
  - `community`
  - `profile_photo_url`
  - `gender`

## Vehicles

Auth: bearer token required

- `GET /vehicles/`
  List vehicles owned by the current user.

- `POST /vehicles/`
  Add a vehicle.
  Input:
  - `vehicle_type`
  - `vehicle_number`
  Notes: backend stores only type and number, and the main profile vehicle form is now aligned to those fields.

- `PUT /vehicles/{vehicle_id}`
  Update a vehicle owned by the current user.
  Input:
  - optional `vehicle_type`
  - optional `vehicle_number`

- `DELETE /vehicles/{vehicle_id}`
  Delete a vehicle owned by the current user.

## Driver Profiles

Auth: bearer token required

- `POST /driver-profiles/`
  Create driver profile.
  Input:
  - `vehicle_id`
  - `daily_seat_limit`

- `GET /driver-profiles/me`
  Get current user’s driver profile.

- `PUT /driver-profiles/me`
  Update driver profile.
  Fields:
  - `vehicle_id`
  - `daily_seat_limit`
  - `is_driver_active`

## Verification

Auth: bearer token required

### College email verification

- `POST /verification/email/send-otp`
  Sends OTP to a Christ University email.
  Input: `email`
  Notes: only allows `@christuniversity.in` or matching subdomain variants such as `*@*.christuniversity.in`.

- `POST /verification/email/verify-otp`
  Verifies email OTP and links email to user.
  Input:
  - `email_session_token`
  - `otp`
  Output: marks `is_email_verified = true` and stores the verified email on the user.

### Identity verification

- `POST /verification/identity/submit`
  Submit identity verification for admin review.
  Input:
  - `document_url`
  - optional `college_id_number`
  Output: status message

- `GET /verification/identity/status`
  Get current identity verification status for the logged-in user.

### Driver verification

- `POST /verification/driver/submit`
  Submit driving licence verification for admin review.
  Input:
  - `license_document_url`
  - optional `license_number`
  Notes: identity verification must already be approved.

- `GET /verification/driver/status`
  Get current driver verification status.

Verification enforcement now in use:

- `POST /rides/{ride_id}/request` requires college email verification.
- `POST /vehicles/` requires driver verification.
- `POST /rides/` requires driver verification.

## Rides

Auth: bearer token required

- `POST /rides/`
  Create a ride.
  Input:
  - `vehicle_id`
  - `start_location`
  - `end_location`
  - `start_address`
  - `end_address`
  - `ride_date`
  - `ride_time`
  - `available_seats`
  - `allowed_gender`
  - optional `allowed_community`
  - optional `estimated_fare`
  Notes: route logic checks that the vehicle belongs to the current user.

- `GET /rides/`
  List rides with status `open`.
  Notes: current implementation is a simple open-rides listing, not a location-filtered search.

- `GET /rides/mine`
  List rides created by the current authenticated driver.
  Notes:
  - returns driver-owned rides across statuses, not just `open`
  - intended for dashboard and driver management views

- `GET /rides/history`
  List rides and requests relevant to the current authenticated user.
  Notes:
  - merges driver-owned rides, accepted passenger rides, and pending/rejected ride requests
  - each item includes `history_state` so the client can render `active`, `requested`, `completed`, and `cancelled`
  - each item now includes `driver_id`, which the mobile reporting flow uses when a rider reports a driver
  - intended for the app activity/history screen

- `GET /rides/{ride_id}`
  Get detailed ride info, including participants and some driver/vehicle details.
  Notes:
  - participant pickup OTPs are exposed only to the driver
  - ride-level pickup OTP is exposed only to non-driver viewers
  - `start_location` and `end_location` are currently returned as placeholder `{latitude: 0, longitude: 0}` in this route

- `PUT /rides/{ride_id}/status`
  Update ride status.
  Input: `status`
  Notes:
  - driver only
  - frontend currently uses `driver_arriving`, `driver_arrived`, `rider_picked_up`, `ongoing`, `completed`, and `cancelled`
  - generates a ride-level pickup OTP when entering `driver_arriving` if none exists

- `POST /rides/{ride_id}/request`
  Passenger requests to join ride.
  Input:
  - optional `pickup_lat`
  - optional `pickup_lng`
  - optional `pickup_address`

- `GET /rides/{ride_id}/requests`
  Driver-only list of pending ride requests.

- `PUT /rides/{ride_id}/requests/{request_id}`
  Driver accepts or rejects a request.
  Input: `action` (`accept` or `reject`)
  Notes:
  - on accept, creates a `RideParticipant`
  - decrements `available_seats`
  - generates a per-rider pickup OTP

- `POST /rides/{ride_id}/verify-otp`
  Driver verifies rider pickup OTP.
  Input:
  - `otp`
  - optional `participant_id`
  Notes:
  - verifies accepted rider pickup against participant OTPs
  - marks the matched participant as picked up

- `GET /rides/{ride_id}/participants`
  Returns accepted participants with pickup details.
  Notes: per-rider OTPs are visible only to the driver.

## Tracking

Auth: bearer token required

- `GET /tracking/{ride_id}`
  Returns live ride tracking payload:
  - ride status
  - `viewer_role`
  - `viewer_participant` for the authenticated passenger, when applicable
  - start/end coordinates
  - addresses
  - driver info
  - vehicle info
  - live driver location
  - rider-facing pickup OTP
  Notes:
  - `viewer_participant` includes the authenticated rider's `participant_id`,
    `pickup_otp`, `pickup_address`, and `is_picked_up`
  - this is the preferred source for real ride-live rider state

- `POST /tracking/{ride_id}/location`
  Driver updates live location.
  Input:
  - `latitude`
  - `longitude`

- `DELETE /tracking/{ride_id}/location`
  Clears the stored live location for a ride.

## Fare

- `GET /fare/estimate`
  Estimate trip fare.
  Query params:
  - `start_lat`
  - `start_lng`
  - `end_lat`
  - `end_lng`
  - `num_riders`

- `GET /fare/campus-matrix`
  Return Christ campus definitions and precomputed campus-to-campus routes.

## Ratings

Auth:

- `POST /ratings/{ride_id}` requires bearer token
- read endpoints do not enforce user participation but still use backend route logic

Endpoints:

- `POST /ratings/{ride_id}`
  Submit a rating.
  Input:
  - `rated_user_id`
  - `rating_value`
  - optional `comment`
  Notes:
  - ride must be completed
  - passengers can rate only the driver for that ride
  - drivers can rate only confirmed participants from that ride
  - duplicate ratings for the same rater/rated user/ride are rejected

- `GET /ratings/ride/{ride_id}`
  List all ratings for a ride.

- `GET /ratings/user/{user_id}`
  Get aggregate average and count for a user.

## Reports

Auth: bearer token required

- `POST /reports/`
  Submit a report against another user for a ride.
  Input:
  - `ride_id`
  - `reported_user_id`
  - `comment`

- `GET /reports/mine`
  List reports created by current user.

## Emergency Contacts

Auth: bearer token required

- `GET /emergency-contacts/`
  List the current user’s emergency contacts.

- `POST /emergency-contacts/`
  Add a contact.
  Input:
  - `contact_name`
  - `contact_phone`
  - `relationship`

- `DELETE /emergency-contacts/{contact_id}`
  Delete a contact owned by the current user.

## SOS

Auth: bearer token required

- `POST /sos/trigger`
  Trigger an SOS alert tied to a ride.
  Input:
  - `ride_id`
  - `location.latitude`
  - `location.longitude`

- `GET /sos/active`
  Returns SOS alerts created by the current user.
  Notes:
  - the route name is legacy, but the payload now includes lifecycle fields such as `status`, `resolved_at`, and `resolution_notes`
  - mobile surfaces can use this to show alert history and current resolution state

## Admin

Auth: bearer token required, `is_admin = true`

### User management

- `GET /admin/users`
  Paginated user list.
  Query params:
  - `page`
  - `page_size`

- `GET /admin/users/{user_id}`
  Enriched user detail view for support and moderation.
  Includes:
  - core user profile and verification flags
  - latest identity and driver verification records
  - vehicles
  - recent rides, requests, reports, and SOS alerts
  - summary counts for ride activity and moderation context

- `PUT /admin/users/{user_id}/deactivate`
  Deactivate non-admin user.

- `PUT /admin/users/{user_id}/activate`
  Reactivate user.

### Identity verification review

- `GET /admin/verifications/identity/pending`
  List submitted identity verification requests.

- `PUT /admin/verifications/identity/{user_id}/approve`
  Approve identity verification.
  Input: optional `notes`

- `PUT /admin/verifications/identity/{user_id}/reject`
  Reject identity verification.
  Input: optional `notes`

### Driver verification review

- `GET /admin/verifications/driver/pending`
  List submitted driver verification requests.

- `PUT /admin/verifications/driver/{user_id}/approve`
  Approve driver verification.
  Input: optional `notes`

- `PUT /admin/verifications/driver/{user_id}/reject`
  Reject driver verification.
  Input: optional `notes`

### SOS and stats

- `GET /admin/sos`
  List SOS alerts for admin triage.
  Query params:
  - `status`: `all`, `open`, `resolved`, or `closed`
  - `page_size`
  Notes:
  - returns alert lifecycle state plus user, ride, and admin-resolution context
  - intended to drive the admin incident desk

- `GET /admin/sos/active`
  Returns open SOS alerts ordered by most recent.
  Notes:
  - compatibility alias for unresolved alerts only

- `PUT /admin/sos/{alert_id}/status`
  Update SOS lifecycle status.
  Input:
  - `status`: `open`, `resolved`, or `closed`
  - optional `notes`
  Notes:
  - used by the admin web incident desk
  - when moved to `resolved` or `closed`, the backend stores `resolved_at` and `resolved_by_user_id`

- `PUT /admin/sos/{alert_id}/resolve`
  Convenience endpoint to mark an alert resolved.
  Input: optional `notes`

- `PUT /admin/sos/{alert_id}/close`
  Convenience endpoint to mark an alert closed.
  Input: optional `notes`

- `GET /admin/stats`
  Returns dashboard aggregates for users, verifications, open rides, and SOS totals.
  SOS payload includes:
  - `total_triggered`
  - `open`
  - `resolved`
  - `closed`

## Addresses

- `GET /addresses/`
  Placeholder endpoint returning `{"status": "not_implemented"}`.
  Notes: current product choice keeps saved addresses local-only in the mobile app, so this backend route is intentionally unused for now.

## API observations for future tasks

- Driver dashboard should use `GET /rides/mine`; activity/history should use `GET /rides/history` rather than `GET /rides/`.
- `GET /tracking/{ride_id}` is richer for location data than `GET /rides/{ride_id}` right now.
- Real rider live tracking should prefer `GET /tracking/{ride_id}` plus `viewer_participant` instead of relying on the legacy ride-level pickup OTP field.
- Vehicle verification is not yet a backend concept. Vehicles can be added by driver-verified users, but there is no `/vehicles/.../verify` or admin vehicle-review flow yet, so “verified vehicle required for ride creation” is still a future backend task.
