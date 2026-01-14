from app.services.trust_service import trust_service

def test_trust_score_calculation():
    initial_score = 100.0
    
    # Test Ride Completion (+2)
    new_score = trust_service.calculate_score(initial_score, "RIDE_COMPLETED")
    assert new_score == 100.0 # Cap at 100
    
    # Test Penalty
    score_after_penalty = trust_service.calculate_score(90.0, "RIDE_CANCELLED_LATE")
    assert score_after_penalty == 75.0
    
    # Test Severe Penalty
    score_after_report = trust_service.calculate_score(80.0, "SAFETY_REPORT")
    assert score_after_report == 30.0

def test_trust_tiers():
    assert trust_service.get_trust_tier(95.0) == "ELITE"
    assert trust_service.get_trust_tier(40.0) == "AT_RISK"
