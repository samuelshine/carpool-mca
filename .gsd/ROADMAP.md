# ROADMAP.md

> **Current Phase**: Not started
> **Milestone**: v1.0 — Full Backend

## Must-Haves (from SPEC)
- [ ] Complete ride lifecycle (create → request → accept → start → track → complete)
- [ ] Route-based ride matching with PostGIS
- [ ] Real-time location tracking via WebSocket
- [ ] Fare calculation and splitting
- [ ] Push notifications (FCM)
- [ ] Ratings and reports
- [ ] Emergency contacts + SOS demo
- [ ] Admin API
- [ ] Driver profiles

## Phases

### Phase 1: Ride Lifecycle & Driver Profiles
**Status**: ⬜ Not Started
**Objective**: Complete the ride request/accept/reject/join/complete workflow and driver profile management. This is the **core** of the app — everything else builds on it.
**Requirements**: REQ-01, REQ-02, REQ-03, REQ-04, REQ-20, REQ-22

**Deliverables:**
- `POST /rides/{id}/requests` — Passenger requests to join
- `PUT /rides/{id}/requests/{request_id}` — Driver accepts/rejects
- `POST /rides/{id}/start` — Driver starts the ride
- `POST /rides/{id}/complete` — Driver completes the ride
- `POST /rides/{id}/cancel` — Cancel a ride
- `GET /rides/{id}/participants` — List confirmed riders
- `GET /users/me/rides` — User's ride history (as driver + passenger)
- `POST /driver-profiles/` — Create/update driver profile
- `GET /driver-profiles/me` — Get own driver profile
- Status machine: `open` → `ongoing` → `completed` / `cancelled`

---

### Phase 2: Geospatial Search & Route Matching
**Status**: ⬜ Not Started
**Objective**: Implement PostGIS-powered ride search — find rides near a passenger's pickup point along the driver's route.
**Requirements**: REQ-05, REQ-06

**Deliverables:**
- `GET /rides/search?lat=...&lng=...&radius_km=...&date=...` — Proximity search
- PostGIS `ST_DWithin` queries for point-to-point matching
- Route corridor matching (find rides whose route passes near a given point)
- Distance calculation between points for fare estimation input

---

### Phase 3: Real-Time Tracking & Push Notifications
**Status**: ⬜ Not Started
**Objective**: WebSocket for live location during rides + Firebase Cloud Messaging for push notifications on ride events.
**Requirements**: REQ-07, REQ-08, REQ-11, REQ-12, REQ-21

**Deliverables:**
- `WebSocket /ws/rides/{ride_id}/track` — Driver sends location, passengers receive
- `POST /users/me/fcm-token` — Register device FCM token
- FCM notification triggers: request received, request accepted/rejected, ride starting, ride completed
- Connection management (auth via token query param)

---

### Phase 4: Fare, Ratings, Reports & Safety
**Status**: ⬜ Not Started
**Objective**: Fare estimation/splitting, post-ride ratings, user reporting, emergency contacts, and SOS demo.
**Requirements**: REQ-09, REQ-10, REQ-13, REQ-14, REQ-15, REQ-16

**Deliverables:**
- `GET /rides/{id}/fare` — Calculate fare based on distance
- `GET /rides/{id}/fare/split` — Split fare among confirmed participants
- `POST /rides/{id}/ratings` — Submit post-ride rating
- `GET /users/{id}/ratings` — Get user's average rating
- `POST /reports/` — Submit a user report
- CRUD for `/emergency-contacts/`
- `POST /sos/` — SOS alert endpoint (stores in DB, demo only)

---

### Phase 5: Admin API & Production Polish
**Status**: ⬜ Not Started
**Objective**: Admin endpoints for platform management, security hardening, and API documentation polish.
**Requirements**: REQ-17, REQ-18, REQ-19

**Deliverables:**
- `GET /admin/users` — List/search users with filters
- `PUT /admin/users/{id}/deactivate` — Deactivate user
- `GET /admin/reports` — View all reports with status
- `PUT /admin/reports/{id}` — Act on report (resolve, escalate)
- `GET /admin/stats` — Platform statistics (total users, rides, active today, etc.)
- Admin role/permission system (admin flag on User model)
- CORS configuration for production
- API documentation review
- Error response standardization
