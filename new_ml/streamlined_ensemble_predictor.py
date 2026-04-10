# SmartPulse Streamlined Ensemble Predictor
# Top 3 Algorithms + Ensemble Methods for Superior Performance

import joblib
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.metrics import confusion_matrix, classification_report, accuracy_score, roc_auc_score, roc_curve
from sklearn.preprocessing import label_binarize
from sklearn.metrics import auc as sklearn_auc
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import (
    RandomForestClassifier, 
    ExtraTreesClassifier,
    VotingClassifier,
    StackingClassifier
)
from sklearn.svm import SVC
from sklearn.linear_model import LogisticRegression
import warnings
warnings.filterwarnings('ignore')

class StreamlinedEnsemblePredictor:
    """
    Streamlined Ensemble with Top 3 Algorithms:
    1. Random Forest
    2. Extra Trees  
    3. SVM (RBF)
    
    Combined using Voting and Stacking ensembles
    """
    
    def __init__(self):
        self.scaler = None
        self.feature_names = []
        self.class_names = ['Low Addiction', 'Moderate Addiction', 'High Addiction']
        
        # Top 3 individual algorithms - different configurations for variety
        self.base_models = {
            'Random Forest': RandomForestClassifier(n_estimators=300, max_depth=10, random_state=42),
            'Extra Trees': ExtraTreesClassifier(n_estimators=300, max_depth=10, random_state=42),
            'SVM (RBF)': SVC(kernel='rbf', C=1.5, gamma='scale', random_state=42, probability=True)
        }
        
        # Ensemble combinations - optimized to capture both linear and non-linear patterns
        self.ensemble_models = {
            'Voting (Soft)': VotingClassifier(
                estimators=[
                    ('rf', RandomForestClassifier(n_estimators=350, max_depth=12, random_state=42)),
                    ('et', ExtraTreesClassifier(n_estimators=350, max_depth=12, random_state=42)),
                    ('svm', SVC(kernel='rbf', C=2.0, gamma='scale', random_state=42, probability=True))
                ],
                voting='soft',
                weights=[2, 2, 3]  # Give SVM higher weight for non-linear patterns
            ),
            
            'Stacking': StackingClassifier(
                estimators=[
                    ('rf', RandomForestClassifier(n_estimators=250, max_depth=8, random_state=42)),
                    ('et', ExtraTreesClassifier(n_estimators=250, max_depth=8, random_state=42)),
                    ('svm', SVC(kernel='rbf', C=1.8, gamma='scale', random_state=42, probability=True))
                ],
                final_estimator=LogisticRegression(random_state=42, max_iter=1000, C=2.5),
                cv=5
            )
        }
        
        self.all_models = {**self.base_models, **self.ensemble_models}
        self.results = {}
        
    def load_models(self):
        """Load the best trained model and scaler"""
        try:
            self.best_model = joblib.load('streamlined_best_model.pkl')
            self.scaler = joblib.load('streamlined_scaler.pkl')
            print("✅ Models loaded successfully")
            return True
        except FileNotFoundError:
            print("❌ Model files not found. Run evaluation first.")
            return False
    
    def predict_addiction(self, user_data):
        """Make prediction for new user data"""
        # Convert to DataFrame
        input_df = pd.DataFrame([user_data])
        
        # Ensure correct feature order
        feature_columns = [
            'screen_time', 'app_usage', 'night_usage', 'unlock_count', 'notification_count',
            'social_media_time', 'gaming_time', 'productivity_time', 'weekend_usage',
            'stress_level', 'anxiety_level', 'depression_level', 'sleep_quality',
            'work_productivity', 'social_interactions', 'physical_activity',
            'age', 'gender', 'education', 'occupation_type', 'income_level'
        ]
        
        input_df = input_df[feature_columns]
        
        # Scale features
        input_scaled = self.scaler.transform(input_df)
        
        # Make prediction
        prediction = self.best_model.predict(input_scaled)[0]
        probabilities = self.best_model.predict_proba(input_scaled)[0]
        
        # Get confidence
        confidence = max(probabilities)
        
        return {
            'addiction_level': int(prediction),
            'confidence': confidence,
            'probabilities': probabilities.tolist()
        }
        
    def load_data(self):
        """Load and prepare the dataset"""
        try:
            df = pd.read_csv('dataset.csv')
            print(f"✅ Dataset loaded: {df.shape[0]} samples, {df.shape[1]} features")
            return df
        except FileNotFoundError:
            print("⚠️ Dataset not found. Generating synthetic data...")
            return self.generate_synthetic_data()
    
    def generate_synthetic_data(self):
        """Generate synthetic smartphone addiction data"""
        np.random.seed(42)
        n_samples = 1000
        
        # Generate realistic smartphone usage features
        data = {
            'screen_time': np.random.uniform(1, 12, n_samples),
            'app_usage': np.random.uniform(2, 8, n_samples),
            'night_usage': np.random.uniform(0, 4, n_samples),
            'unlock_count': np.random.uniform(20, 200, n_samples),
            'notification_count': np.random.uniform(50, 500, n_samples),
            'social_media_time': np.random.uniform(1, 6, n_samples),
            'gaming_time': np.random.uniform(0, 3, n_samples),
            'productivity_time': np.random.uniform(0, 2, n_samples),
            'weekend_usage': np.random.uniform(2, 14, n_samples),
            'stress_level': np.random.randint(1, 6, n_samples),
            'anxiety_level': np.random.randint(1, 6, n_samples),
            'depression_level': np.random.randint(1, 6, n_samples),
            'sleep_quality': np.random.randint(1, 6, n_samples),
            'work_productivity': np.random.randint(1, 6, n_samples),
            'social_interactions': np.random.randint(1, 11, n_samples),
            'physical_activity': np.random.randint(0, 4, n_samples),
            'age': np.random.randint(16, 65, n_samples),
            'gender': np.random.choice([0, 1], n_samples),
            'education': np.random.randint(1, 6, n_samples),
            'occupation_type': np.random.randint(1, 4, n_samples),
            'income_level': np.random.randint(1, 6, n_samples),
        }
        
        df = pd.DataFrame(data)
        
        # Create addiction level based on features
        addiction_score = (
            df['screen_time'] * 0.15 +
            df['app_usage'] * 0.12 +
            df['night_usage'] * 0.18 +
            df['unlock_count'] * 0.08 +
            df['notification_count'] * 0.06 +
            df['social_media_time'] * 0.10 +
            df['gaming_time'] * 0.08 +
            df['stress_level'] * 0.07 +
            df['anxiety_level'] * 0.06 +
            df['depression_level'] * 0.05 -
            df['sleep_quality'] * 0.03 -
            df['work_productivity'] * 0.02
        )
        
        # Create addiction levels: 0=Low, 1=Moderate, 2=High
        df['addiction_level'] = pd.cut(
            addiction_score,
            bins=[-np.inf, addiction_score.quantile(0.33), addiction_score.quantile(0.67), np.inf],
            labels=[0, 1, 2]
        ).astype(int)
        
        print(f"✅ Synthetic data generated: {df.shape[0]} samples, {df.shape[1]} features")
        return df
    
    def prepare_data(self, df):
        """Prepare features and target"""
        feature_columns = [col for col in df.columns if col != 'addiction_level']
        X = df[feature_columns]
        y = df['addiction_level']
        self.feature_names = feature_columns
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        # Scale features
        self.scaler = StandardScaler()
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        return X_train_scaled, X_test_scaled, y_train, y_test, feature_columns
    
    def plot_confusion_matrix(self, y_true, y_pred, model_name, accuracy):
        """Create and save confusion matrix plot"""
        cm = confusion_matrix(y_true, y_pred)
        
        # Create figure
        plt.figure(figsize=(10, 8))
        
        # Create heatmap
        sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
                   square=True, cbar_kws={'shrink': 0.8},
                   annot_kws={'size': 14, 'weight': 'bold'})
        
        plt.title(f'{model_name}\nAccuracy: {accuracy:.2%}', 
                 fontsize=16, fontweight='bold', pad=20)
        plt.xlabel('Predicted Label', fontsize=14, fontweight='bold')
        plt.ylabel('True Label', fontsize=14, fontweight='bold')
        
        # Set tick labels
        class_names = ['Low', 'Moderate', 'High']
        plt.xticks(np.arange(3) + 0.5, class_names, fontsize=12)
        plt.yticks(np.arange(3) + 0.5, class_names, fontsize=12)
        
        # Add grid
        plt.grid(False)
        
        # Save plot
        filename = f'visualizations/confusion_matrix_{model_name.lower().replace(" ", "_").replace("(", "").replace(")", "")}.png'
        plt.savefig(filename, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"📊 Confusion matrix saved: {filename}")
        return filename
    
    def plot_roc_curve(self, y_true, y_scores, model_name):
        """Create and save ROC curve plot"""
        if not hasattr(self, 'class_names'):
            self.class_names = ['Low Addiction', 'Moderate Addiction', 'High Addiction']
        
        # Binarize labels for multi-class ROC
        y_test_binarized = label_binarize(y_true, classes=[0, 1, 2])
        
        # Calculate AUC for each class
        auc_scores = {}
        for i in range(len(np.unique(y_true))):
            auc_scores[f'Class {i}'] = roc_auc_score(y_test_binarized[:, i], y_scores[:, i])
        
        # Calculate macro AUC
        macro_auc = np.mean(list(auc_scores.values()))
        
        # Create ROC curves
        plt.figure(figsize=(12, 8))
        colors = ['blue', 'red', 'green']
        class_labels = self.class_names
        
        for i, color, label in zip(range(len(np.unique(y_true))), colors, class_labels):
            fpr, tpr, _ = roc_curve(y_test_binarized[:, i], y_scores[:, i])
            roc_auc_value = sklearn_auc(fpr, tpr)
            plt.plot(fpr, tpr, color=color, lw=2,
                    label=f'{label} (AUC = {roc_auc_value:.3f})')
        
        plt.plot([0, 1], [0, 1], 'k--', lw=2, color='black')
        plt.xlim([0.0, 1.0])
        plt.ylim([0.0, 1.05])
        plt.xlabel('False Positive Rate', fontsize=14, fontweight='bold')
        plt.ylabel('True Positive Rate', fontsize=14, fontweight='bold')
        plt.title(f'ROC Curve - {model_name}', fontsize=16, fontweight='bold', pad=20)
        plt.legend(loc="lower right", fontsize=12)
        plt.grid(True, alpha=0.3)
        
        # Save ROC curve
        filename = f'visualizations/roc_curve_{model_name.lower().replace(" ", "_").replace("(", "").replace(")", "")}.png'
        plt.savefig(filename, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"📈 ROC curve saved: {filename}")
        print(f"📈 AUC Scores: {auc_scores}")
        print(f"📈 Macro AUC: {macro_auc:.4f}")
        return filename, auc_scores, macro_auc
    
    def evaluate_model(self, model, X_train, X_test, y_train, y_test, model_name):
        """Evaluate a single model"""
        print(f"\n🔍 Evaluating {model_name}...")
        
        # Train model
        if 'Stacking' in model_name:
            print("  ⏳ Training Stacking ensemble (this may take a moment)...")
        
        model.fit(X_train, y_train)
        
        # Make predictions
        y_pred = model.predict(X_test)
        
        # Calculate metrics
        accuracy = accuracy_score(y_test, y_pred)
        report = classification_report(y_test, y_pred, output_dict=True)
        
        # Store results
        self.results[model_name] = {
            'accuracy': accuracy,
            'precision': report['weighted avg']['precision'],
            'recall': report['weighted avg']['recall'],
            'f1_score': report['weighted avg']['f1-score'],
            'confusion_matrix': confusion_matrix(y_test, y_pred),
            'predictions': y_pred,
            'true_labels': y_test
        }
        
        # Check if visualizations already exist
        import os
        cm_filename = f'visualizations/confusion_matrix_{model_name.lower().replace(" ", "_").replace("(", "").replace(")", "")}.png'
        roc_filename = f'visualizations/roc_curve_{model_name.lower().replace(" ", "_").replace("(", "").replace(")", "")}.png'
        
        vis_exist = os.path.exists(cm_filename) and (not hasattr(model, 'predict_proba') or os.path.exists(roc_filename))
        
        if not vis_exist:
            # Plot confusion matrix
            self.plot_confusion_matrix(y_test, y_pred, model_name, accuracy)
            
            # Generate ROC curve if model supports probabilities
            if hasattr(model, 'predict_proba'):
                y_scores = model.predict_proba(X_test)
                roc_filename, auc_scores, macro_auc = self.plot_roc_curve(y_test, y_scores, model_name)
                
                # Store AUC in results
                self.results[model_name]['auc_scores'] = auc_scores
                self.results[model_name]['macro_auc'] = macro_auc
            else:
                print(f"⚠️ {model_name} does not support probability predictions, skipping ROC/AUC")
        else:
            print(f"⏭️  Visualizations already exist for {model_name}, skipping generation")
            
            # Still load AUC data if available
            if hasattr(model, 'predict_proba'):
                y_scores = model.predict_proba(X_test)
                y_test_binarized = label_binarize(y_test, classes=[0, 1, 2])
                
                auc_scores = {}
                for i in range(len(np.unique(y_test))):
                    auc_scores[f'Class {i}'] = roc_auc_score(y_test_binarized[:, i], y_scores[:, i])
                
                macro_auc = np.mean(list(auc_scores.values()))
                self.results[model_name]['auc_scores'] = auc_scores
                self.results[model_name]['macro_auc'] = macro_auc
        
        print(f"✅ {model_name}: {accuracy:.2%} accuracy")
        return accuracy
    
    def run_evaluation(self):
        """Run complete evaluation for streamlined models"""
        print("🚀 SmartPulse Streamlined Ensemble Evaluation")
        print("=" * 60)
        print("📊 Top 3 Algorithms + Ensemble Methods")
        print("=" * 60)
        
        # Load data
        df = self.load_data()
        
        # Prepare data
        X_train, X_test, y_train, y_test, feature_columns = self.prepare_data(df)
        
        print(f"\n📊 Dataset split: {len(X_train)} training, {len(X_test)} test samples")
        print(f"🎯 Features: {len(feature_columns)}")
        print(f"🏷️ Classes: 3 (Low=0, Moderate=1, High=2)")
        
        # Evaluate base models first
        print("\n" + "=" * 50)
        print("📊 EVALUATING TOP 3 ALGORITHMS")
        print("=" * 50)
        
        base_accuracies = []
        for model_name, model in self.base_models.items():
            accuracy = self.evaluate_model(model, X_train, X_test, y_train, y_test, model_name)
            base_accuracies.append((model_name, accuracy))
        
        # Evaluate ensemble models
        print("\n" + "=" * 50)
        print("🔥 EVALUATING ENSEMBLE COMBINATIONS")
        print("=" * 50)
        
        ensemble_accuracies = []
        for model_name, model in self.ensemble_models.items():
            accuracy = self.evaluate_model(model, X_train, X_test, y_train, y_test, model_name)
            ensemble_accuracies.append((model_name, accuracy))
        
        # Combine and sort all results
        all_accuracies = base_accuracies + ensemble_accuracies
        all_accuracies.sort(key=lambda x: x[1], reverse=True)
        
        print("\n" + "=" * 60)
        print("🎯 INDIVIDUAL ALGORITHM PERFORMANCE METRICS")
        print("=" * 60)
        
        # Display individual metrics for each model
        for model_name, metrics in self.results.items():
            model_type = "🔥 ENSEMBLE" if model_name in self.ensemble_models else "📊 BASE"
            
            print(f"\n{model_type} {model_name}:")
            print(f"   📈 Accuracy:  {metrics['accuracy']:.4f} ({metrics['accuracy']*100:.2f}%)")
            print(f"   🎯 Precision: {metrics['precision']:.4f}")
            print(f"   🔄 Recall:    {metrics['recall']:.4f}")
            print(f"   ⚖️  F1-Score:  {metrics['f1_score']:.4f}")
            
            if 'macro_auc' in metrics:
                print(f"   📊 Macro AUC: {metrics['macro_auc']:.4f}")
                
                # Show per-class AUC
                auc_scores = metrics['auc_scores']
                print(f"   📈 Class AUC:")
                for class_name, auc_val in auc_scores.items():
                    print(f"      {class_name}: {auc_val:.4f}")
        
        print("\n" + "=" * 60)
        print("📈 COMPLETE PERFORMANCE RANKING")
        print("=" * 60)
        
        for i, (model_name, accuracy) in enumerate(all_accuracies, 1):
            model_type = "🔥 ENSEMBLE" if model_name in self.ensemble_models else "📊 BASE"
            metrics = self.results[model_name]
            
            print(f"{i:2d}. {model_type} {model_name}:")
            print(f"     📈 Accuracy:  {metrics['accuracy']:.2%}")
            print(f"     🎯 Precision: {metrics['precision']:.3f}")
            print(f"     🔄 Recall:    {metrics['recall']:.3f}")
            print(f"     ⚖️  F1-Score:  {metrics['f1_score']:.3f}")
            
            if 'macro_auc' in metrics:
                print(f"     📊 Macro AUC: {metrics['macro_auc']:.3f}")
            print()
        
        # Find best model
        best_model_name, best_accuracy = all_accuracies[0]
        best_model = None
        
        # Get best model from appropriate dictionary
        if best_model_name in self.ensemble_models:
            best_model = self.ensemble_models[best_model_name]
            model_type = "Ensemble"
        else:
            best_model = self.base_models[best_model_name]
            model_type = "Base"
        
        # Retrain best model on full dataset
        X_full = np.vstack([X_train, X_test])
        y_full = np.concatenate([y_train, y_test])
        best_model.fit(X_full, y_full)
        
        # Save best model
        joblib.dump(best_model, 'models/best_model.pkl')
        joblib.dump(self.scaler, 'models/scaler.pkl')
        
        print(f"\n🏆 Best model: {best_model_name} ({model_type}) - {best_accuracy:.2%} accuracy")
        print("💾 Best model saved as 'models/best_model.pkl'")
        
        return self.results
    
    def create_summary_report(self):
        """Create comprehensive summary report"""
        if not self.results:
            print("❌ No results to summarize. Run evaluation first.")
            return
        
        print("\n" + "=" * 80)
        print("📋 STREAMLINED ENSEMBLE EVALUATION REPORT")
        print("=" * 80)
        
        # Separate base and ensemble models
        base_results = {k: v for k, v in self.results.items() if k not in self.ensemble_models}
        ensemble_results = {k: v for k, v in self.results.items() if k in self.ensemble_models}
        
        # Create comparison tables
        print("\n📊 TOP 3 ALGORITHMS PERFORMANCE:")
        self.print_comparison_table(base_results)
        
        print("\n🔥 ENSEMBLE METHODS PERFORMANCE:")
        self.print_comparison_table(ensemble_results)
        
        # Find best models in each category
        if base_results:
            best_base = max(base_results.items(), key=lambda x: x[1]['accuracy'])
            print(f"\n🏆 Best Base Algorithm: {best_base[0]} ({best_base[1]['accuracy']:.2%})")
        
        if ensemble_results:
            best_ensemble = max(ensemble_results.items(), key=lambda x: x[1]['accuracy'])
            print(f"\n🏆 Best Ensemble Method: {best_ensemble[0]} ({best_ensemble[1]['accuracy']:.2%})")
        
        # Overall best model
        overall_best = max(self.results.items(), key=lambda x: x[1]['accuracy'])
        overall_type = "Ensemble" if overall_best[0] in self.ensemble_models else "Base"
        print(f"\n🥇 Overall Best Model: {overall_best[0]} ({overall_type}) - {overall_best[1]['accuracy']:.2%}")
        
        # Create performance plot
        self.create_performance_plot()
        
        print("\n📁 Generated Files:")
        print("📊 Confusion Matrix Plots:")
        for model_name in self.results.keys():
            filename = f'visualizations/confusion_matrix_{model_name.lower().replace(" ", "_").replace("(", "").replace(")", "")}.png'
            print(f"  - {filename}")
        
        print("\n💾 Model Files:")
        print("  - models/best_model.pkl (Best performing model)")
        print("  - models/scaler.pkl (Feature scaler)")
        print("  - models/training_results.pkl (All results)")
        
        # Save results
        joblib.dump(self.results, 'models/training_results.pkl')
    
    def print_comparison_table(self, results):
        """Print comparison table for results"""
        if not results:
            print("  No models in this category")
            return
            
        comparison_data = []
        for model_name, metrics in results.items():
            comparison_data.append({
                'Model': model_name,
                'Accuracy': f"{metrics['accuracy']:.2%}",
                'Precision': f"{metrics['precision']:.3f}",
                'Recall': f"{metrics['recall']:.3f}",
                'F1-Score': f"{metrics['f1_score']:.3f}"
            })
        
        df_comparison = pd.DataFrame(comparison_data)
        print(df_comparison.to_string(index=False))
    
    def create_performance_plot(self):
        """Create performance comparison plot"""
        models = list(self.results.keys())
        accuracies = [self.results[model]['accuracy'] for model in models]
        
        # Separate base and ensemble for coloring
        base_models = [m for m in models if m not in self.ensemble_models]
        ensemble_models = [m for m in models if m in self.ensemble_models]
        
        base_accuracies = [self.results[m]['accuracy'] for m in base_models]
        ensemble_accuracies = [self.results[m]['accuracy'] for m in ensemble_models]
        
        plt.figure(figsize=(16, 10))
        
        # Create subplot positions
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8))
        
        # Base models plot
        if base_models:
            x_pos_base = np.arange(len(base_models))
            bars1 = ax1.bar(x_pos_base, base_accuracies, color='lightblue', alpha=0.8, edgecolor='black')
            ax1.set_title('Top 3 Algorithms', fontsize=14, fontweight='bold')
            ax1.set_ylabel('Accuracy', fontsize=12, fontweight='bold')
            ax1.set_ylim(0, 1)
            ax1.set_xticks(x_pos_base, base_models, rotation=15, ha='center', fontsize=11)
            
            # Add value labels
            for bar, accuracy in zip(bars1, base_accuracies):
                label = f'{accuracy:.2%}'
                color = 'darkred' if accuracy == max(base_accuracies) else 'black'
                ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01,
                        label, ha='center', va='bottom', 
                        fontsize=10, fontweight='bold', color=color)
        
        # Ensemble models plot
        if ensemble_models:
            x_pos_ensemble = np.arange(len(ensemble_models))
            bars2 = ax2.bar(x_pos_ensemble, ensemble_accuracies, color='lightcoral', alpha=0.8, edgecolor='black')
            ax2.set_title('Ensemble Methods', fontsize=14, fontweight='bold')
            ax2.set_ylabel('Accuracy', fontsize=12, fontweight='bold')
            ax2.set_ylim(0, 1)
            ax2.set_xticks(x_pos_ensemble, ensemble_models, rotation=15, ha='center', fontsize=11)
            
            # Add value labels
            for bar, accuracy in zip(bars2, ensemble_accuracies):
                label = f'{accuracy:.2%}'
                color = 'darkred' if accuracy == max(ensemble_accuracies) else 'black'
                ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01,
                        label, ha='center', va='bottom', 
                        fontsize=10, fontweight='bold', color=color)
        
        plt.suptitle('Top 3 Algorithms vs Ensemble Methods - Performance Comparison', 
                     fontsize=16, fontweight='bold', y=1.02)
        
        # Add legend
        import matplotlib.patches as mpatches
        patch1 = mpatches.Patch(color='lightblue', label='Top 3 Algorithms')
        patch2 = mpatches.Patch(color='lightcoral', label='Ensemble Methods')
        fig.legend(handles=[patch1, patch2], loc='upper right')
        
        # Add grid
        ax1.grid(axis='y', alpha=0.3)
        ax2.grid(axis='y', alpha=0.3)
        
        # Save plot
        plt.tight_layout()
        plt.savefig('visualizations/performance_comparison.png', dpi=300, bbox_inches='tight')
        plt.close()
        
        print("📈 Performance comparison plot saved: visualizations/performance_comparison.png")

def main():
    """Main function to run streamlined ensemble evaluation"""
    print("🤖 SmartPulse Streamlined Ensemble Predictor")
    print("=" * 60)
    print("📊 Top 3 Algorithms: Random Forest, Extra Trees, SVM")
    print("🔥 Ensemble Methods: Voting (Soft), Stacking")
    print("=" * 60)
    
    # Create evaluator
    evaluator = StreamlinedEnsemblePredictor()
    
    # Run evaluation
    results = evaluator.run_evaluation()
    
    # Create summary report
    evaluator.create_summary_report()
    
    print("\n" + "=" * 60)
    print("✅ Streamlined Ensemble Evaluation Complete!")
    print("📊 Check current folder for all confusion matrix plots")
    print("🚀 Top 3 algorithms + Ensemble methods ready for production!")
    print("=" * 60)

if __name__ == "__main__":
    main()
