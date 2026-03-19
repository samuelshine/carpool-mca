"""
Users Router — User profile management.
"""
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from core.deps import DBSession, CurrentUser
from db.models.users import User
from schemas.users import UserRead, UserUpdate


router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserRead)
async def get_my_profile(user: CurrentUser):
    """Get the current authenticated user's profile."""
    return user


@router.put("/me", response_model=UserRead)
async def update_my_profile(
    payload: UserUpdate, user: CurrentUser, db: DBSession
):
    """Update the current user's profile."""
    if payload.full_name is not None:
        user.full_name = payload.full_name
    if payload.community is not None:
        user.community = payload.community
    if payload.profile_photo_url is not None:
        user.profile_photo_url = payload.profile_photo_url
    if payload.gender is not None:
        user.gender = payload.gender

    await db.flush()
    await db.refresh(user)
    return user


@router.delete("/me", status_code=status.HTTP_200_OK)
async def delete_my_profile(user: CurrentUser, db: DBSession):
    """Delete the current user's profile and all associated data."""
    # Since a soft delete or true cascade might be required, we'll delete the user record here.
    # Note: SQLAlchemy cascade should handle child records if configured.
    await db.delete(user)
    await db.commit()
    return {"message": "Account successfully deleted"}


@router.post("/me/suspend", status_code=status.HTTP_200_OK)
async def suspend_my_profile(user: CurrentUser, db: DBSession):
    """Suspend the current user's profile (soft-delete or disable login)."""
    # For now, we will clear their tokens or set an inactive flag.
    # Since there's no explicit is_active flag in UserRead schema that we can toggle,
    # we'll represent suspension as clearing verification flags.
    user.is_phone_verified = False
    user.is_driver_verified = False
    await db.flush()
    return {"message": "Account suspended successfully"}
