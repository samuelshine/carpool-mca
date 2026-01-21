from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from .enums import VehicleTypeEnum

class VehicleBase(BaseModel):
    vehicle_type: VehicleTypeEnum
    vehicle_number: str

class VehicleCreate(VehicleBase):
    user_id: UUID

class VehicleRead(VehicleBase):
    vehicle_id: UUID
    user_id: UUID
    created_at: datetime
