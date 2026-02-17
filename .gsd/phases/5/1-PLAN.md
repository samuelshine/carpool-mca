---
phase: 5
plan: 1
wave: 1
---

# Plan 5.1: Fare Estimation & Splitting

## Objective
Implement fare calculation endpoint and fare splitting among ride participants. Uses the distance between ride start/end (via PostGIS `ST_Distance` from Phase 3) and a configurable per-km rate.

## Context
- @.gsd/SPEC.md — REQ-21, REQ-22
- @backend/app/db/models/fare_estimates.py — FareEstimate model (exists)
- @backend/app/db/models/ride_participants.py — RideParticipant model
- @backend/app/routers/rides.py — Existing rides router

## Tasks

<task type="auto">
  <name>Create fare router with estimation + splitting</name>
  <files>
    backend/app/schemas/fare.py
    backend/app/routers/fare.py
    backend/app/main.py
  </files>
  <action>
    1. Create `schemas/fare.py`:
       ```python
       class FareEstimateRead(BaseModel):
           estimate_id: UUID
           ride_id: UUID
           distance_km: float
           estimated_fare: float
           calculated_at: datetime
       
       class FareSplitRead(BaseModel):
           total_fare: float
           distance_km: float
           participant_count: int
           per_person: float
       ```

    2. Create `routers/fare.py` with `prefix="/rides"`:
       
       **GET /{ride_id}/fare** — Calculate and store fare estimate:
       - Get ride's start_location and end_location
       - Use `func.ST_Distance(start, end)` to get distance in meters → convert to km
       - Calculate fare: `distance_km * FARE_PER_KM` (use 10.0 as default rate)
       - Upsert into FareEstimate table (one per ride)
       - Return FareEstimateRead

       **GET /{ride_id}/fare/split** — Split fare among participants:
       - Get the fare estimate (or calculate it)
       - Count confirmed participants (RideParticipant)
       - Split: `estimated_fare / (participant_count + 1)` (include driver)
       - Return FareSplitRead

    3. Register in `main.py`:
       ```python
       from routers import fare as fare_router
       app.include_router(fare_router.router)
       ```
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from routers.fare import router
    routes = [r.path for r in router.routes]
    assert '/rides/{ride_id}/fare' in routes
    assert '/rides/{ride_id}/fare/split' in routes
    print('Fare routes OK')
    "
  </verify>
  <done>GET /rides/{id}/fare and GET /rides/{id}/fare/split endpoints registered</done>
</task>

## Success Criteria
- [ ] Fare calculation uses PostGIS distance
- [ ] Fare stored in FareEstimate table
- [ ] Split divides among participants + driver
- [ ] Server starts clean
