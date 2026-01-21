from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from typing import Optional

class LocationPoint(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)

class TimestampMixin(BaseModel):
    created_at: Optional[datetime] = None
