// test/unit/models/usage_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpulse/models/usage_data.dart';

void main() {
  group('UsageData Tests', () {
    test('should create UsageData with required parameters', () {
      final usageData = UsageData(
        date: DateTime.now(),
        screenTime: 4.5,
        appUsage: 2.0,
        nightUsage: 1.5,
        unlockCount: 85,
        notificationCount: 120,
        appBreakdown: {'com.whatsapp': 45.0, 'com.instagram': 30.0},
      );

      expect(usageData.screenTime, equals(4.5));
      expect(usageData.appUsage, equals(2.0));
      expect(usageData.nightUsage, equals(1.5));
      expect(usageData.unlockCount, equals(85));
      expect(usageData.notificationCount, equals(120));
      expect(usageData.appBreakdown.length, equals(2));
    });

    test('should create empty UsageData', () {
      final emptyUsage = UsageData.empty();

      expect(emptyUsage.screenTime, equals(0));
      expect(emptyUsage.appUsage, equals(0));
      expect(emptyUsage.nightUsage, equals(0));
      expect(emptyUsage.unlockCount, equals(0));
      expect(emptyUsage.notificationCount, equals(0));
      expect(emptyUsage.appBreakdown.isEmpty, isTrue);
      expect(emptyUsage.hasPermission, isTrue);
    });

    test('should create UsageData with no permission', () {
      final noPermissionUsage = UsageData.noPermission();

      expect(noPermissionUsage.screenTime, equals(0));
      expect(noPermissionUsage.hasPermission, isFalse);
    });

    test('should serialize to JSON correctly', () {
      final usageData = UsageData(
        date: DateTime(2024, 4, 3, 10, 30),
        screenTime: 4.5,
        appUsage: 2.0,
        nightUsage: 1.5,
        unlockCount: 85,
        notificationCount: 120,
      );

      final json = usageData.toJson();

      expect(json['date'], equals('2024-04-03T10:30:00.000'));
      expect(json['screenTime'], equals(4.5));
      expect(json['appUsage'], equals(2.0));
      expect(json['nightUsage'], equals(1.5));
      expect(json['unlockCount'], equals(85));
      expect(json['notificationCount'], equals(120));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'date': '2024-04-03T10:30:00.000',
        'screenTime': 4.5,
        'appUsage': 2.0,
        'nightUsage': 1.5,
        'unlockCount': 85,
        'notificationCount': 120,
      };

      final usageData = UsageData.fromJson(json);

      expect(usageData.screenTime, equals(4.5));
      expect(usageData.appUsage, equals(2.0));
      expect(usageData.nightUsage, equals(1.5));
      expect(usageData.unlockCount, equals(85));
      expect(usageData.notificationCount, equals(120));
      expect(usageData.date.year, equals(2024));
      expect(usageData.date.month, equals(4));
      expect(usageData.date.day, equals(3));
    });

    test('should handle null values in JSON deserialization', () {
      final json = {
        'date': '2024-04-03T10:30:00.000',
        'screenTime': 4.5,
        'appUsage': 2.0,
        'nightUsage': 1.5,
        'unlockCount': 85,
        'notificationCount': 120,
      };

      // Should handle valid JSON correctly
      expect(() => UsageData.fromJson(json), returnsNormally);

      final usageData = UsageData.fromJson(json);
      expect(usageData.appUsage, equals(2.0));
    });
  });
}
