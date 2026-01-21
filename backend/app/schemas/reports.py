from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional

class ReportCreate(BaseModel):
    ride_id: UUID
    reported_user_id: UUID
    comment: Optional[str] = None

class ReportRead(ReportCreate):
    report_id: UUID
    reporter_id: UUID
    created_at: datetime
