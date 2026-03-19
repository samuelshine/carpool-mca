import uuid
from sqlalchemy import TIMESTAMP, Enum, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from geoalchemy2 import Geography
from db.base import Base
from db.enums import SOSAlertStatusEnum

class SOSAlert(Base):
    __tablename__ = "sos_alerts"

    alert_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False
    )
    ride_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rides.ride_id"), nullable=False
    )
    location = mapped_column(
        Geography(geometry_type="POINT", srid=4326), nullable=False
    )
    triggered_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )
    status: Mapped[SOSAlertStatusEnum] = mapped_column(
        Enum(SOSAlertStatusEnum, name="sosalertstatusenum"),
        nullable=False,
        default=SOSAlertStatusEnum.open,
        server_default=SOSAlertStatusEnum.open.value,
    )
    resolved_at: Mapped[str | None] = mapped_column(TIMESTAMP(timezone=True))
    resolved_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id"),
        nullable=True,
    )
    resolution_notes: Mapped[str | None] = mapped_column(Text)
