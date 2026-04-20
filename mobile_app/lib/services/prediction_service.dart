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
    Map<String, double> appBreakdown = const {},
    int? peakHour,
    bool? isWeekend,
  }) async {
    if (screenTimeHours <= 0 &&
        socialAppHours <= 0 &&
        nightUsageHours <= 0 &&
        unlockCount <= 0 &&
        notificationCount <= 0) {
      throw Exception(
          'Prediction requires real sensed device usage data. No realtime data is available yet.');
    }

    return _predictWithFallback(
      screenTimeHours: screenTimeHours,
      socialAppHours: socialAppHours,
      nightUsageHours: nightUsageHours,
      unlockCount: unlockCount,
      notificationCount: notificationCount,
      stressLevel: stressLevel,
      anxietyLevel: anxietyLevel,
      depressionLevel: depressionLevel,
      appBreakdown: appBreakdown,
      peakHour: peakHour,
      isWeekend: isWeekend,
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

    return generatePrediction(
      screenTimeHours: screenTimeHours,
      socialAppHours: socialAppHours,
      nightUsageHours: nightUsageHours,
      unlockCount: unlockCount,
      notificationCount: notificationCount,
      appBreakdown: appBreakdown,
      peakHour: peakHour,
      isWeekend: isWeekend,
      stressLevel: stressLevel,
      anxietyLevel: anxietyLevel,
      depressionLevel: depressionLevel,
    );
  }

  static Future<PredictionResult> _predictWithFallback({
    required double screenTimeHours,
    required double socialAppHours,
    required double nightUsageHours,
    required int unlockCount,
    required int notificationCount,
    required int stressLevel,
    required int anxietyLevel,
    required int depressionLevel,
    required Map<String, double> appBreakdown,
    int? peakHour,
    bool? isWeekend,
  }) async {
    try {
      return _predictLocally(
        screenTimeHours: screenTimeHours,
        socialAppHours: socialAppHours,
        nightUsageHours: nightUsageHours,
        unlockCount: unlockCount,
        notificationCount: notificationCount,
        stressLevel: stressLevel,
        anxietyLevel: anxietyLevel,
        depressionLevel: depressionLevel,
        appBreakdown: appBreakdown,
        peakHour: peakHour,
        isWeekend: isWeekend,
      );
    } catch (_) {
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
  }

  static PredictionResult _predictLocally({
    required double screenTimeHours,
    required double socialAppHours,
    required double nightUsageHours,
    required int unlockCount,
    required int notificationCount,
    required int stressLevel,
    required int anxietyLevel,
    required int depressionLevel,
    required Map<String, double> appBreakdown,
    int? peakHour,
    bool? isWeekend,
  }) {
    final socialRatio = _socialRatio(appBreakdown);
    final wellbeingTotal = stressLevel + anxietyLevel + depressionLevel;

    var riskScore = 0;

    if (screenTimeHours > 8) {
      riskScore += 3;
    } else if (screenTimeHours > 6) {
      riskScore += 2;
    } else if (screenTimeHours > 4) {
      riskScore += 1;
    }

    if (nightUsageHours > 3) {
      riskScore += 2;
    } else if (nightUsageHours > 1.5) {
      riskScore += 1;
    }

    if (unlockCount > 200) {
      riskScore += 2;
    } else if (unlockCount > 100) {
      riskScore += 1;
    }

    if (notificationCount > 300) {
      riskScore += 2;
    } else if (notificationCount > 150) {
      riskScore += 1;
    }

    if (socialRatio > 0.8) {
      riskScore += 2;
    } else if (socialRatio > 0.6) {
      riskScore += 1;
    }

    if (wellbeingTotal >= 11) {
      riskScore += 2;
    } else if (wellbeingTotal >= 8) {
      riskScore += 1;
    }

    if ((peakHour != null && (peakHour >= 22 || peakHour < 6)) ||
        (isWeekend == true && screenTimeHours >= 6)) {
      riskScore += 1;
    }

    final severeSignals = [
      screenTimeHours >= 9.5,
      nightUsageHours >= 2.5,
      unlockCount >= 180,
      notificationCount >= 300,
      socialAppHours >= 3.5,
      wellbeingTotal >= 11,
    ].where((signal) => signal).length;

    final lowSignals = [
      screenTimeHours <= 3.5,
      nightUsageHours <= 0.5,
      unlockCount <= 60,
      notificationCount <= 80,
      socialAppHours <= 1.0,
      wellbeingTotal <= 6,
    ].where((signal) => signal).length;

    late String addictionLevel;
    late double confidenceScore;

    if (severeSignals >= 3 || (screenTimeHours >= 11 && nightUsageHours >= 3)) {
      addictionLevel = 'High';
      confidenceScore = 0.84;
    } else if (lowSignals >= 5 && severeSignals == 0) {
      addictionLevel = 'Low';
      confidenceScore = 0.84;
    } else if (riskScore >= 7) {
      addictionLevel = 'High';
      confidenceScore = 0.75;
    } else if (riskScore >= 4) {
      addictionLevel = 'Medium';
      confidenceScore = 0.68;
    } else {
      addictionLevel = 'Low';
      confidenceScore = 0.62;
    }

    return PredictionResult(
      addictionLevel: addictionLevel,
      confidenceScore: confidenceScore,
      riskColor: _riskColor(addictionLevel),
      message: _riskMessage(addictionLevel),
      recommendations: _recommendations(addictionLevel),
      timestamp: DateTime.now(),
    );
  }

  static double _socialRatio(Map<String, double> appBreakdown) {
    if (appBreakdown.isEmpty) {
      return 0.0;
    }
    final totalUsage = appBreakdown.values.fold<double>(0.0, (a, b) => a + b);
    if (totalUsage <= 0) {
      return 0.0;
    }
    final socialUsage = appBreakdown.entries
        .where((entry) => _isSocialApp(entry.key))
        .fold<double>(0.0, (sum, entry) => sum + entry.value);
    return socialUsage / totalUsage;
  }

  static String _riskColor(String addictionLevel) {
    switch (addictionLevel) {
      case 'High':
        return '#F44336';
      case 'Medium':
        return '#FFC107';
      case 'Low':
        return '#4CAF50';
      default:
        return '#9E9E9E';
    }
  }

  static String _riskMessage(String addictionLevel) {
    switch (addictionLevel) {
      case 'High':
        return 'High addiction risk detected from your latest real device usage.';
      case 'Medium':
        return 'Moderate addiction risk detected from your latest real device usage.';
      case 'Low':
        return 'Your latest real device usage looks relatively healthy.';
      default:
        return 'Prediction completed from local offline analysis.';
    }
  }

  static List<String> _recommendations(String addictionLevel) {
    switch (addictionLevel) {
      case 'High':
        return const [
          'Activate Focus Mode to block distracting apps.',
          'Set a hard daily screen limit of 4 hours.',
          'Try a 1-day digital detox each week.',
          'Replace evening phone time with reading or exercise.',
          'Turn off all non-essential notifications.',
        ];
      case 'Medium':
        return const [
          'Limit social-media apps to under 2 hours per day.',
          'Avoid phone use 30 minutes before bedtime.',
          'Enable app timers on your top apps.',
          'Take a short break every 45 minutes of screen time.',
          'Turn off non-essential notifications.',
        ];
      case 'Low':
        return const [
          'Maintain your current screen-time habits.',
          'Keep prioritizing offline activities.',
          'Continue using do-not-disturb during sleep hours.',
        ];
      default:
        return const [];
    }
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
