---
phase: 5
plan: 2
wave: 1
---

# Plan 5.2: Ratings & User Reports

## Objective
Implement post-ride rating system and user reporting. Existing DB models: `Rating` (1-5 stars, rater ≠ rated), `Report` (unique per ride+reporter+reported).

## Context
- @.gsd/SPEC.md — REQ-23, REQ-24, REQ-25
- @backend/app/db/models/ratings.py — Rating model (has ride_id, rater_id, rated_user_id, rating_value, comment)
- @backend/app/db/models/reports.py — Report model (has ride_id, reporter_id, reported_user_id, comment)

## Tasks

<task type="auto">
  <name>Create ratings router</name>
  <files>
    backend/app/schemas/ratings.py
    backend/app/routers/ratings.py
  </files>
  <action>
    1. Create `schemas/ratings.py`:
       ```python
       class RatingCreate(BaseModel):
           rated_user_id: UUID
           rating_value: int = Field(..., ge=1, le=5)
           comment: Optional[str] = None
       
       class RatingRead(BaseModel):
           rating_id: UUID
           ride_id: UUID
           rater_id: UUID
           rated_user_id: UUID
           rating_value: int
           comment: Optional[str]
           created_at: datetime
       
       class UserRatingSummary(BaseModel):
           user_id: UUID
           average_rating: float
           total_ratings: int
       ```

    2. Create `routers/ratings.py` with `prefix="/rides"` for submit and `/users` for summary:
       
       **POST /{ride_id}/ratings** (VerifiedUser):
       - Validate ride exists and is completed
       - Validate rater ≠ rated_user
       - Check for duplicate rating (same rater + rated_user + ride)
       - Create Rating record
       - Return RatingRead

       **GET /users/{user_id}/ratings** (VerifiedUser):
       - Use `func.avg(Rating.rating_value)` and `func.count(Rating.rating_id)`
       - Return UserRatingSummary

    Note: Use two routers or include on a ratings router with no prefix, adding full paths.
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from routers.ratings import router
    routes = [r.path for r in router.routes]
    print(f'Rating routes: {routes}')
    print('Ratings OK')
    "
  </verify>
  <done>POST /rides/{id}/ratings and GET /users/{id}/ratings endpoints registered</done>
</task>

<task type="auto">
  <name>Create reports router</name>
  <files>
    backend/app/schemas/reports.py
    backend/app/routers/reports.py
    backend/app/main.py
  </files>
  <action>
    1. Create `schemas/reports.py`:
       ```python
       class ReportCreate(BaseModel):
           ride_id: UUID
           reported_user_id: UUID
           comment: str = Field(..., min_length=10, max_length=500)
       
       class ReportRead(BaseModel):
           report_id: UUID
           ride_id: UUID
           reporter_id: UUID
           reported_user_id: UUID
           comment: Optional[str]
           created_at: datetime
       ```

    2. Create `routers/reports.py` with `prefix="/reports"`:
       
       **POST /** (VerifiedUser):
       - Validate reporter ≠ reported_user
       - Check unique constraint (ride + reporter + reported)
       - Create Report record
       - Return ReportRead

    3. Register ratings + reports routers in `main.py`:
       ```python
       from routers import ratings as ratings_router, reports as reports_router
       app.include_router(ratings_router.router)
       app.include_router(reports_router.router)
       ```
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from routers.reports import router
    routes = [r.path for r in router.routes]
    assert '/reports/' in routes or '/reports' in routes
    print('Reports OK')
    "
  </verify>
  <done>POST /reports/ endpoint registered, validation enforced</done>
</task>

## Success Criteria
- [ ] Rating submission validates ride completion + no duplicates
- [ ] User rating summary returns average + count
- [ ] Report submission validates unique constraint
- [ ] All routes registered, server starts clean
