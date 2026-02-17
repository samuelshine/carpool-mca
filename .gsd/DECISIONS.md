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

---

## Phase 1 Decisions

**Date:** 2026-02-17

### Auth Flow
- **Both phone AND email verification** required for full identity verification
- Phone OTP at registration (account creation)
- College email verification as separate step (part of identity verification)
- This provides dual verification: phone proves real person, email proves college association

### College Identity Verification — OCR + DB Lookup
- **Approach**: Student photographs their college ID card
- **OCR extraction**: Use OCR to read register number + name from the ID image
- **Cross-verification**: Compare extracted data against a `college_students` database table
- **Implementation**: Pluggable OCR provider pattern (Tesseract for local/free, Google Vision API for production accuracy)
- **College DB**: Pre-loaded table of valid student/faculty records (register number, name, department, role)

### Driver/Vehicle Verification — Pluggable Provider with Demo Fallback
- **Ideal**: Automated verification via third-party APIs (Surepass, HyperVerge, Signzy) wrapping Vahan/Sarathi
- **Reality for academic project**: These APIs cost ₹1-5 per call and require business agreements
- **Decision**: Build with pluggable provider pattern:
  - `ConsoleVerificationProvider` — auto-approves for demo/dev
  - `SurepassProvider` / `HyperVergeProvider` — production integration when ready
- **Vehicle addition gated**: A user CANNOT add a vehicle without verified registration document
- **Driver activation gated**: A user CANNOT create rides without verified driver's license

### Feature Gating (Confirmed)
```
Unverified:    profile, addresses           ❌ rides
Verified:      + search, request, rate      ❌ create rides
Driver:        + create rides, manage       ✅ full access
```

### Database
- **Fresh start**: Existing data can be reset. No migration concerns.
- All tables will be recreated with updated schema.
