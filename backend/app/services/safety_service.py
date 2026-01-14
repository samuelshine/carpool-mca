import math
from typing import Tuple, List

class SafetyService:
    """
    Monitors active rides for deviations and anomalies.
    """
    
    EARTH_RADIUS_KM = 6371.0
    MAX_DEVIATION_METERS = 500.0 # Alert if > 500m off course
    
    def _haversine_distance(self, lat1, lon1, lat2, lon2) -> float:
        """
        Calculate distance in meters between two coordinates.
        """
        d_lat = math.radians(lat2 - lat1)
        d_lon = math.radians(lon2 - lon1)
        
        a = (math.sin(d_lat / 2) * math.sin(d_lat / 2) +
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
             math.sin(d_lon / 2) * math.sin(d_lon / 2))
             
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return self.EARTH_RADIUS_KM * c * 1000 # Return in meters

    def check_route_deviation(self, current_location: Tuple[float, float], planned_route_points: List[Tuple[float, float]]) -> bool:
        """
        Checks if the current location is significantly far from the nearest point on the route.
        Returns True if deviated (Danger), False if safe.
        """
        if not planned_route_points:
            return False
            
        min_distance = float('inf')
        
        # Simple point-to-point check (Optimized: segment distance in prod)
        for point in planned_route_points:
            dist = self._haversine_distance(
                current_location[0], current_location[1],
                point[0], point[1]
            )
            if dist < min_distance:
                min_distance = dist
                
        return min_distance > self.MAX_DEVIATION_METERS

    def detect_abnormal_stop(self, speed_history: List[float], threshold_mins: int = 5) -> bool:
        """
        Detects if the vehicle has stopped for an unusually long time in an unsafe area.
        """
        # Simplistic logic: if last N speeds are 0, return True
        if len(speed_history) < threshold_mins:
            return False
            
        recent_speeds = speed_history[-threshold_mins:]
        return all(s < 1.0 for s in recent_speeds)

safety_service = SafetyService()
