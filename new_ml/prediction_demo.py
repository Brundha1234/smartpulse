import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent
sys.path.append(str(PROJECT_ROOT))

from new_backend.simple_ml_predictor import SmartPulsePredictor  # noqa: E402


def main():
    print("SmartPulse Advanced Prediction Demo")
    print("=" * 60)

    predictor = SmartPulsePredictor()
    if not predictor.load_model():
        print("Model files not found. Run train_model.py first.")
        return

    scenarios = [
        (
            "Low-risk healthy usage",
            {
                "screen_time": 2.4,
                "night_usage": 0.1,
                "unlock_count": 38,
                "notification_count": 42,
                "app_breakdown": {"WhatsApp": 35, "Chrome": 28, "YouTube": 18},
                "stress_level": 2,
                "anxiety_level": 2,
                "depression_level": 1,
                "sleep_quality": 5,
                "work_productivity": 4,
                "social_interactions": 6,
                "physical_activity": 3,
                "age": 28,
                "gender": 1,
                "education": 4,
                "occupation_type": 2,
                "income_level": 3,
            },
        ),
        (
            "Moderate-risk mixed usage",
            {
                "screen_time": 6.1,
                "night_usage": 1.2,
                "unlock_count": 112,
                "notification_count": 185,
                "app_breakdown": {"Instagram": 110, "YouTube": 75, "WhatsApp": 55},
                "stress_level": 4,
                "anxiety_level": 3,
                "depression_level": 2,
                "sleep_quality": 3,
                "work_productivity": 3,
                "social_interactions": 4,
                "physical_activity": 2,
                "age": 24,
                "gender": 1,
                "education": 3,
                "occupation_type": 2,
                "income_level": 3,
            },
        ),
        (
            "High-risk compulsive usage",
            {
                "screen_time": 11.4,
                "night_usage": 4.0,
                "unlock_count": 238,
                "notification_count": 420,
                "app_breakdown": {"Instagram": 210, "TikTok": 185, "YouTube": 140, "Snapchat": 75},
                "stress_level": 5,
                "anxiety_level": 5,
                "depression_level": 4,
                "sleep_quality": 2,
                "work_productivity": 2,
                "social_interactions": 3,
                "physical_activity": 1,
                "age": 19,
                "gender": 1,
                "education": 3,
                "occupation_type": 1,
                "income_level": 2,
            },
        ),
    ]

    for label, payload in scenarios:
        result = predictor.predict_addiction_risk(payload)
        print(f"\nScenario: {label}")
        print(f"Model: {result['model_type']} | Accuracy: {result['model_accuracy']:.2f}%")
        print(f"Prediction: {result['risk_level']} | Confidence: {result['confidence']:.2f}%")


if __name__ == "__main__":
    main()
