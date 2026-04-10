// lib/screens/survey_screen.dart
//
// SmartPulse v2 — Psychological Survey Screen
// Users only provide stress, anxiety, depression (1–5).
// All other features are auto-sensed from device.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});
  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  int _stress = 3;
  int _anxiety = 3;
  int _depression = 3;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _stress = state.stress;
    _anxiety = state.anxiety;
    _depression = state.depression;

    // Initialize usage data when survey screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.refreshUsage();
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final state = context.read<AppState>();

    // Refresh usage data before submission
    await state.refreshUsage();

    await state.updateSurvey(
      stress: _stress,
      anxiety: _anxiety,
      depression: _depression,
    );

    // Also store mental health scores with keys that PredictionService expects
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('stress_level', _stress);
    await prefs.setInt('anxiety_level', _anxiety);
    await prefs.setInt('depression_level', _depression);

    // Trigger prediction immediately after survey submission using current data
    if (mounted) {
      await state.triggerPredictionFromCurrentData(context: context);
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = true; // Mark as submitted
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Survey saved and prediction generated!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Psychological Assessment',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: const BackButton(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Column(children: [
              Icon(
                Icons.psychology,
                size: 48,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'On a scale of 1-5, how much do you agree with these statements?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Rate your current emotional state (1-5)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ]),
          ),

          const SizedBox(height: 30),

          const SizedBox(height: 24),
          const Text('How are you feeling today?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Rate each item from 1 (low) to 5 (high)',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textDim : Colors.grey.shade600,
              )),
          const SizedBox(height: 24),

          _surveySlider(
            label: 'Stress Level',
            emoji: '😤',
            value: _stress,
            lowLabel: 'Relaxed',
            hiLabel: 'Very stressed',
            onChanged: (v) => setState(() => _stress = v),
          ),
          const SizedBox(height: 20),
          _surveySlider(
            label: 'Anxiety Level',
            emoji: '😰',
            value: _anxiety,
            lowLabel: 'Calm',
            hiLabel: 'Very anxious',
            onChanged: (v) => setState(() => _anxiety = v),
          ),
          const SizedBox(height: 20),
          _surveySlider(
            label: 'Depression Level',
            emoji: '😔',
            value: _depression,
            lowLabel: 'Happy',
            hiLabel: 'Very low',
            onChanged: (v) => setState(() => _depression = v),
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.psychology),
              label: Text(_submitting
                  ? 'Submitting...'
                  : _submitted
                      ? 'Saved for Analysis ✓'
                      : 'Submit Survey for Analysis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _submitted
                    ? Colors.green
                    : (_submitting ? Colors.grey : AppColors.primary),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _surveySlider({
    required String label,
    required String emoji,
    required int value,
    required String lowLabel,
    required String hiLabel,
    required ValueChanged<int> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
      ),
      child: Column(children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$value / 5',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ]),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: AppColors.primary,
          onChanged: (v) => onChanged(v.toInt()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lowLabel,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(hiLabel,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ]),
    );
  }
}
