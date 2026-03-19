# Features

This file groups the project by capability rather than by file.

Last reviewed: 2026-03-19

## Core user features

## 1. Passwordless authentication

Implemented backend support:

- signup via phone OTP
- login via phone OTP
- JWT access tokens
- refresh token rotation
- logout via refresh token revocation

Frontend support:

- fully surfaced in Flutter auth flow
- also reused by admin web login

## 2. College-community verification model

Implemented backend support:

- Christ University email OTP verification
- identity verification submission
- driver licence verification submission
- admin approval/rejection workflows
- persistent user flags:
  - phone verified
  - email verified
  - identity verified
  - driver verified

Current frontend state:

- college email OTP, identity submission, and driver licence submission are wired into the main verification UI
- profile and settings surfaces now show backend verification status
- booking is restricted to college-email-verified users
- adding vehicles and creating rides are restricted to driver-verified users
- vehicle verification is still not a distinct backend-reviewed feature

## 3. Rider journey and ride discovery

Implemented or partially implemented:

- home landing screen
- current-location detection
- address search via Nominatim
- saved pickup address in local app storage
- campus destination selection
- route preview using OSRM
- fare estimate using backend fare API
- matching ride browse screen backed by open rides
- real rider join-request submission

Current limitation:

- the flow is now backend-backed end to end for basic booking, but ride matching is still fairly simple and based on open rides plus destination proximity rather than richer search/ranking logic

## 4. Ride creation and management

Implemented backend support:

- create ride
- list open rides
- view ride details
- update ride status
- handle seat counts
- gender/community restrictions fields in ride model

Current frontend state:

- driver dashboard now opens a dedicated create-ride flow
- ride creation is wired through backend vehicles, backend profile state, fare estimation, and `POST /rides/`

## 5. Ride request and participant management

Implemented backend support:

- passengers can request to join rides
- drivers can approve or reject requests
- accepted passengers become ride participants
- participant pickup locations are stored
- per-rider OTPs are generated

Current frontend state:

- request review UI exists in `RideRequestsScreen`
- participant list and pending request review are visible to the driver

## 6. Ride tracking and pickup verification

Implemented backend support:

- live tracking info endpoint
- driver location updates
- driver location clear endpoint
- pickup OTP verification endpoint

Implemented frontend support:

- live ride screen
- driver/rider view toggling
- OTP verification UI
- progress/status display
- backend tracking polling for real rides
- backend driver location updates for real rides

Current limitation:

- tracking backend is single-instance and in-memory only
- Flutter still supports demo mode, but real rides now use backend tracking and ride-status state as the primary source of truth

## 7. Fare estimation

Implemented:

- campus route matrix
- Haversine fallback for non-campus trips
- fare split by rider count
- minimum fare floor

Current state:

- good enough for estimation and previews
- not yet tied to a more advanced pricing engine or stored quote workflow

## 8. Ratings and trust

Implemented backend support:

- post-ride rating submission
- ride rating listing
- user rating summary

Current frontend state:

- rating surfaces exist
- some rating-related screens are still partly illustrative or not fully sequenced from completed backend ride states

## 9. Reporting and safety

Implemented backend support:

- report another user in a ride context
- SOS trigger linked to ride and location
- emergency contacts CRUD
- admin visibility into SOS alerts

Current frontend state:

- SOS is surfaced in live ride UI
- preferences/settings mention safety features
- report/support surfaces are not all wired end-to-end yet

## 10. Admin moderation and oversight

Implemented:

- admin OTP login
- admin gate using `is_admin`
- user listing
- user activation/deactivation
- pending verification review
- dashboard stats
- SOS visibility

Current limitation:

- no dedicated resolve/close SOS action in the current admin router implementation

## Feature maturity by area

## Strongest / closest to backend truth

- auth flow
- refresh token handling
- user profile read/update basics
- backend-backed profile vehicles
- rider booking flow
- driver create-ride flow
- backend-backed history flow
- ride request handling
- admin verification review
- fare estimation
- emergency contacts
- ratings/reporting backend

## Partially integrated

- driver dashboard
- ride history/activity
- verification UI
- live tracking
- safety/support surfaces

## Mostly prototype or local-state driven

- some verification forms
- some settings/support actions
- parts of the ride-live simulation
- legacy history/detail pages under `activity/`

## Important mismatches and future-task warnings

- Flutter now uses a consolidated API layer in `api_service.dart`, so future mobile API work should extend that file rather than recreating feature-specific wrappers.
- Some Flutter pages store data locally even though backend entities already exist.
- `RideDetailsScreen` is still more of a showcase/mock screen than a canonical backend-backed page.
- `RideHistoryScreen` now acts as a compatibility wrapper that forwards to the
  canonical backend-backed `ActivityHistoryScreen`.
- Admin web now supports environment-based API configuration and same-origin hosting fallback.
- Backend tracking in memory conflicts with multi-worker deployment.
- Backend models include scaffolded entities like `saved_addresses` and `face_data` that are not yet fully surfaced in the product.

## Practical summary

If future work needs a reliable source of truth, prioritize:

1. backend routers and schemas
2. `frontend_flutter/lib/services/api_service.dart`
3. admin-web API calls

If future work touches UX polish or prototype flows, confirm first whether the target screen is expected to remain simulated or should be converted into a fully backend-driven feature.
