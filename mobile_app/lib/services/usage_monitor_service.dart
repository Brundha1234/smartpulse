// lib/services/usage_monitor_service.dart
//
// SmartPulse v2 — Background Usage Monitor
// ─────────────────────────────────────────────────────────────────────────────
// Runs a periodic timer (every 5 minutes) that:
//   1. Re-reads device usage from UsageStatsManager
//   2. Checks screen-time against the user's goal (80% and 100% alerts)
//   3. Detects continuous usage → fires break reminders every 45 min
//   4. Detects night use (10 PM–6 AM) → fires sleep alert
//   5. NEW: Monitors notification_count → fires alert when > threshold
//   6. NEW: Monitors unlock_count → fires alert when > threshold
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'usage_service.dart';
import '../models/usage_data.dart';

class UsageMonitorService {
  static Timer? _timer;
  static bool _limitAlertFired = false;
  static bool _approachAlertFired = false;
  static bool _nightAlertFired = false;
  static bool _highNotifAlertFired = false; // NEW
  static bool _highUnlockAlertFired = false; // NEW
  static int _continuousMinutes = 0;
  static double _lastScreenTime = 0;
  static String? _lastUsageDateKey;

  static const int _defaultGoalHours = 4;
  static const int _notifCountThreshold = 200; // warn at 200 notifications/day
  static const int _unlockCountThreshold = 80; // warn at 80 unlocks/day

  // ── Start / Stop ──────────────────────────────────────────────────────

  static Future<void> start() async {
    if (_timer != null && _timer!.isActive) return;
    debugPrint('[UsageMonitor] Starting background monitor...');
    resetDailyFlags();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _poll());
    debugPrint('[UsageMonitor] Started — polling every 5 minutes');
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _reset();
    debugPrint('[UsageMonitor] Stopped');
  }

  static void _reset() {
    _limitAlertFired = false;
    _approachAlertFired = false;
    _nightAlertFired = false;
    _highNotifAlertFired = false;
    _highUnlockAlertFired = false;
    _continuousMinutes = 0;
    _lastScreenTime = 0;
    _lastUsageDateKey = null;
  }

  static void resetDailyFlags() {
    _limitAlertFired = false;
    _approachAlertFired = false;
    _nightAlertFired = false;
    _highNotifAlertFired = false;
    _highUnlockAlertFired = false;
    _continuousMinutes = 0;
  }

  // ── Main poll ─────────────────────────────────────────────────────────

  static Future<void> _poll() async {
    final prefs = await SharedPreferences.getInstance();
    final goalHours =
        prefs.getDouble('screen_time_goal') ?? _defaultGoalHours.toDouble();
    final notifThreshold =
        prefs.getInt('notif_threshold') ?? _notifCountThreshold;
    final unlockThreshold =
        prefs.getInt('unlock_threshold') ?? _unlockCountThreshold;

    final now = DateTime.now();

    // Get real usage data
    UsageData usage;
    try {
      final usageStats = await UsageService.getUsageStatistics();
      final usageDate = _usageBucketDate(usageStats);
      final usageDateKey = _dateKeyFor(usageDate);

      if (_lastUsageDateKey != null && _lastUsageDateKey != usageDateKey) {
        resetDailyFlags();
        _lastScreenTime = 0;
      }
      _lastUsageDateKey = usageDateKey;

      usage = UsageData(
        date: usageDate,
        screenTime:
            ((usageStats['total_screen_time_minutes'] as num?)?.toDouble() ??
                    0.0) /
                60.0,
        appUsage: _calculateSocialAppHours(
          Map<String, double>.from(usageStats['app_breakdown'] ?? {}),
        ),
        nightUsage:
            ((usageStats['night_usage_minutes'] as num?)?.toDouble() ?? 0.0) /
                60.0,
        unlockCount: usageStats['total_unlocks'] as int? ?? 0,
        notificationCount: usageStats['total_notifications'] as int? ?? 0,
        appBreakdown:
            Map<String, double>.from(usageStats['app_breakdown'] ?? {}),
      );
    } catch (e) {
      debugPrint('[UsageMonitor] Failed to get usage data: $e');
      return; // Skip this poll if we can't get data
    }

    final double current = usage.screenTime;
    final double delta5min = current - _lastScreenTime;
    _lastScreenTime = current;

    debugPrint('[UsageMonitor] Screen: ${current.toStringAsFixed(2)}h  '
        'Unlocks: ${usage.unlockCount}  Notifs: ${usage.notificationCount}');

    // ── 1. Continuous-use tracking ────────────────────────────────────
    if (delta5min > 0.033) {
      _continuousMinutes += 5;
    } else {
      _continuousMinutes = 0;
    }

    if (_continuousMinutes > 0 && _continuousMinutes % 45 == 0) {
      await NotificationService.sendBreakReminder(
          minutesUsed: _continuousMinutes);
      debugPrint(
          '[UsageMonitor] Break reminder sent ($_continuousMinutes min)');
    }

    // ── 2. Screen-time goal checks ────────────────────────────────────
    final double ratio = current / goalHours;

    if (ratio >= 0.8 && !_approachAlertFired) {
      _approachAlertFired = true;
      await NotificationService.sendApproachingLimitWarning(
        currentHours: current,
        limitHours: goalHours,
      );
      debugPrint('[UsageMonitor] Approaching-limit alert sent');
    }

    if (ratio >= 1.0 && !_limitAlertFired) {
      _limitAlertFired = true;
      await NotificationService.sendLimitExceededAlert(
        currentHours: current,
        limitHours: goalHours,
      );
      debugPrint('[UsageMonitor] Limit-exceeded alert sent');
    }

    // Allow re-alert every full extra hour over limit
    if (ratio >= 1.0 && _limitAlertFired) {
      final hoursOver = current - goalHours;
      if (hoursOver > 0 && (hoursOver * 10).round() % 10 == 0) {
        _limitAlertFired = false;
      }
    }

    // Night-use detection (10 PM-6 AM)
    final hour = now.hour;
    if (((hour >= 22) || (hour < 6)) &&
        usage.nightUsage > 0.1 &&
        !_nightAlertFired) {
      _nightAlertFired = true;
      await NotificationService.sendNightUseAlert(nightHours: usage.nightUsage);
      debugPrint('[UsageMonitor] Night-use alert sent');
    }

    // ── 4. NEW: High notification count ──────────────────────────────
    if (usage.notificationCount >= notifThreshold && !_highNotifAlertFired) {
      _highNotifAlertFired = true;
      await NotificationService.sendHighNotificationAlert(
        count: usage.notificationCount,
        threshold: notifThreshold,
      );
      debugPrint(
          '[UsageMonitor] High-notification alert sent (${usage.notificationCount})');
    }

    // ── 5. NEW: High unlock count ─────────────────────────────────────
    if (usage.unlockCount >= unlockThreshold && !_highUnlockAlertFired) {
      _highUnlockAlertFired = true;
      await NotificationService.sendHighUnlockAlert(
        count: usage.unlockCount,
        threshold: unlockThreshold,
      );
      debugPrint(
          '[UsageMonitor] High-unlock alert sent (${usage.unlockCount})');
    }
  }

  // ── Goal / threshold setters ──────────────────────────────────────────

  static Future<void> setGoalHours(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('screen_time_goal', hours);
    _approachAlertFired = false;
    _limitAlertFired = false;
  }

  static Future<double> getGoalHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('screen_time_goal') ?? _defaultGoalHours.toDouble();
  }

  static Future<void> setNotifThreshold(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notif_threshold', count);
    _highNotifAlertFired = false;
  }

  static Future<void> setUnlockThreshold(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('unlock_threshold', count);
    _highUnlockAlertFired = false;
  }

  static double _calculateSocialAppHours(Map<String, double> appBreakdown) {
    final socialMinutes = appBreakdown.entries
        .where((entry) =>
            _isSocialApp(entry.key))
        .fold<double>(0.0, (sum, entry) => sum + entry.value);

    return socialMinutes / 60.0;
  }

  static bool _isSocialApp(String packageName) {
    final normalized = packageName.toLowerCase();
    const directPackages = {
      'com.whatsapp',
      'com.whatsapp.w4b',
      'com.instagram.android',
      'com.facebook.katana',
      'com.facebook.lite',
      'com.twitter.android',
      'com.snapchat.android',
      'com.linkedin.android',
      'com.tinder',
      'com.discord',
      'com.reddit.frontpage',
      'com.pinterest',
      'com.tiktok',
      'com.zhiliaoapp.musically',
      'com.ss.android.ugc.trill',
      'com.facebook.orca',
      'org.telegram.messenger',
      'org.thunderdog.challegram',
    };
    const fragments = [
      'social',
      'chat',
      'messenger',
      'telegram',
      'discord',
      'reddit',
      'snap',
      'insta',
      'facebook',
      'whatsapp',
      'twitter',
      'linkedin',
      'tiktok',
      'musical',
      'pinterest',
    ];

    return directPackages.contains(normalized) ||
        fragments.any(normalized.contains);
  }

  static DateTime _usageBucketDate(Map<String, dynamic> usageStats) {
    final sessionStart = DateTime.tryParse(
      usageStats['tracking_session_start']?.toString() ?? '',
    );
    final value = sessionStart ?? DateTime.now();
    return DateTime(value.year, value.month, value.day);
  }

  static String _dateKeyFor(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .toIso8601String()
        .split('T')
        .first;
  }
}
