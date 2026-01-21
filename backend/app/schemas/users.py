from pydantic import BaseModel, EmailStr
from uuid import UUID
from typing import Optional
from datetime import datetime
from .enums import GenderEnum

class UserBase(BaseModel):
    full_name: str
    email: EmailStr
    phone_number: str
    college_id: str
    gender: GenderEnum
    community: Optional[str] = None
    profile_photo_url: Optional[str] = None

class UserCreate(UserBase):
    pass

class UserRead(UserBase):
    user_id: UUID
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
