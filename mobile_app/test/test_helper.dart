// test/test_helper.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test helper utilities for SmartPulse v2 testing
class TestHelper {
  static Future<void> setUpTestEnvironment() async {
    // Initialize Flutter binding for tests
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Set up mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
  }

  static Map<String, dynamic> createMockUsageData() {
    return {
      'total_screen_time_minutes': 240.0, // 4 hours
      'total_unlocks': 85,
      'total_notifications': 120,
      'total_apps_used': 15.0,
      'app_breakdown': {
        'com.whatsapp': 45.0,
        'com.instagram': 30.0,
        'com.facebook': 25.0,
      },
      'top_apps': [
        {
          'name': 'WhatsApp',
          'package': 'com.whatsapp',
          'usage_time': 45,
          'icon': '📱',
        },
        {
          'name': 'Instagram',
          'package': 'com.instagram',
          'usage_time': 30,
          'icon': '📱',
        },
      ],
      'permission_granted': true,
      'query_period': {
        'start': '2024-04-03T06:00:00.000Z',
        'end': '2024-04-04T06:00:00.000Z',
        'description': 'Yesterday 6 AM to Today 6 AM (complete 24hr)',
      },
    };
  }

  static Map<String, dynamic> createMockPredictionResult() {
    return {
      'addiction_level': 'Medium',
      'confidence_score': 0.75,
      'risk_color': '#FFA500',
      'message': 'Moderate risk detected',
      'recommendations': ['Reduce usage', 'Take breaks'],
      'timestamp': '2024-04-03T06:00:00.000Z',
    };
  }

  static Map<String, dynamic> createMockUser() {
    return {
      'id': 'test_user_123',
      'name': 'Test User',
      'email': 'test@example.com',
      'gender': 'Other',
    };
  }
}
