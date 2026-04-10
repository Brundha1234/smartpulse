import pickle
import os
import gzip
import zlib
import lzma

model_path = os.path.join('new_ml', 'models', 'best_model.pkl')

print(f"File size: {os.path.getsize(model_path)} bytes")

# Try different decompression methods
decompression_methods = [
    ('gzip', gzip.open),
    ('zlib', lambda f: zlib.decompress(f.read())),
    ('lzma', lzma.open),
]

with open(model_path, 'rb') as f:
    raw_data = f.read()
    print(f"Raw data starts with: {raw_data[:20]}")

for method_name, decompress_func in decompression_methods:
    try:
        print(f"\nTrying {method_name} decompression...")
        
        if method_name == 'zlib':
            # zlib works on the data directly
            decompressed_data = decompress_func(open(model_path, 'rb'))
            # Now try to unpickle the decompressed data
            model = pickle.loads(decompressed_data)
        else:
            # gzip and lzma work with file-like objects
            with decompress_func(model_path, 'rb') as f:
                model = pickle.load(f)
        
        print(f"SUCCESS with {method_name}!")
        print("Model type:", type(model))
        
        if hasattr(model, '__dict__'):
            print("\nModel attributes:")
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
        
        print(f"\nModel loaded successfully using {method_name}!")
        break
        
    except Exception as e:
        print(f"Failed with {method_name}: {e}")
        continue

# If all methods fail, try to see if it's a joblib file
try:
    import joblib
    print("\nTrying joblib...")
    model = joblib.load(model_path)
    print("SUCCESS with joblib!")
    print("Model type:", type(model))
    
    if hasattr(model, '__dict__'):
        print("\nModel attributes:")
        for attr, value in model.__dict__.items():
            print(f"  {attr}: {type(value)}")
            if hasattr(value, 'shape'):
                print(f"    Shape: {value.shape}")
    
except ImportError:
    print("\njoblib not available")
except Exception as e:
    print(f"Failed with joblib: {e}")
