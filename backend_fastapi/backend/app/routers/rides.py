"""
Rides Router — Multi-passenger ride lifecycle management.

Endpoints:
  POST   /rides                              — Create ride (driver)
  GET    /rides                              — List available rides
  GET    /rides/mine                         — List rides created by current driver
  GET    /rides/history                      — List rides and requests for current user
  GET    /rides/{ride_id}                    — Get ride details
  PUT    /rides/{ride_id}/status             — Update ride status
  POST   /rides/{ride_id}/request            — Rider requests to join (with pickup loc)
  GET    /rides/{ride_id}/requests           — List pending requests (driver)
  PUT    /rides/{ride_id}/requests/{req_id}  — Accept/reject request
  POST   /rides/{ride_id}/verify-otp         — Verify rider's pickup OTP
  GET    /rides/{ride_id}/participants       — List participants with pickup info
"""
import random
import string
import uuid
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from core.deps import DBSession, CurrentUser, VerifiedDriver, EmailVerifiedUser
from db.models.rides import Ride
from db.models.vehicles import Vehicle
from db.models.ride_requests import RideRequest
from db.models.ride_participants import RideParticipant
from db.models.users import User
from db.enums import RideStatusEnum, RideRequestStatusEnum
from schemas.rides import (
    RideCreate, RideRead, RideDetailRead, RideParticipantDetailRead,
    RideStatusUpdate, OtpVerifyRequest, RideHistoryItemRead,
)
from schemas.ride_requests import (
    RideRequestCreate, RideRequestRead, RideRequestAction, RideRequestWithUser,
)


router = APIRouter(prefix="/rides", tags=["Rides"])


def _generate_otp() -> str:
    return "".join(random.choices(string.digits, k=4))


def _history_state_from_ride_status(status: RideStatusEnum) -> str:
    if status in {
        RideStatusEnum.open,
        RideStatusEnum.driver_arriving,
        RideStatusEnum.driver_arrived,
        RideStatusEnum.rider_picked_up,
        RideStatusEnum.ongoing,
    }:
        return "active"
    if status == RideStatusEnum.completed:
        return "completed"
    if status == RideStatusEnum.cancelled:
        return "cancelled"
    return "active"


def _status_label_from_ride_status(status: RideStatusEnum) -> str:
    return status.value.replace("_", " ").upper()


# ─── Create ride ────────────────────────────────────────────────────────────

@router.post("/", response_model=RideRead, status_code=status.HTTP_201_CREATED)
async def create_ride(payload: RideCreate, user: VerifiedDriver, db: DBSession):
    """Create a new ride. Only the driver creates rides."""
    result = await db.execute(
        select(Vehicle).where(
            Vehicle.vehicle_id == payload.vehicle_id,
            Vehicle.user_id == user.user_id,
        )
    )
    vehicle = result.scalar_one_or_none()
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or does not belong to you.",
        )

    from geoalchemy2.shape import from_shape
    from shapely.geometry import Point

    ride = Ride(
        ride_id=uuid.uuid4(),
        driver_id=user.user_id,
        vehicle_id=payload.vehicle_id,
        start_location=from_shape(
            Point(payload.start_location.longitude, payload.start_location.latitude),
            srid=4326,
        ),
        end_location=from_shape(
            Point(payload.end_location.longitude, payload.end_location.latitude),
            srid=4326,
        ),
        start_address=payload.start_address,
        end_address=payload.end_address,
        ride_date=payload.ride_date,
        ride_time=payload.ride_time,
        available_seats=payload.available_seats,
        allowed_gender=payload.allowed_gender,
        allowed_community=payload.allowed_community,
        estimated_fare=payload.estimated_fare,
    )
    db.add(ride)
    await db.flush()
    await db.refresh(ride)
    return ride


# ─── List rides ─────────────────────────────────────────────────────────────

@router.get("/", response_model=list[RideRead])
async def list_rides(db: DBSession):
    """List rides with status 'open'."""
    result = await db.execute(
        select(Ride).where(Ride.status == RideStatusEnum.open)
    )
    return result.scalars().all()


@router.get("/mine", response_model=list[RideRead])
async def list_my_rides(user: CurrentUser, db: DBSession):
    """List rides created by the current authenticated driver."""
    result = await db.execute(
        select(Ride)
        .where(Ride.driver_id == user.user_id)
        .order_by(Ride.ride_date.desc(), Ride.ride_time.desc(), Ride.created_at.desc())
    )
    return result.scalars().all()


@router.get("/history", response_model=list[RideHistoryItemRead])
async def list_my_ride_history(user: CurrentUser, db: DBSession):
    """List rides and requests relevant to the current user across roles."""
    driver_result = await db.execute(
        select(Ride)
        .options(selectinload(Ride.driver), selectinload(Ride.vehicle))
        .where(Ride.driver_id == user.user_id)
        .order_by(Ride.ride_date.desc(), Ride.ride_time.desc(), Ride.created_at.desc())
    )
    driver_rides = driver_result.scalars().all()

    participant_result = await db.execute(
        select(RideParticipant)
        .options(
            selectinload(RideParticipant.ride).selectinload(Ride.driver),
            selectinload(RideParticipant.ride).selectinload(Ride.vehicle),
        )
        .where(RideParticipant.user_id == user.user_id)
    )
    participations = participant_result.scalars().all()

    request_result = await db.execute(
        select(RideRequest)
        .options(
            selectinload(RideRequest.ride).selectinload(Ride.driver),
            selectinload(RideRequest.ride).selectinload(Ride.vehicle),
        )
        .where(RideRequest.passenger_id == user.user_id)
        .where(RideRequest.request_status.in_([
            RideRequestStatusEnum.pending,
            RideRequestStatusEnum.rejected,
        ]))
    )
    requests = request_result.scalars().all()

    items: list[RideHistoryItemRead] = []
    included_ride_ids: set[uuid.UUID] = set()

    for ride in driver_rides:
        included_ride_ids.add(ride.ride_id)
        items.append(
            RideHistoryItemRead(
                ride_id=ride.ride_id,
                user_role="driver",
                history_state=_history_state_from_ride_status(ride.status),
                status_label=_status_label_from_ride_status(ride.status),
                ride_status=ride.status,
                start_address=ride.start_address,
                end_address=ride.end_address,
                ride_date=ride.ride_date,
                ride_time=ride.ride_time,
                available_seats=ride.available_seats,
                estimated_fare=float(ride.estimated_fare) if ride.estimated_fare is not None else None,
                driver_name=ride.driver.full_name if ride.driver else None,
                vehicle_number=ride.vehicle.vehicle_number if ride.vehicle else None,
                created_at=ride.created_at,
            )
        )

    for participation in participations:
        ride = participation.ride
        if ride is None or ride.ride_id in included_ride_ids:
            continue
        included_ride_ids.add(ride.ride_id)
        items.append(
            RideHistoryItemRead(
                ride_id=ride.ride_id,
                user_role="passenger",
                history_state=_history_state_from_ride_status(ride.status),
                status_label=_status_label_from_ride_status(ride.status),
                ride_status=ride.status,
                start_address=ride.start_address,
                end_address=ride.end_address,
                ride_date=ride.ride_date,
                ride_time=ride.ride_time,
                available_seats=ride.available_seats,
                estimated_fare=float(ride.estimated_fare) if ride.estimated_fare is not None else None,
                driver_name=ride.driver.full_name if ride.driver else None,
                vehicle_number=ride.vehicle.vehicle_number if ride.vehicle else None,
                joined_at=participation.joined_at,
                created_at=ride.created_at,
            )
        )

    for request in requests:
        ride = request.ride
        if ride is None or ride.ride_id in included_ride_ids:
            continue
        items.append(
            RideHistoryItemRead(
                ride_id=ride.ride_id,
                user_role="requester",
                history_state="requested",
                status_label=request.request_status.value.upper(),
                ride_status=ride.status,
                request_status=request.request_status.value,
                start_address=ride.start_address,
                end_address=ride.end_address,
                ride_date=ride.ride_date,
                ride_time=ride.ride_time,
                available_seats=ride.available_seats,
                estimated_fare=float(ride.estimated_fare) if ride.estimated_fare is not None else None,
                driver_name=ride.driver.full_name if ride.driver else None,
                vehicle_number=ride.vehicle.vehicle_number if ride.vehicle else None,
                requested_at=request.requested_at,
                created_at=ride.created_at,
            )
        )

    items.sort(
        key=lambda item: (
            item.ride_date,
            item.ride_time,
            item.requested_at or item.joined_at or item.created_at,
        ),
        reverse=True,
    )
    return items


# ─── Get ride details ───────────────────────────────────────────────────────

@router.get("/{ride_id}", response_model=RideDetailRead)
async def get_ride(
    ride_id: uuid.UUID, user: CurrentUser, db: DBSession
):
    """Get full ride details including participants and their pickup info."""
    result = await db.execute(
        select(Ride)
        .options(
            selectinload(Ride.driver),
            selectinload(Ride.vehicle),
            selectinload(Ride.participants).selectinload(RideParticipant.user),
        )
        .where(Ride.ride_id == ride_id)
    )
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")

    is_driver = ride.driver_id == user.user_id

    participants = []
    for p in ride.participants:
        participants.append(RideParticipantDetailRead(
            participant_id=p.participant_id,
            user_id=p.user_id,
            full_name=p.user.full_name if p.user else "Unknown",
            phone_number=p.user.phone_number if p.user else "",
            pickup_lat=p.pickup_lat,
            pickup_lng=p.pickup_lng,
            pickup_address=p.pickup_address,
            is_picked_up=p.is_picked_up,
            # Show per-rider OTP to driver only
            pickup_otp=p.pickup_otp if is_driver else None,
            joined_at=p.joined_at,
        ))

    return RideDetailRead(
        ride_id=ride.ride_id,
        start_location={"latitude": 0, "longitude": 0},  # placeholder
        end_location={"latitude": 0, "longitude": 0},
        start_address=ride.start_address,
        end_address=ride.end_address,
        ride_date=ride.ride_date,
        ride_time=ride.ride_time,
        available_seats=ride.available_seats,
        allowed_gender=ride.allowed_gender,
        status=ride.status,
        created_at=ride.created_at,
        driver_name=ride.driver.full_name if ride.driver else None,
        vehicle_number=ride.vehicle.vehicle_number if ride.vehicle else None,
        participants=participants,
        pickup_otp=ride.pickup_otp if not is_driver else None,
    )


# ─── Update ride status ────────────────────────────────────────────────────

@router.put("/{ride_id}/status", response_model=RideRead)
async def update_ride_status(
    ride_id: uuid.UUID,
    payload: RideStatusUpdate,
    user: CurrentUser,
    db: DBSession,
):
    """Update ride status (driver only)."""
    result = await db.execute(
        select(Ride).where(Ride.ride_id == ride_id, Ride.driver_id == user.user_id)
    )
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found or access denied")

    # Generate ride-level OTP when driver starts heading out
    if payload.status == RideStatusEnum.driver_arriving and not ride.pickup_otp:
        ride.pickup_otp = _generate_otp()

    ride.status = payload.status
    await db.flush()
    await db.refresh(ride)
    return ride


# ─── Rider request to join ──────────────────────────────────────────────────

@router.post("/{ride_id}/request", response_model=RideRequestRead)
async def request_join_ride(
    ride_id: uuid.UUID,
    payload: RideRequestCreate,
    user: EmailVerifiedUser,
    db: DBSession,
):
    """Rider requests to join a ride, optionally providing a pickup location."""
    ride_result = await db.execute(
        select(Ride).where(Ride.ride_id == ride_id)
    )
    ride = ride_result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")
    if ride.driver_id == user.user_id:
        raise HTTPException(status_code=400, detail="Cannot request your own ride")
    if ride.available_seats <= 0:
        raise HTTPException(status_code=400, detail="No seats available")

    # Check for existing request
    existing = await db.execute(
        select(RideRequest).where(
            RideRequest.ride_id == ride_id,
            RideRequest.passenger_id == user.user_id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="You have already requested this ride")

    req = RideRequest(
        request_id=uuid.uuid4(),
        ride_id=ride_id,
        passenger_id=user.user_id,
        pickup_lat=payload.pickup_lat,
        pickup_lng=payload.pickup_lng,
        pickup_address=payload.pickup_address,
    )
    db.add(req)
    await db.flush()
    await db.refresh(req)
    return req


# ─── List pending requests (driver) ────────────────────────────────────────

@router.get("/{ride_id}/requests", response_model=list[RideRequestWithUser])
async def list_ride_requests(
    ride_id: uuid.UUID, user: CurrentUser, db: DBSession
):
    """List pending join requests for a ride (driver only)."""
    ride_result = await db.execute(
        select(Ride).where(Ride.ride_id == ride_id, Ride.driver_id == user.user_id)
    )
    if not ride_result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Not your ride")

    result = await db.execute(
        select(RideRequest)
        .options(selectinload(RideRequest.passenger))
        .where(
            RideRequest.ride_id == ride_id,
            RideRequest.request_status == RideRequestStatusEnum.pending,
        )
    )
    requests = result.scalars().all()

    return [
        RideRequestWithUser(
            request_id=r.request_id,
            ride_id=r.ride_id,
            passenger_id=r.passenger_id,
            request_status=r.request_status.value,
            pickup_lat=r.pickup_lat,
            pickup_lng=r.pickup_lng,
            pickup_address=r.pickup_address,
            requested_at=r.requested_at,
            passenger_name=r.passenger.full_name,
            passenger_phone=r.passenger.phone_number,
        )
        for r in requests
    ]


# ─── Accept / reject request ───────────────────────────────────────────────

@router.put("/{ride_id}/requests/{request_id}")
async def handle_ride_request(
    ride_id: uuid.UUID,
    request_id: uuid.UUID,
    payload: RideRequestAction,
    user: CurrentUser,
    db: DBSession,
):
    """Accept or reject a ride request (driver only)."""
    ride_result = await db.execute(
        select(Ride).where(Ride.ride_id == ride_id, Ride.driver_id == user.user_id)
    )
    ride = ride_result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status_code=403, detail="Not your ride")

    req_result = await db.execute(
        select(RideRequest).where(
            RideRequest.request_id == request_id,
            RideRequest.ride_id == ride_id,
        )
    )
    req = req_result.scalar_one_or_none()
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")

    if payload.action == "accept":
        if ride.available_seats <= 0:
            raise HTTPException(status_code=400, detail="No seats available")

        req.request_status = RideRequestStatusEnum.accepted

        # Create participant with pickup info and per-rider OTP
        participant = RideParticipant(
            participant_id=uuid.uuid4(),
            ride_id=ride_id,
            user_id=req.passenger_id,
            pickup_lat=req.pickup_lat,
            pickup_lng=req.pickup_lng,
            pickup_address=req.pickup_address,
            pickup_otp=_generate_otp(),
        )
        db.add(participant)
        ride.available_seats -= 1
    else:
        req.request_status = RideRequestStatusEnum.rejected

    await db.flush()
    return {"message": f"Request {payload.action}ed", "status": req.request_status.value}


# ─── Verify per-rider OTP ──────────────────────────────────────────────────

@router.post("/{ride_id}/verify-otp")
async def verify_pickup_otp(
    ride_id: uuid.UUID,
    payload: OtpVerifyRequest,
    user: CurrentUser,
    db: DBSession,
):
    """Driver enters OTP from a rider to confirm their pickup."""
    ride_result = await db.execute(
        select(Ride).where(Ride.ride_id == ride_id, Ride.driver_id == user.user_id)
    )
    if not ride_result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Not your ride")

    # If participant_id provided, verify that specific rider
    if payload.participant_id:
        p_result = await db.execute(
            select(RideParticipant).where(
                RideParticipant.participant_id == payload.participant_id,
                RideParticipant.ride_id == ride_id,
            )
        )
        participant = p_result.scalar_one_or_none()
        if not participant:
            raise HTTPException(status_code=404, detail="Participant not found")
        if participant.pickup_otp != payload.otp:
            raise HTTPException(status_code=400, detail="Invalid OTP")
        participant.is_picked_up = True
        await db.flush()
        return {"message": "Rider picked up successfully", "participant_id": str(participant.participant_id)}

    # Otherwise try to match OTP against any not-yet-picked-up participant
    result = await db.execute(
        select(RideParticipant).where(
            RideParticipant.ride_id == ride_id,
            RideParticipant.is_picked_up == False,
        )
    )
    for p in result.scalars():
        if p.pickup_otp == payload.otp:
            p.is_picked_up = True
            await db.flush()
            return {"message": "Rider picked up successfully", "participant_id": str(p.participant_id)}

    raise HTTPException(status_code=400, detail="Invalid OTP")


# ─── List participants ──────────────────────────────────────────────────────

@router.get("/{ride_id}/participants", response_model=list[RideParticipantDetailRead])
async def list_participants(
    ride_id: uuid.UUID, user: CurrentUser, db: DBSession
):
    """List confirmed participants with their pickup info."""
    ride_result = await db.execute(select(Ride).where(Ride.ride_id == ride_id))
    ride = ride_result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")

    is_driver = ride.driver_id == user.user_id

    result = await db.execute(
        select(RideParticipant)
        .options(selectinload(RideParticipant.user))
        .where(RideParticipant.ride_id == ride_id)
    )
    participants = result.scalars().all()

    return [
        RideParticipantDetailRead(
            participant_id=p.participant_id,
            user_id=p.user_id,
            full_name=p.user.full_name if p.user else "Unknown",
            phone_number=p.user.phone_number if p.user else "",
            pickup_lat=p.pickup_lat,
            pickup_lng=p.pickup_lng,
            pickup_address=p.pickup_address,
            is_picked_up=p.is_picked_up,
            pickup_otp=p.pickup_otp if is_driver else None,
            joined_at=p.joined_at,
        )
        for p in participants
    ]
