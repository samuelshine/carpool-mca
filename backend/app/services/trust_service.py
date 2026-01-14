from typing import Dict, Any

class TrustScoreService:
    """
    Calculates and updates user Trust Scores based on interactions.
    Range: 0 to 100.
    """
    
    def calculate_score(self, current_score: float, event_type: str, metadata: Dict[str, Any] = None) -> float:
        """
        Recalculate score based on a new event.
        """
        delta = 0.0
        
        if event_type == "RIDE_COMPLETED":
            delta = 2.0
            
        elif event_type == "RIDE_CANCELLED_LATE":
            delta = -15.0
            
        elif event_type == "RIDE_CANCELLED_EARLY":
            delta = -5.0
            
        elif event_type == "RATING_RECEIVED":
            rating = metadata.get("rating", 5)
            if rating == 5: delta = 1.0
            elif rating == 4: delta = 0.5
            elif rating <= 2: delta = -5.0 * (3 - rating)
            
        elif event_type == "VERIFICATION_ADDED":
            delta = 20.0
            
        elif event_type == "SAFETY_REPORT":
            delta = -50.0  # Severe penalty
            
        new_score = current_score + delta
        return min(max(new_score, 0.0), 100.0)

    def get_trust_tier(self, score: float) -> str:
        if score >= 90: return "ELITE"
        if score >= 70: return "TRUSTED"
        if score >= 50: return "NEUTRAL"
        return "AT_RISK"

trust_service = TrustScoreService()
