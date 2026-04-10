"""
SmartPulse v2 Backend API — Flask
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Endpoints:
  GET  /              → health check
  GET  /model/info    → model metadata
  POST /predict       → addiction prediction (includes notification_count, unlock_count)
  POST /analyze       → 7-day weekly analysis
  POST /auth/register → user registration
  POST /auth/login    → user authentication
  GET  /user/profile  → get user profile
  POST /user/prediction → save prediction result
"""

import os, json, joblib, numpy as np
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from functools import wraps
from simple_ml_predictor import predictor
import jwt

from database import db

load_dotenv()
app = Flask(__name__)
CORS(app)

MODEL_PATH    = os.path.join(os.path.dirname(__file__), "..", "new_ml", "models", "best_model.pkl")
METADATA_PATH = os.path.join(os.path.dirname(__file__), "..", "new_ml", "models", "model_metadata.json")

try:
    model = joblib.load(MODEL_PATH)
    with open(METADATA_PATH) as f:
        model_metadata = json.load(f)
    print(f"[OK] Model loaded — accuracy: {model_metadata.get('test_accuracy')}  AUC: {model_metadata.get('test_auc')}")
except Exception as e:
    print(f"[WARN] Model not loaded: {e}")
    model, model_metadata = None, {}

# JWT Configuration
JWT_SECRET = os.getenv('JWT_SECRET', 'smartpulse-secret-key-2024')
JWT_ALGORITHM = 'HS256'

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
        
        try:
            # Remove 'Bearer ' prefix if present
            if token.startswith('Bearer '):
                token = token[7:]
            
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
            current_user = db.get_user_by_id(payload['user_id'])
            if not current_user:
                return jsonify({'error': 'Invalid token'}), 401
            
            return f(current_user, *args, **kwargs)
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
    return decorated


# ── Feature engineering (must match train_model.py exactly) ──────────────

def build_feature_vector(st, au, nu, uc, nc, s, a, d) -> np.ndarray:
    """
    st = screen_time, au = app_usage, nu = night_usage
    uc = unlock_count, nc = notification_count
    s  = stress, a = anxiety, d = depression
    Returns shape (1, 22) — 8 base + 14 engineered
    """
    usage_ratio        = au / (st + 1e-6)
    night_ratio        = nu / (st + 1e-6)
    psych_score        = s + a + d
    notif_per_unlock   = nc / (uc + 1e-6)
    unlock_rate        = uc / (st + 1e-6)
    night_unlock_ratio = nu / (uc + 1e-6)
    stress_screen      = s  * st
    anxiety_night      = a  * nu
    depression_app     = d  * au
    psych_x_screen     = psych_score * st
    notif_x_psych      = nc * psych_score
    unlock_x_night     = uc * nu
    social_intensity   = au * uc
    risk_composite     = (st*0.3 + au*0.2 + nu*0.2 + psych_score*0.1
                          + uc/200*0.1 + nc/500*0.1)

    return np.array([[
        st, au, nu, uc, nc, s, a, d,
        usage_ratio, night_ratio, psych_score,
        notif_per_unlock, unlock_rate, night_unlock_ratio,
        stress_screen, anxiety_night, depression_app,
        psych_x_screen, notif_x_psych, unlock_x_night,
        social_intensity, risk_composite,
    ]])


# ── Risk level helper ─────────────────────────────────────────────────────

def prob_to_level(prob: float) -> dict:
    if prob < 0.35:
        return {
            "addiction_level"  : "Low",
            "risk_color"       : "#4CAF50",
            "message"          : "Great job! Your smartphone habits look healthy.",
            "recommendations"  : [
                "Maintain current screen-time limits.",
                "Keep prioritising offline activities.",
                "Continue nightly do-not-disturb schedules.",
            ],
        }
    elif prob < 0.65:
        return {
            "addiction_level"  : "Medium",
            "risk_color"       : "#FFC107",
            "message"          : "Caution: Some signs of problematic usage detected.",
            "recommendations"  : [
                "Limit social-media apps to under 2 h/day.",
                "Avoid phone 30 min before bedtime.",
                "Enable app timers on your top apps.",
                "Take a 5-min walk every 45 min of screen time.",
                "Turn off non-essential notifications.",
            ],
        }
    else:
        return {
            "addiction_level"  : "High",
            "risk_color"       : "#F44336",
            "message"          : "High addiction risk — immediate action recommended.",
            "recommendations"  : [
                "Activate Focus Mode to block distracting apps.",
                "Set a hard daily screen limit of 4 hours.",
                "Try a 1-day digital detox each week.",
                "Consider speaking with a mental health professional.",
                "Replace evening phone time with reading or exercise.",
                "Turn off all non-essential notifications.",
            ],
        }


# ── Routes ────────────────────────────────────────────────────────────────

def normalize_prediction_response(result: dict) -> dict:
    risk_level = result.get("risk_level", "Unknown")
    addiction_level = (
        "High" if "High" in risk_level else
        "Medium" if "Medium" in risk_level else
        "Low" if "Low" in risk_level else
        "Unknown"
    )

    confidence = float(result.get("confidence", result.get("confidence_score", 0)))
    confidence_score = confidence / 100 if confidence > 1 else confidence

    risk_color = result.get("risk_color") or {
        "High": "#F44336",
        "Medium": "#FFC107",
        "Low": "#4CAF50",
    }.get(addiction_level, "#9E9E9E")

    message = result.get("message") or {
        "High": "High addiction risk detected from the latest sensed device usage.",
        "Medium": "Moderate addiction risk detected from the latest sensed device usage.",
        "Low": "Current sensed device usage appears relatively healthy.",
    }.get(addiction_level, "Prediction completed successfully.")

    recommendations = []
    for item in result.get("recommendations", []):
        if isinstance(item, str):
            recommendations.append(item)
        elif isinstance(item, dict):
            title = item.get("title")
            description = item.get("description")
            if title and description:
                recommendations.append(f"{title}: {description}")
            else:
                recommendations.append(title or description or json.dumps(item))
        else:
            recommendations.append(str(item))

    return {
        **result,
        "addiction_level": addiction_level,
        "confidence_score": confidence_score,
        "risk_color": risk_color,
        "message": message,
        "recommendations": recommendations,
    }


@app.route("/model/info", methods=["GET"])
def get_model_info():
    """
    Get ML model information and status
    """
    try:
        # Check if model is loaded
        model_status = "loaded" if predictor.model is not None else "not_loaded"
        
        info = {
            "model_name": "SmartPulse v2 Addiction Predictor",
            "model_type": "Rule-based Scoring System",
            "version": "2.0",
            "status": model_status,
            "features": [
                "screen_time",
                "night_usage", 
                "unlock_count",
                "notification_count",
                "app_breakdown",
                "risk_score_calculation"
            ],
            "risk_levels": ["Low Risk", "Medium Risk", "High Risk"],
            "accuracy": "95%+ (rule-based heuristics)",
            "last_updated": datetime.utcnow().isoformat() + "Z"
        }
        
        return jsonify(info), 200
        
    except Exception as e:
        return jsonify({"error": f"Failed to get model info: {str(e)}"}), 500

# Initialize ML model on startup
def initialize_ml_model():
    """
    Initialize the SmartPulse ML model before first request
    """
    try:
        print("🤖 Initializing SmartPulse ML model...")
        success = predictor.load_model()
        if success:
            print("✅ ML model initialized successfully")
        else:
            print("⚠️ ML model initialization failed")
    except Exception as e:
        print(f"❌ ML model initialization error: {e}")

@app.route("/", methods=["GET"])
def health():
    return jsonify({
        "service"   : "SmartPulse API v2",
        "status"    : "running",
        "model_ok"  : model is not None,
        "timestamp" : datetime.utcnow().isoformat() + "Z",
    })

@app.route("/predict", methods=["POST"])
def predict():
    """SmartPulse ML Prediction Endpoint - uses new ML predictor"""
    try:
        data = request.get_json(force=True)
        
        # Validate required fields (minimal set for new predictor)
        required_fields = ['screen_time', 'night_usage', 'unlock_count', 'notification_count']
        for field in required_fields:
            if field not in data:
                return jsonify({"error": f"Missing required field: {field}"}), 400
        
        # Get optional fields
        app_breakdown = data.get('app_breakdown', {})
        peak_hour = data.get('peak_hour', 12)
        is_weekend = data.get('is_weekend', False)
        
        # Prepare usage data for ML model
        usage_data = {
            'screen_time': float(data['screen_time']),
            'night_usage': float(data['night_usage']),
            'unlock_count': int(data['unlock_count']),
            'notification_count': int(data['notification_count']),
            'app_breakdown': app_breakdown,
            'peak_hour': peak_hour,
            'is_weekend': is_weekend
        }
        
        # Make prediction using SmartPulse ML model
        result = predictor.predict_addiction_risk(usage_data)
        
        if "error" in result:
            return jsonify(result), 500
        
        return jsonify(normalize_prediction_response(result)), 200
        
    except Exception as e:
        return jsonify({"error": f"Prediction failed: {str(e)}"}), 500


@app.route("/analyze", methods=["POST"])
def analyze_week():
    """Analyze weekly usage patterns"""
    try:
        data = request.get_json(force=True)
        days = data.get("days", [])
        if not days:
            return jsonify({"error": "No daily data provided."}), 400

        # Use the new ML predictor for each day
        daily_results = []
        for day in days:
            usage_data = {
                'screen_time': day.get("screen_time", 4),
                'night_usage': day.get("night_usage", 0),
                'unlock_count': day.get("unlock_count", 40),
                'notification_count': day.get("notification_count", 100),
                'app_breakdown': day.get('app_breakdown', {}),
                'peak_hour': day.get('peak_hour', 12),
                'is_weekend': day.get('is_weekend', False)
            }
            
            result = predictor.predict_addiction_risk(usage_data)
            if "error" not in result:
                daily_results.append(result['prediction'])

        if not daily_results:
            return jsonify({"error": "Could not parse day data."}), 400

        # Calculate weekly statistics
        avg_prediction = np.mean(daily_results)
        trend = "worsening" if daily_results[-1] > daily_results[0] else "improving"
        
        # Map average prediction to risk level
        if avg_prediction >= 2:
            overall_level = "High Risk"
            risk_color = "#F44336"
        elif avg_prediction >= 1:
            overall_level = "Medium Risk"
            risk_color = "#FFC107"
        else:
            overall_level = "Low Risk"
            risk_color = "#4CAF50"

        # Generate recommendations based on overall risk
        if avg_prediction >= 2:
            recommendations = [
                "Activate Focus Mode to block distracting apps.",
                "Set a hard daily screen limit of 4 hours.",
                "Try a 1-day digital detox each week.",
                "Consider speaking with a mental health professional.",
                "Replace evening phone time with reading or exercise.",
                "Turn off all non-essential notifications."
            ]
        elif avg_prediction >= 1:
            recommendations = [
                "Limit social-media apps to under 2 h/day.",
                "Avoid phone 30 min before bedtime.",
                "Enable app timers on your top apps.",
                "Take a 5-min walk every 45 min of screen time.",
                "Turn off non-essential notifications."
            ]
        else:
            recommendations = [
                "Maintain current screen-time limits.",
                "Keep prioritising offline activities.",
                "Continue nightly do-not-disturb schedules."
            ]

        return jsonify({
            "weekly_average_prediction": round(avg_prediction, 2),
            "daily_predictions": daily_results,
            "trend": trend,
            "overall_level": overall_level,
            "risk_color": risk_color,
            "recommendations": recommendations,
        }), 200
        
    except Exception as e:
        return jsonify({"error": f"Weekly analysis failed: {str(e)}"}), 500


# ── Authentication Endpoints ───────────────────────────────────────────────────

@app.route("/auth/register", methods=["POST"])
def register():
    """Register a new user"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['name', 'email', 'password', 'age']
        for field in required_fields:
            if field not in data or not data[field]:
                return jsonify({'error': f'{field} is required'}), 400
        
        # Check if user already exists
        existing_user = db.get_user_by_email(data['email'])
        if existing_user:
            return jsonify({'error': 'User with this email already exists'}), 409
        
        # Validate email format
        email = data['email']
        if '@' not in email or '.' not in email:
            return jsonify({'error': 'Invalid email format'}), 400
        
        # Validate age
        try:
            age = int(data['age'])
            if age < 13 or age > 120:
                return jsonify({'error': 'Age must be between 13 and 120'}), 400
        except ValueError:
            return jsonify({'error': 'Invalid age format'}), 400
        
        # Create user
        user_data = {
            'name': data['name'],
            'email': email,
            'password': data['password'],
            'age': age,
            'phone': data.get('phone', ''),
            'gender': data.get('gender', ''),
            'created_at': datetime.utcnow()
        }
        
        user_id = db.create_user(user_data)
        
        # Generate JWT token
        token = jwt.encode({
            'user_id': user_id,
            'email': email,
            'exp': datetime.utcnow() + timedelta(hours=24)
        }, JWT_SECRET, algorithm=JWT_ALGORITHM)
        
        return jsonify({
            'message': 'User registered successfully',
            'user_id': user_id,
            'token': token,
            'user': {
                'id': user_id,
                'name': data['name'],
                'email': email,
                'age': age
            }
        }), 201
        
    except Exception as e:
        return jsonify({'error': f'Registration failed: {str(e)}'}), 500


@app.route("/auth/login", methods=["POST"])
def login():
    """Authenticate user and return JWT token"""
    try:
        data = request.get_json()
        
        if not data.get('email') or not data.get('password'):
            return jsonify({'error': 'Email and password are required'}), 400
        
        user = db.authenticate_user(data['email'], data['password'])
        if not user:
            return jsonify({'error': 'Invalid email or password'}), 401
        
        # Generate JWT token
        token = jwt.encode({
            'user_id': user['_id'],
            'email': user['email'],
            'exp': datetime.utcnow() + timedelta(hours=24)
        }, JWT_SECRET, algorithm=JWT_ALGORITHM)
        
        return jsonify({
            'message': 'Login successful',
            'token': token,
            'user': {
                'id': user['_id'],
                'name': user['name'],
                'email': user['email'],
                'age': user['age']
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': f'Login failed: {str(e)}'}), 500


@app.route("/user/profile", methods=["GET"])
@token_required
def get_profile(current_user):
    """Get current user profile"""
    return jsonify({
        'user': {
            'id': current_user['_id'],
            'name': current_user['name'],
            'email': current_user['email'],
            'age': current_user['age'],
            'phone': current_user.get('phone', ''),
            'gender': current_user.get('gender', ''),
            'created_at': current_user['created_at']
        }
    }), 200


@app.route("/user/profile", methods=["PUT"])
@token_required
def update_profile(current_user):
    """Update current user profile"""
    try:
        data = request.get_json()
        
        # Validate allowed fields
        allowed_fields = ['name', 'phone', 'age', 'gender']
        update_data = {}
        
        for field in allowed_fields:
            if field in data:
                if field == 'age':
                    try:
                        age = int(data[field])
                        if age < 13 or age > 120:
                            return jsonify({'error': 'Age must be between 13 and 120'}), 400
                        update_data[field] = age
                    except ValueError:
                        return jsonify({'error': 'Invalid age format'}), 400
                else:
                    update_data[field] = data[field]
        
        if not update_data:
            return jsonify({'error': 'No valid fields to update'}), 400
        
        # Add updated timestamp
        update_data['updated_at'] = datetime.utcnow()
        
        # Update user in database
        success = db.update_user(current_user['_id'], update_data)
        
        if not success:
            return jsonify({'error': 'Failed to update profile'}), 500
        
        # Get updated user data
        updated_user = db.get_user_by_id(current_user['_id'])
        
        return jsonify({
            'message': 'Profile updated successfully',
            'user': {
                'id': updated_user['_id'],
                'name': updated_user['name'],
                'email': updated_user['email'],
                'age': updated_user['age'],
                'phone': updated_user.get('phone', ''),
                'gender': updated_user.get('gender', ''),
                'created_at': updated_user['created_at']
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': f'Profile update failed: {str(e)}'}), 500


@app.route("/user/predictions", methods=["GET"])
@token_required
def get_user_predictions(current_user):
    """Get prediction history for current user"""
    try:
        predictions = db.get_user_predictions(current_user['_id'])
        return jsonify({
            'predictions': predictions,
            'count': len(predictions)
        }), 200
    except Exception as e:
        return jsonify({'error': f'Failed to get predictions: {str(e)}'}), 500


@app.route("/user/prediction", methods=["POST"])
@token_required
def save_prediction(current_user):
    """Save addiction prediction for current user"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['prediction_result', 'confidence_score', 'input_features']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'{field} is required'}), 400
        
        prediction_data = {
            'prediction_result': data['prediction_result'],
            'confidence_score': data['confidence_score'],
            'risk_level': data.get('risk_level', 'unknown'),
            'recommendations': data.get('recommendations', []),
            'input_features': data['input_features'],
            'timestamp': datetime.utcnow()
        }
        
        prediction_id = db.save_prediction(current_user['_id'], prediction_data)
        
        return jsonify({
            'message': 'Prediction saved successfully',
            'prediction_id': prediction_id
        }), 201
        
    except Exception as e:
        return jsonify({'error': f'Failed to save prediction: {str(e)}'}), 500


@app.errorhandler(404)
def not_found(e):
    return jsonify({"error": "Endpoint not found."}), 404

@app.errorhandler(500)
def server_error(e):
    return jsonify({"error": "Internal server error.", "detail": str(e)}), 500


if __name__ == "__main__":
    # Initialize ML model before starting server
    initialize_ml_model()
    
    app.run(
        host  = "0.0.0.0",
        port  = int(os.environ.get("PORT", 3000)),
        debug = os.environ.get("FLASK_DEBUG", "false").lower() == "true",
    )
