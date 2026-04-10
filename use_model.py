import joblib
import numpy as np

# Load the model
model = joblib.load('new_ml/models/best_model.pkl')

print("Model loaded successfully!")
print(f"Model type: {type(model)}")
print(f"Expected input features: 22")

# Example usage with dummy data
def make_prediction(features):
    """
    Make prediction with the model
    
    Args:
        features: array-like with 22 features
    
    Returns:
        prediction and probabilities
    """
    if len(features) != 22:
        raise ValueError(f"Expected 22 features, got {len(features)}")
    
    # Convert to numpy array and reshape
    features_array = np.array(features).reshape(1, -1)
    
    # Make prediction
    prediction = model.predict(features_array)[0]
    probabilities = model.predict_proba(features_array)[0]
    
    return prediction, probabilities

# Example with random data
example_features = np.random.randn(22)  # 22 random features
pred, probs = make_prediction(example_features)

print(f"\nExample prediction:")
print(f"Predicted class: {pred}")
print(f"Class probabilities: {probs}")
print(f"Confidence: {max(probs):.3f}")

# You can also access individual pipeline components
print(f"\nPipeline steps:")
for name, step in model.steps:
    print(f"  {name}: {type(step).__name__}")
