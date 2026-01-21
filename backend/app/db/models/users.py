import uuid
from sqlalchemy import String, Boolean, TIMESTAMP, Enum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base
from db.enums import GenderEnum
from sqlalchemy.orm import relationship

class User(Base):
    __tablename__ = "users"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    full_name: Mapped[str] = mapped_column(String(100), nullable=False)
    email: Mapped[str] = mapped_column(String(150), unique=True, nullable=False)
    phone_number: Mapped[str] = mapped_column(String(15), unique=True)
    college_id: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    gender: Mapped[GenderEnum] = mapped_column(Enum(GenderEnum), nullable=False)
    community: Mapped[str | None] = mapped_column(String(50))
    profile_photo_url: Mapped[str | None] = mapped_column(String)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )

    driven_rides = relationship(
        "Ride",
        back_populates="driver",
        foreign_keys="Ride.driver_id"
    )

    # Vehicles owned by user
    vehicles = relationship(
        "Vehicle",
        back_populates="owner"
    )

    # Ride requests made as passenger
    ride_requests = relationship(
        "RideRequest",
        back_populates="passenger"
    )

    # Confirmed rides as passenger
    ride_participations = relationship(
        "RideParticipant",
        back_populates="user"
    )