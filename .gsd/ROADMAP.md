# ROADMAP.md

> **Current Phase**: Not started
> **Milestone**: v1.0 — Full Backend
> **Revised**: 2026-02-16 (verification flow rework)

## Must-Haves (from SPEC)
- [ ] Phone-only registration + login (rework existing email OTP flow)
- [ ] College identity verification (ID against college DB)
- [ ] Driver verification (license + vehicle registration)
- [ ] Feature gating by verification status
- [ ] Complete ride lifecycle
- [ ] Route-based ride matching with PostGIS
- [ ] Real-time location tracking via WebSocket
- [ ] Fare calculation and splitting
- [ ] Push notifications (FCM)
- [ ] Ratings, reports, emergency contacts, SOS demo
- [ ] Saved addresses
- [ ] Admin API with verification approval

## Phases

### Phase 1: Auth Rework & Verification System
**Status**: ⬜ Not Started
**Objective**: Simplify registration to phone-only, implement tiered identity verification (college ID + driver verification), and add verification-based feature gating.
**Requirements**: REQ-01 through REQ-08

**Deliverables:**
- **Auth rework:**
  - Simplify `POST /auth/register` — phone OTP only (remove email OTP requirement)
  - Keep login flow as-is (phone OTP → access token)
  - Update User model: remove email requirement at registration, add verification status fields
- **College identity verification:**
  - New model: `IdentityVerification` (user_id, college_id_image_url, status, admin_notes)
  - `POST /verification/identity` — Submit college ID for verification
  - `GET /verification/identity/status` — Check verification status
  - College database table or lookup for validation
- **Driver verification:**
  - New model: `DriverVerification` (user_id, license_image_url, registration_image_url, status)
  - `POST /verification/driver` — Submit license + vehicle registration
  - `GET /verification/driver/status` — Check verification status
- **Feature gating:**
  - `get_verified_user` dependency — blocks unverified users from ride endpoints
  - `get_verified_driver` dependency — blocks non-drivers from ride creation
- **Saved addresses:**
  - New model: `SavedAddress` (user_id, label, address, lat, lng)
  - CRUD: `POST/GET/PUT/DELETE /addresses/`

---

### Phase 2: Ride Lifecycle & Driver Profiles
**Status**: ✅ Complete
**Objective**: Complete ride request/accept/reject/join/complete workflow, driver profile management, and vehicle management improvements.
**Requirements**: REQ-09 through REQ-14, REQ-28

**Deliverables:**
- `POST /rides/{id}/requests` — Passenger requests to join
- `PUT /rides/{id}/requests/{request_id}` — Driver accepts/rejects
- `POST /rides/{id}/start` — Driver starts the ride
- `POST /rides/{id}/complete` — Driver completes the ride
- `POST /rides/{id}/cancel` — Cancel a ride
- `GET /rides/{id}/participants` — List confirmed riders
- `GET /users/me/rides` — Ride history (driver + passenger)
- `POST /driver-profiles/` — Create/update driver profile
- `GET /driver-profiles/me` — Get own driver profile
- Status machine: `open` → `ongoing` → `completed` / `cancelled`

---

### Phase 3: Geospatial Search & Route Matching
**Status**: ⬜ Not Started
**Objective**: PostGIS-powered ride search — find rides near a passenger's pickup point along the driver's route.
**Requirements**: REQ-15, REQ-16

**Deliverables:**
- `GET /rides/search?lat=...&lng=...&radius_km=...&date=...` — Proximity search
- PostGIS `ST_DWithin` queries for point-to-point matching
- Route corridor matching (rides whose route passes near a given point)
- Distance calculation between points for fare estimation input

---

### Phase 4: Real-Time Tracking & Push Notifications
**Status**: ⬜ Not Started
**Objective**: WebSocket for live location during rides + Firebase Cloud Messaging for push notifications on ride events.
**Requirements**: REQ-17 through REQ-20

**Deliverables:**
- `WebSocket /ws/rides/{ride_id}/track` — Driver sends location, passengers receive
- `POST /users/me/fcm-token` — Register device FCM token
- FCM notification triggers: request received, accepted/rejected, ride starting, ride completed
- WebSocket auth via token query parameter

---

### Phase 5: Fare, Ratings, Reports & Safety
**Status**: ⬜ Not Started
**Objective**: Fare estimation/splitting, post-ride ratings, user reporting, emergency contacts, and SOS demo.
**Requirements**: REQ-21 through REQ-26

**Deliverables:**
- `GET /rides/{id}/fare` — Calculate fare based on distance
- `GET /rides/{id}/fare/split` — Split among confirmed participants
- `POST /rides/{id}/ratings` — Submit post-ride rating
- `GET /users/{id}/ratings` — Get user's average rating
- `POST /reports/` — Submit a user report
- CRUD for `/emergency-contacts/`
- `POST /sos/` — SOS alert (stores in DB, demo only)

---

### Phase 6: Admin API & Production Polish
**Status**: ⬜ Not Started
**Objective**: Admin endpoints for platform management including verification approvals, security hardening, and API documentation.
**Requirements**: REQ-29 through REQ-33

**Deliverables:**
- `GET /admin/users` — List/search users with filters
- `PUT /admin/users/{id}/deactivate` — Deactivate user
- `GET /admin/verifications/identity` — Pending identity verifications
- `PUT /admin/verifications/identity/{id}` — Approve/reject
- `GET /admin/verifications/driver` — Pending driver verifications
- `PUT /admin/verifications/driver/{id}` — Approve/reject
- `GET /admin/reports` — View all reports
- `PUT /admin/reports/{id}` — Act on report
- `GET /admin/stats` — Platform statistics
- Admin role on User model (`is_admin` field)
- CORS configuration for production
- API documentation review
