---
phase: 3
plan: 2
wave: 1
---

# Plan 3.2: Server Validation & Route Corridor Matching

## Objective
Add route corridor matching (find rides whose route passes near a given point) and validate the complete Phase 3 implementation.

## Context
- @.gsd/SPEC.md — REQ-15, REQ-16
- @backend/app/db/models/rides.py — `start_location`, `end_location` Geography columns
- @backend/app/routers/rides.py — Updated from Plan 3.1 with geospatial search

## Tasks

<task type="auto">
  <name>Add corridor search (along-route matching)</name>
  <files>backend/app/routers/rides.py</files>
  <action>
    Add a "corridor" search mode to the existing `search_rides` endpoint.

    When `search_type == "corridor"`:
    - A passenger provides their pickup point (lat/lng)
    - Find rides where the STRAIGHT LINE from start→end passes within `radius_km` of the passenger's point
    - Implementation: Use `ST_DWithin` against `ST_MakeLine(Ride.start_location, Ride.end_location)` — a line between start and end
    - This approximates "rides that go near me" without requiring full route polylines

    Update the `search_type` Query parameter to accept: `"pickup" | "dropoff" | "corridor"`

    Corridor query:
    ```python
    from geoalchemy2 import func as geo_func
    
    route_line = geo_func.ST_MakeLine(
        geo_func.ST_GeomFromText(geo_func.ST_AsText(Ride.start_location)),
        geo_func.ST_GeomFromText(geo_func.ST_AsText(Ride.end_location))
    )
    # Alternative simpler approach if the above is complex:
    # Check if the point is within radius of EITHER start OR end
    # This is a practical simplification for an MVP
    ```

    NOTE: If `ST_MakeLine` with Geography types proves complex (Geography vs Geometry cast issues), 
    fall back to the simpler approach: check if the passenger's point is within radius of 
    EITHER the start OR the end location. This is a practical MVP approach that covers 
    the most common use case (rides to/from college) and avoids casting complexity.

    The fallback query:
    ```python
    or_(
        geo_func.ST_DWithin(Ride.start_location, search_point, radius_m),
        geo_func.ST_DWithin(Ride.end_location, search_point, radius_m)
    )
    ```
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from routers.rides import router
    routes = [r.path for r in router.routes]
    assert '/rides/search' in routes
    print('Corridor search integrated')
    print('OK')
    "
  </verify>
  <done>Corridor search mode available via `search_type=corridor` parameter</done>
</task>

<task type="auto">
  <name>Validate server startup and all Phase 3 routes</name>
  <files>backend/app/main.py</files>
  <action>
    1. Start the server and verify clean startup
    2. Verify all new routes are registered:
       - GET /rides/search (geospatial)
       - GET /rides/distance
    3. Verify all imports resolve
    4. Run a quick sanity check: import models and verify Geography columns exist
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    import subprocess, signal, sys, time
    proc = subprocess.Popen([sys.executable, '-m', 'uvicorn', 'main:app', '--host', '127.0.0.1', '--port', '8004'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(5)
    proc.send_signal(signal.SIGTERM)
    stdout, stderr = proc.communicate(timeout=5)
    output = stdout.decode() + stderr.decode()
    assert 'Application startup complete' in output, 'Server failed!'
    print('SERVER OK')
    "
  </verify>
  <done>Server starts clean, geospatial endpoints registered</done>
</task>

## Success Criteria
- [ ] `search_type=corridor` finds rides near a point along start→end line (or start/end proximity fallback)
- [ ] Server starts without errors
- [ ] All Phase 3 routes registered
