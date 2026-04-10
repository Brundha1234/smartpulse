import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent
sys.path.append(str(PROJECT_ROOT))

from new_backend.simple_ml_predictor import SmartPulsePredictor  # noqa: E402


SAMPLE_USER_DATA = {
    "screen_time": 8.5,
    "night_usage": 3.5,
    "unlock_count": 150,
    "notification_count": 400,
    "app_breakdown": {
        "Instagram": 180,
        "YouTube": 90,
        "WhatsApp": 75,
        "Telegram": 35,
    },
    "stress_level": 4,
    "anxiety_level": 3,
    "depression_level": 3,
    "sleep_quality": 3,
    "work_productivity": 3,
    "social_interactions": 5,
    "physical_activity": 1,
    "age": 25,
    "gender": 1,
    "education": 3,
    "occupation_type": 2,
    "income_level": 3,
}


def predict_custom_data(user_data):
    predictor = SmartPulsePredictor()
    if not predictor.load_model():
        return None
    return predictor.predict_addiction_risk(user_data)


def predict_model():
    print("SmartPulse Advanced Model Prediction")
    print("=" * 50)
    result = predict_custom_data(SAMPLE_USER_DATA)
    if not result:
        print("Model files not found. Run train_model.py first.")
        return None

    print(f"Loaded model: {result['model_type']}")
    print(f"Model accuracy: {result['model_accuracy']:.2f}%")
    print(f"Risk level: {result['risk_level']}")
    print(f"Confidence: {result['confidence']:.2f}%")
    print(f"Probabilities: {result['probabilities']}")
    return result


if __name__ == "__main__":
    predict_model()
