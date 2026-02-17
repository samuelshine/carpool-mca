---
phase: 5
plan: 3
wave: 2
---

# Plan 5.3: Emergency Contacts, SOS & Phase Validation

## Objective
CRUD for emergency contacts, SOS alert endpoint (demo), and full Phase 5 validation.

## Context
- @.gsd/SPEC.md — REQ-25, REQ-26
- @backend/app/db/models/emergency_contacts.py — EmergencyContact model (contact_name, contact_phone, relationship)
- @backend/app/db/models/sos_alerts.py — SOSAlert model (user_id, ride_id, location POINT)
- @backend/app/schemas/emergency_contacts.py — May already exist

## Tasks

<task type="auto">
  <name>Create emergency contacts CRUD + SOS endpoint</name>
  <files>
    backend/app/schemas/emergency_contacts.py
    backend/app/routers/emergency_contacts.py
    backend/app/schemas/sos.py
    backend/app/routers/sos.py
    backend/app/main.py
  </files>
  <action>
    1. Check if `schemas/emergency_contacts.py` exists — update or create:
       ```python
       class EmergencyContactCreate(BaseModel):
           contact_name: str = Field(..., max_length=100)
           contact_phone: str = Field(..., max_length=15)
           relationship: str = Field(..., max_length=50)
       
       class EmergencyContactRead(BaseModel):
           contact_id: UUID
           user_id: UUID
           contact_name: str
           contact_phone: str
           relationship: str
       
       class EmergencyContactUpdate(BaseModel):
           contact_name: Optional[str] = None
           contact_phone: Optional[str] = None
           relationship: Optional[str] = None
       ```

    2. Create `routers/emergency_contacts.py` with `prefix="/emergency-contacts"`:
       
       **POST /** — Add emergency contact (VerifiedUser, max 3 per user)
       **GET /** — List my emergency contacts (VerifiedUser)
       **PUT /{contact_id}** — Update contact (owner only)
       **DELETE /{contact_id}** — Delete contact (owner only)

    3. Create `schemas/sos.py`:
       ```python
       class SOSAlertCreate(BaseModel):
           ride_id: UUID
           latitude: float = Field(..., ge=-90, le=90)
           longitude: float = Field(..., ge=-180, le=180)
       
       class SOSAlertRead(BaseModel):
           alert_id: UUID
           user_id: UUID
           ride_id: UUID
           triggered_at: datetime
       ```

    4. Create `routers/sos.py` with `prefix="/sos"`:
       
       **POST /** — Create SOS alert (VerifiedUser):
       - Validate ride exists
       - Store SOS with user's location as Geography POINT
       - Print to console: `[SOS ALERT] User {id} — Ride {id} — Location: {lat},{lng}`
       - Return SOSAlertRead

    5. Register both routers in `main.py`
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from routers.emergency_contacts import router as ec_router
    from routers.sos import router as sos_router
    ec_routes = [r.path for r in ec_router.routes]
    sos_routes = [r.path for r in sos_router.routes]
    print(f'Emergency: {ec_routes}')
    print(f'SOS: {sos_routes}')
    print('OK')
    "
  </verify>
  <done>CRUD endpoints for emergency contacts + POST /sos/ endpoint registered</done>
</task>

<task type="auto">
  <name>Full Phase 5 validation</name>
  <files>backend/app/main.py</files>
  <action>
    1. Verify server starts clean
    2. Verify ALL Phase 5 routes registered:
       - GET /rides/{id}/fare
       - GET /rides/{id}/fare/split
       - POST /rides/{id}/ratings
       - GET /users/{id}/ratings
       - POST /reports/
       - CRUD /emergency-contacts/
       - POST /sos/
    3. Verify all model imports resolve
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    import subprocess, signal, sys, time
    proc = subprocess.Popen([sys.executable, '-m', 'uvicorn', 'main:app', '--host', '127.0.0.1', '--port', '8008'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(5)
    proc.send_signal(signal.SIGTERM)
    stdout, stderr = proc.communicate(timeout=5)
    output = stdout.decode() + stderr.decode()
    assert 'Application startup complete' in output, f'FAIL: {output}'
    print('SERVER OK — Phase 5 verified')
    "
  </verify>
  <done>Server starts clean, all Phase 5 routes registered</done>
</task>

## Success Criteria
- [ ] Emergency contacts CRUD (max 3 per user)
- [ ] SOS alert stores location + prints to console
- [ ] Server starts clean with all Phase 5 routes
- [ ] All Phase 5 deliverables from ROADMAP satisfied
