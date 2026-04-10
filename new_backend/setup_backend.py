#!/usr/bin/env python3
"""
SmartPulse v2 - Backend Setup Script
Sets up the complete backend with ML dependencies
"""

import os
import sys
import subprocess
from pathlib import Path

def check_python_version():
    """Check if Python version is compatible"""
    version = sys.version_info
    if version.major < 3 or (version.major == 3 and version.minor < 8):
        print("❌ Python 3.8+ is required")
        print(f"   Current version: {version.major}.{version.minor}.{version.micro}")
        return False
    print(f"✅ Python {version.major}.{version.minor}.{version.micro} detected")
    return True

def install_dependencies():
    """Install required dependencies"""
    print("📦 Installing Python dependencies...")
    
    try:
        # Upgrade pip
        subprocess.run([sys.executable, "-m", "pip", "install", "--upgrade", "pip"], 
                      check=True, capture_output=True)
        
        # Install requirements
        result = subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"], 
                           check=True, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ All dependencies installed successfully")
        else:
            print("❌ Failed to install dependencies:")
            print(result.stderr)
            return False
            
    except Exception as e:
        print(f"❌ Installation error: {e}")
        return False
    
    return True

def create_directories():
    """Create necessary directories"""
    print("📁 Creating directories...")
    
    directories = ["models", "logs"]
    for directory in directories:
        Path(directory).mkdir(exist_ok=True)
        print(f"   ✅ {directory}/ directory created")

def initialize_model():
    """Initialize the ML model"""
    print("🤖 Initializing ML model...")
    
    try:
        from init_model import main as init_main
        success = init_main()
        return success
    except Exception as e:
        print(f"❌ Model initialization failed: {e}")
        return False

def test_backend():
    """Test backend startup"""
    print("🧪 Testing backend startup...")
    
    try:
        # Test import of main app
        from app import app
        print("✅ Flask app imports successfully")
        
        # Test ML predictor
        from ml_predictor import predictor
        if predictor.model is not None:
            print("✅ ML model is loaded")
        else:
            print("⚠️ ML model not loaded")
        
        return True
        
    except Exception as e:
        print(f"❌ Backend test failed: {e}")
        return False

def main():
    """Main setup function"""
    print("🚀 SmartPulse v2 - Backend Setup")
    print("=" * 50)
    
    # Check Python version
    if not check_python_version():
        return False
    
    # Create directories
    create_directories()
    
    # Install dependencies
    if not install_dependencies():
        return False
    
    # Initialize ML model
    if not initialize_model():
        return False
    
    # Test backend
    if not test_backend():
        return False
    
    print("\n" + "=" * 50)
    print("✅ SmartPulse v2 backend setup complete!")
    print("🚀 Ready to start with: python app.py")
    print("🔗 ML API will be available at: http://localhost:3000")
    print("📊 Model info: http://localhost:3000/model/info")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
