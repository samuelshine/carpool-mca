from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from .enums import RideRequestStatusEnum

class RideRequestCreate(BaseModel):
    ride_id: UUID
    passenger_id: UUID

class RideRequestRead(BaseModel):
    request_id: UUID
    ride_id: UUID
    passenger_id: UUID
    request_status: RideRequestStatusEnum
    requested_at: datetime
