#!/usr/bin/env python3
"""
SmartPulse v2 - ML Model Initialization Script
Initializes and trains the ML model for addiction prediction
"""

import os
import sys
from ml_predictor import predictor

def main():
    """Initialize the SmartPulse ML model"""
    print("🚀 SmartPulse v2 - ML Model Initialization")
    print("=" * 50)
    
    try:
        # Check if model already exists
        if os.path.exists('models/addiction_model.pkl'):
            print("📁 Existing model found")
            success = predictor.load_model()
            if success:
                print("✅ Existing model loaded successfully!")
                print("🎯 Model is ready for predictions")
            else:
                print("⚠️ Existing model failed to load, training new model...")
                accuracy = predictor.train_model()
                print(f"🎯 New model trained with {accuracy:.1%} accuracy")
        else:
            print("🆕 No existing model found, training new model...")
            accuracy = predictor.train_model()
            print(f"🎯 New model trained with {accuracy:.1%} accuracy")
        
        print("\n✅ ML model initialization complete!")
        print("🚀 SmartPulse v2 backend is ready to serve predictions")
        
        return True
        
    except Exception as e:
        print(f"❌ Model initialization failed: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
