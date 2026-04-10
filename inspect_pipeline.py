import joblib
import os

model_path = os.path.join('new_ml', 'models', 'best_model.pkl')

# Load the pipeline
pipeline = joblib.load(model_path)

print("=" * 60)
print("MODEL PIPELINE INSPECTION")
print("=" * 60)

print(f"Pipeline type: {type(pipeline)}")
print(f"Number of steps: {len(pipeline.steps)}")
print(f"Verbose: {pipeline.verbose}")
print(f"Memory: {pipeline.memory}")
print(f"Transform input: {pipeline.transform_input}")

print("\n" + "=" * 60)
print("PIPELINE STEPS")
print("=" * 60)

for i, (name, step) in enumerate(pipeline.steps):
    print(f"\nStep {i}: {name}")
    print(f"  Type: {type(step)}")
    print(f"  Module: {type(step).__module__}")
    
    # Get step parameters
    if hasattr(step, 'get_params'):
        params = step.get_params()
        print(f"  Parameters:")
        for param_name, param_value in params.items():
            if isinstance(param_value, (str, int, float, bool)):
                print(f"    {param_name}: {param_value}")
            elif hasattr(param_value, 'shape'):
                print(f"    {param_name}: {type(param_value)} with shape {param_value.shape}")
            else:
                print(f"    {param_name}: {type(param_value)}")
    
    # Special handling for different step types
    if hasattr(step, 'n_features_in_'):
        print(f"  Input features: {step.n_features_in_}")
    
    if hasattr(step, 'feature_names_in_'):
        print(f"  Feature names: {step.feature_names_in_}")
    
    if hasattr(step, 'classes_'):
        print(f"  Classes: {step.classes_}")
    
    if hasattr(step, 'feature_importances_'):
        print(f"  Feature importances shape: {step.feature_importances_.shape}")
        print(f"  Top 5 feature importances: {step.feature_importances_[:5]}")

print("\n" + "=" * 60)
print("PIPELINE SUMMARY")
print("=" * 60)

# Try to get overall pipeline info
try:
    # This will work if the pipeline is fitted
    if hasattr(pipeline, 'named_steps'):
        print("Named steps:")
        for name, step in pipeline.named_steps.items():
            print(f"  {name}: {type(step).__name__}")
    
    # Check if it's a classifier or regressor
    last_step = pipeline.steps[-1][1]
    if hasattr(last_step, 'predict_proba'):
        print("Pipeline type: Classifier")
    elif hasattr(last_step, 'predict'):
        print("Pipeline type: Regressor")
    else:
        print("Pipeline type: Transformer/Other")
        
except Exception as e:
    print(f"Could not get full pipeline info: {e}")

print(f"\nModel loaded successfully from: {model_path}")
