from fastapi import APIRouter

from app.api.v1.endpoints import login, users, rides, tracking

api_router = APIRouter()
api_router.include_router(login.router, tags=["login"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(rides.router, prefix="/rides", tags=["rides"])
api_router.include_router(tracking.router, tags=["tracking"])
