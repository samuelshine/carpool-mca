# Tech Stack

Last reviewed: 2026-03-19

## Product surfaces

### Backend

- Framework: FastAPI
- Language: Python 3.11
- API style: JSON REST
- Auth model: passwordless OTP + JWT access tokens + hashed refresh tokens with rotation
- ORM: SQLAlchemy 2.x async
- Database driver: `asyncpg`
- Database: PostgreSQL
- Geospatial support: `geoalchemy2` with PostGIS-style geography columns
- Migrations: Alembic
- Validation/settings: Pydantic v2 + `pydantic-settings`
- JWT library: `python-jose`
- Email: SMTP or console provider
- SMS: console, MSG91, or Twilio-style abstraction
- Multipart support: `python-multipart`
- HTTP client: `httpx`
- Server runtime: `uvicorn`

### Mobile frontend

- Framework: Flutter
- Language: Dart
- UI system: Material 3
- State style: mostly local `StatefulWidget` state + `ChangeNotifier` for theme
- Local persistence: `shared_preferences`
- Maps: `flutter_map`
- Coordinates/math: `latlong2`
- Device location: `geolocator`
- Permissions: `permission_handler`
- Media upload selection: `image_picker`
- HTTP: `http`

### Admin frontend

- Stack: plain HTML, CSS, and vanilla JavaScript
- State/persistence: in-memory JS state + `localStorage` for admin tokens
- API access: direct `fetch()` calls to FastAPI

## Infrastructure and deployment

- Containerization: Docker
- Local backend orchestration: `docker-compose`
- Hosted deployment config: Render (`render.yaml`)
- Backend container base image: `python:3.11-slim`
- Health check endpoint: `/health`
- CORS: environment-driven via `ALLOWED_ORIGINS`

## External and platform services

### Backend-configurable services

- SMS provider abstraction:
  - `console`
  - `msg91`
  - `twilio` placeholder
- Email provider abstraction:
  - `console`
  - `smtp`
- OCR provider placeholder:
  - `console`
  - `tesseract`
  - `google_vision`
- Verification provider placeholder:
  - `console`
  - `surepass`

### Frontend third-party APIs

- Geocoding: OpenStreetMap Nominatim
- Routing: OSRM public API
- Map tiles: OpenStreetMap tile server

## Persistence and storage summary

### Persistent storage

- PostgreSQL for users, rides, vehicles, OTP sessions, verifications, refresh tokens, reports, ratings, and related entities
- Flutter `SharedPreferences` for auth/session/theme/profile snippets
- Admin browser `localStorage` for admin access/refresh token persistence

### Non-persistent or semi-persistent runtime state

- Driver live location in backend tracking router is stored in an in-memory Python dictionary, not in Redis or the database
- Demo-mode ride simulation still exists on the Flutter side for explicit non-real-ride scenarios

## Key runtime configuration

### Backend env vars

- `DATABASE_URL`
- `JWT_SECRET_KEY`
- `ALLOWED_ORIGINS`
- `EMAIL_PROVIDER`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASSWORD`
- `EMAIL_FROM`
- `SMS_PROVIDER`
- `SMS_API_KEY`
- `SMS_SENDER_ID`
- `OCR_PROVIDER`
- `VERIFICATION_PROVIDER`
- `VERIFICATION_API_KEY`

### Flutter local config

- `frontend_flutter/lib/config.dart` is expected locally and is not committed
- `config.dart.example` shows `kBaseUrl` pointing to a tunnel URL, implying developers commonly test against a locally exposed backend

## Notable implementation characteristics

- The backend is structured like a real production API, with typed schemas, async DB sessions, and service abstractions.
- The Flutter client is still a hybrid of production intent and prototype UX, but the main booking, create-ride, history, verification, and real live-ride paths are now backend-oriented.
- The admin app is intentionally minimal and tightly coupled to the backend admin routes.
- Geospatial data is handled seriously in the backend schema, but some API responses still return placeholder location payloads in specific ride-detail responses.
- The mobile client now uses a single shared API surface in `frontend_flutter/lib/services/api_service.dart`.
