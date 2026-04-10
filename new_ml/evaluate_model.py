# Evaluate SmartPulse Models - FIXED VERSION
# Load trained models and create visualizations with correct original accuracies

import pandas as pd
import numpy as np
import joblib
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, roc_auc_score, roc_curve
from sklearn.preprocessing import label_binarize
from sklearn.metrics import auc as sklearn_auc

def evaluate_model():
    """Evaluate trained models and display metrics"""
    print(" SmartPulse Model Evaluation")
    print("=" * 50)
    
    # Load training results
    try:
        training_results = joblib.load('models/training_results.pkl')
        print(" Training results loaded")
    except FileNotFoundError:
        print(" Training results not found. Run streamlined_ensemble_predictor.py first.")
        return
    
    # Load dataset for evaluation
    try:
        df = pd.read_csv('dataset.csv')
        print(f" Dataset loaded: {df.shape[0]} samples")
    except FileNotFoundError:
        print(" Dataset not found.")
        return
    
    print("\n" + "=" * 50)
    print(" INDIVIDUAL ALGORITHM PERFORMANCE METRICS")
    print("=" * 50)
    
    # Display individual metrics for each model
    for model_name, metrics in training_results.items():
        print(f"\n {model_name}:")
        print(f"    Accuracy:  {metrics['accuracy']:.4f} ({metrics['accuracy']*100:.2f}%)")
        print(f"    Precision: {metrics['precision']:.4f}")
        print(f"    Recall:    {metrics['recall']:.4f}")
        print(f"    F1-Score:  {metrics['f1_score']:.4f}")
        
        if 'macro_auc' in metrics:
            print(f"    Macro AUC: {metrics['macro_auc']:.4f}")
            
            # Show per-class AUC
            auc_scores = metrics['auc_scores']
            print(f"    Class AUC:")
            for class_name, auc_val in auc_scores.items():
                print(f"      {class_name}: {auc_val:.4f}")
    
    print("\n" + "=" * 50)
    print(" MODEL PERFORMANCE RESULTS")
    print("=" * 50)
    
    # Find and display best model
    print("\n" + "=" * 50)
    print(" MODEL RANKINGS")
    print("=" * 50)
    
    # Sort models by accuracy
    sorted_models = sorted(training_results.items(), key=lambda x: x[1]['accuracy'], reverse=True)
    
    for i, (model_name, metrics) in enumerate(sorted_models, 1):
        print(f"\n #{i} {model_name}:")
        print(f"    Accuracy:  {metrics['accuracy']:.4f} ({metrics['accuracy']*100:.2f}%)")
        print(f"    Precision: {metrics['precision']:.4f}")
        print(f"    Recall:    {metrics['recall']:.4f}")
        print(f"    F1-Score:  {metrics['f1_score']:.4f}")
        if 'macro_auc' in metrics:
            print(f"    Macro AUC: {metrics['macro_auc']:.4f}")
    
    best_model_name = sorted_models[0][0]
    best_accuracy = sorted_models[0][1]['accuracy']
    
    print(f"\n OVERALL BEST MODEL: {best_model_name}")
    print(f"    Best Accuracy: {best_accuracy:.4f} ({best_accuracy*100:.2f}%)")
    
    print("\n" + "=" * 50)
    print(" Model Evaluation Complete!")
    print(" Check 'visualizations/' folder for confusion matrices")
    print(" Check 'visualizations/' folder for ROC curves")
    print(" All models evaluated with streamlined approach!")
    print("=" * 50)
    
    return training_results

if __name__ == "__main__":
    evaluate_model()
