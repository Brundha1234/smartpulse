# Linear + Non-Linear Dataset Generator for SmartPulse
# Creates dataset with both linear and non-linear relationships for true ensemble benefits

import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler

def generate_linear_nonlinear_dataset():
    """
    Generate dataset with both linear and non-linear relationships
    to ensure different models capture different aspects and ensembles improve performance
    """
    print("🎯 Generating Linear + Non-Linear dataset (true ensemble benefits)...")
    
    np.random.seed(42)  # For reproducibility
    
    # Create profiles with mixed linear and non-linear patterns
    n_samples = 10000
    
    # Profile 1: Linear Relationship Heavy (30%) - Tree models favor
    n_linear_heavy = int(n_samples * 0.30)
    linear_heavy = {
        'screen_time': np.random.normal(8.0, 2.0, n_linear_heavy),
        'app_usage': np.random.normal(6.0, 1.8, n_linear_heavy),
        'night_usage': np.random.normal(3.0, 1.2, n_linear_heavy),
        'unlock_count': np.random.normal(150, 40, n_linear_heavy),
        'notification_count': np.random.normal(300, 80, n_linear_heavy),
        'social_media_time': np.random.normal(4.0, 1.5, n_linear_heavy),
        'gaming_time': np.random.normal(1.5, 1.0, n_linear_heavy),
        'productivity_time': np.random.normal(0.5, 0.3, n_linear_heavy),
        'weekend_usage': np.random.normal(9.0, 2.5, n_linear_heavy),
        'stress_level': np.random.randint(3, 6, n_linear_heavy),
        'anxiety_level': np.random.randint(2, 5, n_linear_heavy),
        'depression_level': np.random.randint(2, 5, n_linear_heavy),
        'sleep_quality': np.random.randint(2, 4, n_linear_heavy),
        'work_productivity': np.random.randint(2, 4, n_linear_heavy),
        'social_interactions': np.random.randint(4, 6, n_linear_heavy),
        'physical_activity': np.random.randint(1, 3, n_linear_heavy),
        'age': np.random.normal(30, 8, n_linear_heavy),
        'gender': np.random.choice([0, 1], n_linear_heavy, p=[0.55, 0.45]),
        'education': np.random.randint(2, 4, n_linear_heavy),
        'occupation_type': np.random.randint(1, 3, n_linear_heavy),
        'income_level': np.random.randint(2, 4, n_linear_heavy)
    }
    
    # Profile 2: Non-Linear Relationship Heavy (30%) - SVM favors
    n_nonlinear_heavy = int(n_samples * 0.30)
    nonlinear_heavy = {
        'screen_time': np.random.normal(10.0, 4.0, n_nonlinear_heavy),
        'app_usage': np.random.normal(7.5, 3.0, n_nonlinear_heavy),
        'night_usage': np.random.normal(4.5, 2.5, n_nonlinear_heavy),
        'unlock_count': np.random.normal(200, 80, n_nonlinear_heavy),
        'notification_count': np.random.normal(400, 150, n_nonlinear_heavy),
        'social_media_time': np.random.normal(5.5, 2.5, n_nonlinear_heavy),
        'gaming_time': np.random.normal(2.5, 2.0, n_nonlinear_heavy),
        'productivity_time': np.random.normal(0.3, 0.4, n_nonlinear_heavy),
        'weekend_usage': np.random.normal(12.0, 4.0, n_nonlinear_heavy),
        'stress_level': np.random.randint(4, 7, n_nonlinear_heavy),
        'anxiety_level': np.random.randint(3, 6, n_nonlinear_heavy),
        'depression_level': np.random.randint(3, 6, n_nonlinear_heavy),
        'sleep_quality': np.random.randint(1, 3, n_nonlinear_heavy),
        'work_productivity': np.random.randint(1, 3, n_nonlinear_heavy),
        'social_interactions': np.random.randint(2, 5, n_nonlinear_heavy),
        'physical_activity': np.random.randint(0, 2, n_nonlinear_heavy),
        'age': np.random.normal(25, 10, n_nonlinear_heavy),
        'gender': np.random.choice([0, 1], n_nonlinear_heavy, p=[0.6, 0.4]),
        'education': np.random.randint(2, 3, n_nonlinear_heavy),
        'occupation_type': np.random.randint(1, 2, n_nonlinear_heavy),
        'income_level': np.random.randint(2, 3, n_nonlinear_heavy)
    }
    
    # Profile 3: Mixed Linear/Non-Linear (25%) - Challenging for all
    n_mixed = int(n_samples * 0.25)
    mixed = {
        'screen_time': np.random.normal(6.0, 3.0, n_mixed),
        'app_usage': np.random.normal(4.5, 2.2, n_mixed),
        'night_usage': np.random.normal(2.0, 1.8, n_mixed),
        'unlock_count': np.random.normal(100, 60, n_mixed),
        'notification_count': np.random.normal(250, 120, n_mixed),
        'social_media_time': np.random.normal(3.0, 2.0, n_mixed),
        'gaming_time': np.random.normal(1.0, 1.5, n_mixed),
        'productivity_time': np.random.normal(1.0, 0.8, n_mixed),
        'weekend_usage': np.random.normal(7.0, 3.5, n_mixed),
        'stress_level': np.random.randint(2, 5, n_mixed),
        'anxiety_level': np.random.randint(2, 4, n_mixed),
        'depression_level': np.random.randint(2, 4, n_mixed),
        'sleep_quality': np.random.randint(3, 5, n_mixed),
        'work_productivity': np.random.randint(3, 5, n_mixed),
        'social_interactions': np.random.randint(5, 7, n_mixed),
        'physical_activity': np.random.randint(1, 3, n_mixed),
        'age': np.random.normal(35, 12, n_mixed),
        'gender': np.random.choice([0, 1], n_mixed, p=[0.5, 0.5]),
        'education': np.random.randint(3, 5, n_mixed),
        'occupation_type': np.random.randint(2, 4, n_mixed),
        'income_level': np.random.randint(3, 5, n_mixed)
    }
    
    # Profile 4: Ensemble-Optimal (15%) - Complex patterns requiring combination
    n_ensemble_opt = int(n_samples * 0.15)
    ensemble_opt = {
        'screen_time': np.random.normal(3.0, 2.5, n_ensemble_opt),
        'app_usage': np.random.normal(2.0, 1.8, n_ensemble_opt),
        'night_usage': np.random.normal(1.0, 1.2, n_ensemble_opt),
        'unlock_count': np.random.normal(60, 40, n_ensemble_opt),
        'notification_count': np.random.normal(150, 80, n_ensemble_opt),
        'social_media_time': np.random.normal(1.5, 1.2, n_ensemble_opt),
        'gaming_time': np.random.normal(0.5, 0.6, n_ensemble_opt),
        'productivity_time': np.random.normal(2.0, 1.2, n_ensemble_opt),
        'weekend_usage': np.random.normal(4.0, 3.0, n_ensemble_opt),
        'stress_level': np.random.randint(1, 3, n_ensemble_opt),
        'anxiety_level': np.random.randint(1, 3, n_ensemble_opt),
        'depression_level': np.random.randint(1, 3, n_ensemble_opt),
        'sleep_quality': np.random.randint(4, 6, n_ensemble_opt),
        'work_productivity': np.random.randint(4, 6, n_ensemble_opt),
        'social_interactions': np.random.randint(6, 9, n_ensemble_opt),
        'physical_activity': np.random.randint(2, 4, n_ensemble_opt),
        'age': np.random.normal(40, 15, n_ensemble_opt),
        'gender': np.random.choice([0, 1], n_ensemble_opt),
        'education': np.random.randint(3, 6, n_ensemble_opt),
        'occupation_type': np.random.randint(2, 4, n_ensemble_opt),
        'income_level': np.random.randint(3, 6, n_ensemble_opt)
    }
    
    # Combine all profiles
    all_data = {}
    for key in linear_heavy.keys():
        all_data[key] = np.concatenate([
            linear_heavy[key],
            nonlinear_heavy[key], 
            mixed[key],
            ensemble_opt[key]
        ])
    
    # Create addiction levels with mixed linear/non-linear patterns
    addiction_levels = []
    for i in range(n_samples):
        if i < n_linear_heavy:  # Linear heavy - clear additive relationships
            # Linear relationship: screen_time + app_usage + notifications
            screen_score = all_data['screen_time'][i] / 24
            app_score = all_data['app_usage'][i] / 24
            notification_score = all_data['notification_count'][i] / 1000
            linear_score = screen_score + app_score + notification_score
            
            if linear_score > 0.8:
                addiction_levels.append(2)  # High addiction
            elif linear_score > 0.5:
                addiction_levels.append(1)  # Moderate addiction
            else:
                addiction_levels.append(0)  # Low addiction
                
        elif i < n_linear_heavy + n_nonlinear_heavy:  # Non-linear heavy
            # Non-linear relationship: exponential stress impact
            stress = all_data['stress_level'][i]
            anxiety = all_data['anxiety_level'][i]
            depression = all_data['depression_level'][i]
            
            # Non-linear scoring: exponential stress impact
            stress_factor = np.exp(stress / 3) / 10
            anxiety_factor = np.sin(anxiety * np.pi / 4) + 1
            depression_factor = depression ** 1.5 / 10
            
            nonlinear_score = stress_factor * anxiety_factor * depression_factor
            
            if nonlinear_score > 1.5:
                addiction_levels.append(2)  # High addiction
            elif nonlinear_score > 0.8:
                addiction_levels.append(1)  # Moderate addiction
            else:
                addiction_levels.append(0)  # Low addiction
                
        elif i < n_linear_heavy + n_nonlinear_heavy + n_mixed:  # Mixed patterns
            # Mixed linear + non-linear relationships
            linear_part = (all_data['screen_time'][i] + all_data['app_usage'][i]) / 48
            nonlinear_part = np.log(all_data['unlock_count'][i] + 1) / 10
            interaction_part = (all_data['stress_level'][i] * all_data['night_usage'][i]) / 50
            
            mixed_score = linear_part + nonlinear_part + interaction_part
            
            if mixed_score > 0.9:
                addiction_levels.append(2)  # High addiction
            elif mixed_score > 0.5:
                addiction_levels.append(1)  # Moderate addiction
            else:
                addiction_levels.append(0)  # Low addiction
        else:  # Ensemble optimal - complex interactions
            # Complex multi-dimensional relationships
            time_factors = (all_data['screen_time'][i] + all_data['night_usage'][i]) / 36
            psychological_factors = (all_data['stress_level'][i] + all_data['anxiety_level'][i]) / 14
            social_factors = all_data['social_interactions'][i] / 10
            
            # Complex interaction model
            base_score = time_factors * psychological_factors
            interaction_bonus = social_factors * np.sin(all_data['weekend_usage'][i] * np.pi / 12)
            ensemble_score = base_score + interaction_bonus
            
            if ensemble_score > 1.2:
                addiction_levels.append(2)  # High addiction
            elif ensemble_score > 0.6:
                addiction_levels.append(1)  # Moderate addiction
            else:
                addiction_levels.append(0)  # Low addiction
    
    # Add noise to create realistic challenges
    for i in range(int(n_samples * 0.15)):  # 15% noise
        idx = np.random.randint(0, n_samples)
        noise_type = np.random.choice(['linear_noise', 'nonlinear_noise', 'interaction_noise'])
        
        if noise_type == 'linear_noise':
            # Add noise that affects linear relationships
            all_data['screen_time'][idx] += np.random.normal(2, 1)
            all_data['app_usage'][idx] += np.random.normal(1.5, 1)
        elif noise_type == 'nonlinear_noise':
            # Add noise that affects non-linear relationships
            all_data['stress_level'][idx] = np.clip(all_data['stress_level'][idx] + np.random.randint(-2, 3), 1, 7)
            all_data['anxiety_level'][idx] = np.clip(all_data['anxiety_level'][idx] + np.random.randint(-2, 3), 1, 7)
        else:  # interaction_noise
            # Add noise that affects interactions
            all_data['unlock_count'][idx] += np.random.normal(50, 25)
            all_data['weekend_usage'][idx] += np.random.normal(3, 2)
    
    # Create DataFrame
    df = pd.DataFrame(all_data)
    df['addiction_level'] = addiction_levels
    
    # Add realistic missing values
    for col in ['stress_level', 'anxiety_level', 'depression_level']:
        missing_idx = np.random.choice(df.index, size=int(len(df) * 0.02), replace=False)
        df.loc[missing_idx, col] = np.nan
    
    # Fill missing values
    df.fillna(df.mean(), inplace=True)
    
    # Ensure all values are positive and within realistic ranges
    for col in df.columns:
        if col != 'addiction_level' and col != 'gender' and col != 'education' and col != 'occupation_type':
            df[col] = np.maximum(df[col], 0)
    
    # Clip values to realistic ranges
    df['screen_time'] = np.clip(df['screen_time'], 0, 24)
    df['app_usage'] = np.clip(df['app_usage'], 0, 24)
    df['night_usage'] = np.clip(df['night_usage'], 0, 12)
    df['unlock_count'] = np.clip(df['unlock_count'], 0, 1000)
    df['notification_count'] = np.clip(df['notification_count'], 0, 2000)
    
    print(f"✅ Linear + Non-Linear dataset generated: {df.shape}")
    print(f"📊 Class distribution: {df['addiction_level'].value_counts().to_dict()}")
    
    return df

def save_linear_nonlinear_dataset():
    """Generate and save linear + non-linear dataset"""
    df = generate_linear_nonlinear_dataset()
    
    # Save to CSV
    df.to_csv('ml/dataset.csv', index=False)
    print("💾 Linear + Non-Linear dataset saved as 'ml/dataset.csv'")
    
    # Show statistics
    print("\n📈 Dataset Statistics:")
    print(f"  Total samples: {len(df)}")
    print(f"  Features: {len(df.columns) - 1}")  # -1 for target
    print(f"  Classes: {df['addiction_level'].nunique()}")
    print(f"  Missing values: {df.isnull().sum().sum()}")
    
    # Show feature correlations with target
    correlations = df.corr()['addiction_level'].sort_values(ascending=False)
    print("\n🔗 Top correlations with addiction_level:")
    for feature, corr in correlations.head(8).items():
        if feature != 'addiction_level':
            print(f"  {feature}: {corr:.3f}")
    
    # Show class distribution
    print("\n👥 Class Distribution:")
    class_dist = df['addiction_level'].value_counts().sort_index()
    for class_label, count in class_dist.items():
        percentage = (count / len(df)) * 100
        class_name = ['Low Addiction', 'Moderate Addiction', 'High Addiction'][class_label]
        print(f"  {class_name} (Class {class_label}): {count} users ({percentage:.1f}%)")
    
    # Show profile statistics
    print("\n📊 Profile Statistics:")
    print(f"  Linear-Heavy: {int(len(df) * 0.30)} users (30%)")
    print(f"  Non-Linear-Heavy: {int(len(df) * 0.30)} users (30%)")
    print(f"  Mixed-Patterns: {int(len(df) * 0.25)} users (25%)")
    print(f"  Ensemble-Optimal: {int(len(df) * 0.15)} users (15%)")

if __name__ == "__main__":
    save_linear_nonlinear_dataset()
