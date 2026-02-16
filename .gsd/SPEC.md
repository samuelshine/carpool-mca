# SPEC.md — Project Specification

> **Status**: `FINALIZED`

## Vision
Build a **production-grade FastAPI backend** for a college carpooling platform serving Christ University students. The backend powers a Flutter mobile app (built by a separate team) and provides route-based ride matching using PostGIS, real-time location tracking via WebSockets, in-app fare splitting, push notifications, and admin functionality. Designed as an academic project with immediate startup potential.

## Goals
1. **Complete ride lifecycle** — Full request/accept/reject/join/complete workflow with status transitions
2. **Route-based ride matching** — Match passengers to rides near the driver's route (to/from college) without deviation, powered by PostGIS
3. **Real-time location tracking** — WebSocket-based live location sharing during active rides
4. **Fare splitting** — Calculate and split fares among participants (payment happens externally via cash/UPI)
5. **Push notifications** — Firebase Cloud Messaging for ride updates (request accepted, ride starting, etc.)
6. **Ratings & reports** — Post-ride mutual rating system and user reporting
7. **Safety features** — Emergency contacts management, SOS alert endpoint (demo — stores alert, no actual notification dispatch)
8. **Admin panel API** — User management, ride oversight, report review, platform statistics
9. **Driver profiles** — Driver registration with vehicle linkage and daily seat limits

## Non-Goals (Out of Scope)
- Flutter mobile app (separate team)
- In-app payment processing (students settle externally)
- Face verification / biometric matching (deferred to later version)
- Actual SOS notification dispatch (demo only — stores alert in DB)
- Chat / messaging between riders
- Ride scheduling recurrence (no "repeat every Monday")
- Community system (deferred — field exists but no special logic)

## Users
- **Students (riders)** — Christ University students who register with verified phone + college email. Can be passengers or drivers.
- **Drivers** — Students who own vehicles and offer rides to/from college
- **Passengers** — Students who search for and join available rides
- **Admins** — University staff or moderators who manage users, review reports, and monitor platform health

## Constraints
- **Tech stack is fixed** — FastAPI + SQLAlchemy 2.0 + PostgreSQL (Supabase) + asyncpg
- **Backend only** — Must provide clean REST API + WebSocket endpoints for the Flutter team
- **PostGIS required** — Already integrated for geospatial features
- **No breaking changes** — Existing auth, user, vehicle, and basic ride endpoints must remain compatible
- **Academic timeline** — Must be feature-complete quickly
- **College-only** — Registration restricted to `*@*christuniversity.in` email addresses

## Success Criteria
- [ ] All 13 database models have corresponding API endpoints
- [ ] Ride lifecycle works end-to-end: create → search → request → accept → start → track → complete
- [ ] Route-based matching returns rides within configurable proximity of a given point
- [ ] WebSocket endpoint streams live driver location during active rides
- [ ] Fare is calculated based on distance and split equally among confirmed participants
- [ ] Push notifications fire for key ride events via FCM
- [ ] Admin can list/deactivate users, view reports, and see platform stats
- [ ] Ratings can be submitted after ride completion (1-5 scale)
- [ ] SOS endpoint stores alert with location (demo)
- [ ] Emergency contacts CRUD works
- [ ] API documentation is complete (Swagger/ReDoc)
