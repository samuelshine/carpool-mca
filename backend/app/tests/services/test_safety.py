from app.services.safety_service import safety_service

def test_haversine_distance():
    # Distance between New York and London approx 5570km
    ny = (40.7128, -74.0060)
    lon = (51.5074, -0.1278)
    
    dist_meters = safety_service._haversine_distance(ny[0], ny[1], lon[0], lon[1])
    dist_km = dist_meters / 1000.0
    
    assert 5500 < dist_km < 5600

def test_route_deviation():
    route_points = [(12.9716, 77.5946)] # Bangalore coords
    
    # Near point (Safe)
    safe_loc = (12.9717, 77.5947) 
    assert safety_service.check_route_deviation(safe_loc, route_points) == False
    
    # Far point (Unsafe) - 1 degree (approx 111km away)
    unsafe_loc = (13.9716, 77.5946)
    assert safety_service.check_route_deviation(unsafe_loc, route_points) == True
