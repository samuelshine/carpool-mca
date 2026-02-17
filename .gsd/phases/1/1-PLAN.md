---
phase: 1
plan: 1
wave: 1
---

# Plan 1.1: Database Schema Reset & New Models

## Objective
Reset the database schema and create/update all models needed for the verification system. This is Wave 1 — everything else depends on these models existing.

## Context
- @.gsd/SPEC.md — Tiered verification flow
- @.gsd/DECISIONS.md — Phase 1 decisions (OCR, pluggable providers, feature gating)
- @.gsd/ARCHITECTURE.md — Current 13 models, conventions (UUID PKs, timestamps)
- @backend/app/db/models/users.py — Existing User model
- @backend/app/db/base.py — Base class
- @backend/app/db/enums.py — Existing enums
- @backend/app/init_db.py — DB initialization script

## Tasks

<task type="auto">
  <name>Update User model with verification fields</name>
  <files>backend/app/db/models/users.py, backend/app/db/enums.py</files>
  <action>
    Modify the User model to support the tiered verification system:
    
    1. Add to `enums.py`:
       - `VerificationStatusEnum`: pending, submitted, verified, rejected
       
    2. Update `User` model in `users.py`:
       - Add `is_identity_verified: bool = False` — set True after college ID verification
       - Add `is_driver_verified: bool = False` — set True after license verification  
       - Add `is_admin: bool = False` — for admin role
       - Make `email` nullable (not required at registration anymore)
       - Make `college_id` nullable (populated after identity verification)
       - Keep `is_phone_verified`, `is_email_verified`, `is_active`
       
    IMPORTANT: Keep ALL existing columns and relationships intact. Only ADD new columns and modify nullable constraints.
  </action>
  <verify>python -c "from backend.app.db.models.users import User; print([c.name for c in User.__table__.columns])"</verify>
  <done>User model has is_identity_verified, is_driver_verified, is_admin columns. email and college_id are nullable.</done>
</task>

<task type="auto">
  <name>Create new verification models</name>
  <files>
    backend/app/db/models/identity_verifications.py [NEW]
    backend/app/db/models/driver_verifications.py [NEW]
    backend/app/db/models/saved_addresses.py [NEW]
    backend/app/db/models/college_students.py [NEW]
  </files>
  <action>
    Create 4 new models following existing conventions (UUID PK, timestamps, func.now()):
    
    1. `IdentityVerification` (identity_verifications table):
       - id: UUID PK
       - user_id: FK → users.user_id
       - college_id_image_url: String (URL to uploaded ID image)
       - extracted_name: String nullable (OCR result)
       - extracted_register_number: String nullable (OCR result)
       - matched_student_id: FK → college_students.id nullable
       - status: VerificationStatusEnum (default: submitted)
       - admin_notes: String nullable
       - submitted_at, reviewed_at: timestamps
       
    2. `DriverVerification` (driver_verifications table):
       - id: UUID PK
       - user_id: FK → users.user_id
       - license_number: String
       - license_image_url: String
       - vehicle_registration_number: String
       - registration_image_url: String
       - status: VerificationStatusEnum (default: submitted)
       - admin_notes: String nullable
       - submitted_at, reviewed_at: timestamps
       
    3. `SavedAddress` (saved_addresses table):
       - id: UUID PK
       - user_id: FK → users.user_id
       - label: String (e.g., "Home", "College")
       - address: String (full text address)
       - latitude: Float
       - longitude: Float
       - is_default: Boolean (default False)
       - created_at: timestamp
       
    4. `CollegeStudent` (college_students table):
       - id: UUID PK
       - register_number: String UNIQUE
       - full_name: String
       - department: String nullable
       - program: String nullable (e.g., "MCA", "BCA")
       - role: String (default "student") — student or faculty
       - is_active: Boolean (default True)
       
    All models must import Base from db.base and follow the pattern in existing models.
  </action>
  <verify>
    python -c "
    from backend.app.db.models.identity_verifications import IdentityVerification
    from backend.app.db.models.driver_verifications import DriverVerification
    from backend.app.db.models.saved_addresses import SavedAddress
    from backend.app.db.models.college_students import CollegeStudent
    print('All models import successfully')
    "
  </verify>
  <done>All 4 new models exist, import without errors, and have the specified columns.</done>
</task>

<task type="auto">
  <name>Update init_db.py and reset database</name>
  <files>backend/app/init_db.py</files>
  <action>
    1. Add imports for ALL new models (IdentityVerification, DriverVerification, SavedAddress, CollegeStudent)
    2. Ensure they are registered with Base.metadata
    3. Add `drop_all` BEFORE `create_all` since we're doing a fresh reset
    4. Add a flag/comment to remove drop_all after initial reset
    
    Do NOT actually run the script — just update it. The user will run it when ready.
  </action>
  <verify>grep -c "import" backend/app/init_db.py</verify>
  <done>init_db.py imports all 17+ models and will drop+recreate all tables on run.</done>
</task>

## Success Criteria
- [ ] User model has 3 new boolean fields (is_identity_verified, is_driver_verified, is_admin)
- [ ] User.email and User.college_id are nullable
- [ ] 4 new models created: IdentityVerification, DriverVerification, SavedAddress, CollegeStudent
- [ ] VerificationStatusEnum added to enums.py
- [ ] init_db.py imports all models and supports fresh reset
