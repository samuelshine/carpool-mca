"""
College Carpool API - Main Application Entry Point
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from core.config import get_settings
# Import models to ensure they are registered with SQLAlchemy
from db.models import users, vehicles, rides, ride_requests, ride_participants
from routers import auth, users as users_router, vehicles as vehicles_router, rides as rides_router

settings = get_settings()

app = FastAPI(
    title=settings.APP_NAME,
    description="A secure carpooling platform for college students",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(users_router.router)
app.include_router(vehicles_router.router)
app.include_router(rides_router.router)


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "version": "1.0.0"
    }


@app.get("/health")
async def health():
    """Health check for load balancers."""
    return {"status": "ok"}