import 'dart:async';
import 'package:flutter/services.dart';
import 'usage_service.dart';

class AutoSensingService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.smartpulse/usage');
  static const EventChannel _eventChannel =
      EventChannel('com.example.smartpulse/usage_stream');

  static final StreamController<Map<String, dynamic>> _realtimeController =
      StreamController<Map<String, dynamic>>.broadcast();

  static StreamSubscription? _nativeSubscription;
  static Map<String, dynamic>? _latestSnapshot;
  static bool _isTracking = false;
  static bool _initialized = false;
  static DateTime? _lastSnapshotAt;

  static Stream<Map<String, dynamic>> get realtimeDataStream =>
      _realtimeController.stream;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _listenToNativeStream();
    try {
      await _methodChannel.invokeMethod('initialize');
    } catch (_) {}

    final snapshot = await UsageService.getUsageStatistics();
    _publish(snapshot);
  }

  static Future<bool> startTracking() async {
    await initialize();

    try {
      await _methodChannel.invokeMethod('startTracking');
      _isTracking = true;
      final snapshot = await UsageService.getUsageStatistics();
      _publish(snapshot);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopTracking() async {
    try {
      await _methodChannel.invokeMethod('stopTracking');
    } catch (_) {}
    _isTracking = false;
  }

  static Future<bool> isTracking() async {
    if (_isTracking) return true;
    final snapshot = await UsageService.getUsageStatistics();
    _latestSnapshot = snapshot;
    _isTracking = snapshot['tracking_enabled'] == true;
    return _isTracking;
  }

  static Future<Map<String, dynamic>> getRealtimeUsageData() async {
    final snapshot = await UsageService.getUsageStatistics();
    _publish(snapshot);
    return snapshot;
  }

  static Future<Map<String, dynamic>> forceRefresh() async {
    final snapshot = await UsageService.getUsageStatistics();
    _publish(snapshot);
    return snapshot;
  }

  static Future<Map<String, dynamic>> getComprehensiveUsageStats() async {
    final snapshotAge = _lastSnapshotAt == null
        ? null
        : DateTime.now().difference(_lastSnapshotAt!);
    if (_latestSnapshot != null &&
        snapshotAge != null &&
        snapshotAge < const Duration(seconds: 2)) {
      return _latestSnapshot!;
    }
    return getRealtimeUsageData();
  }

  static Future<bool> hasNotificationListenerPermission() async {
    try {
      final granted =
          await _methodChannel.invokeMethod<bool>('hasNotificationPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestNotificationListenerPermission() async {
    try {
      await _methodChannel.invokeMethod('requestNotificationPermission');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openNotificationListenerSettings() async {
    await _methodChannel.invokeMethod('openNotificationListenerSettings');
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final ignored = await _methodChannel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return ignored ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openBatteryOptimizationSettings() async {
    await _methodChannel.invokeMethod('openBatteryOptimizationSettings');
  }

  static Future<void> resetDailyCounts() async {
    await _methodChannel.invokeMethod('resetCounters');
    final snapshot = await UsageService.getUsageStatistics();
    _publish(snapshot);
  }

  static Future<void> simulateUnlock() async {
    await _methodChannel.invokeMethod('simulateUnlock');
  }

  static Future<Map<String, dynamic>> getTodayUsageSummary() async {
    final snapshot = await getComprehensiveUsageStats();
    return {
      'date': DateTime.now().toIso8601String().split('T')[0],
      'screen_time_minutes': snapshot['total_screen_time_minutes'] ?? 0.0,
      'screen_time_hours':
          ((snapshot['total_screen_time_minutes'] as num?)?.toDouble() ?? 0.0) /
              60.0,
      'unlock_count': snapshot['total_unlocks'] ?? 0,
      'notification_count': snapshot['total_notifications'] ?? 0,
      'night_usage_minutes': snapshot['night_usage_minutes'] ?? 0.0,
      'top_apps': snapshot['top_apps'] ?? const [],
      'risk_level': snapshot['risk_level'] ?? 'Unknown',
      'auto_sensing_active': snapshot['tracking_enabled'] ?? false,
      'permission_granted': snapshot['permission_granted'] ?? false,
    };
  }

  static void _listenToNativeStream() {
    _nativeSubscription ??=
        _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      _publish(UsageService.normalizeSnapshot(event));
    }, onError: (_) {});
  }

  static void _publish(Map<String, dynamic> snapshot) {
    _latestSnapshot = snapshot;
    _lastSnapshotAt = DateTime.now();
    _isTracking = snapshot['tracking_enabled'] == true;
    _realtimeController.add(snapshot);
  }
}
