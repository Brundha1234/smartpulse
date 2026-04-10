import pickle
import os
import sys

model_path = os.path.join('new_ml', 'models', 'best_model.pkl')

print(f"File size: {os.path.getsize(model_path)} bytes")

# Try different protocols
protocols = [pickle.DEFAULT_PROTOCOL, pickle.HIGHEST_PROTOCOL, 2, 3, 4, 5]

for protocol in protocols:
    try:
        print(f"\nTrying protocol {protocol}...")
        with open(model_path, 'rb') as f:
            # Try to peek at the first few bytes
            f.seek(0)
            first_bytes = f.read(10)
            print(f"First 10 bytes: {first_bytes}")
            
            # Reset and try to load
            f.seek(0)
            model = pickle.load(f)
            
        print(f"SUCCESS with protocol {protocol}!")
        print("Model type:", type(model))
        
        if hasattr(model, '__dict__'):
            print("\nModel attributes:")
            for attr, value in model.__dict__.items():
                print(f"  {attr}: {type(value)}")
                if hasattr(value, 'shape'):
                    print(f"    Shape: {value.shape}")
        
        break
        
    except Exception as e:
        print(f"Failed with protocol {protocol}: {e}")
        continue

# If all protocols fail, try to examine the raw bytes
print("\nExamining raw file structure...")
with open(model_path, 'rb') as f:
    # Read first 100 bytes
    f.seek(0)
    header = f.read(100)
    print(f"First 100 bytes: {header}")
    
    # Check if it's a valid pickle by looking for pickle opcodes
    f.seek(0)
    try:
        # Try to unpickle without loading fully
        unpickler = pickle.Unpickler(f)
        # Just get the first object info without loading
        f.seek(0)
        # This might still fail but gives us more info
        obj = unpickler.load()
        print("Object type:", type(obj))
    except Exception as e:
        print(f"Pickle examination failed: {e}")
