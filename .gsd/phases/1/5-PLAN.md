---
phase: 1
plan: 5
wave: 3
---

# Plan 1.5: Feature Gating & Saved Addresses

## Objective
Create verification-based dependency injection functions for feature gating and implement saved addresses CRUD. This ties everything together — existing and new endpoints are gated by verification status.

## Context
- @.gsd/SPEC.md — Feature gating tiers, saved addresses
- @.gsd/DECISIONS.md — Confirmed gating: unverified → verified → driver
- @backend/app/core/deps.py — Existing DI pattern (get_current_active_user)
- @backend/app/db/models/saved_addresses.py — Created in Plan 1.1
- @backend/app/routers/rides.py — Needs gating (verified users only)
- @backend/app/routers/vehicles.py — Needs gating (verified drivers only)

## Tasks

<task type="auto">
  <name>Create verification-based dependencies</name>
  <files>backend/app/core/deps.py</files>
  <action>
    Add new dependency injection functions following the existing pattern:
    
    1. `get_verified_user(user = Depends(get_current_active_user))`:
       - Checks user.is_identity_verified == True
       - If not: raise HTTPException(403, "Identity verification required to access this feature")
       - Returns user
       - Type alias: `VerifiedUser = Annotated[User, Depends(get_verified_user)]`
    
    2. `get_verified_driver(user = Depends(get_verified_user))`:
       - Checks user.is_driver_verified == True
       - If not: raise HTTPException(403, "Driver verification required to offer rides")
       - Returns user
       - Type alias: `VerifiedDriver = Annotated[User, Depends(get_verified_driver)]`
    
    3. `get_admin_user(user = Depends(get_current_active_user))`:
       - Checks user.is_admin == True
       - If not: raise HTTPException(403, "Admin access required")
       - Returns user
       - Type alias: `AdminUser = Annotated[User, Depends(get_admin_user)]`
    
    The dependency chain:
    - get_current_active_user → any authenticated, active user
    - get_verified_user → authenticated + identity verified
    - get_verified_driver → authenticated + identity verified + driver verified
    - get_admin_user → authenticated + is_admin flag
  </action>
  <verify>python -c "from backend.app.core.deps import VerifiedUser, VerifiedDriver, AdminUser; print('Dependencies OK')"</verify>
  <done>Three new dependency functions + type aliases exist. Dependency chain correct.</done>
</task>

<task type="auto">
  <name>Apply gating to existing routers and create saved addresses</name>
  <files>
    backend/app/routers/rides.py
    backend/app/routers/vehicles.py
    backend/app/routers/addresses.py [NEW]
    backend/app/schemas/addresses.py [NEW]
    backend/app/main.py
  </files>
  <action>
    1. Update `routers/rides.py`:
       - `POST /rides/` — Change from CurrentUser to VerifiedDriver dependency
       - `GET /rides/` (search) — Change to VerifiedUser dependency
       - `GET /rides/{id}` — Change to VerifiedUser dependency
    
    2. Update `routers/vehicles.py`:
       - `POST /vehicles/` — Change to VerifiedDriver dependency
       - `GET /vehicles/` — Keep as CurrentUser (user can view own vehicles)
       - `DELETE /vehicles/{id}` — Change to VerifiedDriver dependency
    
    3. Create `schemas/addresses.py`:
       - AddressCreate: label (str), address (str), latitude (float), longitude (float), is_default (bool, optional)
       - AddressRead: id (UUID), label, address, latitude, longitude, is_default, created_at
       - AddressUpdate: label (optional), address (optional), latitude (optional), longitude (optional), is_default (optional)
    
    4. Create `routers/addresses.py`:
       - `POST /addresses/` — Create saved address (requires CurrentUser — unverified can save addresses)
       - `GET /addresses/` — List user's saved addresses
       - `PUT /addresses/{id}` — Update address (with ownership check)
       - `DELETE /addresses/{id}` — Delete address (with ownership check)
       - `PUT /addresses/{id}/default` — Set as default address
    
    5. Register in `main.py`:
       - `app.include_router(addresses.router, prefix="/addresses", tags=["Addresses"])`
    
    IMPORTANT: Saved addresses are available to ALL authenticated users (even unverified). This is intentional — let users set up their profile before verification.
  </action>
  <verify>grep "addresses\|verification\|VerifiedUser\|VerifiedDriver" backend/app/main.py backend/app/routers/rides.py</verify>
  <done>Rides gated by VerifiedUser/VerifiedDriver. Vehicles gated by VerifiedDriver. Addresses CRUD works for all authenticated users.</done>
</task>

## Success Criteria
- [ ] VerifiedUser, VerifiedDriver, AdminUser dependencies exist in deps.py
- [ ] Ride creation blocked for non-drivers (403)
- [ ] Ride search blocked for non-verified users (403)
- [ ] Vehicle creation blocked for non-drivers (403)
- [ ] Saved addresses CRUD works for any authenticated user
- [ ] All existing tests (if any) still pass
