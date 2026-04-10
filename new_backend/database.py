# database.py
# MongoDB connection and database operations

import os
from datetime import datetime
from pymongo import MongoClient
from bson.objectid import ObjectId
from typing import Optional, Dict, Any
import bcrypt

class MongoDB:
    def __init__(self):
        self.client = None
        self.db = None
        self.users_collection = None
        self.predictions_collection = None
        self.connect()
    
    def connect(self):
        """Connect to MongoDB with error handling"""
        try:
            self.client = MongoClient(os.getenv('MONGODB_URI', 'mongodb://localhost:27017/'))
            # Test connection
            self.client.admin.command('ping')
            self.db = self.client['smartpulse_db']
            self.users_collection = self.db['users']
            self.predictions_collection = self.db['predictions']
            print("✅ MongoDB connected successfully")
        except Exception as e:
            print(f"❌ MongoDB connection failed: {e}")
            print("📝 Using local fallback storage for development")
            # Fallback to local storage
            self.client = None
            self.db = None
            self.users_collection = {}
            self.predictions_collection = {}
        
    def create_user(self, user_data: Dict[str, Any]) -> str:
        """Create a new user in the database"""
        # Hash the password
        if 'password' in user_data:
            user_data['password'] = bcrypt.hashpw(
                user_data['password'].encode('utf-8'), 
                bcrypt.gensalt()
            ).decode('utf-8')
        
        # Add timestamps
        user_data['created_at'] = datetime.utcnow()
        user_data['updated_at'] = datetime.utcnow()
        
        if self.client is not None:
            # Use MongoDB
            result = self.users_collection.insert_one(user_data)
            return str(result.inserted_id)
        else:
            # Use local fallback storage
            user_id = str(len(self.users_collection) + 1)
            user_data['_id'] = user_id
            self.users_collection[user_id] = user_data
            return user_id
    
    def authenticate_user(self, email: str, password: str) -> Optional[Dict[str, Any]]:
        """Authenticate user with email and password"""
        if self.client is not None:
            # Use MongoDB
            user = self.users_collection.find_one({'email': email})
            if user and bcrypt.checkpw(password.encode('utf-8'), user['password'].encode('utf-8')):
                # Convert ObjectId to string and remove password
                user['_id'] = str(user['_id'])
                user.pop('password', None)
                return user
        else:
            # Use local fallback storage
            for user_id, user_data in self.users_collection.items():
                if user_data.get('email') == email and bcrypt.checkpw(password.encode('utf-8'), user_data['password'].encode('utf-8')):
                    user_data_copy = user_data.copy()
                    user_data_copy.pop('password', None)
                    return user_data_copy
        return None
    
    def get_user_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user by ID"""
        if self.client is not None:
            # Use MongoDB
            try:
                user = self.users_collection.find_one({'_id': ObjectId(user_id)})
                if user:
                    user['_id'] = str(user['_id'])
                    user.pop('password', None)
                    return user
            except:
                pass
        else:
            # Use local fallback storage
            user_data = self.users_collection.get(user_id)
            if user_data:
                user_data_copy = user_data.copy()
                user_data_copy.pop('password', None)
                return user_data_copy
        return None
    
    def get_user_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """Get user by email"""
        if self.client is not None:
            # Use MongoDB
            user = self.users_collection.find_one({'email': email})
            if user:
                user['_id'] = str(user['_id'])
                user.pop('password', None)
                return user
        else:
            # Use local fallback storage
            for user_id, user_data in self.users_collection.items():
                if user_data.get('email') == email:
                    user_data_copy = user_data.copy()
                    user_data_copy.pop('password', None)
                    return user_data_copy
        return None
    
    def update_user(self, user_id: str, update_data: Dict[str, Any]) -> bool:
        """Update user information"""
        update_data['updated_at'] = datetime.utcnow()
        if self.client is not None:
            # Use MongoDB
            result = self.users_collection.update_one(
                {'_id': ObjectId(user_id)},
                {'$set': update_data}
            )
            return result.modified_count > 0
        else:
            # Use local fallback storage
            if user_id in self.users_collection:
                self.users_collection[user_id].update(update_data)
                return True
        return False
    
    def save_prediction(self, user_id: str, prediction_data: Dict[str, Any]) -> str:
        """Save addiction prediction for a user"""
        prediction_data['user_id'] = user_id
        prediction_data['created_at'] = datetime.utcnow()
        
        if self.client is not None:
            # Use MongoDB
            prediction_data['user_id'] = ObjectId(user_id)
            result = self.predictions_collection.insert_one(prediction_data)
            return str(result.inserted_id)
        else:
            # Use local fallback storage
            prediction_id = str(len(self.predictions_collection) + 1)
            prediction_data['_id'] = prediction_id
            self.predictions_collection[prediction_id] = prediction_data
            return prediction_id
    
    def get_user_predictions(self, user_id: str, limit: int = 10) -> list:
        """Get prediction history for a user"""
        if self.client is not None:
            # Use MongoDB
            predictions = self.predictions_collection.find(
                {'user_id': ObjectId(user_id)}
            ).sort('created_at', -1).limit(limit)
            
            # Convert ObjectId to string for JSON serialization
            result = []
            for pred in predictions:
                pred['_id'] = str(pred['_id'])
                pred['user_id'] = str(pred['user_id'])
                result.append(pred)
            
            return result
        else:
            # Use local fallback storage
            result = []
            for pred_id, pred_data in self.predictions_collection.items():
                if pred_data.get('user_id') == user_id:
                    pred_data_copy = pred_data.copy()
                    result.append(pred_data_copy)
            
            # Sort by created_at (newest first) and limit
            result.sort(key=lambda x: x.get('created_at', ''), reverse=True)
            return result[:limit]

# Global database instance
db = MongoDB()
