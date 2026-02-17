---
phase: 4
plan: 3
wave: 2
---

# Plan 4.3: Wire Notifications into Ride Lifecycle + Validation

## Objective
Integrate the notification service into ride lifecycle endpoints so that notifications fire on key events. Then validate the entire Phase 4 (WebSocket, FCM tokens, notifications).

## Context
- @.gsd/SPEC.md — REQ-19, REQ-20
- @backend/app/routers/rides.py — Ride lifecycle endpoints (request, accept/reject, start, complete)
- @backend/app/services/notification_service.py — NotificationService from Plan 4.2

## Tasks

<task type="auto">
  <name>Wire notifications into ride lifecycle</name>
  <files>backend/app/routers/rides.py</files>
  <action>
    Import `notification_service` and add notification triggers to these endpoints:

    1. **request_to_join** — After creating request:
       - Fetch driver's fcm_token from User model
       - If token exists: `await notification_service.notify_ride_request(token, passenger_name, ride_id)`

    2. **action_ride_request** — After accept/reject:
       - Fetch passenger's fcm_token
       - If accept: `await notification_service.notify_request_accepted(token, ride_id)`
       - If reject: `await notification_service.notify_request_rejected(token, ride_id)`

    3. **start_ride** — After status change:
       - Get all participant fcm_tokens (join RideParticipant → User)
       - `await notification_service.notify_ride_starting(tokens, ride_id)`

    4. **complete_ride** — After status change:
       - Get all participant fcm_tokens
       - `await notification_service.notify_ride_completed(tokens, ride_id)`

    IMPORTANT: Notifications should be fire-and-forget (don't fail the request if notification fails).
    Wrap notification calls in try/except and log errors silently.
    
    Helper to get participant tokens:
    ```python
    async def _get_participant_tokens(db, ride_id):
        stmt = (
            select(User.fcm_token)
            .join(RideParticipant, RideParticipant.user_id == User.user_id)
            .where(RideParticipant.ride_id == ride_id)
            .where(User.fcm_token.is_not(None))
        )
        result = await db.execute(stmt)
        return [row[0] for row in result.all()]
    ```
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from routers.rides import router
    import inspect
    # Check that notification_service is imported in rides module
    import routers.rides as rm
    assert hasattr(rm, 'notification_service') or 'notification_service' in inspect.getsource(rm), 'notification_service not wired'
    print('Notifications wired OK')
    "
  </verify>
  <done>Notification calls wired into request_to_join, action_ride_request, start_ride, complete_ride</done>
</task>

<task type="auto">
  <name>Full Phase 4 validation</name>
  <files>backend/app/main.py</files>
  <action>
    1. Verify server starts clean
    2. Verify all new routes are registered:
       - ws://host/ws/rides/{ride_id}/track
       - POST /users/me/fcm-token
       - DELETE /users/me/fcm-token
    3. Verify all imports resolve
    4. Quick import sanity check for new modules
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    import subprocess, signal, sys, time
    proc = subprocess.Popen([sys.executable, '-m', 'uvicorn', 'main:app', '--host', '127.0.0.1', '--port', '8006'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(5)
    proc.send_signal(signal.SIGTERM)
    stdout, stderr = proc.communicate(timeout=5)
    output = stdout.decode() + stderr.decode()
    assert 'Application startup complete' in output, f'Server failed: {output}'
    print('SERVER OK')
    "
  </verify>
  <done>Server starts clean, WebSocket + FCM endpoints registered, notifications wired</done>
</task>

## Success Criteria
- [ ] Notifications fire on ride request, accept, reject, start, complete
- [ ] Notifications are fire-and-forget (don't break ride endpoints)
- [ ] Server starts without errors
- [ ] All Phase 4 routes (HTTP + WebSocket) registered
