# REQUIREMENTS.md

> Derived from SPEC.md — Revised 2026-02-16

## Auth & Account
| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-01 | Phone OTP registration (no email OTP) — send, verify, create account | Goal 1 | Rework |
| REQ-02 | Phone OTP login — send, verify, return access token | Goal 1 | Existing |
| REQ-03 | JWT access token with user identity | Goal 1 | Existing |

## Identity & Driver Verification
| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-04 | College identity verification — submit college ID, validate against DB | Goal 2 | Pending |
| REQ-05 | Verification status gating — block unverified users from ride features | Goal 2 | Pending |
| REQ-06 | Driver license verification — upload + verify license | Goal 3 | Pending |
| REQ-07 | Vehicle registration verification — upload + verify registration | Goal 3 | Pending |
| REQ-08 | Only verified drivers can create rides | Goal 3 | Pending |

## Ride Lifecycle
| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-09 | Ride creation with PostGIS locations | Goal 4 | Existing |
| REQ-10 | Ride request/accept/reject workflow | Goal 4 | Pending |
| REQ-11 | Ride participant management (join after accept, leave) | Goal 4 | Pending |
| REQ-12 | Ride status transitions (open → ongoing → completed/cancelled) | Goal 4 | Pending |
| REQ-13 | Ride completion with history recording | Goal 4 | Pending |
| REQ-14 | User's ride history (as driver + passenger) | Goal 4 | Pending |

## Geospatial & Matching
| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-15 | PostGIS proximity search — find rides near a given point | Goal 5 | Pending |
| REQ-16 | Route-based matching — rides along driver's route without deviation | Goal 5 | Pending |

## Real-Time & Notifications
| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-17 | WebSocket endpoint for live driver location streaming | Goal 6 | Pending |
| REQ-18 | Ride status change broadcasts via WebSocket | Goal 6 | Pending |
| REQ-19 | FCM device token registration endpoint | Goal 8 | Pending |
| REQ-20 | Push notification triggers for key events | Goal 8 | Pending |

## Financial & Social
| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-21 | Distance-based fare calculation | Goal 7 | Pending |
| REQ-22 | Fare splitting among confirmed participants | Goal 7 | Pending |
| REQ-23 | Post-ride rating (1-5 scale, mutual) | Goal 9 | Pending |
| REQ-24 | User reporting with moderation support | Goal 9 | Pending |

## Safety & Convenience
| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-25 | Emergency contacts CRUD | Goal 10 | Pending |
| REQ-26 | SOS alert endpoint (demo — stores in DB) | Goal 10 | Pending |
| REQ-27 | Saved addresses CRUD (pickup/drop locations) | Goal 11 | Pending |
| REQ-28 | Driver profile with vehicle linkage + daily seat limits | Goal 13 | Pending |

## Admin
| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-29 | Admin: list/search/deactivate users | Goal 12 | Pending |
| REQ-30 | Admin: approve/reject identity verifications | Goal 12 | Pending |
| REQ-31 | Admin: approve/reject driver verifications | Goal 12 | Pending |
| REQ-32 | Admin: view and act on reports | Goal 12 | Pending |
| REQ-33 | Admin: platform statistics | Goal 12 | Pending |
