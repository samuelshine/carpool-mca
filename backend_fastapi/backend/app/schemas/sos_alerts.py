from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from .common import LocationPoint

class SOSAlertCreate(BaseModel):
    ride_id: UUID
    location: LocationPoint

class SOSAlertRead(SOSAlertCreate):
    alert_id: UUID
    user_id: UUID
    triggered_at: datetime
    status: str = "open"
    resolved_at: datetime | None = None
    resolved_by_user_id: UUID | None = None
    resolution_notes: str | None = None
