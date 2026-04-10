import requests
import json

# Test registration
registration_data = {
    "name": "Test User 2",
    "email": "test2@example.com", 
    "password": "password123",
    "age": 30,
    "phone": "0987654321",
    "gender": "Female"
}

print("Testing registration...")
response = requests.post(
    'http://127.0.0.1:5000/auth/register',
    json=registration_data
)

print(f"Status Code: {response.status_code}")
print(f"Response: {json.dumps(response.json(), indent=2)}")

if response.status_code == 201:
    data = response.json()
    token = data.get('token')
    
    print("\nTesting login...")
    login_response = requests.post(
        'http://127.0.0.1:5000/auth/login',
        json={
            "email": "test2@example.com",
            "password": "password123"
        }
    )
    
    print(f"Login Status Code: {login_response.status_code}")
    print(f"Login Response: {json.dumps(login_response.json(), indent=2)}")
    
    if login_response.status_code == 200:
        login_data = login_response.json()
        token = login_data.get('token')
        
        print("\nTesting user profile...")
        headers = {'Authorization': f'Bearer {token}'}
        profile_response = requests.get(
            'http://127.0.0.1:5000/user/profile',
            headers=headers
        )
        
        print(f"Profile Status Code: {profile_response.status_code}")
        print(f"Profile Response: {json.dumps(profile_response.json(), indent=2)}")
