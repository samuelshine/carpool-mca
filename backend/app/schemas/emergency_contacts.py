from pydantic import BaseModel
from uuid import UUID

class EmergencyContactCreate(BaseModel):
    contact_name: str
    contact_phone: str
    relationship: str

class EmergencyContactRead(EmergencyContactCreate):
    contact_id: UUID
    user_id: UUID
