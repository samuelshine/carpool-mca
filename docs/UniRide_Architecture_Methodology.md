# UniRide: Architecture & Methodology Documentation

## 1. Project Overview
**UniRide** is a comprehensive, multi-platform carpooling application designed specifically for college students (e.g., Christ University). The application facilitates safe, cost-effective, and verified ride-sharing among students across different campus locations.

The system is structured into three main components:
1. **Backend API**: A high-performance, asynchronous REST API built with Python, FastAPI, and PostgreSQL.
2. **Mobile Frontend**: A cross-platform mobile application built with Flutter/Dart for students (Riders and Drivers).
3. **Web Admin Panel**: A standalone web application built with vanilla HTML/JS/CSS for administrative oversight.

---

## 2. Software Architecture Methodology

The project follows a **Microservices-inspired Monolithic Architecture** with clear separation of concerns at the backend and a robust **MVVM (Model-View-ViewModel)/Service-Oriented** pattern on the frontend.

### 2.1 Backend Architecture (FastAPI)
The backend is structured into distinct functional layers, ensuring maintainability, testability, and scalability.

*   **API Routers (`routers/`)**: Define the HTTP endpoints, grouped by domain (e.g., `auth`, `rides`, `tracking`, `verification`). They handle request validation via Pydantic schemas and route logic to services/database.
*   **Database Models (`db/models/`)**: Define the SQL schema using SQLAlchemy ORM. The models heavily utilize Postgres-specific features like `UUIDs` and `PostGIS` (GeoAlchemy2) for geospatial data.
*   **Business Logic & Services (`services/`)**: Encapsulate complex logic independent of exactly how the request arrived (e.g., `OTPService`, `EmailService`).
*   **Core Configuration & Security (`core/`)**: Manage environment variables (`pydantic-settings`), dependencies (`Deps`), and JWT-based authentication security.

### 2.2 Frontend Architecture (Flutter)
The mobile app is designed with a **Service-Oriented Architecture** pattern separating UI, state, and API communication.

*   **UI/Screens (`screens/`)**: Grouped by feature domain (`auth/`, `home/`, `driver/`, `profile/`, `rides/`). Uses Material 3 design language with both Light and Dark mode support (`ThemeNotifier`).
*   **Core Services (`services/`)**: Singleton-like classes handling all external communication and business logic abstraction:
    *   `ApiService` and its feature-specific service classes (for example `RideApiService`, `VerificationApiService`, `UserApiService`): Handle HTTP/network communication with the FastAPI backend, including JWT token management and automatic refresh token rotation.
    *   `LocationService`: Manages GPS, geolocation (Coordinates ↔ Address), and map routing (Nominatim/OSRM).

### 2.3 Deployment Architecture
*   **Containerization**: The backend is containerized using `Docker`, ensuring consistent environments across development and production.
*   **CI/CD & Cloud Orchestration**: Managed via `render.yaml` (Infrastructure as Code) which defines the service deployment parameters, environment variables, health checks, and build paths.

---

## 3. Technology Stack & Tooling

### Backend Stack
*   **Framework**: FastAPI (Python 3.11+) - chosen for its asynchronous capability and built-in data validation (Pydantic).
*   **Database**: PostgreSQL with PostGIS - critical for efficient geographic proximity searches (finding nearby rides).
*   **ORM**: SQLAlchemy 2.0 with `asyncpg` - purely asynchronous database interactions.
*   **Authentication**: Passwordless OTP flow with JWT (JSON Web Tokens) access and refresh tokens.
*   **Geospatial Processing**: GeoAlchemy2 for database mapping and Haversine formula for distance fallback calculations.

### Frontend Stack (Mobile)
*   **Framework**: Flutter (Dart) - enables a single codebase for both iOS and Android.
*   **Mapping UI**: `flutter_map` - implements OpenStreetMap integration without reliance on proprietary Google Maps SDKs.
*   **Persistence**: `shared_preferences` - for storing JWTs, user profiles, and theme settings locally.

### Admin Web Stack
*   **Framework**: Vanilla HTML5, CSS3, and JavaScript (ES6+).
*   **Design**: Custom CSS without heavy frameworks, utilizing modern Grid/Flexbox layouts.

---

## 4. Key Methodologies & Implementation Details

### 4.1 Security & "Passwordless" Authentication Flow
The system utilizes a modern, passwordless authentication methodology:
1.  **Phone OTP**: User requests an OTP which is sent (via SMS provider) to their phone.
2.  **Verification**: User submits the OTP. The backend validates the hash and issues short-lived `access_tokens` (1 hour) and long-lived `refresh_tokens` (30 days).
3.  **Token Rotation**: The `ApiService` intercepts 401 Unauthorized errors, automatically uses the `refresh_token` to get a new session, and replays the failed request seamlessly.

### 4.2 Tiered Identity & Trust Methodology
Safety is the core defining feature of UniRide. The platform employs a **Tiered Access Control** system enforced via FastAPI Dependency Injection (`get_verified_user`, `get_verified_driver`):
1.  **Tier 1 (Base User)**: Phone number verified. Can edit profile but cannot view rides.
2.  **Tier 2 (Identity Verified)**: Must verify a distinct `@christuniversity.in` email via OTP and upload a College ID card. The Admin panel reviews the ID. Once verified, the student is allowed to *request/join* rides.
3.  **Tier 3 (Driver Verified)**: Must upload a valid Driving Licence/RC. Once approved by Admin, the student is allowed to *publish/create* rides.

### 4.3 Geospatial Ride Matching & Fare Calculation
*   **Geospatial Models**: Rides leverage `Geography(geometry_type="POINT", srid=4326)` to store exact coordinates.
*   **Campus Matrix**: A predefined node graph of the university campuses (`Fare Router`).
*   **Fare Algorithm**: Calculates distance. If between two known campuses, it uses pre-computed ideal-route distances. If arbitrary custom points, it uses the Haversine formula (Earth's curvature) multiplied by a 1.3 "road factor" to approximate street distance. Fares are automatically split among the number of accepted participants.

### 4.4 Ride Lifecycle & Real-Time Tracking State Machine
The system handles complex state transitions (`RideStatusEnum`):
1.  **Open**: Driver publishes a ride.
2.  **Pending Request**: Passenger sends a request. Driver accepts/rejects.
3.  **Driver Arriving**: Ride starts. Driver application continuously POSTs GPS payloads to `POST /tracking/{ride_id}/location`.
4.  **Live Polling**: Passenger app polls `GET /tracking/{ride_id}` to render the driver's icon moving on the map.
5.  **Pickup Verification**: To prevent fraud, passengers are issued a 4-digit OTP. The driver must input this OTP to officially start the trip for that specific passenger (`verify_pickup_otp`).
6.  **SOS System**: Integrated panic button writes GPS coordinates directly to an `sos_alerts` ledger and alerts the admin dashboard instantly.
