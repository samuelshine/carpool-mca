"""
Admin Router — Full admin-only management API.

All endpoints require is_admin = True.

User Management:
  GET  /admin/users                    — List all users (paginated)
  GET  /admin/users/{user_id}         — Get enriched user detail
  PUT  /admin/users/{user_id}/deactivate — Deactivate user

Identity Verification:
  GET  /admin/verifications/identity/pending        — List pending identity verifications
  PUT  /admin/verifications/identity/{user_id}/approve — Approve identity
  PUT  /admin/verifications/identity/{user_id}/reject  — Reject identity

Driver Verification:
  GET  /admin/verifications/driver/pending          — List pending driver verifications
  PUT  /admin/verifications/driver/{user_id}/approve   — Approve driver
  PUT  /admin/verifications/driver/{user_id}/reject    — Reject driver

SOS Alerts:
  GET  /admin/sos/active               — List active (unresolved) SOS alerts
  PUT  /admin/sos/{alert_id}/resolve   — Mark SOS alert resolved

Stats:
  GET  /admin/stats                    — Dashboard statistics
"""
import uuid
from datetime import datetime, timezone
from typing import Literal, Optional
from fastapi import APIRouter, HTTPException, status, Query, Depends
from sqlalchemy import select, func
from sqlalchemy.orm import aliased
from pydantic import BaseModel

from core.deps import DBSession, CurrentUser
from db.models.users import User
from db.models.identity_verifications import IdentityVerification
from db.models.driver_verifications import DriverVerification
from db.models.sos_alerts import SOSAlert
from db.models.rides import Ride
from db.models.ride_requests import RideRequest
from db.models.ride_participants import RideParticipant
from db.models.reports import Report
from db.models.vehicles import Vehicle
from db.enums import VerificationStatusEnum, RideStatusEnum, SOSAlertStatusEnum

router = APIRouter(prefix="/admin", tags=["Admin"])


# ---------------------------------------------------------------------------
# Admin guard dependency
# ---------------------------------------------------------------------------
async def require_admin(user: CurrentUser) -> User:
    if not user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required.",
        )
    return user


AdminUser = Depends(require_admin)


# ---------------------------------------------------------------------------
# Pydantic response schemas
# ---------------------------------------------------------------------------

class UserListItem(BaseModel):
    user_id: str
    full_name: str
    phone_number: str
    email: Optional[str]
    gender: str
    is_active: bool
    is_phone_verified: bool
    is_email_verified: bool
    is_identity_verified: bool
    is_driver_verified: bool
    is_admin: bool
    created_at: Optional[str]

    class Config:
        from_attributes = True


class UserVehicleItem(BaseModel):
    vehicle_id: str
    vehicle_type: str
    vehicle_number: str
    created_at: Optional[str]


class VerificationDetail(BaseModel):
    status: str
    submitted_at: Optional[str]
    reviewed_at: Optional[str]
    reviewer_notes: Optional[str]
    document_url: Optional[str] = None
    college_id_number: Optional[str] = None
    license_document_url: Optional[str] = None
    license_number: Optional[str] = None


class UserActivitySummary(BaseModel):
    driver_rides: int
    passenger_rides: int
    ride_requests: int
    reports_filed: int
    reports_received: int
    sos_triggered: int
    vehicles: int


class AdminUserRideItem(BaseModel):
    ride_id: str
    role: str
    status: str
    ride_date: Optional[str]
    ride_time: Optional[str]
    start_address: Optional[str]
    end_address: Optional[str]
    driver_name: Optional[str] = None
    vehicle_number: Optional[str] = None
    request_status: Optional[str] = None
    activity_at: Optional[str] = None


class AdminUserReportItem(BaseModel):
    report_id: str
    ride_id: str
    direction: str
    other_user_id: str
    other_user_name: str
    comment: Optional[str]
    created_at: Optional[str]


class AdminUserSOSItem(BaseModel):
    alert_id: str
    ride_id: str
    status: str
    triggered_at: Optional[str]
    resolved_at: Optional[str]
    resolution_notes: Optional[str]


class AdminUserDetail(UserListItem):
    community: Optional[str]
    profile_photo_url: Optional[str]
    updated_at: Optional[str]
    identity_verification: Optional[VerificationDetail]
    driver_verification: Optional[VerificationDetail]
    activity_summary: UserActivitySummary
    vehicles: list[UserVehicleItem]
    recent_rides: list[AdminUserRideItem]
    recent_reports: list[AdminUserReportItem]
    recent_sos_alerts: list[AdminUserSOSItem]


class VerificationItem(BaseModel):
    user_id: str
    full_name: str
    phone_number: str
    email: Optional[str]
    status: str
    submitted_at: Optional[str]
    reviewer_notes: Optional[str]
    document_url: Optional[str] = None
    license_document_url: Optional[str] = None
    college_id_number: Optional[str] = None
    license_number: Optional[str] = None


class SOSAlertItem(BaseModel):
    alert_id: str
    user_id: str
    user_name: str
    user_phone_number: str
    user_email: Optional[str]
    ride_id: str
    ride_date: Optional[str]
    ride_time: Optional[str]
    ride_status: Optional[str]
    start_address: Optional[str]
    end_address: Optional[str]
    triggered_at: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    status: str
    resolved_at: Optional[str]
    resolved_by_user_id: Optional[str]
    resolved_by_name: Optional[str]
    resolution_notes: Optional[str]


class SOSStatusUpdateRequest(BaseModel):
    status: Literal["open", "resolved", "closed"]
    notes: Optional[str] = None


def _extract_alert_location(alert: SOSAlert) -> tuple[Optional[float], Optional[float]]:
    lat, lng = None, None
    if alert.location is not None:
        try:
            from geoalchemy2.shape import to_shape
            point = to_shape(alert.location)
            lat, lng = point.y, point.x
        except Exception:
            pass
    return lat, lng


def _enum_value(value):
    if value is None:
        return None
    return value.value if hasattr(value, "value") else str(value)


def _serialize_user_list_item(user: User) -> UserListItem:
    return UserListItem(
        user_id=str(user.user_id),
        full_name=user.full_name,
        phone_number=user.phone_number,
        email=user.email,
        gender=_enum_value(user.gender) or "",
        is_active=user.is_active,
        is_phone_verified=user.is_phone_verified,
        is_email_verified=user.is_email_verified,
        is_identity_verified=user.is_identity_verified,
        is_driver_verified=user.is_driver_verified,
        is_admin=user.is_admin,
        created_at=str(user.created_at) if user.created_at else None,
    )


def _serialize_verification_detail(record) -> VerificationDetail:
    return VerificationDetail(
        status=_enum_value(record.status) or "pending",
        submitted_at=str(record.created_at) if record.created_at else None,
        reviewed_at=str(record.reviewed_at) if record.reviewed_at else None,
        reviewer_notes=record.reviewer_notes,
        document_url=getattr(record, "document_url", None),
        college_id_number=getattr(record, "college_id_number", None),
        license_document_url=getattr(record, "license_document_url", None),
        license_number=getattr(record, "license_number", None),
    )


def _serialize_sos_item(
    alert: SOSAlert,
    user: User,
    ride: Ride,
    resolver: Optional[User] = None,
) -> SOSAlertItem:
    lat, lng = _extract_alert_location(alert)
    return SOSAlertItem(
        alert_id=str(alert.alert_id),
        user_id=str(alert.user_id),
        user_name=user.full_name,
        user_phone_number=user.phone_number,
        user_email=user.email,
        ride_id=str(alert.ride_id),
        ride_date=str(ride.ride_date) if ride.ride_date else None,
        ride_time=str(ride.ride_time) if ride.ride_time else None,
        ride_status=ride.status.value if hasattr(ride.status, "value") else str(ride.status),
        start_address=ride.start_address,
        end_address=ride.end_address,
        triggered_at=str(alert.triggered_at) if alert.triggered_at else None,
        latitude=lat,
        longitude=lng,
        status=alert.status.value if hasattr(alert.status, "value") else str(alert.status),
        resolved_at=str(alert.resolved_at) if alert.resolved_at else None,
        resolved_by_user_id=str(alert.resolved_by_user_id) if alert.resolved_by_user_id else None,
        resolved_by_name=resolver.full_name if resolver else None,
        resolution_notes=alert.resolution_notes,
    )


async def _get_sos_alert_row(
    db: DBSession,
    alert_id: uuid.UUID,
) -> tuple[SOSAlert, User, Ride, Optional[User]] | None:
    resolver = aliased(User)
    result = await db.execute(
        select(SOSAlert, User, Ride, resolver)
        .join(User, SOSAlert.user_id == User.user_id)
        .join(Ride, SOSAlert.ride_id == Ride.ride_id)
        .outerjoin(resolver, SOSAlert.resolved_by_user_id == resolver.user_id)
        .where(SOSAlert.alert_id == alert_id)
    )
    return result.first()


# ---------------------------------------------------------------------------
# USER MANAGEMENT
# ---------------------------------------------------------------------------

@router.get("/users", response_model=list[UserListItem])
async def list_users(
    _: User = AdminUser,
    db: DBSession = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
):
    """List all users with pagination."""
    offset = (page - 1) * page_size
    result = await db.execute(
        select(User).order_by(User.created_at.desc()).offset(offset).limit(page_size)
    )
    users = result.scalars().all()
    return [_serialize_user_list_item(u) for u in users]


@router.get("/users/{user_id}", response_model=AdminUserDetail)
async def get_user(
    user_id: uuid.UUID,
    _: User = AdminUser,
    db: DBSession = None,
):
    """Get a specific user's details plus support and moderation context."""
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    identity_result = await db.execute(
        select(IdentityVerification)
        .where(IdentityVerification.user_id == user_id)
        .order_by(IdentityVerification.created_at.desc())
        .limit(1)
    )
    identity_record = identity_result.scalar_one_or_none()

    driver_result = await db.execute(
        select(DriverVerification)
        .where(DriverVerification.user_id == user_id)
        .order_by(DriverVerification.created_at.desc())
        .limit(1)
    )
    driver_record = driver_result.scalar_one_or_none()

    vehicles_result = await db.execute(
        select(Vehicle)
        .where(Vehicle.user_id == user_id)
        .order_by(Vehicle.created_at.desc())
    )
    vehicles = vehicles_result.scalars().all()

    driver_rides_result = await db.execute(
        select(Ride, Vehicle)
        .outerjoin(Vehicle, Ride.vehicle_id == Vehicle.vehicle_id)
        .where(Ride.driver_id == user_id)
        .order_by(Ride.created_at.desc())
        .limit(5)
    )
    driver_rides = [
        {
            "ride_id": str(ride.ride_id),
            "role": "driver",
            "status": _enum_value(ride.status) or "unknown",
            "ride_date": str(ride.ride_date) if ride.ride_date else None,
            "ride_time": str(ride.ride_time) if ride.ride_time else None,
            "start_address": ride.start_address,
            "end_address": ride.end_address,
            "driver_name": user.full_name,
            "vehicle_number": vehicle.vehicle_number if vehicle else None,
            "request_status": None,
            "activity_at": str(ride.created_at) if ride.created_at else None,
        }
        for ride, vehicle in driver_rides_result.all()
    ]

    driver_alias = aliased(User)
    participant_rides_result = await db.execute(
        select(RideParticipant, Ride, driver_alias, Vehicle)
        .join(Ride, RideParticipant.ride_id == Ride.ride_id)
        .join(driver_alias, Ride.driver_id == driver_alias.user_id)
        .outerjoin(Vehicle, Ride.vehicle_id == Vehicle.vehicle_id)
        .where(RideParticipant.user_id == user_id)
        .order_by(RideParticipant.joined_at.desc())
        .limit(5)
    )
    participant_rides = [
        {
            "ride_id": str(ride.ride_id),
            "role": "passenger",
            "status": _enum_value(ride.status) or "unknown",
            "ride_date": str(ride.ride_date) if ride.ride_date else None,
            "ride_time": str(ride.ride_time) if ride.ride_time else None,
            "start_address": ride.start_address,
            "end_address": ride.end_address,
            "driver_name": driver_user.full_name,
            "vehicle_number": vehicle.vehicle_number if vehicle else None,
            "request_status": None,
            "activity_at": str(participant.joined_at) if participant.joined_at else None,
        }
        for participant, ride, driver_user, vehicle in participant_rides_result.all()
    ]

    request_driver_alias = aliased(User)
    ride_requests_result = await db.execute(
        select(RideRequest, Ride, request_driver_alias)
        .join(Ride, RideRequest.ride_id == Ride.ride_id)
        .join(request_driver_alias, Ride.driver_id == request_driver_alias.user_id)
        .where(RideRequest.passenger_id == user_id)
        .order_by(RideRequest.requested_at.desc())
        .limit(5)
    )
    ride_requests = [
        {
            "ride_id": str(ride.ride_id),
            "role": "requester",
            "status": _enum_value(ride.status) or "unknown",
            "ride_date": str(ride.ride_date) if ride.ride_date else None,
            "ride_time": str(ride.ride_time) if ride.ride_time else None,
            "start_address": ride.start_address,
            "end_address": ride.end_address,
            "driver_name": driver_user.full_name,
            "vehicle_number": None,
            "request_status": _enum_value(request.request_status),
            "activity_at": str(request.requested_at) if request.requested_at else None,
        }
        for request, ride, driver_user in ride_requests_result.all()
    ]

    recent_rides = sorted(
        driver_rides + participant_rides + ride_requests,
        key=lambda item: item["activity_at"] or "",
        reverse=True,
    )[:8]

    reported_alias = aliased(User)
    filed_reports_result = await db.execute(
        select(Report, reported_alias)
        .join(reported_alias, Report.reported_user_id == reported_alias.user_id)
        .where(Report.reporter_id == user_id)
        .order_by(Report.created_at.desc())
        .limit(5)
    )
    filed_reports = [
        {
            "report_id": str(report.report_id),
            "ride_id": str(report.ride_id),
            "direction": "filed",
            "other_user_id": str(other_user.user_id),
            "other_user_name": other_user.full_name,
            "comment": report.comment,
            "created_at": str(report.created_at) if report.created_at else None,
        }
        for report, other_user in filed_reports_result.all()
    ]

    reporter_alias = aliased(User)
    received_reports_result = await db.execute(
        select(Report, reporter_alias)
        .join(reporter_alias, Report.reporter_id == reporter_alias.user_id)
        .where(Report.reported_user_id == user_id)
        .order_by(Report.created_at.desc())
        .limit(5)
    )
    received_reports = [
        {
            "report_id": str(report.report_id),
            "ride_id": str(report.ride_id),
            "direction": "received",
            "other_user_id": str(other_user.user_id),
            "other_user_name": other_user.full_name,
            "comment": report.comment,
            "created_at": str(report.created_at) if report.created_at else None,
        }
        for report, other_user in received_reports_result.all()
    ]

    recent_reports = sorted(
        filed_reports + received_reports,
        key=lambda item: item["created_at"] or "",
        reverse=True,
    )[:8]

    sos_result = await db.execute(
        select(SOSAlert)
        .where(SOSAlert.user_id == user_id)
        .order_by(SOSAlert.triggered_at.desc())
        .limit(8)
    )
    sos_alerts = sos_result.scalars().all()

    driver_rides_count = (
        await db.execute(
            select(func.count(Ride.ride_id)).where(Ride.driver_id == user_id)
        )
    ).scalar() or 0
    passenger_rides_count = (
        await db.execute(
            select(func.count(RideParticipant.participant_id))
            .where(RideParticipant.user_id == user_id)
        )
    ).scalar() or 0
    ride_requests_count = (
        await db.execute(
            select(func.count(RideRequest.request_id))
            .where(RideRequest.passenger_id == user_id)
        )
    ).scalar() or 0
    reports_filed_count = (
        await db.execute(
            select(func.count(Report.report_id)).where(Report.reporter_id == user_id)
        )
    ).scalar() or 0
    reports_received_count = (
        await db.execute(
            select(func.count(Report.report_id)).where(Report.reported_user_id == user_id)
        )
    ).scalar() or 0
    sos_count = (
        await db.execute(
            select(func.count(SOSAlert.alert_id)).where(SOSAlert.user_id == user_id)
        )
    ).scalar() or 0

    list_item = _serialize_user_list_item(user)
    return AdminUserDetail(
        user_id=list_item.user_id,
        full_name=list_item.full_name,
        phone_number=list_item.phone_number,
        email=list_item.email,
        gender=list_item.gender,
        is_active=list_item.is_active,
        is_phone_verified=list_item.is_phone_verified,
        is_email_verified=list_item.is_email_verified,
        is_identity_verified=list_item.is_identity_verified,
        is_driver_verified=list_item.is_driver_verified,
        is_admin=list_item.is_admin,
        created_at=list_item.created_at,
        community=user.community,
        profile_photo_url=user.profile_photo_url,
        updated_at=str(user.updated_at) if user.updated_at else None,
        identity_verification=_serialize_verification_detail(identity_record) if identity_record else None,
        driver_verification=_serialize_verification_detail(driver_record) if driver_record else None,
        activity_summary=UserActivitySummary(
            driver_rides=driver_rides_count,
            passenger_rides=passenger_rides_count,
            ride_requests=ride_requests_count,
            reports_filed=reports_filed_count,
            reports_received=reports_received_count,
            sos_triggered=sos_count,
            vehicles=len(vehicles),
        ),
        vehicles=[
            UserVehicleItem(
                vehicle_id=str(vehicle.vehicle_id),
                vehicle_type=_enum_value(vehicle.vehicle_type) or "",
                vehicle_number=vehicle.vehicle_number,
                created_at=str(vehicle.created_at) if vehicle.created_at else None,
            )
            for vehicle in vehicles
        ],
        recent_rides=[
            AdminUserRideItem(**item)
            for item in recent_rides
        ],
        recent_reports=[
            AdminUserReportItem(**item)
            for item in recent_reports
        ],
        recent_sos_alerts=[
            AdminUserSOSItem(
                alert_id=str(alert.alert_id),
                ride_id=str(alert.ride_id),
                status=_enum_value(alert.status) or "open",
                triggered_at=str(alert.triggered_at) if alert.triggered_at else None,
                resolved_at=str(alert.resolved_at) if alert.resolved_at else None,
                resolution_notes=alert.resolution_notes,
            )
            for alert in sos_alerts
        ],
    )


@router.put("/users/{user_id}/deactivate")
async def deactivate_user(
    user_id: uuid.UUID,
    _: User = AdminUser,
    db: DBSession = None,
):
    """Deactivate a user account (blocks login)."""
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.is_admin:
        raise HTTPException(status_code=400, detail="Cannot deactivate another admin.")
    user.is_active = False
    await db.flush()
    return {"message": f"User {user.full_name} deactivated."}


@router.put("/users/{user_id}/activate")
async def activate_user(
    user_id: uuid.UUID,
    _: User = AdminUser,
    db: DBSession = None,
):
    """Re-activate a deactivated user account."""
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = True
    await db.flush()
    return {"message": f"User {user.full_name} activated."}


# ---------------------------------------------------------------------------
# IDENTITY VERIFICATION MANAGEMENT
# ---------------------------------------------------------------------------

@router.get("/verifications/identity/pending", response_model=list[VerificationItem])
async def list_pending_identity(
    _: User = AdminUser,
    db: DBSession = None,
):
    """List all submitted (pending) identity verifications."""
    result = await db.execute(
        select(IdentityVerification, User)
        .join(User, IdentityVerification.user_id == User.user_id)
        .where(IdentityVerification.status == VerificationStatusEnum.submitted)
        .order_by(IdentityVerification.created_at.asc())
    )
    rows = result.all()
    return [
        VerificationItem(
            user_id=str(iv.user_id),
            full_name=u.full_name,
            phone_number=u.phone_number,
            email=u.email,
            status=iv.status.value,
            submitted_at=str(iv.created_at) if iv.created_at else None,
            reviewer_notes=iv.reviewer_notes,
            document_url=iv.document_url,
            college_id_number=iv.college_id_number,
        )
        for iv, u in rows
    ]


class ReviewRequest(BaseModel):
    notes: Optional[str] = None


@router.put("/verifications/identity/{user_id}/approve")
async def approve_identity(
    user_id: uuid.UUID,
    payload: ReviewRequest = ReviewRequest(),
    _: User = AdminUser,
    db: DBSession = None,
):
    """Approve identity verification: sets is_identity_verified = True."""
    iv_result = await db.execute(
        select(IdentityVerification).where(IdentityVerification.user_id == user_id)
    )
    iv = iv_result.scalar_one_or_none()
    if not iv:
        raise HTTPException(status_code=404, detail="Verification record not found")
    iv.status = VerificationStatusEnum.verified
    iv.reviewer_notes = payload.notes
    iv.reviewed_at = datetime.now(timezone.utc)

    user_result = await db.execute(select(User).where(User.user_id == user_id))
    user = user_result.scalar_one_or_none()
    if user:
        user.is_identity_verified = True
    await db.flush()
    return {"message": "Identity verified and approved."}


@router.put("/verifications/identity/{user_id}/reject")
async def reject_identity(
    user_id: uuid.UUID,
    payload: ReviewRequest = ReviewRequest(),
    _: User = AdminUser,
    db: DBSession = None,
):
    """Reject identity verification with optional notes."""
    iv_result = await db.execute(
        select(IdentityVerification).where(IdentityVerification.user_id == user_id)
    )
    iv = iv_result.scalar_one_or_none()
    if not iv:
        raise HTTPException(status_code=404, detail="Verification record not found")
    iv.status = VerificationStatusEnum.rejected
    iv.reviewer_notes = payload.notes
    iv.reviewed_at = datetime.now(timezone.utc)
    await db.flush()
    return {"message": "Identity verification rejected."}


# ---------------------------------------------------------------------------
# DRIVER VERIFICATION MANAGEMENT
# ---------------------------------------------------------------------------

@router.get("/verifications/driver/pending", response_model=list[VerificationItem])
async def list_pending_driver(
    _: User = AdminUser,
    db: DBSession = None,
):
    """List all submitted (pending) driver verifications."""
    result = await db.execute(
        select(DriverVerification, User)
        .join(User, DriverVerification.user_id == User.user_id)
        .where(DriverVerification.status == VerificationStatusEnum.submitted)
        .order_by(DriverVerification.created_at.asc())
    )
    rows = result.all()
    return [
        VerificationItem(
            user_id=str(dv.user_id),
            full_name=u.full_name,
            phone_number=u.phone_number,
            email=u.email,
            status=dv.status.value,
            submitted_at=str(dv.created_at) if dv.created_at else None,
            reviewer_notes=dv.reviewer_notes,
            license_document_url=dv.license_document_url,
            license_number=dv.license_number,
        )
        for dv, u in rows
    ]


@router.put("/verifications/driver/{user_id}/approve")
async def approve_driver(
    user_id: uuid.UUID,
    payload: ReviewRequest = ReviewRequest(),
    _: User = AdminUser,
    db: DBSession = None,
):
    """Approve driver verification: sets is_driver_verified = True."""
    dv_result = await db.execute(
        select(DriverVerification).where(DriverVerification.user_id == user_id)
    )
    dv = dv_result.scalar_one_or_none()
    if not dv:
        raise HTTPException(status_code=404, detail="Driver verification record not found")
    dv.status = VerificationStatusEnum.verified
    dv.reviewer_notes = payload.notes
    dv.reviewed_at = datetime.now(timezone.utc)

    user_result = await db.execute(select(User).where(User.user_id == user_id))
    user = user_result.scalar_one_or_none()
    if user:
        user.is_driver_verified = True
    await db.flush()
    return {"message": "Driver verified and approved."}


@router.put("/verifications/driver/{user_id}/reject")
async def reject_driver(
    user_id: uuid.UUID,
    payload: ReviewRequest = ReviewRequest(),
    _: User = AdminUser,
    db: DBSession = None,
):
    """Reject driver verification."""
    dv_result = await db.execute(
        select(DriverVerification).where(DriverVerification.user_id == user_id)
    )
    dv = dv_result.scalar_one_or_none()
    if not dv:
        raise HTTPException(status_code=404, detail="Driver verification record not found")
    dv.status = VerificationStatusEnum.rejected
    dv.reviewer_notes = payload.notes
    dv.reviewed_at = datetime.now(timezone.utc)
    await db.flush()
    return {"message": "Driver verification rejected."}


# ---------------------------------------------------------------------------
# SOS ALERTS
# ---------------------------------------------------------------------------

@router.get("/sos", response_model=list[SOSAlertItem])
async def list_sos_alerts(
    _: User = AdminUser,
    db: DBSession = None,
    status_filter: str = Query("all", alias="status"),
    page_size: int = Query(100, ge=1, le=250),
):
    """List SOS alerts for admin triage."""
    normalized_status = status_filter.lower()
    if normalized_status not in {"all", "open", "resolved", "closed"}:
        raise HTTPException(
            status_code=400,
            detail="status must be one of: all, open, resolved, closed",
        )

    resolver = aliased(User)
    stmt = (
        select(SOSAlert, User, Ride, resolver)
        .join(User, SOSAlert.user_id == User.user_id)
        .join(Ride, SOSAlert.ride_id == Ride.ride_id)
        .outerjoin(resolver, SOSAlert.resolved_by_user_id == resolver.user_id)
        .order_by(SOSAlert.triggered_at.desc())
        .limit(page_size)
    )
    if normalized_status != "all":
        stmt = stmt.where(SOSAlert.status == SOSAlertStatusEnum(normalized_status))

    result = await db.execute(stmt)
    rows = result.all()
    return [
        _serialize_sos_item(alert, user, ride, resolver_user)
        for alert, user, ride, resolver_user in rows
    ]


@router.get("/sos/active", response_model=list[SOSAlertItem])
async def list_active_sos(
    _: User = AdminUser,
    db: DBSession = None,
):
    """List open SOS alerts with location."""
    return await list_sos_alerts(_, db, status_filter="open", page_size=100)


@router.put("/sos/{alert_id}/status", response_model=SOSAlertItem)
async def update_sos_status(
    alert_id: uuid.UUID,
    payload: SOSStatusUpdateRequest,
    admin: User = AdminUser,
    db: DBSession = None,
):
    """Update SOS lifecycle status for admin triage."""
    row = await _get_sos_alert_row(db, alert_id)
    if not row:
        raise HTTPException(status_code=404, detail="SOS alert not found")

    alert, _, _, _ = row
    next_status = SOSAlertStatusEnum(payload.status)
    alert.status = next_status

    if next_status == SOSAlertStatusEnum.open:
        alert.resolved_at = None
        alert.resolved_by_user_id = None
    else:
        alert.resolved_at = datetime.now(timezone.utc)
        alert.resolved_by_user_id = admin.user_id

    alert.resolution_notes = payload.notes
    await db.flush()

    updated_row = await _get_sos_alert_row(db, alert_id)
    assert updated_row is not None
    updated_alert, user, ride, resolver = updated_row
    return _serialize_sos_item(updated_alert, user, ride, resolver)


@router.put("/sos/{alert_id}/resolve", response_model=SOSAlertItem)
async def resolve_sos_alert(
    alert_id: uuid.UUID,
    payload: ReviewRequest = ReviewRequest(),
    admin: User = AdminUser,
    db: DBSession = None,
):
    """Resolve an SOS alert."""
    return await update_sos_status(
        alert_id,
        SOSStatusUpdateRequest(status="resolved", notes=payload.notes),
        admin,
        db,
    )


@router.put("/sos/{alert_id}/close", response_model=SOSAlertItem)
async def close_sos_alert(
    alert_id: uuid.UUID,
    payload: ReviewRequest = ReviewRequest(),
    admin: User = AdminUser,
    db: DBSession = None,
):
    """Close an SOS alert."""
    return await update_sos_status(
        alert_id,
        SOSStatusUpdateRequest(status="closed", notes=payload.notes),
        admin,
        db,
    )


# ---------------------------------------------------------------------------
# DASHBOARD STATS
# ---------------------------------------------------------------------------

@router.get("/stats")
async def get_stats(
    _: User = AdminUser,
    db: DBSession = None,
):
    """Return high-level platform statistics."""
    total_users = (await db.execute(select(func.count(User.user_id)))).scalar()
    active_users = (await db.execute(
        select(func.count(User.user_id)).where(User.is_active == True)
    )).scalar()
    verified_identities = (await db.execute(
        select(func.count(User.user_id)).where(User.is_identity_verified == True)
    )).scalar()
    verified_drivers = (await db.execute(
        select(func.count(User.user_id)).where(User.is_driver_verified == True)
    )).scalar()
    pending_identity = (await db.execute(
        select(func.count(IdentityVerification.verification_id))
        .where(IdentityVerification.status == VerificationStatusEnum.submitted)
    )).scalar()
    pending_driver = (await db.execute(
        select(func.count(DriverVerification.verification_id))
        .where(DriverVerification.status == VerificationStatusEnum.submitted)
    )).scalar()
    active_rides = (await db.execute(
        select(func.count(Ride.ride_id))
        .where(Ride.status == RideStatusEnum.open)
    )).scalar()
    total_sos = (await db.execute(select(func.count(SOSAlert.alert_id)))).scalar()
    open_sos = (await db.execute(
        select(func.count(SOSAlert.alert_id))
        .where(SOSAlert.status == SOSAlertStatusEnum.open)
    )).scalar()
    resolved_sos = (await db.execute(
        select(func.count(SOSAlert.alert_id))
        .where(SOSAlert.status == SOSAlertStatusEnum.resolved)
    )).scalar()
    closed_sos = (await db.execute(
        select(func.count(SOSAlert.alert_id))
        .where(SOSAlert.status == SOSAlertStatusEnum.closed)
    )).scalar()

    return {
        "users": {
            "total": total_users,
            "active": active_users,
            "identity_verified": verified_identities,
            "driver_verified": verified_drivers,
        },
        "verifications": {
            "pending_identity": pending_identity,
            "pending_driver": pending_driver,
        },
        "rides": {
            "active_open": active_rides,
        },
        "sos": {
            "total_triggered": total_sos,
            "open": open_sos,
            "resolved": resolved_sos,
            "closed": closed_sos,
        },
    }
