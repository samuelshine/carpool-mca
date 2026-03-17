# Architecture

## Repository structure

### Root

- `backend_fastapi/`: FastAPI backend application, Docker config, migrations
- `frontend_flutter/`: Flutter application
- `admin-web/`: standalone admin dashboard
- `docs/`: legacy project documents and methodology writeups
- `documentation/`: this current code-derived reference set

## Runtime components

### 1. FastAPI backend

Main entrypoint: `backend_fastapi/backend/app/main.py`

Responsibilities:

- exposes REST APIs
- owns authentication and token lifecycle
- persists domain data
- enforces verification and admin access rules
- calculates fares
- manages ride creation, requests, participants, ratings, reports, SOS, and tracking

Router groups:

- `auth`
- `users`
- `vehicles`
- `rides`
- `verification`
- `addresses`
- `driver_profiles`
- `tracking`
- `fare`
- `ratings`
- `reports`
- `emergency_contacts`
- `sos`
- `admin`

### 2. Flutter app

Main entrypoint: `frontend_flutter/lib/main.dart`

Responsibilities:

- handles OTP-based auth UX
- stores tokens locally
- renders rider, driver, profile, settings, verification, and activity flows
- performs location lookup and route preview
- simulates or displays live ride progression

Important note:

- The Flutter app is not uniformly backend-driven. Some flows use the real FastAPI API. Others are UI-only or simulated.

### 3. Admin web app

Entrypoints:

- `admin-web/index.html`
- `admin-web/app.js`

Responsibilities:

- admin OTP login using normal user auth endpoints
- admin authorization check via `/users/me`
- dashboard stats from `/admin/stats`
- user activation/deactivation
- identity and driver verification review
- active SOS monitoring

## Backend architecture details

### Core layers

1. `core/`
   Settings, JWT/token helpers, dependency injection, auth guards
2. `db/`
   SQLAlchemy base, async session, enums, models
3. `schemas/`
   Pydantic request/response models
4. `services/`
   OTP, email, and SMS abstractions
5. `routers/`
   API endpoints and business-flow orchestration

### Access control model

The backend uses layered dependency guards:

- `CurrentUser`: authenticated user only
- `VerifiedUser`: authenticated + identity verified
- `VerifiedDriver`: identity verified + driver verified
- `AdminUser`: admin only

Current reality:

- the guard helpers exist centrally, but not every router currently uses the stricter `VerifiedUser` / `VerifiedDriver` aliases consistently
- some feature restrictions are implemented inside route logic instead of entirely through dependencies

### Authentication flow

#### Signup

1. send phone OTP
2. verify phone OTP
3. receive `phone_verified_token`
4. register account
5. backend issues `access_token` + `refresh_token`

#### Login

1. send login OTP to registered phone
2. verify OTP
3. backend issues `access_token` + `refresh_token`

#### Session continuation

- access token is short-lived JWT
- refresh token is stored hashed in DB
- refresh token is rotated on refresh
- logout revokes refresh token only

### Verification architecture

The verification system is tiered:

1. phone verified
2. college email verified
3. identity verified by admin
4. driver verified by admin

The backend stores verification records separately from the `users` table and updates boolean flags on the user after admin approval.

### Ride architecture

Core ride entities:

- `Ride`: driver offer and route metadata
- `RideRequest`: pending join request from a passenger
- `RideParticipant`: accepted rider with pickup details and per-rider OTP
- `RideHistory`: historical ride table exists but is not the main live source used by the current routers

Ride lifecycle in code:

1. driver creates a ride
2. passengers submit join requests
3. driver accepts or rejects requests
4. accepted requests become `RideParticipant` records
5. ride status moves through `open -> driver_arriving -> driver_arrived/rider_picked_up -> ongoing -> completed/cancelled`
6. OTP can be used to verify pickup
7. ride can later be rated or reported against

### Tracking architecture

- ride metadata comes from the database
- live driver location is stored in `_driver_locations`, an in-memory dict inside `tracking.py`
- this works for a single-process demo but is not durable or multi-instance safe

### Fare architecture

- campus routes use a hardcoded campus distance matrix
- non-campus routes use Haversine distance with a road-factor multiplier
- fare uses `base fare + per km`, with a minimum fare floor

### Admin architecture

- admin is not a separate auth system
- admin users authenticate via the normal OTP login flow
- admin status is a boolean flag on `users.is_admin`
- a helper script exists to promote/create an admin user

## Data model summary

### Primary tables actively used by routes

- `users`
- `vehicles`
- `rides`
- `ride_requests`
- `ride_participants`
- `otp_sessions`
- `refresh_tokens`
- `identity_verifications`
- `driver_verifications`
- `ratings`
- `reports`
- `emergency_contacts`
- `sos_alerts`

### Secondary or scaffolded tables

- `saved_addresses`
- `fare_estimates`
- `ride_history`
- `college_students`
- `face_data`

These exist in the data model but are not all fully wired into current frontend flows or backend endpoints yet.

## Frontend architecture details

### App shell

- `MaterialApp`
- auth gate based on `SharedPreferences`
- global theme toggle through `ThemeNotifier`

### Client service layer

- `ApiService`: base HTTP wrapper and token storage
- `AuthApiService`: OTP auth flow
- `RideApiService`: primary backend ride APIs
- `RidesApiService`: overlapping ride API wrapper with broader feature coverage
- `LocationService`: GPS, reverse geocoding, forward geocoding, saved pickup persistence
- `RoutingService`: OSRM route retrieval
- `RideSimulationService`: client-only ride progression simulation

Important note:

- there are two ride-oriented service wrappers, `RideApiService` and `RidesApiService`
- they overlap but are not identical
- future work should avoid creating a third abstraction and should probably consolidate these two

### UI architecture

The Flutter app is organized mainly by feature folders:

- `auth/`
- `home/`
- `driver/`
- `profile/`
- `settings/`
- `rides/`
- `activity/`

## End-to-end flow summary

### Rider discovery flow

1. login/signup
2. land on home screen
3. choose pickup in `LocationSearchScreen`
4. choose a Christ campus destination
5. preview route and fare
6. move into a ride/live-tracking experience

Current implementation note:

- this flow is more ride-preview / simulation oriented than a fully integrated marketplace search flow

### Driver management flow

1. open driver dashboard
2. inspect driver profile and existing rides
3. inspect ride requests
4. accept/reject requests
5. see participants and OTPs

Current implementation note:

- driver ride creation UX is still incomplete from the dashboard side

### Admin review flow

1. admin logs in with phone OTP
2. admin is validated through `/users/me`
3. dashboard loads stats
4. admin can moderate users, approve/reject verifications, and inspect SOS alerts

## Architectural risks and future-task notes

- Tracking is in-memory only, so it will break across multiple workers/instances.
- Docker runs Uvicorn with 4 workers, which makes in-memory tracking even less consistent across workers.
- Some backend responses still return placeholder location values in `GET /rides/{ride_id}`.
- Some frontend screens are mock-first and do not persist through backend APIs.
- Some frontend code expects API shapes slightly differently from the backend.
- The admin app hardcodes `http://localhost:8000` as its API base URL.

