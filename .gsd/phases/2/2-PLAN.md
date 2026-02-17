---
phase: 2
plan: 2
wave: 1
---

# Plan 2.2: Ride State Machine (Start / Complete / Cancel)

## Objective
Implement ride lifecycle transitions: driver starts a ride (open→ongoing), driver completes a ride (ongoing→completed), and cancellation (open/ongoing→cancelled). Completion triggers ride history records for all participants.

## Context
- @.gsd/SPEC.md — REQ-11, REQ-12, REQ-13
- @backend/app/db/models/rides.py — Ride model with `status` field
- @backend/app/db/models/ride_history.py — RideHistory model (ride_id, driver_id, passenger_id, completed_at)
- @backend/app/db/models/ride_participants.py — RideParticipant model
- @backend/app/db/enums.py — `RideStatusEnum`: open, ongoing, completed, cancelled
- @backend/app/routers/rides.py — Existing rides router (to extend from Plan 2.1)

## Tasks

<task type="auto">
  <name>Add ride lifecycle endpoints</name>
  <files>backend/app/routers/rides.py</files>
  <action>
    Add 3 new endpoints to the rides router:

    1. `POST /rides/{ride_id}/start` — Driver starts the ride
       - Auth: `VerifiedDriver` (must own the ride)
       - Validate: ride status must be `open`, ride must have at least 1 accepted participant
       - Transition: `open` → `ongoing`
       - Return updated RideRead

    2. `POST /rides/{ride_id}/complete` — Driver completes the ride
       - Auth: `VerifiedDriver` (must own the ride)
       - Validate: ride status must be `ongoing`
       - Transition: `ongoing` → `completed`
       - Side effects:
         a. Create `RideHistory` record for each `RideParticipant`
         b. Set `completed_at` = now()
       - Return updated RideRead

    3. `POST /rides/{ride_id}/cancel` — Cancel a ride
       - Auth: `VerifiedDriver` (must own the ride)
       - Validate: ride status must be `open` or `ongoing` (not already completed/cancelled)
       - Transition: → `cancelled`
       - Side effects:
         a. Set all pending `RideRequest` statuses to `rejected` (auto-reject)
       - Return updated RideRead

    Import: `RideHistory`, `RideParticipant`, `RideRequest`, `RideRequestStatusEnum`
    Use `from datetime import datetime, timezone` for `completed_at` timestamp.
    Do NOT use `db.commit()` — the session auto-commits via the `get_db()` dependency.
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from routers.rides import router
    routes = [r.path for r in router.routes]
    assert any('start' in r for r in routes)
    assert any('complete' in r for r in routes)
    assert any('cancel' in r for r in routes)
    print(f'Routes: {routes}')
    print('OK')
    "
  </verify>
  <done>3 lifecycle endpoints appear in routes, state transitions validated</done>
</task>

<task type="auto">
  <name>Add participants endpoint and ride history</name>
  <files>backend/app/routers/rides.py, backend/app/schemas/rides.py</files>
  <action>
    1. Extend `schemas/rides.py` with:
       - `RideParticipantRead` — participant_id, user_id, full_name, phone_number, joined_at
       - `RideDetailRead` — extends `RideRead` with driver_name, vehicle_number, participants list

    2. Add 2 endpoints to rides router:
       
       a. `GET /rides/{ride_id}/participants` — List confirmed riders
          - Auth: `VerifiedUser` (any verified user who is driver or participant can view)
          - Join with User table to get names
          - Return `list[RideParticipantRead]`

       b. `GET /users/me/rides` — User's ride history (as driver + as passenger)
          - Auth: `CurrentUser` (any authenticated user)
          - Query rides where user is driver OR user is in ride_participants
          - Return `list[RideRead]` ordered by `created_at desc`
          - NOTE: This endpoint path is under /rides but logically it's "my rides"
            Use path `/rides/my-rides` to keep it under the rides router prefix
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from schemas.rides import RideParticipantRead, RideDetailRead
    from routers.rides import router
    routes = [r.path for r in router.routes]
    assert any('participant' in r for r in routes)
    assert any('my' in r for r in routes)
    print(f'Routes: {routes}')
    print('OK')
    "
  </verify>
  <done>Participants and ride history endpoints importable and registered</done>
</task>

## Success Criteria
- [ ] `POST /rides/{ride_id}/start` transitions open→ongoing (with participants check)
- [ ] `POST /rides/{ride_id}/complete` transitions ongoing→completed and creates RideHistory
- [ ] `POST /rides/{ride_id}/cancel` transitions to cancelled and auto-rejects pending requests
- [ ] `GET /rides/{ride_id}/participants` returns confirmed riders with names
- [ ] `GET /rides/my-rides` returns user's ride history
