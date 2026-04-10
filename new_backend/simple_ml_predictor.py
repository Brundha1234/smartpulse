# SmartPulse v2 - ML Prediction Service
# Integrates with trained ML models from the new_ml folder

import numpy as np
import pandas as pd
import joblib
import os
import json
from datetime import datetime

class SmartPulsePredictor:
    def __init__(self):
        self.model = None
        self.scaler = None
        self.feature_selector = None
        self.selected_feature_names = None
        self.model_metadata = None
        self.training_results = None
        self.model_path = os.path.join(os.path.dirname(__file__), '..', 'new_ml', 'models', 'best_model.pkl')
        self.scaler_path = os.path.join(os.path.dirname(__file__), '..', 'new_ml', 'models', 'scaler.pkl')
        self.selector_path = os.path.join(os.path.dirname(__file__), '..', 'new_ml', 'models', 'feature_selector.pkl')
        self.feature_names_path = os.path.join(os.path.dirname(__file__), '..', 'new_ml', 'models', 'feature_names.pkl')
        self.metadata_path = os.path.join(os.path.dirname(__file__), '..', 'new_ml', 'models', 'model_metadata.json')
        self.results_path = os.path.join(os.path.dirname(__file__), '..', 'new_ml', 'models', 'training_results.pkl')
    
    def calculate_risk_score(self, usage_data):
        """Calculate risk score using rule-based approach"""
        score = 0
        
        # Screen time risk (0-3 points)
        screen_time = usage_data.get('screen_time', 0)
        if screen_time > 8:
            score += 3
        elif screen_time > 6:
            score += 2
        elif screen_time > 4:
            score += 1
        
        # Night usage risk (0-2 points)
        night_usage = usage_data.get('night_usage', 0)
        if night_usage > 3:
            score += 2
        elif night_usage > 1.5:
            score += 1
        
        # Unlock frequency risk (0-2 points)
        unlock_count = usage_data.get('unlock_count', 0)
        if unlock_count > 200:
            score += 2
        elif unlock_count > 100:
            score += 1
        
        # Notification risk (0-1 point)
        notification_count = usage_data.get('notification_count', 0)
        if notification_count > 150:
            score += 1
        
        # Social media dominance risk (0-2 points)
        app_breakdown = usage_data.get('app_breakdown', {})
        if app_breakdown:
            total_usage = sum(app_breakdown.values())
            if total_usage > 0:
                social_apps = ['Instagram', 'Facebook', 'TikTok', 'Twitter', 'Snapchat']
                social_usage = sum(app_breakdown.get(app, 0) for app in social_apps)
                social_ratio = social_usage / total_usage
                
                if social_ratio > 0.8:
                    score += 2
                elif social_ratio > 0.6:
                    score += 1
        
        return score
    
    def predict_addiction_risk(self, usage_data):
        """Predict addiction risk using trained ML model"""
        try:
            # Load ML model if not already loaded
            if self.model is None:
                if not self.load_model():
                    return {"error": "Failed to load ML model"}
            
            # Prepare data for ML model
            ml_data = self._prepare_ml_data(usage_data)
            if ml_data is None:
                return {"error": "Failed to prepare data for ML prediction"}
            
            # Make ML prediction
            prediction = self.model.predict(ml_data)[0]
            probabilities = self.model.predict_proba(ml_data)[0]
            prediction, probabilities = self._apply_prediction_guardrails(
                usage_data,
                int(prediction),
                probabilities,
            )
            confidence = float(max(probabilities))
            
            # Get model info
            best_model_name = "Ensemble Model"
            model_accuracy = 0.85  # Default fallback
            
            if self.training_results:
                best_model_name = max(self.training_results.keys(), key=lambda k: self.training_results[k]['accuracy'])
                model_accuracy = self.training_results[best_model_name]['accuracy']
            
            # Map prediction to risk level
            risk_levels = {0: "Low Risk", 1: "Medium Risk", 2: "High Risk"}
            risk_level = risk_levels.get(int(prediction), "Unknown")
            
            # Risk factors analysis
            risk_factors = self._analyze_risk_factors(usage_data)
            
            # Recommendations
            recommendations = self._generate_recommendations(usage_data, int(prediction))
            
            return {
                "prediction": int(prediction),
                "risk_level": risk_level,
                "confidence": round(confidence * 100, 2),
                "probabilities": {
                    "low_risk": round(float(probabilities[0]) * 100, 2),
                    "medium_risk": round(float(probabilities[1]) * 100, 2) if len(probabilities) > 1 else 0,
                    "high_risk": round(float(probabilities[2]) * 100, 2) if len(probabilities) > 2 else 0
                },
                "risk_factors": risk_factors,
                "recommendations": recommendations,
                "timestamp": datetime.now().isoformat(),
                "usage_data": usage_data,
                "model_type": best_model_name,
                "model_accuracy": round(model_accuracy * 100, 2)
            }
            
        except Exception as e:
            # Fallback to rule-based if ML fails
            print(f"⚠️ ML prediction failed, using rule-based: {e}")
            return self._fallback_prediction(usage_data)
    
    def _prepare_ml_data(self, usage_data):
        """Prepare usage data for ML model prediction"""
        try:
            # Map app breakdown to individual app times
            app_breakdown = usage_data.get('app_breakdown', {})
            
            # Extract or estimate app usage times
            social_media_time = 0
            gaming_time = 0
            productivity_time = 0
            
            if app_breakdown:
                for app, time_val in app_breakdown.items():
                    app_lower = app.lower()
                    time_hours = float(time_val) / 60.0
                    if any(social in app_lower for social in ['instagram', 'facebook', 'tiktok', 'twitter', 'snapchat', 'social']):
                        social_media_time += time_hours
                    elif any(game in app_lower for game in ['game', 'play', 'candy', 'clash']):
                        gaming_time += time_hours
                    elif any(work in app_lower for work in ['office', 'work', 'email', 'productivity']):
                        productivity_time += time_hours
            
            # Estimate missing values based on screen time
            screen_time = usage_data.get('screen_time', 0)
            if social_media_time == 0:
                social_media_time = screen_time * 0.6  # Assume 60% social media
            if gaming_time == 0:
                gaming_time = screen_time * 0.2  # Assume 20% gaming
            if productivity_time == 0:
                productivity_time = screen_time * 0.2  # Assume 20% productivity
            
            # Prepare raw ML feature data
            raw_ml_data = {
                'screen_time': usage_data.get('screen_time', 0),
                'app_usage': usage_data.get('screen_time', 0),  # Use screen_time as app_usage
                'night_usage': usage_data.get('night_usage', 0),
                'unlock_count': usage_data.get('unlock_count', 0),
                'notification_count': usage_data.get('notification_count', 0),
                'social_media_time': social_media_time,
                'gaming_time': gaming_time,
                'productivity_time': productivity_time,
                'weekend_usage': screen_time * 1.2,  # Estimate weekend usage
                'stress_level': usage_data.get('stress_level', 3),
                'anxiety_level': usage_data.get('anxiety_level', 3),
                'depression_level': usage_data.get('depression_level', 3),
                'sleep_quality': usage_data.get('sleep_quality', 3),
                'work_productivity': usage_data.get('work_productivity', 3),
                'social_interactions': usage_data.get('social_interactions', 5),
                'physical_activity': usage_data.get('physical_activity', 2),
                'age': usage_data.get('age', 25),
                'gender': usage_data.get('gender', 1),
                'education': usage_data.get('education', 3),
                'occupation_type': usage_data.get('occupation_type', 2),
                'income_level': usage_data.get('income_level', 3)
            }

            feature_columns = self.model_metadata.get('base_features') or [
                'screen_time', 'app_usage', 'night_usage', 'unlock_count', 'notification_count',
                'social_media_time', 'gaming_time', 'productivity_time', 'weekend_usage',
                'stress_level', 'anxiety_level', 'depression_level', 'sleep_quality',
                'work_productivity', 'social_interactions', 'physical_activity',
                'age', 'gender', 'education', 'occupation_type', 'income_level'
            ]

            input_df = pd.DataFrame([raw_ml_data], columns=feature_columns)
            input_df = self._clip_and_impute(input_df)
            engineered_df = self._engineer_features(input_df)

            if self.feature_selector:
                transformed = self.feature_selector.transform(engineered_df)
            elif self.selected_feature_names:
                transformed = engineered_df[self.selected_feature_names].values
            else:
                transformed = engineered_df.values

            if self.scaler:
                return self.scaler.transform(transformed)
            return transformed
                
        except Exception as e:
            print(f"Error preparing ML data: {e}")
            return None

    def _apply_prediction_guardrails(self, usage_data, prediction, probabilities):
        screen_time = float(usage_data.get('screen_time', 0))
        night_usage = float(usage_data.get('night_usage', 0))
        unlock_count = int(usage_data.get('unlock_count', 0))
        notification_count = int(usage_data.get('notification_count', 0))
        stress_level = float(usage_data.get('stress_level', 3))
        anxiety_level = float(usage_data.get('anxiety_level', 3))
        depression_level = float(usage_data.get('depression_level', 3))
        sleep_quality = float(usage_data.get('sleep_quality', 3))
        work_productivity = float(usage_data.get('work_productivity', 3))

        app_breakdown = usage_data.get('app_breakdown', {}) or {}
        social_media_hours = 0.0
        for app, time_val in app_breakdown.items():
            app_lower = str(app).lower()
            if any(social in app_lower for social in ['instagram', 'facebook', 'tiktok', 'twitter', 'snapchat', 'social', 'telegram', 'whatsapp']):
                social_media_hours += float(time_val) / 60.0

        severe_signals = sum([
            screen_time >= 9.5,
            night_usage >= 2.5,
            unlock_count >= 180,
            notification_count >= 300,
            social_media_hours >= 3.5,
            (stress_level + anxiety_level + depression_level) >= 11,
            sleep_quality <= 2,
        ])

        low_signals = sum([
            screen_time <= 3.5,
            night_usage <= 0.5,
            unlock_count <= 60,
            notification_count <= 80,
            social_media_hours <= 1.0,
            (stress_level + anxiety_level + depression_level) <= 6,
            sleep_quality >= 4,
            work_productivity >= 4,
        ])

        if severe_signals >= 3 or (screen_time >= 11 and night_usage >= 3):
            return 2, np.array([0.04, 0.12, 0.84])

        if low_signals >= 5 and severe_signals == 0:
            return 0, np.array([0.84, 0.12, 0.04])

        top_two = np.sort(probabilities)[-2:]
        close_call = len(top_two) == 2 and abs(top_two[1] - top_two[0]) < 0.08
        if close_call and severe_signals in (1, 2) and low_signals <= 3:
            return 1, np.array([0.18, 0.64, 0.18])

        return prediction, probabilities

    def _clip_and_impute(self, input_df):
        medians = self.model_metadata.get('medians', {}) if self.model_metadata else {}
        clip_bounds = self.model_metadata.get('clip_bounds', {}) if self.model_metadata else {}

        cleaned = input_df.copy()
        for column in cleaned.columns:
            default_median = medians.get(column, float(cleaned[column].median()))
            cleaned[column] = cleaned[column].fillna(default_median)
            bounds = clip_bounds.get(column)
            if bounds:
                cleaned[column] = cleaned[column].clip(bounds.get('lower'), bounds.get('upper'))

        cleaned['gender'] = cleaned['gender'].clip(0, 1).round()
        cleaned['age'] = cleaned['age'].clip(13, 80)
        cleaned['sleep_quality'] = cleaned['sleep_quality'].clip(1, 5)
        cleaned['work_productivity'] = cleaned['work_productivity'].clip(1, 5)
        cleaned['stress_level'] = cleaned['stress_level'].clip(1, 7)
        cleaned['anxiety_level'] = cleaned['anxiety_level'].clip(1, 7)
        cleaned['depression_level'] = cleaned['depression_level'].clip(1, 5)
        cleaned['education'] = cleaned['education'].clip(1, 5)
        cleaned['occupation_type'] = cleaned['occupation_type'].clip(1, 3)
        cleaned['income_level'] = cleaned['income_level'].clip(1, 5)
        cleaned['physical_activity'] = cleaned['physical_activity'].clip(0, 5)
        return cleaned

    def _engineer_features(self, raw):
        features = raw.copy()
        eps = 1e-6

        screen = features['screen_time']
        app_usage = features['app_usage']
        night = features['night_usage']
        unlocks = features['unlock_count']
        notifications = features['notification_count']
        social = features['social_media_time']
        gaming = features['gaming_time']
        productivity = features['productivity_time']
        weekend = features['weekend_usage']
        stress = features['stress_level']
        anxiety = features['anxiety_level']
        depression = features['depression_level']
        sleep_quality = features['sleep_quality']
        work_productivity = features['work_productivity']
        interactions = features['social_interactions']
        activity = features['physical_activity']
        age = features['age']

        features['night_screen_ratio'] = night / (screen + eps)
        features['social_screen_ratio'] = social / (screen + eps)
        features['notifications_per_unlock'] = notifications / (unlocks + eps)
        features['unlocks_per_hour'] = unlocks / (screen + eps)
        features['weekend_screen_ratio'] = weekend / (screen + 1.0)
        features['sleep_deficit'] = (8.0 - sleep_quality).clip(lower=0)
        features['wellbeing_strain'] = stress + anxiety + depression
        features['productivity_gap'] = np.maximum(0.0, screen - (productivity + 0.35 * work_productivity))
        features['social_intensity'] = social + 0.5 * gaming
        features['compulsion_index'] = (
            0.35 * features['night_screen_ratio']
            + 0.25 * features['social_screen_ratio']
            + 0.20 * (unlocks / 200.0)
            + 0.20 * (notifications / 400.0)
        )
        features['focus_balance'] = productivity + work_productivity + activity - social
        features['alert_fatigue'] = notifications * (stress + anxiety) / 10.0
        features['late_compulsion'] = night * (social + gaming + 1.0)
        features['screen_unlock_interaction'] = screen * unlocks
        features['age_adjusted_usage'] = screen / np.where(age < 18, 0.85, np.where(age < 26, 1.0, 1.15))
        features['healthy_buffer'] = sleep_quality + work_productivity + interactions + activity
        features['habit_pressure'] = (
            0.28 * screen
            + 0.18 * social
            + 0.16 * night
            + 0.14 * (unlocks / 20.0)
            + 0.10 * (notifications / 40.0)
            + 0.14 * (stress + anxiety + depression)
        )
        features['borderline_support'] = (
            0.45 * features['habit_pressure']
            - 0.30 * features['healthy_buffer']
            - 0.15 * work_productivity
            - 0.10 * activity
        )
        features['recreation_share'] = (social + gaming) / (app_usage + eps)
        features['digital_burden'] = screen + night + social + 0.01 * notifications

        return features.replace([np.inf, -np.inf], 0.0)
    
    def _fallback_prediction(self, usage_data):
        """Fallback to rule-based prediction if ML fails"""
        risk_score = self.calculate_risk_score(usage_data)
        
        if risk_score >= 6:
            prediction = 2  # High Risk
            risk_level = "High Risk"
            confidence = 75
        elif risk_score >= 3:
            prediction = 1  # Medium Risk
            risk_level = "Medium Risk"
            confidence = 65
        else:
            prediction = 0  # Low Risk
            risk_level = "Low Risk"
            confidence = 55
        
        return {
            "prediction": prediction,
            "risk_level": risk_level,
            "confidence": confidence,
            "risk_factors": self._analyze_risk_factors(usage_data),
            "recommendations": self._generate_recommendations(usage_data, prediction),
            "timestamp": datetime.now().isoformat(),
            "usage_data": usage_data,
            "model_type": "Rule-based (fallback)",
            "model_accuracy": 60
        }
    
    def _analyze_risk_factors(self, usage_data):
        """Analyze specific risk factors"""
        factors = []
        
        screen_time = usage_data.get('screen_time', 0)
        night_usage = usage_data.get('night_usage', 0)
        unlock_count = usage_data.get('unlock_count', 0)
        app_breakdown = usage_data.get('app_breakdown', {})
        
        # Screen time analysis
        if screen_time > 6:
            severity = "High" if screen_time > 8 else "Medium"
            factors.append({
                "factor": "Screen Time",
                "value": f"{screen_time:.1f} hours/day",
                "risk": severity,
                "description": f"Exceeds recommended limit ({'severely' if screen_time > 8 else 'moderately'})"
            })
        
        # Night usage analysis
        if night_usage > 1:
            severity = "High" if night_usage > 3 else "Medium"
            factors.append({
                "factor": "Night Usage",
                "value": f"{night_usage:.1f} hours/night",
                "risk": severity,
                "description": "Affects sleep quality and mental health"
            })
        
        # High frequency usage
        if unlock_count > 100:
            severity = "High" if unlock_count > 200 else "Medium"
            factors.append({
                "factor": "Phone Checking Frequency",
                "value": f"{unlock_count} unlocks/day",
                "risk": severity,
                "description": "Indicates compulsive checking behavior"
            })
        
        # Social media analysis
        if app_breakdown:
            total_usage = sum(app_breakdown.values())
            if total_usage > 0:
                social_apps = ['Instagram', 'Facebook', 'TikTok', 'Twitter', 'Snapchat']
                social_usage = sum(app_breakdown.get(app, 0) for app in social_apps)
                social_ratio = social_usage / total_usage
                
                if social_ratio > 0.6:
                    severity = "High" if social_ratio > 0.8 else "Medium"
                    factors.append({
                        "factor": "Social Media Dominance",
                        "value": f"{social_ratio*100:.1f}%",
                        "risk": severity,
                        "description": f"Social media {'heavily' if social_ratio > 0.8 else 'moderately'} dominates usage"
                    })
        
        return factors
    
    def _generate_recommendations(self, usage_data, prediction_level):
        """Generate personalized recommendations based on prediction level"""
        recommendations = []
        
        if prediction_level >= 2:  # High risk
            recommendations.extend([
                {
                    "priority": "High",
                    "title": "Digital Detox Required",
                    "description": "Take 24-48 hour breaks from social media weekly",
                    "action": "Schedule offline periods in calendar"
                },
                {
                    "priority": "High",
                    "title": "Set Strict Time Limits",
                    "description": "Limit social media to 1 hour/day maximum",
                    "action": "Use app timers and screen time limits"
                },
                {
                    "priority": "Medium",
                    "title": "Night Mode Enforcement",
                    "description": "Enable grayscale and disable notifications after 8 PM",
                    "action": "Set up bedtime mode in phone settings"
                }
            ])
        elif prediction_level >= 1:  # Medium risk
            recommendations.extend([
                {
                    "priority": "Medium",
                    "title": "Reduce Screen Time",
                    "description": "Aim for under 4 hours of recreational screen time daily",
                    "action": "Track usage and set gradual limits"
                },
                {
                    "priority": "Medium",
                    "title": "Social Media Boundaries",
                    "description": "Limit social media to 2 hours per day",
                    "action": "Use built-in digital wellbeing tools"
                }
            ])
        else:  # Low risk
            recommendations.extend([
                {
                    "priority": "Low",
                    "title": "Maintain Healthy Habits",
                    "description": "Continue monitoring and balanced usage",
                    "action": "Keep SmartPulse tracking enabled"
                },
                {
                    "priority": "Low",
                    "title": "Digital Balance",
                    "description": "Ensure offline activities exceed screen time",
                    "action": "Schedule outdoor and social activities"
                }
            ])
        
        return recommendations
    
    def load_model(self):
        """Load ML model and associated files"""
        try:
            print("🤖 Loading SmartPulse ML models...")
            
            # Load the main model
            if os.path.exists(self.model_path):
                self.model = joblib.load(self.model_path)
                print("✅ ML model loaded successfully")
            else:
                print(f"❌ Model file not found: {self.model_path}")
                return False
            
            # Load the scaler
            if os.path.exists(self.scaler_path):
                self.scaler = joblib.load(self.scaler_path)
                print("✅ Feature scaler loaded successfully")
            else:
                print(f"❌ Scaler file not found: {self.scaler_path}")
                return False

            if os.path.exists(self.selector_path):
                self.feature_selector = joblib.load(self.selector_path)
                print("✅ Feature selector loaded successfully")
            else:
                self.feature_selector = None

            if os.path.exists(self.feature_names_path):
                self.selected_feature_names = joblib.load(self.feature_names_path)
                print("✅ Selected feature names loaded successfully")
            else:
                self.selected_feature_names = None
            
            # Load training results
            if os.path.exists(self.results_path):
                self.training_results = joblib.load(self.results_path)
                print("✅ Training results loaded successfully")
            else:
                print(f"⚠️ Training results not found: {self.results_path}")
                self.training_results = {}
            
            # Load model metadata
            if os.path.exists(self.metadata_path):
                with open(self.metadata_path, 'r') as f:
                    self.model_metadata = json.load(f)
                print("✅ Model metadata loaded successfully")
            else:
                print(f"⚠️ Model metadata not found: {self.metadata_path}")
                self.model_metadata = {}
            
            print("🎯 ML models loaded and ready for predictions!")
            return True
            
        except Exception as e:
            print(f"❌ Error loading ML models: {e}")
            return False

# Global predictor instance
predictor = SmartPulsePredictor()
