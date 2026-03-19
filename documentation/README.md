# UniRide Project Reference

This folder is a code-derived reference for the current state of the `carpool-mca` repository. It is intended to make future work faster by keeping the important system context in one place.

Last reviewed: 2026-03-19

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
- The Flutter app still mixes real API-backed flows with local/demo-only UI flows, but the main ride discovery, create-ride, history, verification, and live-ride paths are now more tightly coupled to backend APIs than before.
- Several screens and service wrappers still need careful interpretation, especially where a canonical backend-backed flow now coexists with older compatibility wrappers or demo screens.
- The backend contains some models and routes that are scaffolded but not fully surfaced in the frontend yet.
