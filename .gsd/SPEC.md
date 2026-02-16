# SPEC.md — Project Specification

> **Status**: `FINALIZED` (Revised 2026-02-16)

## Vision
Build a **production-grade FastAPI backend** for a college carpooling platform serving Christ University students and faculty. The backend powers a Flutter mobile app (built by a separate team) and implements a **tiered verification system**: phone-based account creation, college identity verification (ID matched against college database), and driver verification (license + vehicle registration). Features include route-based ride matching using PostGIS, real-time location tracking via WebSockets, in-app fare splitting, push notifications, and admin functionality.

## User Journey

```
┌──────────────────────────────────────────────────────────────────────┐
│ 1. ACCOUNT CREATION                                                  │
│    Phone OTP → Enter basic details (name, etc.) → Account created    │
├──────────────────────────────────────────────────────────────────────┤
│ 2. LOGIN                                                             │
│    Phone OTP → Access token → Can view app but NOT use ride features │
├──────────────────────────────────────────────────────────────────────┤
│ 3. IDENTITY VERIFICATION (required for ride features)                │
│    Submit college ID → Verified against college database             │
│    → Unlocks: search rides, request rides, rate users, etc.          │
├──────────────────────────────────────────────────────────────────────┤
│ 4. DRIVER VERIFICATION (required to offer rides)                     │
│    Upload driver's license + vehicle registration                    │
│    → Add vehicles + saved addresses                                  │
│    → Unlocks: create rides, manage ride requests                     │
└──────────────────────────────────────────────────────────────────────┘
```

## Goals
1. **Phone-only account creation** — Register with phone OTP + basic profile details (no email OTP at registration)
2. **College identity verification** — In-app feature to verify student/faculty ID against college database; gates access to all ride features
3. **Driver verification** — Upload and verify driver's license + vehicle registration before offering rides
4. **Complete ride lifecycle** — Full request/accept/reject/join/complete workflow with status transitions
5. **Route-based ride matching** — Match passengers to rides near the driver's route (to/from college) without deviation, powered by PostGIS
6. **Real-time location tracking** — WebSocket-based live location sharing during active rides
7. **Fare splitting** — Calculate and split fares among participants (payment happens externally via cash/UPI)
8. **Push notifications** — Firebase Cloud Messaging for ride updates
9. **Ratings & reports** — Post-ride mutual rating system and user reporting
10. **Safety features** — Emergency contacts, SOS alert endpoint (demo)
11. **Saved addresses** — Users can save frequently used pickup/drop locations
12. **Admin panel API** — User management, verification approvals, ride oversight, report review, platform statistics
13. **Driver profiles** — Driver registration with vehicle linkage and daily seat limits

## Non-Goals (Out of Scope)
- Flutter mobile app (separate team)
- In-app payment processing (students settle externally)
- Face verification / biometric matching (deferred)
- Actual SOS notification dispatch (demo only)
- Chat / messaging between riders
- Ride scheduling recurrence
- Community system (field exists but no special logic)

## Users
- **Unverified users** — Have an account, can log in, but cannot use ride features until identity is verified
- **Verified students/faculty** — Identity confirmed via college ID; can search rides, request to join, rate users
- **Verified drivers** — License + registration verified; can create rides, manage requests, offer seats
- **Admins** — Manage users, approve/reject verifications, review reports, monitor platform

## Constraints
- **Tech stack is fixed** — FastAPI + SQLAlchemy 2.0 + PostgreSQL (Supabase) + asyncpg
- **Backend only** — Must provide clean REST API + WebSocket endpoints for the Flutter team
- **PostGIS required** — Already integrated for geospatial features
- **Existing auth needs rework** — Current auth uses phone + email OTP at registration; needs to be simplified to phone-only with separate identity verification
- **Academic timeline** — Must be feature-complete quickly
- **College-only** — Verification restricted to Christ University students/faculty

## Success Criteria
- [ ] Account creation works with phone OTP only (no email OTP)
- [ ] Login via phone OTP returns access token
- [ ] College identity verification endpoint accepts ID and validates against college DB
- [ ] Unverified users are blocked from ride features (middleware/dependency)
- [ ] Driver verification accepts license + registration documents
- [ ] Only verified drivers can create rides
- [ ] Ride lifecycle works end-to-end: create → search → request → accept → start → track → complete
- [ ] Route-based matching returns rides within configurable proximity
- [ ] WebSocket endpoint streams live driver location during active rides
- [ ] Fare is calculated and split among confirmed participants
- [ ] Push notifications fire for key ride events via FCM
- [ ] Users can save/manage addresses
- [ ] Admin can manage users, approve verifications, view reports, and see stats
- [ ] Ratings can be submitted after ride completion
- [ ] SOS endpoint stores alert with location (demo)
- [ ] Emergency contacts CRUD works
- [ ] API documentation is complete (Swagger/ReDoc)
