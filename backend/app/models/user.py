from sqlalchemy import Boolean, Column, Integer, String, Float, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID
import uuid
import enum

from app.db.base_class import Base

class Gender(str, enum.Enum):
    MALE = "MALE"
    FEMALE = "FEMALE"
    OTHER = "OTHER"

class User(Base):
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    full_name = Column(String, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    phone_number = Column(String, unique=True, index=True)
    is_active = Column(Boolean(), default=True)
    is_superuser = Column(Boolean(), default=False)
    
    # Trust & Verification
    is_verified = Column(Boolean(), default=False) # Email verified
    is_student_verified = Column(Boolean(), default=False) # ID card verified
    trust_score = Column(Float, default=100.0)
    
    gender = Column(Enum(Gender), nullable=True)
    
    # Relationships (to be added as we create other models)
    # rides_offered = relationship("Ride", back_populates="driver")
    # rides_requested = relationship("RideRequest", back_populates="passenger")
