from pydantic import BaseModel, Field
from uuid import UUID
from datetime import date, time, datetime
from typing import Optional
from .common import LocationPoint
from .enums import RideStatusEnum, AllowedGenderEnum

class RideBase(BaseModel):
    start_location: LocationPoint
    end_location: LocationPoint
    start_address: str
    end_address: str
    ride_date: date
    ride_time: time
    available_seats: int = Field(..., ge=0)
    allowed_gender: AllowedGenderEnum
    allowed_community: Optional[str] = None
    estimated_fare: Optional[float] = None

class RideCreate(RideBase):
    vehicle_id: UUID
    # driver_id inferred from auth token

class RideRead(RideBase):
    ride_id: UUID
    status: RideStatusEnum
    created_at: datetime
