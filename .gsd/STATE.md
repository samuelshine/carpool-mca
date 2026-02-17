# STATE.md — Project Memory

## Last Session Summary
Phase 1 planned (2026-02-17).
- 5 execution plans created across 3 waves
- Wave 1: DB schema + auth rework
- Wave 2: College ID verification (OCR) + driver verification
- Wave 3: Feature gating + saved addresses

## Current Phase
Phase 1: Auth Rework & Verification System — 📋 Planned

## Next Action
`/execute 1` — Execute all Phase 1 plans

## Context
- Backend-only project (Flutter frontend by separate team)
- Existing endpoints: Auth (7), Users (2), Vehicles (3), Rides (3)
- Key tech: FastAPI + async SQLAlchemy 2.0 + PostgreSQL/PostGIS (Supabase)
- DB can be reset (no existing users)
- Auth: Reworking to phone-only registration + separate identity/driver verification
- Verification tier: Unverified → Verified student/faculty → Verified driver
- OCR: Pluggable (console for demo, tesseract, google vision)
- Driver verification: Pluggable (console for demo, Surepass for prod)
