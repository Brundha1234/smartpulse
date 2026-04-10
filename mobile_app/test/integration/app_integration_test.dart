// test/integration/app_integration_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartpulse/services/app_state.dart';
import 'package:smartpulse/services/usage_service.dart';
import 'package:smartpulse/models/usage_data.dart';
import 'package:smartpulse/models/prediction_result.dart';

void main() {
  group('App Integration Tests', () {
    late AppState appState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      appState = AppState();
    });

    testWidgets('should initialize complete app state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => appState,
          child: const MaterialApp(
            home: Scaffold(),
          ),
        ),
      );

      await appState.init();
      await tester.pump();

      expect(appState.goalHours, equals(4.0));
      expect(appState.notifThreshold, equals(200));
      expect(appState.unlockThreshold, equals(80));
      expect(appState.predictionStatus, equals(PredictionStatus.idle));
    });

    test('should handle complete user workflow', () async {
      // 1. Initialize app
      await appState.init();
      expect(appState.isLoggedIn, isFalse);

      // 2. User login
      final testUser = {
        'id': 'test_user_123',
        'name': 'Test User',
        'email': 'test@example.com',
      };
      await appState.setUser(testUser, 'test_token');
      expect(appState.isLoggedIn, isTrue);
      expect(appState.user, equals(testUser));

      // 3. Complete survey
      await appState.updateSurvey(stress: 3, anxiety: 2, depression: 1);
      expect(appState.stress, equals(3));
      expect(appState.anxiety, equals(2));
      expect(appState.depression, equals(1));

      // 4. Set daily goals
      await appState.setGoalHours(5.0);
      await appState.setNotifThreshold(250);
      await appState.setUnlockThreshold(90);

      expect(appState.goalHours, equals(5.0));
      expect(appState.notifThreshold, equals(250));
      expect(appState.unlockThreshold, equals(90));

      // 5. Simulate usage data
      final testUsage = UsageData(
        date: DateTime.now(),
        screenTime: 4.5,
        appUsage: 2.0,
        nightUsage: 1.5,
        unlockCount: 85,
        notificationCount: 120,
        appBreakdown: {'com.whatsapp': 45.0, 'com.instagram': 30.0},
      );

      // Store usage data
      appState.dailyUsageData['2024-04-03'] = testUsage;
      expect(appState.dailyUsageData['2024-04-03'], equals(testUsage));

      // 6. Store prediction result
      final testPrediction = PredictionResult(
        addictionLevel: 'Medium',
        confidenceScore: 0.75,
        riskColor: '#FFA500',
        message: 'Moderate risk detected',
        recommendations: ['Reduce usage', 'Take breaks'],
        timestamp: DateTime.now(),
      );

      appState.dailyPredictions['2024-04-03'] = testPrediction;
      expect(appState.dailyPredictions['2024-04-03'], equals(testPrediction));
      expect(appState.hasTodayPrediction, isTrue);

      // 7. Logout
      await appState.logout();
      expect(appState.isLoggedIn, isFalse);
      expect(appState.user, isNull);
    });

    test('should handle data persistence across app restarts', () async {
      // 1. Set initial data
      await appState.setGoalHours(6.0);
      await appState.setNotifThreshold(300);
      await appState.setUnlockThreshold(100);
      await appState.updateSurvey(stress: 4, anxiety: 3, depression: 2);

      // 2. Create new app state instance (simulate app restart)
      final newAppState = AppState();
      await newAppState.init();

      // 3. Verify data persistence
      expect(newAppState.goalHours, equals(6.0));
      expect(newAppState.notifThreshold, equals(300));
      expect(newAppState.unlockThreshold, equals(100));
      expect(newAppState.stress, equals(4));
      expect(newAppState.anxiety, equals(3));
      expect(newAppState.depression, equals(2));
    });

    test('should handle usage data integration', () async {
      // 1. Initialize usage tracking
      await appState.init();
      await appState.refreshUsage();

      // 2. Get usage statistics
      final stats = await UsageService.getUsageStatistics();

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('total_screen_time_minutes'), isTrue);
      expect(stats.containsKey('total_unlocks'), isTrue);
      expect(stats.containsKey('total_notifications'), isTrue);
      expect(stats.containsKey('app_breakdown'), isTrue);
      expect(stats.containsKey('top_apps'), isTrue);
      expect(stats.containsKey('query_period'), isTrue);

      // 3. Verify query period structure
      final queryPeriod = stats['query_period'] as Map<String, String>;
      expect(queryPeriod.containsKey('start'), isTrue);
      expect(queryPeriod.containsKey('end'), isTrue);
      expect(queryPeriod.containsKey('description'), isTrue);
    });

    test('should handle prediction workflow integration', () async {
      // 1. Complete survey
      await appState.updateSurvey(stress: 3, anxiety: 2, depression: 1);

      // 2. Set up usage data (use public getter)
      await appState.refreshUsage();

      // 3. Trigger prediction (will fail without real API, but should not crash)
      try {
        await appState.triggerDailyPrediction();
      } catch (e) {
        // Expected to fail without real backend
        expect(e, isA<Exception>());
      }

      // 4. Verify prediction status handling
      expect(appState.predictionStatus, equals(PredictionStatus.error));
    });

    test('should handle weekly data analysis', () async {
      // 1. Create week's worth of data
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];

        final usage = UsageData(
          date: date,
          screenTime: 3.0 + (i * 0.5),
          appUsage: 1.5 + (i * 0.25),
          nightUsage: 0.5 + (i * 0.1),
          unlockCount: 50 + (i * 10),
          notificationCount: 80 + (i * 15),
          appBreakdown: {'com.whatsapp': 20.0 + (i * 2)},
        );

        final prediction = PredictionResult(
          addictionLevel: i % 3 == 0
              ? 'Low'
              : i % 3 == 1
                  ? 'Medium'
                  : 'High',
          confidenceScore: 0.3 + (i * 0.1),
          riskColor: '#FFA500',
          message: 'Test prediction',
          recommendations: ['Test recommendation'],
          timestamp: date,
        );

        appState.dailyUsageData[dateStr] = usage;
        appState.dailyPredictions[dateStr] = prediction;
      }

      // 2. Verify data storage
      expect(appState.dailyUsageData.length, equals(7));
      expect(appState.dailyPredictions.length, equals(7));

      // 3. Verify data integrity
      for (final entry in appState.dailyUsageData.entries) {
        expect(entry.value, isA<UsageData>());
        expect(entry.value.screenTime, greaterThan(0));
      }

      for (final entry in appState.dailyPredictions.entries) {
        expect(entry.value, isA<PredictionResult>());
        expect(['Low', 'Medium', 'High'], contains(entry.value.addictionLevel));
      }
    });
  });
}
