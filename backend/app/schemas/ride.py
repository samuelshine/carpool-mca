from typing import Optional, List
from pydantic import BaseModel
from datetime import datetime
from uuid import UUID
from app.models.ride import RideStatus, RequestStatus
from app.schemas.user import User

# Shared properties
class RideBase(BaseModel):
    start_lat: float
    start_long: float
    start_address: Optional[str] = None
    end_lat: float
    end_long: float
    end_address: Optional[str] = None
    scheduled_time: datetime
    available_seats: int = 3
    females_only: bool = False

class RideCreate(RideBase):
    pass

class RideUpdate(RideBase):
    status: Optional[RideStatus] = None

class RideInDBBase(RideBase):
    id: UUID
    driver_id: UUID
    status: RideStatus
    created_at: datetime

    class Config:
        from_attributes = True

class Ride(RideInDBBase):
    driver: User

class RideRequestBase(BaseModel):
    ride_id: UUID

class RideRequestCreate(RideRequestBase):
    pass

class RideRequest(RideRequestBase):
    id: UUID
    passenger_id: UUID
    status: RequestStatus
    created_at: datetime
    passenger: User

    class Config:
        from_attributes = True
