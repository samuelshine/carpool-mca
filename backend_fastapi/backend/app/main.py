"""
College Carpool API - Main Application Entry Point
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from core.config import get_settings
from core.deps import DBSession
# Import models to ensure they are registered with SQLAlchemy
from db.models import users, vehicles, rides, ride_requests, ride_participants, ride_history, driver_profiles
from db.models import identity_verifications, driver_verifications, saved_addresses, college_students
from db.models import refresh_tokens  # Required for refresh token auth
from routers import auth, users as users_router, vehicles as vehicles_router, rides as rides_router
from routers import verification as verification_router
from routers import addresses as addresses_router
from routers import driver_profiles as driver_profiles_router
from routers import tracking as tracking_router
from routers import fare as fare_router
from routers import ratings as ratings_router
from routers import reports as reports_router
from routers import emergency_contacts as emergency_contacts_router
from routers import sos as sos_router
from routers import admin as admin_router

settings = get_settings()

app = FastAPI(
    title=settings.APP_NAME,
    description="A secure carpooling platform for college students",
    version=settings.APP_VERSION,
    docs_url="/docs",
    redoc_url="/redoc"
)

allowed_origins = settings.allowed_origins_list

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials="*" not in allowed_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(users_router.router)
app.include_router(vehicles_router.router)
app.include_router(rides_router.router)
app.include_router(verification_router.router)
app.include_router(addresses_router.router)
app.include_router(driver_profiles_router.router)
app.include_router(tracking_router.router)
app.include_router(fare_router.router)
app.include_router(ratings_router.router)
app.include_router(reports_router.router)
app.include_router(emergency_contacts_router.router)
app.include_router(sos_router.router)
app.include_router(admin_router.router)


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT,
    }


@app.get("/health")
async def health():
    """Health check for load balancers."""
    return {
        "status": "ok",
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT,
    }


@app.get("/health/ready")
async def readiness(db: DBSession):
    """Readiness probe that verifies the API can reach the database."""
    try:
        await db.execute(text("SELECT 1"))
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=f"Database readiness check failed: {exc}",
        ) from exc

    return {
        "status": "ready",
        "database": "ok",
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT,
        "cors_origins": settings.allowed_origins_list,
    }
