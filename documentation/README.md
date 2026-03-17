# UniRide Project Reference

This folder is a code-derived reference for the current state of the `carpool-mca` repository. It is intended to make future work faster by keeping the important system context in one place.

## What is in this folder

- `tech-stack.md`: languages, frameworks, packages, infrastructure, and external services
- `architecture.md`: repo layout, runtime boundaries, core flows, data model, and integration notes
- `api-endpoints.md`: FastAPI endpoint catalog with auth expectations and behavior notes
- `frontend-pages.md`: Flutter screens and admin web surfaces, including page purpose and navigation
- `features.md`: user-facing capabilities, admin capabilities, and implementation maturity notes
- `implementation-checklist.md`: prioritized delivery backlog for missing or partial product flows, intended for recurring tracking

## High-level project shape

The repo currently contains three product surfaces:

1. `backend_fastapi/`
   FastAPI backend with async SQLAlchemy, JWT auth, OTP flows, ride lifecycle APIs, verification workflows, and admin APIs.
2. `frontend_flutter/`
   Flutter mobile/web client for riders and drivers, with OTP auth, location search, route preview, ride simulation/tracking, profile, settings, and activity screens.
3. `admin-web/`
   Lightweight HTML/CSS/JS admin dashboard that consumes the backend admin APIs for user moderation, verification review, stats, and SOS visibility.

## Important context for later tasks

- The backend is the most complete source of truth for business logic and persistence.
- The Flutter app mixes real API-backed flows with local/demo-only UI flows.
- Several screens and service wrappers still look like prototypes or partial integrations, so future work should confirm whether a flow is expected to be production-backed or only mocked in the UI.
- The backend contains some models and routes that are scaffolded but not fully surfaced in the frontend yet.
