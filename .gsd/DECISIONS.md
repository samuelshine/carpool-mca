# DECISIONS.md — Architecture Decision Records

> Decisions made during the project lifecycle.

| ID | Date | Decision | Rationale | Status |
|----|------|----------|-----------|--------|
| ADR-01 | 2026-02-16 | Passwordless OTP auth only | College students prefer phone-based login; no password management overhead | Accepted |
| ADR-02 | 2026-02-16 | Supabase PostgreSQL + PostGIS | Free tier for academic use, PostGIS built-in for geospatial matching | Accepted |
| ADR-03 | 2026-02-16 | External payments (cash/UPI) | Avoids payment gateway complexity; students settle outside the app | Accepted |
| ADR-04 | 2026-02-16 | Face verification deferred | Not critical for launch; complexity vs. value tradeoff | Accepted |
| ADR-05 | 2026-02-16 | SOS demo only (no dispatch) | Stores alert in DB; actual emergency contact notification deferred | Accepted |
| ADR-06 | 2026-02-16 | WebSocket for real-time tracking | Lightweight, built-in FastAPI support, best for live location | Accepted |
| ADR-07 | 2026-02-16 | Firebase Cloud Messaging for push | Industry standard, Flutter has excellent FCM support | Accepted |
| ADR-08 | 2026-02-16 | Phone-only registration (remove email OTP) | Simplifies onboarding; college identity verified separately | Accepted |
| ADR-09 | 2026-02-16 | Tiered verification: college ID → driver | Feature gating ensures only verified users access rides; drivers need additional license/registration proof | Accepted |
| ADR-10 | 2026-02-16 | Saved addresses feature | Convenience for repeat commuters; reduces friction in ride creation/search | Accepted |
