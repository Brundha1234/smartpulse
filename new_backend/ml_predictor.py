# SmartPulse v2 - ML Prediction Service
# Machine Learning model for smartphone addiction prediction

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, classification_report
import joblib
import os
from datetime import datetime, timedelta

class SmartPulsePredictor:
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.model_path = 'models/addiction_model.pkl'
        self.scaler_path = 'models/scaler.pkl'
        self._ensure_model_directory()
        
    def _ensure_model_directory(self):
        """Create models directory if it doesn't exist"""
        if not os.path.exists('models'):
            os.makedirs('models')
    
    def prepare_features(self, usage_data):
        """Prepare features from usage data for ML prediction"""
        features = []
        
        # Extract features from usage data
        screen_time = usage_data.get('screen_time', 0)
        night_usage = usage_data.get('night_usage', 0)
        unlock_count = usage_data.get('unlock_count', 0)
        notification_count = usage_data.get('notification_count', 0)
        app_breakdown = usage_data.get('app_breakdown', {})
        
        # Calculate derived features
        total_app_usage = sum(app_breakdown.values()) if app_breakdown else 0
        
        # Social media dominance
        social_apps = ['Instagram', 'Facebook', 'TikTok', 'Twitter', 'Snapchat']
        social_usage = sum(app_breakdown.get(app, 0) for app in social_apps)
        social_dominance = social_usage / total_app_usage if total_app_usage > 0 else 0
        
        # Night usage ratio
        night_usage_ratio = night_usage / screen_time if screen_time > 0 else 0
        
        # Unlock frequency (per hour of screen time)
        unlock_frequency = unlock_count / screen_time if screen_time > 0 else 0
        
        # Notification frequency (per hour of screen time)
        notification_frequency = notification_count / screen_time if screen_time > 0 else 0
        
        # Peak usage hour (if available)
        peak_hour = usage_data.get('peak_hour', 12)
        
        # Weekend usage (if available)
        is_weekend = usage_data.get('is_weekend', False)
        
        # Feature vector
        feature_vector = [
            screen_time,
            night_usage,
            unlock_count,
            notification_count,
            total_app_usage,
            social_dominance,
            night_usage_ratio,
            unlock_frequency,
            notification_frequency,
            peak_hour,
            1 if is_weekend else 0  # Weekend flag
        ]
        
        return np.array(feature_vector).reshape(1, -1)
    
    def generate_training_data(self, num_samples=1000):
        """Generate synthetic training data for demonstration"""
        np.random.seed(42)
        
        # Generate realistic usage patterns
        data = []
        labels = []
        
        for i in range(num_samples):
            # Base usage patterns
            screen_time = np.random.uniform(0.5, 12.0)
            night_usage = np.random.uniform(0, 4.0)
            unlock_count = np.random.randint(20, 300)
            notification_count = np.random.randint(10, 200)
            
            # App breakdown
            apps = ['Instagram', 'Facebook', 'TikTok', 'WhatsApp', 'Twitter', 'Snapchat']
            app_breakdown = {app: np.random.uniform(0, screen_time) for app in apps}
            total_app_usage = sum(app_breakdown.values())
            
            # Calculate derived features
            social_apps = ['Instagram', 'Facebook', 'TikTok', 'Twitter', 'Snapchat']
            social_usage = sum(app_breakdown.get(app, 0) for app in social_apps)
            social_dominance = social_usage / total_app_usage if total_app_usage > 0 else 0
            night_usage_ratio = night_usage / screen_time if screen_time > 0 else 0
            unlock_frequency = unlock_count / screen_time if screen_time > 0 else 0
            notification_frequency = notification_count / screen_time if screen_time > 0 else 0
            
            # Risk score calculation (for labeling)
            risk_score = 0
            if screen_time > 6: risk_score += 1
            if night_usage > 2: risk_score += 1
            if unlock_count > 150: risk_score += 1
            if social_dominance > 0.7: risk_score += 1
            if night_usage_ratio > 0.3: risk_score += 1
            
            # Label: 1 = High Risk (Addiction), 0 = Low Risk (Normal)
            label = 1 if risk_score >= 3 else 0
            
            data.append([
                screen_time, night_usage, unlock_count, notification_count,
                total_app_usage, social_dominance, night_usage_ratio,
                unlock_frequency, notification_frequency,
                np.random.randint(0, 24),  # Peak hour
                np.random.choice([0, 1])  # Weekend flag
            ])
            labels.append(label)
        
        return np.array(data), np.array(labels)
    
    def train_model(self):
        """Train the ML model with synthetic data"""
        print("🤖 Training SmartPulse ML model...")
        
        # Generate training data
        X, y = self.generate_training_data(num_samples=2000)
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        # Train Random Forest model
        self.model = RandomForestClassifier(
            n_estimators=100,
            random_state=42,
            max_depth=10,
            min_samples_split=5,
            min_samples_leaf=2
        )
        
        self.model.fit(X_train_scaled, y_train)
        
        # Evaluate model
        y_pred = self.model.predict(X_test_scaled)
        accuracy = accuracy_score(y_test, y_pred)
        
        print(f"✅ Model trained successfully!")
        print(f"📊 Model accuracy: {accuracy:.2%}")
        print("📈 Classification Report:")
        print(classification_report(y_test, y_pred, target_names=['Low Risk', 'High Risk']))
        
        # Save model and scaler
        joblib.dump(self.model, self.model_path)
        joblib.dump(self.scaler, self.scaler_path)
        
        return accuracy
    
    def load_model(self):
        """Load pre-trained model"""
        try:
            if os.path.exists(self.model_path) and os.path.exists(self.scaler_path):
                self.model = joblib.load(self.model_path)
                self.scaler = joblib.load(self.scaler_path)
                print("✅ Pre-trained model loaded successfully")
                return True
            else:
                print("⚠️ No pre-trained model found. Training new model...")
                return self.train_model() > 0.8  # Train if accuracy > 80%
        except Exception as e:
            print(f"❌ Error loading model: {e}")
            return False
    
    def predict_addiction_risk(self, usage_data):
        """Predict addiction risk from usage data"""
        if self.model is None:
            if not self.load_model():
                return {"error": "Model not available"}
        
        try:
            # Prepare features
            features = self.prepare_features(usage_data)
            
            # Scale features
            features_scaled = self.scaler.transform(features)
            
            # Make prediction
            prediction = self.model.predict(features_scaled)[0]
            probability = self.model.predict_proba(features_scaled)[0]
            
            # Risk level
            risk_level = "High Risk" if prediction == 1 else "Low Risk"
            confidence = max(probability) * 100
            
            # Risk factors analysis
            risk_factors = self._analyze_risk_factors(usage_data)
            
            # Recommendations
            recommendations = self._generate_recommendations(usage_data, prediction)
            
            return {
                "prediction": int(prediction),
                "risk_level": risk_level,
                "confidence": round(confidence, 2),
                "risk_factors": risk_factors,
                "recommendations": recommendations,
                "timestamp": datetime.now().isoformat(),
                "usage_data": usage_data
            }
            
        except Exception as e:
            return {"error": f"Prediction error: {str(e)}"}
    
    def _analyze_risk_factors(self, usage_data):
        """Analyze specific risk factors"""
        factors = []
        
        screen_time = usage_data.get('screen_time', 0)
        night_usage = usage_data.get('night_usage', 0)
        unlock_count = usage_data.get('unlock_count', 0)
        app_breakdown = usage_data.get('app_breakdown', {})
        
        # Screen time analysis
        if screen_time > 8:
            factors.append({
                "factor": "Excessive Screen Time",
                "value": f"{screen_time:.1f} hours/day",
                "risk": "High",
                "description": "Screen time exceeds recommended 8 hours/day limit"
            })
        elif screen_time > 6:
            factors.append({
                "factor": "High Screen Time",
                "value": f"{screen_time:.1f} hours/day",
                "risk": "Medium",
                "description": "Screen time approaching recommended limit"
            })
        
        # Night usage analysis
        if night_usage > 2:
            factors.append({
                "factor": "Excessive Night Usage",
                "value": f"{night_usage:.1f} hours/night",
                "risk": "High",
                "description": "Night usage affects sleep quality and mental health"
            })
        elif night_usage > 1:
            factors.append({
                "factor": "Night Usage Detected",
                "value": f"{night_usage:.1f} hours/night",
                "risk": "Medium",
                "description": "Consider reducing screen time before bed"
            })
        
        # Unlock frequency analysis
        if unlock_count > 150:
            factors.append({
                "factor": "High Unlock Frequency",
                "value": f"{unlock_count} unlocks/day",
                "risk": "High",
                "description": "Frequent phone checking indicates compulsive behavior"
            })
        
        # Social media dominance
        if app_breakdown:
            total_usage = sum(app_breakdown.values())
            if total_usage > 0:
                social_apps = ['Instagram', 'Facebook', 'TikTok', 'Twitter', 'Snapchat']
                social_usage = sum(app_breakdown.get(app, 0) for app in social_apps)
                social_ratio = social_usage / total_usage
                
                if social_ratio > 0.8:
                    factors.append({
                        "factor": "Social Media Dominance",
                        "value": f"{social_ratio*100:.1f}%",
                        "risk": "High",
                        "description": "Social media dominates your digital life"
                    })
                elif social_ratio > 0.6:
                    factors.append({
                        "factor": "High Social Media Usage",
                        "value": f"{social_ratio*100:.1f}%",
                        "risk": "Medium",
                        "description": "Consider diversifying your digital activities"
                    })
        
        return factors
    
    def _generate_recommendations(self, usage_data, prediction):
        """Generate personalized recommendations"""
        recommendations = []
        
        if prediction == 1:  # High risk
            recommendations.extend([
                {
                    "priority": "High",
                    "title": "Set Daily Time Limits",
                    "description": "Use app timers to limit social media to 2 hours/day",
                    "action": "Set up screen time limits in phone settings"
                },
                {
                    "priority": "High", 
                    "title": "Digital Detox Periods",
                    "description": "Take 1-hour breaks every 3 hours of screen time",
                    "action": "Schedule offline periods in your calendar"
                },
                {
                    "priority": "Medium",
                    "title": "Night Mode Activation",
                    "description": "Enable grayscale and disable notifications after 9 PM",
                    "action": "Set up bedtime mode in phone settings"
                }
            ])
        else:  # Low risk
            recommendations.extend([
                {
                    "priority": "Low",
                    "title": "Maintain Healthy Habits",
                    "description": "Continue monitoring your usage patterns",
                    "action": "Keep SmartPulse tracking enabled"
                },
                {
                    "priority": "Low",
                    "title": "Weekly Digital Balance",
                    "description": "Ensure at least 3 hours of offline activities daily",
                    "action": "Schedule outdoor or social activities"
                }
            ])
        
        return recommendations

# Global predictor instance
predictor = SmartPulsePredictor()
