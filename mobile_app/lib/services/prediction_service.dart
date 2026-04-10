import 'package:shared_preferences/shared_preferences.dart';
import '../models/prediction_result.dart';
import 'api_service.dart';
import 'auto_sensing_service.dart';

class PredictionService {
  static Future<PredictionResult> generatePrediction({
    required double screenTimeHours,
    required double socialAppHours,
    required double nightUsageHours,
    required int unlockCount,
    required int notificationCount,
    required int stressLevel,
    required int anxietyLevel,
    required int depressionLevel,
  }) async {
    if (screenTimeHours <= 0 &&
        socialAppHours <= 0 &&
        nightUsageHours <= 0 &&
        unlockCount <= 0 &&
        notificationCount <= 0) {
      throw Exception(
          'Prediction requires real sensed device usage data. No realtime data is available yet.');
    }

    return ApiService.predict(
      screenTime: screenTimeHours,
      appUsage: socialAppHours * 60,
      nightUsage: nightUsageHours,
      unlockCount: unlockCount,
      notificationCount: notificationCount,
      appBreakdown: const {},
      stress: stressLevel,
      anxiety: anxietyLevel,
      depression: depressionLevel,
    );
  }

  static Future<PredictionResult> generatePredictionFromCurrentUsage() async {
    final usageData = await AutoSensingService.getComprehensiveUsageStats();

    final screenTimeMinutes =
        (usageData['total_screen_time_minutes'] as num?)?.toDouble() ?? 0.0;
    final screenTimeHours = screenTimeMinutes / 60.0;

    final appBreakdown =
        Map<String, double>.from(usageData['app_breakdown'] ?? {});
    final socialAppHours = appBreakdown.entries
            .where((entry) => _isSocialApp(entry.key))
            .fold(0.0, (sum, entry) => sum + entry.value) /
        60.0;

    final nightUsageMinutes =
        (usageData['night_usage_minutes'] as num?)?.toDouble() ?? 0.0;
    final nightUsageHours = nightUsageMinutes / 60.0;

    final unlockCount = usageData['total_unlocks'] ?? 0;
    final notificationCount = usageData['total_notifications'] ?? 0;
    final peakHour = usageData['peak_hour'] as int?;
    final isWeekend = usageData['is_weekend'] as bool?;

    if (screenTimeHours <= 0 &&
        socialAppHours <= 0 &&
        nightUsageHours <= 0 &&
        unlockCount <= 0 &&
        notificationCount <= 0) {
      throw Exception(
          'Prediction requires real sensed device usage data. Use the phone for a while and try again.');
    }

    final prefs = await SharedPreferences.getInstance();
    final stressLevel =
        prefs.getInt('survey_stress') ?? prefs.getInt('stress_level') ?? 3;
    final anxietyLevel =
        prefs.getInt('survey_anxiety') ?? prefs.getInt('anxiety_level') ?? 3;
    final depressionLevel =
        prefs.getInt('survey_depression') ?? prefs.getInt('depression_level') ?? 3;

    return ApiService.predict(
      screenTime: screenTimeHours,
      appUsage: socialAppHours * 60,
      nightUsage: nightUsageHours,
      unlockCount: unlockCount,
      notificationCount: notificationCount,
      appBreakdown: appBreakdown,
      peakHour: peakHour,
      isWeekend: isWeekend,
      stress: stressLevel,
      anxiety: anxietyLevel,
      depression: depressionLevel,
    );
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

  static String getRiskDescription(String addictionLevel) {
    switch (addictionLevel) {
      case 'High':
        return 'Immediate attention required. Your usage patterns show strong signs of digital addiction.';
      case 'Medium':
        return 'Caution advised. Your usage patterns suggest developing unhealthy digital habits.';
      case 'Low':
        return 'Healthy usage. Your digital habits appear balanced and controlled.';
      default:
        return 'Unknown risk level. Please complete assessment.';
    }
  }

  static List<String> getPersonalizedTips(
      String addictionLevel, Map<String, dynamic> usageData) {
    switch (addictionLevel) {
      case 'High':
        return [
          'Delete 1-2 social media apps today',
          'Set a 2-hour daily phone limit',
          'Use grayscale mode to reduce screen appeal',
          'Practice 20-20-20 rule: every 20 minutes, look 20 feet away for 20 seconds',
        ];
      case 'Medium':
        return [
          'Reduce screen time by 30% this week',
          'Turn off non-essential notifications',
          'Set app-specific time limits',
          'Create phone-free zones in your home',
        ];
      case 'Low':
        return [
          'Maintain your current healthy habits',
          'Help family members with their digital wellness',
          'Stay aware of potential addiction triggers',
          'Continue regular digital detox periods',
        ];
      default:
        return [];
    }
  }
}
