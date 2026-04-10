import pickle
import os

# Load the pickle file
model_path = os.path.join('new_ml', 'models', 'best_model.pkl')

try:
    with open(model_path, 'rb') as f:
        model = pickle.load(f)
    
    print("Model type:", type(model))
    print("\nModel attributes:")
    
    if hasattr(model, '__dict__'):
        for attr, value in model.__dict__.items():
            print(f"  {attr}: {type(value)}")
            if hasattr(value, 'shape'):
                print(f"    Shape: {value.shape}")
            elif hasattr(value, '__len__'):
                print(f"    Length: {len(value)}")
    
    # Try to get more info about common model types
    if hasattr(model, 'feature_importances_'):
        print(f"\nFeature importances shape: {model.feature_importances_.shape}")
    
    if hasattr(model, 'n_features_in_'):
        print(f"Number of features: {model.n_features_in_}")
    
    if hasattr(model, 'classes_'):
        print(f"Classes: {model.classes_}")
    
    print(f"\nModel loaded successfully!")
    
except Exception as e:
    print(f"Error loading model: {e}")
