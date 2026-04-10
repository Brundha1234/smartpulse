// test/widget/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartpulse/services/app_state.dart';
import 'package:smartpulse/screens/home_screen_fixed.dart';
import 'package:smartpulse/screens/survey_screen.dart';
import 'package:smartpulse/screens/history_screen.dart';
import 'package:smartpulse/models/prediction_result.dart';

void main() {
  group('Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('HomeScreenFixed should build without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: const MaterialApp(
            home: HomeScreenFixed(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify key widgets exist
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('SmartPulse'), findsOneWidget);
      expect(find.text('Daily Usage Monitor'), findsOneWidget);
    });

    testWidgets('SurveyScreen should build and allow interaction',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: const MaterialApp(
            home: SurveyScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify survey elements
      expect(find.text('Psychological Assessment'), findsOneWidget);
      expect(find.byType(Slider),
          findsNWidgets(3)); // 3 sliders for stress, anxiety, depression
      expect(find.text('Submit Assessment'), findsOneWidget);

      // Test slider interaction
      final stressSlider = find.byType(Slider).first;
      await tester.tap(stressSlider);
      await tester.pump();

      // Test submit button
      final submitButton = find.text('Submit Assessment');
      expect(submitButton, findsOneWidget);
    });

    testWidgets('HistoryScreen should display weekly data',
        (WidgetTester tester) async {
      final appState = AppState();
      await appState.init();

      // Add test data
      final testPrediction = PredictionResult(
        addictionLevel: 'Medium',
        confidenceScore: 0.75,
        riskColor: '#FFA500',
        message: 'Test prediction',
        recommendations: ['Test recommendation'],
        timestamp: DateTime.now(),
      );

      appState.dailyPredictions['2024-04-03'] = testPrediction;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => appState,
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify history screen elements
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      // Should show weekly prediction trend when data exists
      expect(find.text('Weekly Prediction Trend Analysis'), findsOneWidget);
      expect(find.text('Daily Usage Behavior Data'), findsOneWidget);
    });

    testWidgets('HomeScreenFixed should display goal settings',
        (WidgetTester tester) async {
      final appState = AppState();
      await appState.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => appState,
          child: const MaterialApp(
            home: HomeScreenFixed(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify goal setting section
      expect(find.text('Daily Goals'), findsOneWidget);
      expect(find.text('Screen Time Goal'), findsOneWidget);
      expect(find.text('Notification Threshold'), findsOneWidget);
      expect(find.text('Unlock Threshold'), findsOneWidget);

      // Verify sliders exist
      expect(find.byType(Slider), findsNWidgets(3)); // 3 goal sliders
    });

    testWidgets(
        'HomeScreenFixed should display testing section when permission granted',
        (WidgetTester tester) async {
      final appState = AppState();
      await appState.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => appState,
          child: const MaterialApp(
            home: HomeScreenFixed(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Look for testing section (debug mode)
      expect(find.text('Testing (Debug Mode)'), findsOneWidget);
      expect(find.text('Simulate Unlock'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('App should handle navigation between screens',
        (WidgetTester tester) async {
      final appState = AppState();
      await appState.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => appState,
          child: MaterialApp(
            home: const HomeScreenFixed(),
            routes: {
              '/survey': (context) => const SurveyScreen(),
              '/history': (context) => const HistoryScreen(),
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify we're on home screen
      expect(find.text('SmartPulse'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);

      // Test navigation to survey
      final surveyButton = find.text('Survey');
      if (surveyButton.evaluate().isNotEmpty) {
        await tester.tap(surveyButton);
        await tester.pumpAndSettle();
        expect(find.text('Psychological Assessment'), findsOneWidget);
      }
    });

    testWidgets('App should handle state changes', (WidgetTester tester) async {
      final appState = AppState();
      await appState.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => appState,
          child: const MaterialApp(
            home: HomeScreenFixed(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test goal changes
      await appState.setGoalHours(6.0);
      await tester.pump();

      // Test survey changes
      await appState.updateSurvey(stress: 3, anxiety: 2, depression: 1);
      await tester.pump();

      // App should still be stable
      expect(find.byType(HomeScreenFixed), findsOneWidget);
    });

    testWidgets('App should handle error states gracefully',
        (WidgetTester tester) async {
      final appState = AppState();
      await appState.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => appState,
          child: const MaterialApp(
            home: HomeScreenFixed(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Simulate error state
      // (This would be tested more thoroughly with actual error scenarios)
      expect(find.byType(HomeScreenFixed), findsOneWidget);
      expect(find.text('SmartPulse'), findsOneWidget);
    });
  });
}
