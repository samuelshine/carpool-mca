---
phase: 6
plan: 3
wave: 2
---

# Plan 6.3: Full Project Validation

## Objective
Final validation of the entire backend — all phases, all routes, server startup, and a complete route inventory. This is the project completion checkpoint.

## Context
- @backend/app/main.py — Full application
- @.gsd/ROADMAP.md — All phase goals

## Tasks

<task type="auto">
  <name>Full project validation</name>
  <files>backend/app/main.py</files>
  <action>
    1. Verify server starts without any errors
    2. Generate a complete route inventory grouped by feature area
    3. Verify all phases' deliverables are present:
       - Phase 1: Auth (auth/*, users/me)
       - Phase 2: Rides lifecycle (rides/*)
       - Phase 3: Geospatial (rides/search, rides/distance)
       - Phase 4: WebSocket + FCM (ws/*, users/me/fcm-token)
       - Phase 5: Fare, ratings, reports, emergency contacts, SOS
       - Phase 6: Admin (admin/*), CORS
    4. Print final route count
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    import subprocess, signal, sys, time
    proc = subprocess.Popen([sys.executable, '-m', 'uvicorn', 'main:app', '--host', '127.0.0.1', '--port', '8010'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(5)
    proc.send_signal(signal.SIGTERM)
    stdout, stderr = proc.communicate(timeout=5)
    output = stdout.decode() + stderr.decode()
    assert 'Application startup complete' in output, f'FAIL: {output}'

    from main import app
    routes = sorted(set(r.path for r in app.routes if hasattr(r, 'path') and r.path != '/'))
    print(f'Total routes: {len(routes)}')
    print()
    for r in routes:
        print(f'  {r}')
    print()
    print('=== PROJECT COMPLETE ===')
    "
  </verify>
  <done>Server starts clean, all routes registered, complete route inventory generated</done>
</task>

## Success Criteria
- [ ] Server starts without errors
- [ ] All 6 phases' deliverables present
- [ ] Complete route inventory printed
- [ ] CORS middleware active
