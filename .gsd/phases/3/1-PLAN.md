---
phase: 3
plan: 1
wave: 1
---

# Plan 3.1: Proximity-Based Ride Search

## Objective
Replace the date-only ride search with a full geospatial search: find open rides whose start OR end point is within a configurable radius of a given coordinate. Uses PostGIS `ST_DWithin` for performant spatial queries.

## Context
- @.gsd/SPEC.md — REQ-15, REQ-16
- @.gsd/ROADMAP.md — Phase 3 deliverables
- @backend/app/db/models/rides.py — `start_location`, `end_location` as `Geography(POINT, srid=4326)`
- @backend/app/schemas/common.py — `LocationPoint` with WKB→lat/lng converter
- @backend/app/schemas/rides.py — existing `RideRead` schema
- @backend/app/routers/rides.py — existing `search_rides` endpoint to rework

## Tasks

<task type="auto">
  <name>Rework search_rides with PostGIS proximity</name>
  <files>backend/app/routers/rides.py</files>
  <action>
    Replace the current `GET /rides/` `search_rides` endpoint with a geospatial version:

    ```python
    @router.get("/search", response_model=List[RideRead])
    async def search_rides(
        current_user: VerifiedUser,
        db: DBSession,
        lat: float = Query(..., ge=-90, le=90, description="Search center latitude"),
        lng: float = Query(..., ge=-180, le=180, description="Search center longitude"),
        radius_km: float = Query(5.0, ge=0.5, le=50, description="Search radius in km"),
        ride_date: Optional[date] = None,
        search_type: str = Query("pickup", description="Search near 'pickup' (start) or 'dropoff' (end)")
    ):
    ```

    Implementation:
    1. Import `from geoalchemy2 import func as geo_func` (for `ST_DWithin`, `ST_Distance`)
    2. Convert radius_km to meters: `radius_m = radius_km * 1000`
    3. Create a WKT point from lat/lng: `search_point = f"SRID=4326;POINT({lng} {lat})"`
    4. Build query:
       - If `search_type == "pickup"`: filter by `geo_func.ST_DWithin(Ride.start_location, search_point, radius_m)`
       - If `search_type == "dropoff"`: filter by `geo_func.ST_DWithin(Ride.end_location, search_point, radius_m)`
       - Always filter: `Ride.status == open`
       - Optional filter: `ride_date`
    5. Order by distance (nearest first): `.order_by(geo_func.ST_Distance(location_col, search_point))`
    6. Return results

    IMPORTANT: Keep the old `GET /rides/` endpoint as a basic listing fallback (no geospatial).
    Add the NEW search as `GET /rides/search` to avoid breaking existing clients.

    NOTE on ST_DWithin with Geography:
    - Geography type uses METERS natively (unlike Geometry which uses SRID units)
    - `ST_DWithin(geog, geog, distance_in_meters)` is correct
    - No need for `ST_Transform` or CRS conversion
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from routers.rides import router
    routes = [r.path for r in router.routes]
    assert '/rides/search' in routes, f'Missing /rides/search, got {routes}'
    print('Route OK')
    "
  </verify>
  <done>`GET /rides/search` endpoint exists with lat, lng, radius_km, ride_date, search_type parameters</done>
</task>

<task type="auto">
  <name>Add distance calculation utility</name>
  <files>backend/app/schemas/rides.py, backend/app/routers/rides.py</files>
  <action>
    1. Add a `RideSearchResult` schema to `schemas/rides.py`:
       ```python
       class RideSearchResult(RideRead):
           """Ride search result with distance from search point."""
           distance_km: float = Field(..., description="Distance from search point in km")
       ```

    2. Update the `search_rides` endpoint to return `List[RideSearchResult]` instead of `List[RideRead]`:
       - Add `geo_func.ST_Distance(location_col, search_point).label("distance")` to the select
       - Map the distance (meters) to km: `distance_km = round(row.distance / 1000, 2)`
       - Return `RideSearchResult` objects with the calculated distance

    3. Add a standalone distance endpoint for fare estimation:
       ```python
       @router.get("/distance", response_model=dict)
       async def calculate_distance(
           current_user: VerifiedUser,
           from_lat: float = Query(...), from_lng: float = Query(...),
           to_lat: float = Query(...), to_lng: float = Query(...)
       ):
       ```
       - Use `geo_func.ST_Distance` between two points
       - Return `{"distance_km": float, "from": {...}, "to": {...}}`
       - This will be used by Phase 5 fare calculation
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from schemas.rides import RideSearchResult
    from routers.rides import router
    routes = [r.path for r in router.routes]
    assert '/rides/distance' in routes, f'Missing /rides/distance, got {routes}'
    print('Schema + Route OK')
    "
  </verify>
  <done>`RideSearchResult` schema importable with `distance_km` field, `/rides/distance` endpoint exists</done>
</task>

## Success Criteria
- [ ] `GET /rides/search?lat=...&lng=...&radius_km=...` returns rides sorted by distance
- [ ] `GET /rides/search` supports `search_type=pickup|dropoff` and optional `ride_date`
- [ ] `RideSearchResult` includes `distance_km` field
- [ ] `GET /rides/distance?from_lat=...&from_lng=...&to_lat=...&to_lng=...` returns distance in km
- [ ] Old `GET /rides/` endpoint still works for basic listing
