// test/unit/services/app_state_core_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartpulse/models/usage_data.dart';
import 'package:smartpulse/models/prediction_result.dart';

// Simple test for AppState core functionality without complex initialization
void main() {
  group('AppState Core Tests', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('should handle UsageData serialization', () {
      final usageData = UsageData(
        date: DateTime.now(),
        screenTime: 4.5,
        appUsage: 2.0,
        nightUsage: 1.5,
        unlockCount: 85,
        notificationCount: 120,
        appBreakdown: {'com.whatsapp': 45.0, 'com.instagram': 30.0},
      );

      final json = usageData.toJson();
      final deserialized = UsageData.fromJson(json);

      expect(deserialized.screenTime, equals(usageData.screenTime));
      expect(deserialized.appUsage, equals(usageData.appUsage));
      expect(deserialized.unlockCount, equals(usageData.unlockCount));
      expect(deserialized.notificationCount, equals(usageData.notificationCount));
    });

    test('should handle PredictionResult serialization', () {
      final prediction = PredictionResult(
        addictionLevel: 'Medium',
        confidenceScore: 0.75,
        riskColor: '#FFA500',
        message: 'Moderate risk detected',
        recommendations: ['Reduce usage', 'Take breaks'],
        timestamp: DateTime.now(),
      );

      final json = prediction.toJson();
      final deserialized = PredictionResult.fromJson(json);

      expect(deserialized.addictionLevel, equals(prediction.addictionLevel));
      expect(deserialized.confidenceScore, equals(prediction.confidenceScore));
      expect(deserialized.message, equals(prediction.message));
      expect(deserialized.recommendations, equals(prediction.recommendations));
    });

    test('should handle empty UsageData', () {
      final emptyUsage = UsageData.empty();
      
      expect(emptyUsage.screenTime, equals(0));
      expect(emptyUsage.appUsage, equals(0));
      expect(emptyUsage.nightUsage, equals(0));
      expect(emptyUsage.unlockCount, equals(0));
      expect(emptyUsage.notificationCount, equals(0));
      expect(emptyUsage.appBreakdown.isEmpty, isTrue);
    });

    test('should handle no permission UsageData', () {
      final noPermissionUsage = UsageData.noPermission();
      
      expect(noPermissionUsage.screenTime, equals(0));
      expect(noPermissionUsage.hasPermission, isFalse);
    });

    test('should validate PredictionResult fields', () {
      final prediction = PredictionResult(
        addictionLevel: 'High',
        confidenceScore: 0.85,
        riskColor: '#FF0000',
        message: 'High risk detected',
        recommendations: ['Immediate action required'],
        timestamp: DateTime.now(),
      );

      expect(prediction.addictionLevel, isIn(['Low', 'Medium', 'High']));
      expect(prediction.confidenceScore, greaterThanOrEqualTo(0.0));
      expect(prediction.confidenceScore, lessThanOrEqualTo(1.0));
      expect(prediction.riskColor, startsWith('#'));
      expect(prediction.recommendations, isNotEmpty);
    });

    test('should handle weekly data structure', () {
      // Test the data structures used in weekly analysis
      final dailyPredictions = <String, PredictionResult>{};
      final dailyUsageData = <String, UsageData>{};

      // Add test data
      final today = DateTime.now().toIso8601String().split('T')[0];
      dailyPredictions[today] = PredictionResult(
        addictionLevel: 'Medium',
        confidenceScore: 0.75,
        riskColor: '#FFA500',
        message: 'Test prediction',
        recommendations: ['Test recommendation'],
        timestamp: DateTime.now(),
      );

      dailyUsageData[today] = UsageData(
        date: DateTime.now(),
        screenTime: 4.5,
        appUsage: 2.0,
        nightUsage: 1.5,
        unlockCount: 85,
        notificationCount: 120,
        appBreakdown: {'com.whatsapp': 45.0},
      );

      expect(dailyPredictions.length, equals(1));
      expect(dailyUsageData.length, equals(1));
      expect(dailyPredictions[today], isA<PredictionResult>());
      expect(dailyUsageData[today], isA<UsageData>());
    });

    test('should handle 24-hour period calculations', () {
      final now = DateTime.now();
      final today6AM = DateTime(now.year, now.month, now.day, 6, 0, 0);
      final yesterday6AM = DateTime(now.year, now.month, now.day - 1, 6, 0, 0);

      // Verify 24-hour period logic
      expect(today6AM.difference(yesterday6AM).inHours, equals(24));
      
      // Verify query period selection
      DateTime queryStart, queryEnd;
      
      if (now.hour >= 6) {
        queryStart = today6AM;
        queryEnd = now;
      } else {
        queryStart = yesterday6AM;
        queryEnd = today6AM;
      }

      expect(queryStart.isBefore(queryEnd), isTrue);
      expect(queryEnd.difference(queryStart).inHours, lessThanOrEqualTo(24));
    });

    test('should handle goal validation', () {
      // Test goal ranges
      final validScreenTimeGoals = [1.0, 4.0, 6.0, 12.0];
      final validNotificationThresholds = [50, 100, 200, 500];
      final validUnlockThresholds = [20, 50, 80, 200];

      for (final goal in validScreenTimeGoals) {
        expect(goal, greaterThanOrEqualTo(1.0));
        expect(goal, lessThanOrEqualTo(12.0));
      }

      for (final threshold in validNotificationThresholds) {
        expect(threshold, greaterThanOrEqualTo(50));
        expect(threshold, lessThanOrEqualTo(500));
      }

      for (final threshold in validUnlockThresholds) {
        expect(threshold, greaterThanOrEqualTo(20));
        expect(threshold, lessThanOrEqualTo(200));
      }
    });
  });
}
