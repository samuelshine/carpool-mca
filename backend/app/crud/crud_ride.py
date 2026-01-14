from typing import List, Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.crud.base import CRUDBase
from app.models.ride import Ride, RideRequest, RequestStatus
from app.schemas.ride import RideCreate, RideUpdate, RideRequestCreate

class CRUDRide(CRUDBase[Ride, RideCreate, RideUpdate]):
    def create_with_driver(
        self, db: Session, *, obj_in: RideCreate, driver_id: UUID
    ) -> Ride:
        db_obj = Ride(
            **obj_in.dict(),
            driver_id=driver_id
        )
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    def get_nearby_rides(self, db: Session) -> List[Ride]:
        # Placeholder for geospatial query. For MVP returning all scheduled rides.
        # Logic: In a real PostGIS impl, we would use ST_DWithin
        return db.query(self.model).filter(
            self.model.status == "SCHEDULED"
        ).all()

ride = CRUDRide(Ride)

class CRUDRideRequest(CRUDBase[RideRequest, RideRequestCreate, RideRequestCreate]):
    def create_request(
        self, db: Session, *, ride_id: UUID, passenger_id: UUID
    ) -> RideRequest:
        db_obj = RideRequest(
            ride_id=ride_id,
            passenger_id=passenger_id,
            status=RequestStatus.PENDING
        )
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

ride_request = CRUDRideRequest(RideRequest)
