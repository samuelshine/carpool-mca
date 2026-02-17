---
phase: 1
plan: 2
wave: 1
---

# Plan 1.2: Auth Rework — Phone-Only Registration

## Objective
Simplify registration to phone OTP only. Remove the email OTP requirement from the registration flow. Email verification becomes a separate post-registration step (handled in Plan 1.3). Keep login flow as-is.

## Context
- @.gsd/SPEC.md — Phone-only account creation
- @.gsd/DECISIONS.md — Phase 1 auth flow decisions
- @backend/app/routers/auth.py — Current 5-step registration + login
- @backend/app/schemas/auth.py — Current auth schemas
- @backend/app/core/security.py — JWT token types
- @backend/app/schemas/users.py — UserCreate, UserRead schemas

## Tasks

<task type="auto">
  <name>Simplify registration schemas</name>
  <files>
    backend/app/schemas/auth.py
    backend/app/schemas/users.py
  </files>
  <action>
    1. In `schemas/auth.py`:
       - Keep PhoneSendOTPRequest, PhoneSendOTPResponse, PhoneVerifyOTPRequest, PhoneVerifyOTPResponse as-is
       - Keep LoginSendOTPRequest, LoginSendOTPResponse, LoginVerifyOTPRequest, LoginResponse as-is
       - Keep EmailSendOTPRequest, EmailSendOTPResponse, EmailVerifyOTPRequest, EmailVerifyOTPResponse — but move them to a new section "EMAIL VERIFICATION (Post-Registration)" and remove the `phone_verified_token` field from EmailSendOTPRequest (user will be authenticated via access token instead)
       - Modify RegisterRequest:
         - Keep `phone_verified_token` 
         - REMOVE `email_verified_token` (no longer required at registration)
         - Keep `full_name`, `gender`
         - REMOVE `college_id` (comes from identity verification later)
         - `community` stays optional
       - Update UserResponse to include new verification flags: `is_identity_verified`, `is_driver_verified`
       - Make `email` and `college_id` Optional in UserResponse
       
    2. In `schemas/users.py`:
       - Make `email` Optional in UserBase
       - Make `college_id` Optional in UserBase
       - Add `is_identity_verified`, `is_driver_verified`, `is_email_verified`, `is_phone_verified` to UserRead
       
    AVOID: Deleting any schema classes that might still be needed. Mark deprecated ones with comments.
  </action>
  <verify>python -c "from backend.app.schemas.auth import RegisterRequest, UserResponse; r = RegisterRequest(phone_verified_token='t', full_name='Test', gender='male'); print('Schema OK')"</verify>
  <done>RegisterRequest no longer requires email_verified_token or college_id. UserResponse includes verification flags.</done>
</task>

<task type="auto">
  <name>Rework registration router</name>
  <files>backend/app/routers/auth.py</files>
  <action>
    Modify the auth router to implement the simplified flow:
    
    1. `POST /auth/register` endpoint:
       - Accept only `phone_verified_token` (no email_verified_token)
       - Decode phone_verified_token to get verified phone number
       - Create user with: full_name, phone, gender, community (optional)
       - Set email=None, college_id=None (will be filled during verification)
       - Set is_phone_verified=True, is_email_verified=False, is_identity_verified=False, is_driver_verified=False
       - Return access token + user data
       
    2. Keep the phone send/verify OTP endpoints EXACTLY as-is (used for both registration and login)
    
    3. Keep the login send/verify OTP endpoints EXACTLY as-is
    
    4. Keep email send/verify OTP endpoints BUT modify them:
       - Instead of requiring phone_verified_token, require the user to be authenticated (use get_current_active_user dependency)
       - After email verification, update user.email and user.is_email_verified = True
       - This makes email verification a POST-REGISTRATION step
       
    5. Remove the check "if phone already registered" from the phone send OTP REGISTRATION endpoint — because the same endpoint is used for login too. Instead, add a `purpose` field to distinguish registration vs login flows, OR create separate registration vs login OTP endpoints.
    
    IMPORTANT: Keep the existing endpoint PATHS to minimize Flutter team disruption. Change behavior, not URLs.
  </action>
  <verify>grep -c "def " backend/app/routers/auth.py</verify>
  <done>Registration creates user with phone only. Email verification is a separate authenticated step. Login unchanged.</done>
</task>

## Success Criteria
- [ ] Registration works with phone OTP only (no email OTP required)
- [ ] Email verification is a separate post-registration step requiring authentication
- [ ] Login flow unchanged
- [ ] All schemas validate correctly
- [ ] No breaking URL changes (same paths, different behavior)
