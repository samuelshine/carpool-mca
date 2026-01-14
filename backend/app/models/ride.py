from sqlalchemy import Column, String, Integer, Float, Boolean, ForeignKey, DateTime, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID
import uuid
import enum
from datetime import datetime

from app.db.base_class import Base

class RideStatus(str, enum.Enum):
    SCHEDULED = "SCHEDULED"
    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"

class Ride(Base):
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    driver_id = Column(UUID(as_uuid=True), ForeignKey("user.id"), nullable=False)
    
    # Locations stored as simple lat/long floats for MVP simpler deployment (upgrade to PostGIS later if needed)
    start_lat = Column(Float, nullable=False)
    start_long = Column(Float, nullable=False)
    start_address = Column(String, nullable=True)
    
    end_lat = Column(Float, nullable=False)
    end_long = Column(Float, nullable=False)
    end_address = Column(String, nullable=True)
    
    scheduled_time = Column(DateTime, nullable=False, index=True)
    available_seats = Column(Integer, default=3)
    females_only = Column(Boolean, default=False)
    
    status = Column(Enum(RideStatus), default=RideStatus.SCHEDULED)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    driver = relationship("User", backref="rides_offered")
    
class RequestStatus(str, enum.Enum):
    PENDING = "PENDING"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"

class RideRequest(Base):
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    ride_id = Column(UUID(as_uuid=True), ForeignKey("ride.id"), nullable=False)
    passenger_id = Column(UUID(as_uuid=True), ForeignKey("user.id"), nullable=False)
    
    status = Column(Enum(RequestStatus), default=RequestStatus.PENDING)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    ride = relationship("Ride", backref="requests")
    passenger = relationship("User", backref="ride_requests")
