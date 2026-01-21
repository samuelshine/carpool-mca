from pydantic import BaseModel, Field
from uuid import UUID

class DriverProfileBase(BaseModel):
    vehicle_id: UUID
    daily_seat_limit: int = Field(..., gt=0)

class DriverProfileCreate(DriverProfileBase):
    user_id: UUID

class DriverProfileRead(DriverProfileBase):
    user_id: UUID
    is_driver_active: bool
