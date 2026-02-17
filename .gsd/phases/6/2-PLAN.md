---
phase: 6
plan: 2
wave: 1
---

# Plan 6.2: Admin Reports, Stats & CORS

## Objective
Complete the admin API with report management and platform stats, plus add CORS middleware for production readiness.

## Context
- @.gsd/SPEC.md — REQ-31, REQ-32, REQ-33
- @backend/app/db/models/reports.py — Report model
- @backend/app/main.py — FastAPI app (add CORS middleware)

## Tasks

<task type="auto">
  <name>Add admin report management + platform stats to admin router</name>
  <files>backend/app/routers/admin.py</files>
  <action>
    Add to existing admin router:

    **Report Management:**

    7. **GET /admin/reports** (AdminUser):
       - Query params: `skip`, `limit`
       - Returns all reports with reporter/reported user names
       - Join User twice (reporter + reported)

    8. **PUT /admin/reports/{report_id}** (AdminUser):
       - Body: `{"action": "reviewed" | "dismissed"}`
       - For now, just acknowledge — no status column on Report model
       - Return the report as-is (mark as reviewed in response only)

    **Platform Statistics:**

    9. **GET /admin/stats** (AdminUser):
       - Total users
       - Total rides (by status breakdown)
       - Total reports
       - Active users (is_active=True)
       - Verified users count (is_identity_verified=True)
       - Verified drivers count (is_driver_verified=True)
       - Return as JSON dict
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from routers.admin import router
    routes = [r.path for r in router.routes]
    assert '/admin/reports' in routes
    assert '/admin/reports/{report_id}' in routes
    assert '/admin/stats' in routes
    print('Admin reports + stats OK')
    "
  </verify>
  <done>GET /admin/reports, PUT /admin/reports/{id}, GET /admin/stats endpoints added</done>
</task>

<task type="auto">
  <name>Add CORS middleware</name>
  <files>backend/app/main.py</files>
  <action>
    Add CORS middleware to main.py:

    ```python
    from fastapi.middleware.cors import CORSMiddleware

    # After app creation
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Configure per environment in production
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    ```

    Place this right after `app = FastAPI(...)` and before router includes.
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from main import app
    middleware_names = [m.cls.__name__ for m in app.user_middleware]
    assert 'CORSMiddleware' in middleware_names, f'Missing CORS, got: {middleware_names}'
    print('CORS OK')
    "
  </verify>
  <done>CORS middleware configured on FastAPI app</done>
</task>

## Success Criteria
- [ ] GET /admin/reports with user details
- [ ] PUT /admin/reports/{id} acknowledges report
- [ ] GET /admin/stats returns platform metrics
- [ ] CORS middleware active
