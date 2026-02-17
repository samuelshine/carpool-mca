---
phase: 1
plan: 4
wave: 2
---

# Plan 1.4: Driver & Vehicle Verification

## Objective
Implement driver license verification and vehicle registration verification. A user cannot add a vehicle without a verified registration document. A user cannot create rides without being a verified driver.

## Context
- @.gsd/SPEC.md — Driver verification requirement
- @.gsd/DECISIONS.md — Pluggable provider (console for demo, Surepass/HyperVerge for prod)
- @backend/app/db/models/driver_verifications.py — Created in Plan 1.1
- @backend/app/routers/vehicles.py — Existing vehicle CRUD (needs gating)
- @backend/app/services/verification_service.py — Created in Plan 1.3

## Tasks

<task type="auto">
  <name>Create driver verification service with pluggable providers</name>
  <files>
    backend/app/services/driver_verification_service.py [NEW]
  </files>
  <action>
    Create a driver/vehicle verification service:
    
    1. Abstract base class `VerificationProvider`:
       - `async def verify_license(license_number: str, license_image_url: str) -> dict`
         Returns: {"valid": bool, "name": str, "license_type": str, "expiry": str, "details": dict}
       - `async def verify_vehicle_registration(reg_number: str, reg_image_url: str) -> dict`
         Returns: {"valid": bool, "owner_name": str, "vehicle_type": str, "details": dict}
    
    2. `ConsoleVerificationProvider`:
       - Auto-approves all verifications for demo/dev
       - Returns plausible mock data
       - Logs the verification attempt
    
    3. `SurepassProvider` (stub for production):
       - Placeholder that would call Surepass API for RC and DL verification
       - API key from settings
       - Raises NotImplementedError with helpful message
    
    4. Factory function `get_verification_provider()` based on `VERIFICATION_PROVIDER` env var
    
    Add to config.py:
    - `VERIFICATION_PROVIDER: str = "console"`
    - `VERIFICATION_API_KEY: str = ""`
  </action>
  <verify>python -c "from backend.app.services.driver_verification_service import get_verification_provider; print(type(get_verification_provider()).__name__)"</verify>
  <done>Driver verification service exists with console (demo) and surepass (stub) providers.</done>
</task>

<task type="auto">
  <name>Add driver verification endpoints and gate vehicle management</name>
  <files>
    backend/app/routers/verification.py
    backend/app/routers/vehicles.py
    backend/app/schemas/verification.py
    backend/app/services/verification_service.py
  </files>
  <action>
    1. Add to `schemas/verification.py` (if not already there from Plan 1.3):
       - DriverVerificationRequest: license_number, license_image_url, vehicle_registration_number, registration_image_url
       - DriverVerificationResponse: id, status, message
       - DriverVerificationStatus: id, status, license_number, vehicle_registration_number, submitted_at, reviewed_at
    
    2. Add to `services/verification_service.py`:
       - `verify_driver(db, user_id, license_number, license_image_url, reg_number, reg_image_url)`:
         a. Call driver_verification_service to verify license
         b. Call driver_verification_service to verify vehicle registration
         c. If both valid: Create DriverVerification(status=verified), update user.is_driver_verified=True
         d. If either fails: status=rejected with details
         e. Return verification record
    
    3. Add to `routers/verification.py`:
       - `POST /verification/driver` — Submit driver verification (requires authenticated + identity-verified user)
         - User must be identity-verified first before becoming a driver
         - Calls verification_service.verify_driver
       - `GET /verification/driver/status` — Check driver verification status
    
    4. Update `routers/vehicles.py`:
       - Gate vehicle creation: require user to be driver-verified
       - Use a `get_verified_driver` dependency (created in Plan 1.5)
       - For now, add a simple check: `if not current_user.is_driver_verified: raise HTTPException(403)`
  </action>
  <verify>grep "driver" backend/app/routers/verification.py</verify>
  <done>Driver verification endpoints work. Vehicle creation requires driver verification. Console provider auto-approves for demo.</done>
</task>

## Success Criteria
- [ ] `POST /verification/driver` accepts license + registration, runs verification, returns status
- [ ] `GET /verification/driver/status` returns current driver verification state
- [ ] Console provider auto-approves for demo
- [ ] Vehicle creation blocked for non-driver-verified users
- [ ] User.is_driver_verified set to True on successful verification
