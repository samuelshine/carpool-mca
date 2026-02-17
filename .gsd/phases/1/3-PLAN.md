---
phase: 1
plan: 3
wave: 2
---

# Plan 1.3: College Identity Verification (OCR + DB Lookup)

## Objective
Implement the college identity verification system: student photographs their college ID card, OCR extracts details, backend cross-verifies register number + name against the college_students table. This is the core feature gate that unlocks ride functionality.

## Context
- @.gsd/SPEC.md — College identity verification requirement
- @.gsd/DECISIONS.md — OCR approach (pluggable: Tesseract/Google Vision), college DB lookup
- @backend/app/db/models/identity_verifications.py — Created in Plan 1.1
- @backend/app/db/models/college_students.py — Created in Plan 1.1
- @backend/app/db/models/users.py — Updated in Plan 1.1 (has is_identity_verified)
- @backend/app/core/deps.py — Existing dependency injection patterns

## Tasks

<task type="auto">
  <name>Create OCR service with pluggable providers</name>
  <files>
    backend/app/services/ocr_service.py [NEW]
  </files>
  <action>
    Create an OCR service following the existing provider pattern (like sms_service.py):
    
    1. Abstract base class `OCRProvider`:
       - `async def extract_text(image_url: str) -> dict` — returns {"name": str, "register_number": str, "raw_text": str}
       
    2. `ConsoleOCRProvider` (for dev/demo):
       - Simulates OCR by returning mock data extracted from the image filename or a fixed response
       - Logs what it would have done
       
    3. `TesseractOCRProvider` (for local/free):
       - Uses pytesseract to extract text from the image
       - Parses patterns to find register number (format like "REG2341001" or similar Christ University pattern)
       - Parses name using common ID card layout patterns
       
    4. `GoogleVisionOCRProvider` (for production accuracy):
       - Stub that calls Google Cloud Vision API
       - Better accuracy but costs money
       
    5. Factory function `get_ocr_provider()` — selects based on `OCR_PROVIDER` env setting
    
    Add to config.py:
    - `OCR_PROVIDER: str = "console"` — default to console for dev
    
    Pattern matching hints for Christ University IDs:
    - Register numbers typically follow patterns like college roll numbers
    - Name is usually prominently displayed
    - The OCR output should be fuzzy-matchable (handle OCR errors)
  </action>
  <verify>python -c "from backend.app.services.ocr_service import get_ocr_provider; p = get_ocr_provider(); print(type(p).__name__)"</verify>
  <done>OCR service exists with 3 providers (console, tesseract, google_vision). Factory works.</done>
</task>

<task type="auto">
  <name>Create identity verification router and service</name>
  <files>
    backend/app/services/verification_service.py [NEW]
    backend/app/routers/verification.py [NEW]
    backend/app/schemas/verification.py [NEW]
    backend/app/main.py
  </files>
  <action>
    1. Create `schemas/verification.py`:
       - IdentityVerificationRequest: college_id_image_url (str)
       - IdentityVerificationResponse: id, status, extracted_name, extracted_register_number, message
       - IdentityVerificationStatus: id, status, submitted_at, reviewed_at
       - DriverVerificationRequest: license_number, license_image_url, vehicle_registration_number, registration_image_url
       - DriverVerificationResponse: id, status, message
       
    2. Create `services/verification_service.py`:
       - `verify_college_identity(db, user_id, image_url)`:
         a. Call OCR provider to extract name + register_number from image
         b. Query college_students table for matching register_number
         c. If register_number found, fuzzy-match the name (use difflib.SequenceMatcher, threshold 0.8)
         d. If both match: Create IdentityVerification(status=verified), update user.is_identity_verified=True, update user.college_id
         e. If register_number found but name doesn't match: status=pending (needs admin review)
         f. If register_number not found: status=rejected with note "Register number not found in college database"
         g. Return the verification record
         
    3. Create `routers/verification.py`:
       - `POST /verification/identity` — Submit college ID for verification (requires authenticated user)
         - Calls verification_service.verify_college_identity
         - Returns verification status
       - `GET /verification/identity/status` — Check current verification status (requires authenticated user)
         - Returns latest verification record for the user
       - `POST /verification/email` — Trigger college email verification (moved from auth router)
         - Requires authenticated user
         - Validates christuniversity.in domain
         - Creates OTP session, sends email
       - `POST /verification/email/verify` — Verify email OTP
         - On success: update user.email, user.is_email_verified = True
         
    4. Register the router in `main.py`:
       - `app.include_router(verification.router, prefix="/verification", tags=["Verification"])`
    
    IMPORTANT: Identity verification should work even if email is not yet verified. They are independent verification tracks.
  </action>
  <verify>grep "verification" backend/app/main.py</verify>
  <done>Verification router registered in main.py. Submit + status endpoints work. OCR + DB lookup pipeline functional.</done>
</task>

<task type="auto">
  <name>Seed college students database</name>
  <files>
    backend/seed_data.py
  </files>
  <action>
    Update or create seed_data.py to populate the college_students table with sample data:
    
    1. Add at least 20 sample student records with realistic Christ University data:
       - Varied register numbers (matching Christ University patterns)
       - Mix of departments (Computer Science, Electrical, Commerce, etc.)
       - Mix of programs (MCA, BCA, MBA, B.Tech, etc.)
       - Mix of roles (student, faculty)
       
    2. Include the user's own data if possible (or a clear placeholder for them to fill)
    
    3. Make it idempotent (check if records exist before inserting, or use upsert)
    
    This seed data is critical for testing the identity verification flow.
  </action>
  <verify>grep -c "CollegeStudent" backend/seed_data.py</verify>
  <done>seed_data.py populates college_students with 20+ entries. Script is idempotent.</done>
</task>

## Success Criteria
- [ ] OCR service extracts name + register number from image (console provider for demo)
- [ ] Verification service cross-checks against college_students table
- [ ] `POST /verification/identity` accepts image URL, runs OCR, verifies, returns status
- [ ] `GET /verification/identity/status` returns current verification state
- [ ] Email verification moved to `/verification/email` endpoints
- [ ] User.is_identity_verified set to True on successful verification
- [ ] College students table seeded with test data
