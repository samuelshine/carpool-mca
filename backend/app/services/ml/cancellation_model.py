import random
from typing import Dict, Any

class CancellationModel:
    """
    Simulates a trained ML model for predicting ride cancellation risk.
    In a real production environment, this would load a serialized .pkl file (scikit-learn/XGBoost).
    """
    
    def __init__(self):
        # Mock weights for features
        self.weights = {
            "past_cancellations": 0.3,
            "days_until_ride": 0.1,
            "weather_severity": 0.2, # 0-1 scale
            "reliability_score": -0.4 # Inverse relationship
        }
        self.bias = 0.1

    def predict(self, features: Dict[str, Any]) -> float:
        """
        Returns a probability (0.0 to 1.0) of cancellation.
        """
        score = self.bias
        
        score += features.get("past_cancellations", 0) * self.weights["past_cancellations"]
        score += features.get("days_until_ride", 0) * self.weights["days_until_ride"]
        score += features.get("weather_severity", 0) * self.weights["weather_severity"]
        score += features.get("reliability_score", 0) * self.weights["reliability_score"]
        
        # Add some stochastic noise for randomness in demo
        noise = random.uniform(-0.05, 0.05)
        score += noise
        
        # Sigmoid-like clamping (simple version)
        probability = 1 / (1 + pow(2.718, -score))
        
        return min(max(probability, 0.0), 1.0)

    def should_require_confirmation(self, probability: float) -> bool:
        """
        Policy: If risk > 70%, require explicit double confirmation.
        """
        return probability > 0.7

cancellation_predictor = CancellationModel()
