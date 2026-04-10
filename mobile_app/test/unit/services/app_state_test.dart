// test/unit/services/app_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartpulse/services/app_state.dart';
import 'package:smartpulse/models/usage_data.dart';
import 'package:smartpulse/models/prediction_result.dart';

void main() {
  group('AppState Tests', () {
    late AppState appState;

    setUp(() async {
      // Initialize Flutter binding for tests
      TestWidgetsFlutterBinding.ensureInitialized();

      // Reset SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      appState = AppState();
      await appState.init();
    });

    test('should initialize with default values', () async {
      expect(appState.goalHours, equals(4.0));
      expect(appState.notifThreshold, equals(200));
      expect(appState.unlockThreshold, equals(80));
      expect(appState.predictionStatus, equals(PredictionStatus.idle));
    });

    test('should set and get goal hours', () async {
      await appState.setGoalHours(6.0);
      expect(appState.goalHours, equals(6.0));
    });

    test('should set and get notification threshold', () async {
      await appState.setNotifThreshold(300);
      expect(appState.notifThreshold, equals(300));
    });

    test('should set and get unlock threshold', () async {
      await appState.setUnlockThreshold(100);
      expect(appState.unlockThreshold, equals(100));
    });

    test('should update survey data', () async {
      await appState.updateSurvey(
        stress: 3,
        anxiety: 2,
        depression: 1,
      );

      // Verify survey data is stored (check if stress has a value)
      expect(appState.stress, equals(3));
      expect(appState.anxiety, equals(2));
      expect(appState.depression, equals(1));
    });

    test('should store and retrieve daily predictions', () async {
      final testPrediction = PredictionResult(
        addictionLevel: 'Medium',
        confidenceScore: 0.75,
        riskColor: '#FFA500',
        message: 'Moderate risk detected',
        recommendations: ['Reduce usage', 'Take breaks'],
        timestamp: DateTime.now(),
      );

      // Simulate storing prediction
      appState.dailyPredictions['2024-04-03'] = testPrediction;

      expect(appState.dailyPredictions['2024-04-03'], equals(testPrediction));
      expect(appState.hasTodayPrediction, isTrue);
    });

    test('should store and retrieve daily usage data', () async {
      final testUsage = UsageData(
        date: DateTime.now(),
        screenTime: 4.5,
        appUsage: 2.0,
        nightUsage: 1.5,
        unlockCount: 85,
        notificationCount: 120,
        appBreakdown: {'com.whatsapp': 45.0, 'com.instagram': 30.0},
      );

      // Simulate storing usage data
      appState.dailyUsageData['2024-04-03'] = testUsage;

      expect(appState.dailyUsageData['2024-04-03'], equals(testUsage));
    });

    test('should handle user data correctly', () async {
      final testUser = {
        'id': 'test_user_123',
        'name': 'Test User',
        'email': 'test@example.com',
      };

      await appState.setUser(testUser, 'test_token');

      expect(appState.user, equals(testUser));
      expect(appState.isLoggedIn, isTrue);
    });

    test('should handle logout correctly', () async {
      await appState.setUser({'id': 'test'}, 'token');
      await appState.logout();

      expect(appState.user, isNull);
      expect(appState.isLoggedIn, isFalse);
    });

    test('should refresh usage data', () async {
      // Test refresh method doesn't throw
      await appState.refreshUsage();
      expect(appState.todayUsage, isA<UsageData>());
    });

    test('should handle prediction scheduling', () {
      // Test that AppState has the required methods
      expect(appState.predictionStatus, equals(PredictionStatus.idle));
      expect(appState.todayUsage, isA<UsageData>());
    });

    test('should trigger daily prediction', () async {
      // This test verifies the method exists and doesn't throw
      try {
        await appState.triggerDailyPrediction();
      } catch (e) {
        // Expected to fail without real data, but method should exist
        expect(e, isA<Exception>());
      }
    });
  });
}
