"""
Simple test server for SmartPulse v2
Doesn't require ML dependencies - just for testing connection
"""

from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route("/", methods=["GET"])
def health():
    return jsonify({
        "service": "SmartPulse API v2 - Test Server",
        "status": "running",
        "model_ok": False,
        "timestamp": "2026-03-24T13:20:00.000000Z",
        "message": "Simple test server for connection testing"
    })

@app.route("/predict", methods=["POST"])
def predict():
    return jsonify({
        "error": "Test server - ML prediction not available"
    }), 503

@app.route("/auth/register", methods=["POST"])
def register():
    return jsonify({
        "message": "Test server - Registration not available"
    }), 503

@app.route("/auth/login", methods=["POST"])
def login():
    return jsonify({
        "message": "Test server - Login not available"
    }), 503

if __name__ == "__main__":
    print("Starting simple test server on port 3000...")
    print("This is just for testing connection - full features require ML dependencies")
    app.run(host="0.0.0.0", port=3000, debug=True)
