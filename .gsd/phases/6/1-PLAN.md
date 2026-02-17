---
phase: 6
plan: 1
wave: 1
---

# Plan 6.1: Admin User Management & Verification Approvals

## Objective
Create admin router with user management (list, search, deactivate) and verification approval endpoints for both identity and driver verifications. Uses the existing `AdminUser` dependency from `core/deps.py`.

## Context
- @.gsd/SPEC.md — REQ-29, REQ-30
- @backend/app/core/deps.py — AdminUser dependency (is_admin check)
- @backend/app/db/models/users.py — User model with is_admin
- @backend/app/db/models/identity_verifications.py — IdentityVerification model
- @backend/app/db/models/driver_verifications.py — DriverVerification model

## Tasks

<task type="auto">
  <name>Create admin router with user management + verification approvals</name>
  <files>
    backend/app/routers/admin.py
    backend/app/main.py
  </files>
  <action>
    Create `routers/admin.py` with `prefix="/admin"`:

    **User Management:**

    1. **GET /admin/users** (AdminUser):
       - Query params: `search` (name/email/phone), `is_active`, `skip`, `limit`
       - Returns paginated user list
       - Use `or_` + `ilike` for search across full_name, email, phone_number

    2. **PUT /admin/users/{user_id}/deactivate** (AdminUser):
       - Set `user.is_active = False`
       - Return updated user

    **Identity Verification Approvals:**

    3. **GET /admin/verifications/identity** (AdminUser):
       - Query params: `status` (pending/approved/rejected), `skip`, `limit`
       - Default: pending only
       - Returns list with user details (join User)

    4. **PUT /admin/verifications/identity/{verification_id}** (AdminUser):
       - Body: `{"action": "approve" | "reject"}`
       - If approve: set status=approved, set user.is_identity_verified=True
       - If reject: set status=rejected
       - Return updated verification

    **Driver Verification Approvals:**

    5. **GET /admin/verifications/driver** (AdminUser):
       - Same pattern as identity verifications
       - Default: pending only

    6. **PUT /admin/verifications/driver/{verification_id}** (AdminUser):
       - If approve: set status=approved, set user.is_driver_verified=True
       - If reject: set status=rejected

    Register in main.py.

    Use existing deps:
    ```python
    from core.deps import DBSession, AdminUser  # AdminUser already exists
    ```
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from routers.admin import router
    routes = sorted([r.path for r in router.routes])
    print(f'Admin routes: {routes}')
    expected = ['/admin/users', '/admin/users/{user_id}/deactivate',
                '/admin/verifications/driver', '/admin/verifications/driver/{verification_id}',
                '/admin/verifications/identity', '/admin/verifications/identity/{verification_id}']
    for e in expected:
        assert e in routes, f'Missing: {e}'
    print('All admin routes OK')
    "
  </verify>
  <done>6 admin endpoints registered for user management and verification approvals</done>
</task>

## Success Criteria
- [ ] GET /admin/users with search + pagination
- [ ] PUT /admin/users/{id}/deactivate
- [ ] GET + PUT /admin/verifications/identity (with auto-flag on approve)
- [ ] GET + PUT /admin/verifications/driver (with auto-flag on approve)
- [ ] All require AdminUser role
