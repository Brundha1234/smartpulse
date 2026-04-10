#!/usr/bin/env python3
"""
Network Bridge for SmartPulse v2
Bypasses network issues by exposing backend to all interfaces
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import os

app = Flask(__name__)
CORS(app)

# SmartPulse backend URL
BACKEND_URL = "http://127.0.0.1:5000"

@app.route('/', methods=['GET'])
def health():
    """Health check endpoint"""
    try:
        response = requests.get(f"{BACKEND_URL}/", timeout=5)
        return response.json(), response.status_code
    except Exception as e:
        return jsonify({"error": str(e), "bridge_status": "running"}), 500

@app.route('/auth/register', methods=['POST'])
def register():
    """Bridge registration endpoint"""
    try:
        response = requests.post(f"{BACKEND_URL}/auth/register", 
                           json=request.get_json(), 
                           timeout=15)
        return response.json(), response.status_code
    except Exception as e:
        return jsonify({"error": str(e), "bridge_error": True}), 500

@app.route('/auth/login', methods=['POST'])
def login():
    """Bridge login endpoint"""
    try:
        response = requests.post(f"{BACKEND_URL}/auth/login", 
                           json=request.get_json(), 
                           timeout=15)
        return response.json(), response.status_code
    except Exception as e:
        return jsonify({"error": str(e), "bridge_error": True}), 500

@app.route('/user/profile', methods=['GET', 'PUT'])
def profile():
    """Bridge profile endpoint"""
    try:
        if request.method == 'GET':
            headers = {'Authorization': request.headers.get('Authorization', '')}
            response = requests.get(f"{BACKEND_URL}/user/profile", 
                               headers=headers, timeout=15)
        else:  # PUT
            headers = {'Authorization': request.headers.get('Authorization', '')}
            response = requests.put(f"{BACKEND_URL}/user/profile", 
                                json=request.get_json(), 
                                headers=headers, timeout=15)
        return response.json(), response.status_code
    except Exception as e:
        return jsonify({"error": str(e), "bridge_error": True}), 500

@app.route('/predict', methods=['POST'])
def predict():
    """Bridge prediction endpoint"""
    try:
        response = requests.post(f"{BACKEND_URL}/predict", 
                           json=request.get_json(), 
                           timeout=20)
        return response.json(), response.status_code
    except Exception as e:
        return jsonify({"error": str(e), "bridge_error": True}), 500

@app.route('/analyze', methods=['POST'])
def analyze():
    """Bridge analysis endpoint"""
    try:
        response = requests.post(f"{BACKEND_URL}/analyze", 
                           json=request.get_json(), 
                           timeout=25)
        return response.json(), response.status_code
    except Exception as e:
        return jsonify({"error": str(e), "bridge_error": True}), 500

@app.route('/model/info', methods=['GET'])
def model_info():
    """Bridge model info endpoint"""
    try:
        response = requests.get(f"{BACKEND_URL}/model/info", timeout=10)
        return response.json(), response.status_code
    except Exception as e:
        return jsonify({"error": str(e), "bridge_error": True}), 500

if __name__ == "__main__":
    print("🌉 Starting SmartPulse Network Bridge...")
    print("🔗 This bridges your local backend to all network interfaces")
    print("📱 Mobile devices can now connect without network issues")
    print("🌐 Bridge will be accessible on all your IP addresses")
    print()
    
    # Run on all interfaces
    app.run(host="0.0.0.0", port=3000, debug=False)
