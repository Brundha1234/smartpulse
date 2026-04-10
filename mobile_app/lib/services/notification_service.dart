// lib/services/notification_service.dart
//
// SmartPulse v2 — Notification Service
// ─────────────────────────────────────────────────────────────────────────────
// Handles ALL push/local notifications:
//   • Usage-limit exceeded alert      (fires when screen time > user goal)
//   • Approaching-limit warning       (fires at 80% of goal)
//   • Night-use alert                 (fires if phone used after midnight)
//   • Break reminder                  (fires every 45 min of continuous use)
//   • High notification-count alert   (fires when daily notifications > threshold)
//   • High unlock-count alert         (fires when unlocks exceed threshold)
//   • High-risk addiction alert       (fires after ML prediction = High)
//   • Scheduled daily check-in        (evening nudge to run the survey)
//   • Morning usage summary           (9 AM daily report)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── Notification IDs ──────────────────────────────────────────────────
  static const int _idUsageLimit = 1;
  static const int _idApproachLimit = 2;
  static const int _idNightUse = 3;
  static const int _idBreakReminder = 4;
  static const int _idHighRisk = 5;
  static const int _idDailyCheckin = 6;
  static const int _idMorningReport = 7;
  static const int _idHighNotifs = 8;
  static const int _idHighUnlocks = 9;

  // ── Thresholds ────────────────────────────────────────────────────────
  static const int notificationCountWarningThreshold = 200; // per day
  static const int unlockCountWarningThreshold = 80; // per day

  // ── Android Notification Channels ─────────────────────────────────────

  static const _urgentChannel = AndroidNotificationDetails(
    'usage_alerts',
    'Usage Alerts',
    channelDescription: 'Fired when screen time exceeds your daily limit',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    playSound: true,
    enableVibration: true,
    color: Color(0xFFEF4444),
  );

  static const _warningChannel = AndroidNotificationDetails(
    'usage_warnings',
    'Usage Warnings',
    channelDescription:
        'Fired when approaching the screen-time limit or night use detected',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    color: Color(0xFFF59E0B),
  );

  static const _reminderChannel = AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Break reminders and daily check-in nudges',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: '@mipmap/ic_launcher',
  );

  static const _infoChannel = AndroidNotificationDetails(
    'info_alerts',
    'Info Alerts',
    channelDescription:
        'Informational alerts about unlock and notification counts',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: '@mipmap/ic_launcher',
    color: Color(0xFF3B82F6),
  );

  // ── Initialise ────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );
    _initialized = true;
  }

  static Future<void> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.requestNotificationsPermission();
    debugPrint('Notification permission granted: $granted');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════

  /// Screen time limit exceeded
  static Future<void> sendLimitExceededAlert({
    required double currentHours,
    required double limitHours,
  }) async {
    final current = currentHours.toStringAsFixed(1);
    final limit = limitHours.toStringAsFixed(0);
    await _plugin.show(
      _idUsageLimit,
      '🚫 Screen Time Limit Reached!',
      'You\'ve used your phone for ${current}h today — your goal was ${limit}h. '
          'Put it down and take a real break.',
      const NotificationDetails(android: _urgentChannel),
    );
  }

  /// 80% of screen time goal
  static Future<void> sendApproachingLimitWarning({
    required double currentHours,
    required double limitHours,
  }) async {
    final remaining = (limitHours - currentHours).toStringAsFixed(1);
    await _plugin.show(
      _idApproachLimit,
      '⚠️ Approaching Screen Time Limit',
      'Only ${remaining}h left of your ${limitHours.toStringAsFixed(0)}h daily goal. '
          'Consider wrapping up soon.',
      const NotificationDetails(android: _warningChannel),
    );
  }

  /// Night-time phone use (00:00–06:00)
  static Future<void> sendNightUseAlert({double nightHours = 0}) async {
    final detail = nightHours > 0
        ? 'You\'ve used your phone for ${nightHours.toStringAsFixed(1)}h during sleep hours. '
        : '';
    await _plugin.show(
      _idNightUse,
      '🌙 Late Night Phone Use Detected',
      '${detail}Using your phone now disrupts sleep and increases addiction risk. '
          'Put it aside and rest.',
      const NotificationDetails(android: _warningChannel),
    );
  }

  /// Break reminder after continuous usage
  static Future<void> sendBreakReminder({int minutesUsed = 45}) async {
    await _plugin.show(
      _idBreakReminder,
      '☕ Time for a Break — ${minutesUsed}min Screen Time',
      'You\'ve been on your phone continuously for $minutesUsed minutes. '
          'Stand up, stretch, look 20 feet away for 20 seconds.',
      const NotificationDetails(android: _reminderChannel),
    );
  }

  /// High addiction risk from ML prediction
  static Future<void> sendHighRiskAlert({double? confidence}) async {
    final pct = confidence != null
        ? ' (${(confidence * 100).toStringAsFixed(0)}% confidence)'
        : '';
    await _plugin.show(
      _idHighRisk,
      '🚨 High Addiction Risk Detected$pct',
      'SmartPulse flagged your usage patterns as high risk. '
          'Open the app for personalised recommendations.',
      const NotificationDetails(android: _urgentChannel),
    );
  }

  /// Too many notifications received today
  static Future<void> sendHighNotificationAlert({
    required int count,
    int threshold = notificationCountWarningThreshold,
  }) async {
    await _plugin.show(
      _idHighNotifs,
      '🔔 High Notification Count — $count Today',
      'You\'ve received $count notifications today (threshold: $threshold). '
          'Consider silencing non-essential apps to reduce distraction.',
      const NotificationDetails(android: _infoChannel),
    );
  }

  /// Too many unlocks today
  static Future<void> sendHighUnlockAlert({
    required int count,
    int threshold = unlockCountWarningThreshold,
  }) async {
    await _plugin.show(
      _idHighUnlocks,
      '📱 Frequent Phone Unlocks — $count Times Today',
      'You\'ve unlocked your phone $count times today (threshold: $threshold). '
          'Try using app timers to reduce compulsive checking.',
      const NotificationDetails(android: _infoChannel),
    );
  }

  /// Schedule daily evening check-in reminder
  static Future<void> scheduleDailyCheckin({int hour = 20}) async {
    await _plugin.cancel(_idDailyCheckin);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      _idDailyCheckin,
      '📊 Daily SmartPulse Check-In',
      'Take 30 seconds to complete your daily wellness survey and see your addiction score.',
      scheduled,
      const NotificationDetails(android: _reminderChannel),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedule morning usage summary at 9 AM
  static Future<void> scheduleMorningSummary() async {
    await _plugin.cancel(_idMorningReport);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      _idMorningReport,
      '🌅 Good Morning! Yesterday\'s Summary',
      'Tap to see your screen time stats and today\'s addiction risk score.',
      scheduled,
      const NotificationDetails(android: _reminderChannel),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
  static Future<void> cancel(int id) => _plugin.cancel(id);
}
