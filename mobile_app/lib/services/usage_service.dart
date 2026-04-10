import 'package:flutter/services.dart';

class UsageService {
  static const MethodChannel _channel =
      MethodChannel('com.example.smartpulse/usage');

  static Future<bool> hasUsageStatsPermission() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('checkUsageAccessPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestUsageStatsPermission() async {
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openUsageAccessSettings() async {
    await _channel.invokeMethod('openUsageAccessSettings');
  }

  static Future<int> getAppLastUpdateTime() async {
    try {
      final value = await _channel.invokeMethod('getAppLastUpdateTime');
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
    } catch (_) {}
    return 0;
  }

  static Future<Map<String, dynamic>> getUsageStatistics() async {
    try {
      final data = await _channel.invokeMethod('getCurrentUsageSnapshot');
      return normalizeSnapshot(data);
    } catch (_) {}

    return _emptySnapshot();
  }

  static Future<Map<String, dynamic>?> testUsageStatsDirect() async {
    try {
      final result = await _channel.invokeMethod('testUsageStatsDirect');
      return _deepStringMap(result);
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic> normalizeSnapshot(dynamic data) {
    final map = _deepStringMap(data);
    if (map == null) {
      return _emptySnapshot();
    }
    return _normalize(map);
  }

  static Map<String, dynamic> _normalize(Map<dynamic, dynamic> data) {
    final topAppsRaw = _deepList(data['top_apps']);
    final queryPeriod = _deepStringMap(data['query_period']) ?? {};
    final notificationBreakdown =
        _deepStringMap(data['notification_breakdown']) ?? {};
    final appBreakdownRaw = _deepStringMap(data['app_breakdown']) ?? {};

    return {
      'status': data['status'] ?? 'unknown',
      'fallback_message': data['fallback_message'] ?? '',
      'service_running': data['service_running'] ?? false,
      'tracking_enabled': data['tracking_enabled'] ?? false,
      'tracking_session_start': data['tracking_session_start'],
      'tracking_session_end': data['tracking_session_end'],
      'tracking_session_complete': data['tracking_session_complete'] ?? false,
      'tracking_session_remaining_ms':
          (data['tracking_session_remaining_ms'] as num?)?.toInt() ?? 0,
      'usage_access_granted': data['usage_access_granted'] ?? false,
      'notification_permission_granted':
          data['notification_permission_granted'] ?? false,
      'permission_granted': data['permission_granted'] ?? false,
      'battery_optimization_ignored':
          data['battery_optimization_ignored'] ?? false,
      'screen_time_minutes':
          (data['screen_time_minutes'] as num?)?.toDouble() ?? 0.0,
      'total_screen_time_minutes':
          (data['total_screen_time_minutes'] as num?)?.toDouble() ?? 0.0,
      'unlock_count': data['unlock_count'] ?? 0,
      'total_unlocks': data['total_unlocks'] ?? 0,
      'notification_count': data['notification_count'] ?? 0,
      'total_notifications': data['total_notifications'] ?? 0,
      'notification_breakdown': notificationBreakdown.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      'total_apps_used': (data['total_apps_used'] as num?)?.toDouble() ?? 0.0,
      'daily_average_screen_time_minutes':
          (data['total_screen_time_minutes'] as num?)?.toDouble() ?? 0.0,
      'risk_level': _mapStatusToRisk(data['status']?.toString()),
      'app_breakdown': appBreakdownRaw.map(
        (key, value) =>
            MapEntry(key.toString(), (value as num?)?.toDouble() ?? 0.0),
      ),
      'top_apps': List<Map<String, dynamic>>.from(
        topAppsRaw.map(
          (item) {
            final map = _deepStringMap(item) ?? <String, dynamic>{};
            map['open_count'] ??= 0;
            return map;
          },
        ),
      ),
      'night_usage_minutes':
          (data['night_usage_minutes'] as num?)?.toDouble() ?? 0.0,
      'peak_hour': data['peak_hour'] ?? DateTime.now().hour,
      'is_weekend': data['is_weekend'] ?? false,
      'query_period': queryPeriod,
      'data_quality': data['data_quality'] ?? 'unknown',
      'last_updated': data['last_updated'] ?? DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic>? _deepStringMap(dynamic value) {
    if (value is! Map) {
      return null;
    }
    return value.map<String, dynamic>(
      (key, dynamic nestedValue) =>
          MapEntry(key.toString(), _deepConvert(nestedValue)),
    );
  }

  static List<dynamic> _deepList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value.map(_deepConvert).toList();
  }

  static dynamic _deepConvert(dynamic value) {
    if (value is Map) {
      return value.map<String, dynamic>(
        (key, dynamic nestedValue) =>
            MapEntry(key.toString(), _deepConvert(nestedValue)),
      );
    }
    if (value is List) {
      return value.map(_deepConvert).toList();
    }
    return value;
  }

  static Map<String, dynamic> _emptySnapshot() {
    return {
      'status': 'unavailable',
      'fallback_message': 'SmartPulse could not read device usage right now.',
      'service_running': false,
      'tracking_enabled': false,
      'tracking_session_start': null,
      'tracking_session_end': null,
      'tracking_session_complete': false,
      'tracking_session_remaining_ms': 0,
      'usage_access_granted': false,
      'notification_permission_granted': false,
      'permission_granted': false,
      'battery_optimization_ignored': false,
      'screen_time_minutes': 0.0,
      'total_screen_time_minutes': 0.0,
      'unlock_count': 0,
      'total_unlocks': 0,
      'notification_count': 0,
      'total_notifications': 0,
      'notification_breakdown': <String, dynamic>{},
      'total_apps_used': 0.0,
      'daily_average_screen_time_minutes': 0.0,
      'risk_level': 'Unknown',
      'app_breakdown': <String, double>{},
      'top_apps': <Map<String, dynamic>>[],
      'night_usage_minutes': 0.0,
      'peak_hour': DateTime.now().hour,
      'is_weekend': false,
      'query_period': <String, dynamic>{},
      'data_quality': 'unavailable',
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  static String _mapStatusToRisk(String? status) {
    switch (status) {
      case 'ok':
        return 'Low Risk';
      case 'empty_data':
        return 'Unknown';
      case 'permission_required':
        return 'Unknown';
      default:
        return 'Unknown';
    }
  }
}
