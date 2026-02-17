---
phase: 2
plan: 3
wave: 2
---

# Plan 2.3: Driver Profile CRUD

## Objective
Implement driver profile management — drivers can create/update their profile with a preferred vehicle and daily seat limit. This extends the existing `DriverProfile` model which has `user_id`, `vehicle_id`, `daily_seat_limit`, and `is_driver_active` fields.

## Context
- @.gsd/SPEC.md — REQ-14, REQ-28
- @backend/app/db/models/driver_profiles.py — `DriverProfile` model (exists: user_id PK, vehicle_id FK, daily_seat_limit, is_driver_active)
- @backend/app/db/models/vehicles.py — Vehicle model (for validation)
- @backend/app/core/deps.py — `VerifiedDriver` dependency

## Tasks

<task type="auto">
  <name>Create driver profile schemas and router</name>
  <files>backend/app/schemas/driver_profiles.py, backend/app/routers/driver_profiles.py</files>
  <action>
    1. Create `schemas/driver_profiles.py`:
       - `DriverProfileCreate` — vehicle_id (UUID), daily_seat_limit (int, ge=1, le=10)
       - `DriverProfileRead` — user_id, vehicle_id, daily_seat_limit, is_driver_active, vehicle_number (joined)
       - `DriverProfileUpdate` — vehicle_id (Optional), daily_seat_limit (Optional), is_driver_active (Optional)

    2. Create `routers/driver_profiles.py`:
       - `POST /driver-profiles/` — Create/upsert driver profile
         - Auth: `VerifiedDriver`
         - Validate vehicle_id belongs to the user
         - If profile exists, update it (upsert behavior)
         - Return `DriverProfileRead`

       - `GET /driver-profiles/me` — Get own driver profile
         - Auth: `VerifiedDriver`
         - Join with Vehicle to get vehicle_number
         - Return `DriverProfileRead` or 404

       - `PUT /driver-profiles/me` — Update own driver profile
         - Auth: `VerifiedDriver`
         - Partial update (only set provided fields)
         - Validate vehicle_id if changed
         - Return updated `DriverProfileRead`

    3. Register in `main.py`:
       - Import and include `driver_profiles` router
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from schemas.driver_profiles import DriverProfileCreate, DriverProfileRead, DriverProfileUpdate
    from routers.driver_profiles import router
    routes = [r.path for r in router.routes]
    print(f'Routes: {routes}')
    print('OK')
    "
  </verify>
  <done>Driver profile schemas importable, 3 endpoints registered</done>
</task>

## Success Criteria
- [ ] `POST /driver-profiles/` creates or updates a driver profile
- [ ] `GET /driver-profiles/me` returns driver profile with vehicle info
- [ ] `PUT /driver-profiles/me` allows partial updates
- [ ] Vehicle ownership validated on create/update
