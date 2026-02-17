---
phase: 2
plan: 1
wave: 1
---

# Plan 2.1: Ride Request & Response Endpoints

## Objective
Implement the passenger-to-driver ride request flow: passenger requests to join a ride, driver accepts or rejects, accepted passengers become confirmed participants. This is the core interaction loop of the platform.

## Context
- @.gsd/SPEC.md — REQ-09, REQ-10
- @.gsd/ARCHITECTURE.md — Ride Lifecycle section
- @backend/app/db/models/ride_requests.py — `RideRequest` model (exists, has `request_status: pending/accepted/rejected`)
- @backend/app/db/models/ride_participants.py — `RideParticipant` model (exists, `ride_id + user_id + joined_at`)
- @backend/app/db/models/rides.py — `Ride` model with `available_seats`, `ride_requests` and `participants` relationships
- @backend/app/db/enums.py — `RideRequestStatusEnum`, `RideStatusEnum`
- @backend/app/schemas/rides.py — Existing ride schemas to extend
- @backend/app/core/deps.py — `VerifiedUser`, `VerifiedDriver` dependencies
- @backend/app/routers/rides.py — Existing rides router to extend

## Tasks

<task type="auto">
  <name>Create ride request schemas</name>
  <files>backend/app/schemas/ride_requests.py</files>
  <action>
    Create new Pydantic schemas file with:
    - `RideRequestCreate` — empty (ride_id from path, passenger_id from auth)
    - `RideRequestRead` — request_id, ride_id, passenger_id, request_status, requested_at
    - `RideRequestAction` — action: Literal["accept", "reject"]
    - `RideRequestWithUser` — extends `RideRequestRead` with passenger `full_name` and `phone_number` (for driver to see who's requesting)
    
    Follow existing schema patterns in `schemas/rides.py` (BaseModel, Field validators, Config from_attributes).
  </action>
  <verify>python3 -c "from schemas.ride_requests import RideRequestCreate, RideRequestRead, RideRequestAction, RideRequestWithUser; print('OK')"</verify>
  <done>All 4 schemas importable, field types correct</done>
</task>

<task type="auto">
  <name>Implement ride request endpoints</name>
  <files>backend/app/routers/rides.py</files>
  <action>
    Add 3 new endpoints to the existing rides router:

    1. `POST /rides/{ride_id}/requests` — Passenger requests to join
       - Auth: `VerifiedUser` (identity-verified)
       - Validate: ride exists, ride is `open`, passenger is not the driver, passenger hasn't already requested, available_seats > current accepted requests count
       - Creates `RideRequest` with status `pending`
       - Returns `RideRequestRead`

    2. `GET /rides/{ride_id}/requests` — Driver views all requests for their ride
       - Auth: `VerifiedDriver` (must own the ride)
       - Returns `list[RideRequestWithUser]` — includes passenger name/phone
       - Only show requests for rides owned by the current user (prevent data leakage)

    3. `PUT /rides/{ride_id}/requests/{request_id}` — Driver accepts/rejects a request
       - Auth: `VerifiedDriver` (must own the ride)
       - Body: `RideRequestAction` (accept or reject)
       - If accept:
         a. Update request status to `accepted`
         b. Create `RideParticipant` record
         c. Decrement `available_seats` on the Ride
         d. If `available_seats` reaches 0, auto-close ride status? (Decision: keep `open` — driver manually starts)
       - If reject: Update request status to `rejected`
       - Prevent action on already-processed requests
       - Return updated `RideRequestRead`

    Import models: `RideRequest`, `RideParticipant`, `User`
    Import deps: `VerifiedUser`, `VerifiedDriver`
    Do NOT import from `core.deps` using `Depends()` directly — use the type aliases.
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from routers.rides import router
    routes = [r.path for r in router.routes]
    assert '/rides/{ride_id}/requests' in routes or any('requests' in r for r in routes)
    print(f'Routes: {routes}')
    print('OK')
    "
  </verify>
  <done>3 new endpoints appear in the routes list, all importable without errors</done>
</task>

## Success Criteria
- [ ] `POST /rides/{ride_id}/requests` creates a pending request
- [ ] `GET /rides/{ride_id}/requests` returns requests (driver only)
- [ ] `PUT /rides/{ride_id}/requests/{request_id}` accepts/rejects and creates participant on accept
- [ ] Proper validation: no duplicate requests, no self-request, seat availability check
