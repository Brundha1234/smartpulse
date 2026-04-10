// lib/models/usage_data.dart
// SmartPulse v2 — Auto-sensed device usage model

class UsageData {
  final DateTime date;
  final double screenTime; // total foreground hours (non-system apps)
  final double appUsage; // social/entertainment app hours
final double nightUsage; // 22:00–06:00 hours
  final int unlockCount; // device unlock / session count
  final int notificationCount; // notifications received today
  final Map<String, double> appBreakdown;
  final bool hasPermission;

  const UsageData({
    required this.date,
    required this.screenTime,
    required this.appUsage,
    required this.nightUsage,
    required this.unlockCount,
    required this.notificationCount,
    this.appBreakdown = const {},
    this.hasPermission = true,
  });

  factory UsageData.empty([DateTime? date]) => UsageData(
        date: date ?? DateTime.now(),
        screenTime: 0,
        appUsage: 0,
        nightUsage: 0,
        unlockCount: 0,
        notificationCount: 0,
        hasPermission: true,
      );

  factory UsageData.noPermission() => UsageData(
        date: DateTime.now(),
        screenTime: 0,
        appUsage: 0,
        nightUsage: 0,
        unlockCount: 0,
        notificationCount: 0,
        hasPermission: false,
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'screenTime': screenTime,
        'appUsage': appUsage,
        'nightUsage': nightUsage,
        'unlockCount': unlockCount,
        'notificationCount': notificationCount,
        'appBreakdown': appBreakdown,
        'hasPermission': hasPermission,
      };

  factory UsageData.fromJson(Map<String, dynamic> json) => UsageData(
        date: DateTime.parse(json['date']),
        screenTime: (json['screenTime'] as num).toDouble(),
        appUsage: (json['appUsage'] as num).toDouble(),
        nightUsage: (json['nightUsage'] as num).toDouble(),
        unlockCount: json['unlockCount'] as int,
        notificationCount: json['notificationCount'] as int,
        appBreakdown: (json['appBreakdown'] as Map?)?.map<String, double>(
              (key, value) =>
                  MapEntry(key.toString(), (value as num?)?.toDouble() ?? 0.0),
            ) ??
            const {},
        hasPermission: json['hasPermission'] as bool? ?? true,
      );
}
