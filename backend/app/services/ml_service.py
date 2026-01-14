from typing import Dict, Any
from app.services.ml.cancellation_model import cancellation_predictor
from app.services.trust_service import trust_service
from app.services.safety_service import safety_service

class MLService:
    def __init__(self):
        self.risk_model = cancellation_predictor
        self.trust_engine = trust_service
        self.safety_monitor = safety_service
        
    def predict_cancellation_risk(self, user_stats: Dict[str, Any], ride_details: Dict[str, Any]) -> float:
        """
        Predict probability of cancellation using weighted heuristics.
        """
        # Combine inputs into a single feature vector
        features = {
            "past_cancellations": user_stats.get("past_cancellations", 0),
            "days_until_ride": ride_details.get("days_until_ride", 0),
            "reliability_score": user_stats.get("trust_score", 100) / 100.0,
            "weather_severity": 0.0 # Placeholder
        }
        return self.risk_model.predict(features)
        
    def calculate_trust_score(self, current_score: float, event_type: str, metadata: Dict[str, Any] = None) -> float:
        """
        Recalculate user trust score based on new events.
        """
        return self.trust_engine.calculate_score(current_score, event_type, metadata)

ml_service = MLService()
