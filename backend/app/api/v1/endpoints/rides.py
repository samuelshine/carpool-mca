from typing import Any, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.api import deps

router = APIRouter()

@router.post("/", response_model=schemas.Ride)
def create_ride(
    *,
    db: Session = Depends(deps.get_db),
    ride_in: schemas.RideCreate,
    current_user: models.User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Create a new ride.
    """
    ride = crud.ride.create_with_driver(db=db, obj_in=ride_in, driver_id=current_user.id)
    return ride

@router.get("/search", response_model=List[schemas.Ride])
def search_rides(
    db: Session = Depends(deps.get_db),
    current_user: models.User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Search for available rides.
    """
    rides = crud.ride.get_nearby_rides(db=db)
    
    # Female-only filter logic
    if current_user.gender != "FEMALE":
         rides = [r for r in rides if not r.females_only]
         
    return rides

@router.post("/{ride_id}/join", response_model=schemas.RideRequest)
def join_ride(
    *,
    db: Session = Depends(deps.get_db),
    ride_id: UUID,
    current_user: models.User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Request to join a ride.
    """
    ride = crud.ride.get(db=db, id=ride_id)
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")
        
    if ride.females_only and current_user.gender != "FEMALE":
        raise HTTPException(status_code=403, detail="This ride is for female passengers only")

    request = crud.ride_request.create_request(db=db, ride_id=ride_id, passenger_id=current_user.id)
    return request
