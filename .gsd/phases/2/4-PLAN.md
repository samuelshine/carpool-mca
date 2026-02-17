---
phase: 2
plan: 4
wave: 2
---

# Plan 2.4: Server Validation & Architecture Update

## Objective
Verify the complete Phase 2 implementation starts cleanly, all new routes are registered, and update the architecture documentation to reflect the new endpoints and state machine.

## Context
- All Plan 2.1–2.3 files
- @backend/app/main.py — Router registration
- @.gsd/ARCHITECTURE.md — To update

## Tasks

<task type="auto">
  <name>Validate server startup and all routes</name>
  <files>backend/app/main.py</files>
  <action>
    1. Start the server and verify it boots without errors:
       ```
       cd backend/app && source ../venv/bin/activate
       python3 -c "
       import subprocess, signal, sys, time
       proc = subprocess.Popen([sys.executable, '-m', 'uvicorn', 'main:app', '--host', '127.0.0.1', '--port', '8003'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
       time.sleep(5)
       proc.send_signal(signal.SIGTERM)
       stdout, stderr = proc.communicate(timeout=5)
       output = stdout.decode() + stderr.decode()
       print(output)
       assert 'Application startup complete' in output
       print('SERVER OK')
       "
       ```
    
    2. Verify all Phase 2 routes are listed:
       ```
       python3 -c "
       from main import app
       routes = sorted(set(r.path for r in app.routes if hasattr(r, 'path')))
       phase2 = [r for r in routes if 'request' in r or 'start' in r or 'complete' in r or 'cancel' in r or 'participant' in r or 'my-rides' in r or 'driver-profile' in r]
       for r in phase2: print(f'  ✓ {r}')
       assert len(phase2) >= 8, f'Expected 8+ Phase 2 routes, found {len(phase2)}'
       print(f'\\nTotal Phase 2 routes: {len(phase2)}')
       print('ROUTES OK')
       "
       ```
  </action>
  <verify>Server starts clean and all Phase 2 routes are registered</verify>
  <done>Server boots, 8+ new Phase 2 routes visible</done>
</task>

<task type="auto">
  <name>Update ARCHITECTURE.md</name>
  <files>.gsd/ARCHITECTURE.md</files>
  <action>
    Update ARCHITECTURE.md to reflect Phase 2 additions:
    - Update the architecture diagram to include the verification and new routers
    - Update the Rides section with the full lifecycle and new endpoints
    - Add Driver Profiles section
    - Update the Data Flow section for ride lifecycle
    - Update endpoint counts and line counts
    - Mark resolved technical debt items (RideRequest, RideParticipant, RideHistory, DriverProfile now have endpoints)
  </action>
  <verify>cat .gsd/ARCHITECTURE.md | grep -c "ride_requests\|RideRequest\|driver-profiles\|start\|complete\|cancel"</verify>
  <done>Architecture doc reflects current state accurately</done>
</task>

## Success Criteria
- [ ] Server starts without errors after all Phase 2 changes
- [ ] All 8+ new endpoints are registered and appear in route listing
- [ ] ARCHITECTURE.md reflects the current state of the codebase
