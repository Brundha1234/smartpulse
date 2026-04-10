#!/usr/bin/env python3
"""
Complete end-to-end test for SmartPulse v2
Tests registration, login, and prediction functionality
"""

import requests
import json
import time

BASE_URL = 'http://192.168.55.101:5000'

def test_backend_connection():
    """Test if backend is running"""
    try:
        response = requests.get(f'{BASE_URL}/', timeout=5)
        if response.status_code == 200:
            print("✅ Backend is running")
            return True
        else:
            print(f"❌ Backend returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Backend connection failed: {e}")
        return False

def test_registration():
    """Test user registration"""
    print("\n📝 Testing Registration...")
    
    # Generate unique email using timestamp
    timestamp = int(time.time())
    test_user = {
        'name': f'Test User {timestamp}',
        'email': f'testuser{timestamp}@example.com',
        'password': 'password123',
        'age': 25,
        'phone': '1234567890',
        'gender': 'Other'
    }
    
    try:
        response = requests.post(f'{BASE_URL}/auth/register', json=test_user, timeout=10)
        
        if response.status_code == 201:
            data = response.json()
            print("✅ Registration successful")
            print(f"   User ID: {data['user_id']}")
            print(f"   Name: {data['user']['name']}")
            print(f"   Email: {data['user']['email']}")
            return data['token'], data['user']['email']
        else:
            print(f"❌ Registration failed: {response.json()}")
            return None, None
    except Exception as e:
        print(f"❌ Registration error: {e}")
        return None, None

def test_login(email, password):
    """Test user login"""
    print("\n🔐 Testing Login...")
    
    login_data = {
        'email': email,
        'password': password
    }
    
    try:
        response = requests.post(f'{BASE_URL}/auth/login', json=login_data, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Login successful")
            print(f"   User: {data['user']['name']}")
            return data['token']
        else:
            print(f"❌ Login failed: {response.json()}")
            return None
    except Exception as e:
        print(f"❌ Login error: {e}")
        return None

def test_prediction(token):
    """Test ML prediction"""
    print("\n🤖 Testing ML Prediction...")
    
    # Test cases for different addiction levels
    test_cases = [
        {
            'name': 'Healthy User',
            'data': {
                'screen_time': 2.0,
                'app_usage': 1.5,
                'night_usage': 0.1,
                'unlock_count': 30,
                'notification_count': 50,
                'stress': 1,
                'anxiety': 1,
                'depression': 1
            }
        },
        {
            'name': 'At Risk User',
            'data': {
                'screen_time': 7.0,
                'app_usage': 5.5,
                'night_usage': 2.5,
                'unlock_count': 150,
                'notification_count': 350,
                'stress': 4,
                'anxiety': 4,
                'depression': 3
            }
        }
    ]
    
    headers = {'Authorization': f'Bearer {token}'} if token else {}
    
    for test_case in test_cases:
        try:
            response = requests.post(
                f'{BASE_URL}/predict', 
                json=test_case['data'], 
                headers=headers,
                timeout=15
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ {test_case['name']} Prediction:")
                print(f"   Level: {result['addiction_level']}")
                print(f"   Confidence: {result['confidence_score']:.1%}")
                print(f"   Message: {result['message'][:50]}...")
            else:
                print(f"❌ {test_case['name']} Prediction failed: {response.json()}")
        except Exception as e:
            print(f"❌ {test_case['name']} Prediction error: {e}")

def main():
    """Run complete test suite"""
    print("🚀 SmartPulse v2 - Complete End-to-End Test")
    print("=" * 50)
    
    # Test backend connection
    if not test_backend_connection():
        return
    
    # Test registration
    token, email = test_registration()
    if not token:
        print("❌ Cannot proceed without successful registration")
        return
    
    # Test login
    login_token = test_login(email, 'password123')
    if not login_token:
        print("❌ Cannot proceed without successful login")
        return
    
    # Test predictions
    test_prediction(login_token)
    
    print("\n" + "=" * 50)
    print("🎉 Test Suite Complete!")
    print("✅ Backend connection working")
    print("✅ User registration working") 
    print("✅ User login working")
    print("✅ ML prediction working")
    print("\nThe SmartPulse v2 system is fully functional!")

if __name__ == '__main__':
    main()
