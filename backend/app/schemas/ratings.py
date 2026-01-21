from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from typing import Optional

class RatingCreate(BaseModel):
    ride_id: UUID
    rated_user_id: UUID
    rating_value: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None

class RatingRead(RatingCreate):
    rating_id: UUID
    rater_id: UUID
    created_at: datetime
