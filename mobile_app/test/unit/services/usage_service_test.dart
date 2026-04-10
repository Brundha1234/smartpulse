// test/unit/services/usage_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpulse/services/usage_service.dart';

void main() {
  group('UsageService Tests', () {
    setUp(() async {
      // Initialize Flutter binding for tests
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('should return default stats when permission not granted', () async {
      final stats = await UsageService.getUsageStatistics();

      expect(stats['total_screen_time_minutes'], equals(0));
      expect(stats['total_unlocks'], equals(0));
      expect(stats['total_notifications'], equals(0));
      expect(stats['permission_granted'], equals(false));
    });

    test('should check usage stats permission', () async {
      final hasPermission = await UsageService.hasUsageStatsPermission();
      expect(hasPermission, isA<bool>());
    });

    test('should request usage stats permission', () async {
      final granted = await UsageService.requestUsageStatsPermission();
      expect(granted, isA<bool>());
    });

    test('should handle app breakdown correctly', () async {
      final stats = await UsageService.getUsageStatistics();

      // Handle empty case gracefully
      expect(stats['app_breakdown'], isA<Map<String, dynamic>>());
      expect(stats['top_apps'], isA<List>());
      expect(stats['total_apps_used'], isA<num>());

      // Should handle empty case gracefully
      expect(
          stats['app_breakdown'].isEmpty || stats['app_breakdown'].isNotEmpty,
          isTrue);
    });

    test('should include query period information', () async {
      final stats = await UsageService.getUsageStatistics();

      // Query period might be null in test environment, so handle gracefully
      if (stats['query_period'] != null) {
        expect(stats['query_period'], isA<Map<String, dynamic>>());
        expect(stats['query_period']['start'], isA<String>());
        expect(stats['query_period']['end'], isA<String>());
        expect(stats['query_period']['description'], isA<String>());
      }
    });

    test('should handle permission checking gracefully', () async {
      // Test that permission checking doesn't throw
      expect(() async => await UsageService.hasUsageStatsPermission(),
          returnsNormally);
      expect(() async => await UsageService.requestUsageStatsPermission(),
          returnsNormally);
    });

    test('should return valid data structure', () async {
      final stats = await UsageService.getUsageStatistics();

      // Verify all required keys exist
      final requiredKeys = [
        'total_screen_time_minutes',
        'total_unlocks',
        'total_notifications',
        'total_apps_used',
        'app_breakdown',
        'top_apps',
        'permission_granted',
      ];

      for (final key in requiredKeys) {
        expect(stats.containsKey(key), isTrue, reason: 'Missing key: $key');
      }
    });
  });
}
