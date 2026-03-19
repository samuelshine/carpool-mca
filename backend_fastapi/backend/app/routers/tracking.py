"""
Tracking Router — Provides ride tracking info for live tracking UI.

GET  /tracking/{ride_id}           — Returns current ride state for the live tracking screen.
POST /tracking/{ride_id}/location  — Driver updates their live location (stored on the ride record).
DELETE /tracking/{ride_id}/location — Clear driver's latest live location.
"""
import uuid
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from pydantic import BaseModel

from core.deps import DBSession, CurrentUser
from db.models.rides import Ride
from db.models.ride_participants import RideParticipant


router = APIRouter(prefix="/tracking", tags=["Tracking"])


class LocationUpdate(BaseModel):
    latitude: float
    longitude: float


def _geo_to_coords(geo_value) -> Optional[dict]:
    """Convert a GeoAlchemy2 Geography value to {latitude, longitude} dict."""
    if geo_value is None:
        return None
    try:
        from geoalchemy2.shape import to_shape
        point = to_shape(geo_value)
        return {"latitude": point.y, "longitude": point.x}
    except Exception:
        return None


@router.get("/{ride_id}")
async def get_tracking_info(
    ride_id: uuid.UUID, user: CurrentUser, db: DBSession
):
    """
    Get tracking information for a ride.

    Returns ride status, locations, driver/rider names, and OTP (for rider only).
    The frontend uses this to drive the live tracking screen.
    """
    result = await db.execute(
        select(Ride)
        .options(selectinload(Ride.driver), selectinload(Ride.vehicle))
        .where(Ride.ride_id == ride_id)
    )
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")

    is_driver = ride.driver_id == user.user_id
    viewer_participant = None

    if not is_driver:
        participant_result = await db.execute(
            select(RideParticipant).where(
                RideParticipant.ride_id == ride_id,
                RideParticipant.user_id == user.user_id,
            )
        )
        participant = participant_result.scalar_one_or_none()
        if participant:
            viewer_participant = {
                "participant_id": str(participant.participant_id),
                "pickup_otp": participant.pickup_otp,
                "pickup_address": participant.pickup_address,
                "is_picked_up": participant.is_picked_up,
            }

    driver_info = None
    if ride.driver:
        driver_info = {
            "user_id": str(ride.driver.user_id),
            "full_name": ride.driver.full_name,
            "phone_number": ride.driver.phone_number,
        }

    vehicle_info = None
    if ride.vehicle:
        vehicle_info = {
            "vehicle_number": ride.vehicle.vehicle_number,
            "vehicle_type": ride.vehicle.vehicle_type.value,
        }

    live_location = None
    if (
        ride.driver_last_latitude is not None and
        ride.driver_last_longitude is not None
    ):
        live_location = {
            "latitude": ride.driver_last_latitude,
            "longitude": ride.driver_last_longitude,
            "updated_at": ride.driver_location_updated_at.isoformat()
            if ride.driver_location_updated_at
            else None,
        }

    return {
        "ride_id": str(ride.ride_id),
        "status": ride.status.value,
        "viewer_role": "driver" if is_driver else (
            "passenger" if viewer_participant is not None else "viewer"
        ),
        "viewer_participant": viewer_participant,
        "start_location": _geo_to_coords(ride.start_location),
        "end_location": _geo_to_coords(ride.end_location),
        "start_address": ride.start_address,
        "end_address": ride.end_address,
        "driver": driver_info,
        "vehicle": vehicle_info,
        # Backward-compatible field; real passenger flows should prefer
        # `viewer_participant.pickup_otp` for the authenticated rider.
        "pickup_otp": (
            viewer_participant["pickup_otp"]
            if viewer_participant is not None
            else (ride.pickup_otp if not is_driver else None)
        ),
        # Live driver location for map tracking
        "driver_location": live_location,
    }


@router.post("/{ride_id}/location", status_code=200)
async def update_driver_location(
    ride_id: uuid.UUID,
    payload: LocationUpdate,
    user: CurrentUser,
    db: DBSession,
):
    """
    Driver posts their current GPS location.
    Passengers polling GET /tracking/{ride_id} will receive it.
    """
    result = await db.execute(
        select(Ride).where(Ride.ride_id == ride_id, Ride.driver_id == user.user_id)
    )
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status_code=403, detail="Not your ride")

    ride.driver_last_latitude = payload.latitude
    ride.driver_last_longitude = payload.longitude
    ride.driver_location_updated_at = datetime.now(timezone.utc)
    await db.flush()
    return {"message": "Location updated"}


@router.delete("/{ride_id}/location", status_code=200)
async def clear_driver_location(
    ride_id: uuid.UUID,
    user: CurrentUser,
    db: DBSession,
):
    """Clear stored driver location when ride completes."""
    result = await db.execute(
        select(Ride).where(Ride.ride_id == ride_id, Ride.driver_id == user.user_id)
    )
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status_code=403, detail="Not your ride")

    ride.driver_last_latitude = None
    ride.driver_last_longitude = None
    ride.driver_location_updated_at = None
    await db.flush()
    return {"message": "Location cleared"}
