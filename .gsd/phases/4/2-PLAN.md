---
phase: 4
plan: 2
wave: 1
---

# Plan 4.2: FCM Token Storage & Notification Service

## Objective
Register device FCM tokens and create a notification service with console provider pattern (matching our existing OCR/verification provider architecture). This enables push notifications without requiring actual Firebase in development.

## Context
- @.gsd/SPEC.md — REQ-19, REQ-20
- @backend/app/db/models/users.py — User model
- @backend/app/services/providers/ — Existing provider pattern (console_ocr, console_verification)

## Tasks

<task type="auto">
  <name>Add FCM token storage</name>
  <files>backend/app/schemas/users.py, backend/app/routers/users.py</files>
  <action>
    1. Add `fcm_token` column to User model (nullable String, stores latest device token):
       ```python
       fcm_token: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
       ```

    2. Add FCM token endpoint to users router:
       ```python
       class FCMTokenUpdate(BaseModel):
           fcm_token: str = Field(..., max_length=255)
       
       @router.post("/me/fcm-token")
       async def register_fcm_token(body: FCMTokenUpdate, current_user: CurrentUser, db: DBSession):
           current_user.fcm_token = body.fcm_token
           await db.flush()
           return {"message": "FCM token registered"}
       ```

    3. Add `DELETE /users/me/fcm-token` to clear token (on logout):
       ```python
       @router.delete("/me/fcm-token")
       async def clear_fcm_token(current_user: CurrentUser, db: DBSession):
           current_user.fcm_token = None
           await db.flush()
           return {"message": "FCM token cleared"}
       ```
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from db.models.users import User
    assert hasattr(User, 'fcm_token'), 'Missing fcm_token column'
    from routers.users import router
    routes = [r.path for r in router.routes]
    print(f'User routes: {routes}')
    print('FCM Token OK')
    "
  </verify>
  <done>User model has `fcm_token` column, `POST /users/me/fcm-token` and `DELETE /users/me/fcm-token` endpoints exist</done>
</task>

<task type="auto">
  <name>Create notification service with console provider</name>
  <files>
    backend/app/services/notification_service.py
    backend/app/services/providers/console_notification.py
  </files>
  <action>
    Follow the existing provider pattern (services/providers/console_ocr.py, etc.):

    1. Create `services/providers/console_notification.py`:
       ```python
       class ConsoleNotificationProvider:
           """Prints notifications to console instead of sending FCM push."""
           
           async def send_notification(self, fcm_token: str, title: str, body: str, data: dict = None) -> bool:
               print(f"[NOTIFICATION] To: {fcm_token}")
               print(f"  Title: {title}")
               print(f"  Body: {body}")
               if data:
                   print(f"  Data: {data}")
               return True
           
           async def send_to_multiple(self, tokens: list, title: str, body: str, data: dict = None) -> int:
               sent = 0
               for token in tokens:
                   if await self.send_notification(token, title, body, data):
                       sent += 1
               return sent
       ```

    2. Create `services/notification_service.py`:
       ```python
       from services.providers.console_notification import ConsoleNotificationProvider
       
       class NotificationService:
           def __init__(self, provider=None):
               self.provider = provider or ConsoleNotificationProvider()
           
           async def notify_ride_request(self, driver_fcm_token: str, passenger_name: str, ride_id: str):
               await self.provider.send_notification(
                   driver_fcm_token,
                   "New Ride Request",
                   f"{passenger_name} wants to join your ride",
                   {"type": "ride_request", "ride_id": ride_id}
               )
           
           async def notify_request_accepted(self, passenger_fcm_token: str, ride_id: str):
               await self.provider.send_notification(
                   passenger_fcm_token,
                   "Request Accepted!",
                   "Your ride request has been accepted",
                   {"type": "request_accepted", "ride_id": ride_id}
               )
           
           async def notify_request_rejected(self, passenger_fcm_token: str, ride_id: str):
               await self.provider.send_notification(
                   passenger_fcm_token,
                   "Request Rejected",
                   "Your ride request was not accepted",
                   {"type": "request_rejected", "ride_id": ride_id}
               )
           
           async def notify_ride_starting(self, participant_tokens: list, ride_id: str):
               await self.provider.send_to_multiple(
                   participant_tokens,
                   "Ride Starting!",
                   "Your ride is about to begin",
                   {"type": "ride_starting", "ride_id": ride_id}
               )
           
           async def notify_ride_completed(self, participant_tokens: list, ride_id: str):
               await self.provider.send_to_multiple(
                   participant_tokens,
                   "Ride Completed",
                   "Your ride has been completed. Please rate your experience.",
                   {"type": "ride_completed", "ride_id": ride_id}
               )
       
       notification_service = NotificationService()
       ```
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from services.notification_service import notification_service, NotificationService
    from services.providers.console_notification import ConsoleNotificationProvider
    assert isinstance(notification_service.provider, ConsoleNotificationProvider)
    print('NotificationService OK')
    "
  </verify>
  <done>`NotificationService` importable with 5 notification methods, console provider prints to stdout</done>
</task>

## Success Criteria
- [ ] User model has `fcm_token` column
- [ ] `POST /users/me/fcm-token` and `DELETE /users/me/fcm-token` endpoints work
- [ ] `NotificationService` with console provider sends 5 notification types
- [ ] Provider pattern matches existing OCR/verification providers
