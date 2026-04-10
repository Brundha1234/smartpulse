import requests
import json

# Test a new user registration
test_user = {
    "name": "Test User Mobile",
    "email": "mobile_test@example.com",
    "password": "password123",
    "age": 25,
    "phone": "1234567890",
    "gender": "Male"
}

print("Testing mobile registration...")
try:
    response = requests.post(
        'http://127.0.0.1:5000/auth/register',
        json=test_user,
        timeout=10
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    if response.status_code == 201:
        print("✅ Registration successful!")
        data = response.json()
        print(f"Token: {data.get('token', 'N/A')}")
        print(f"User ID: {data.get('user_id', 'N/A')}")
    else:
        print("❌ Registration failed")
        
except requests.exceptions.RequestException as e:
    print(f"❌ Connection error: {e}")
except Exception as e:
    print(f"❌ Error: {e}")
