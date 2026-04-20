// lib/services/app_state.dart
//
// SmartPulse v2 — Central App State (Provider)
// All usage data (screen time, app usage, night usage, unlock count,
// notification count) is read automatically from the device.
// The ONLY inputs the user provides manually are the 3 psychological scores.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/usage_data.dart';
import '../models/prediction_result.dart';
import 'api_service.dart';
import 'usage_service.dart';
import 'usage_monitor_service.dart';
import 'notification_service.dart';
import 'auto_sensing_service.dart';
import 'prediction_service.dart';

enum PredictionStatus { idle, loading, success, error }

class AppState extends ChangeNotifier {
  // ── Theme ───────────────────────────────────────────────────────────────
  ThemeMode _themeMode = ThemeMode.system;
  Timer? _dailyPredictionTimer;
  Timer? _sessionPredictionTimer;
  String? _activeTrackingSessionStart;
  String? _activeTrackingSessionEnd;
  String? _lastPredictedSessionStart;

  @override
  void dispose() {
    _dailyPredictionTimer?.cancel();
    _sessionPredictionTimer?.cancel();
    super.dispose();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString('theme_mode', mode.toString());
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : _themeMode == ThemeMode.light
            ? ThemeMode.dark
            : ThemeMode.system;
    await setThemeMode(newMode);
  }

  Future<void> _loadTheme() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('theme_mode');
    if (saved != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == saved,
        orElse: () => ThemeMode.system,
      );
    }
  }

  // ── User Profile ───────────────────────────────────────────────────────
  UserProfile? _user;
  String? _token;

  UserProfile? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _user != null;

  Future<void> setUser(Map<String, dynamic> userData, String token) async {
    _user = UserProfile.fromJson(userData);
    _token = token;
    final p = await SharedPreferences.getInstance();
    await p.setString('user', json.encode(userData));
    await p.setString('token', token);
    notifyListeners();
  }

  Future<void> updateUserProfile(Map<String, dynamic> userData) async {
    if (_user != null) {
      // Update existing user data
      final updatedUser = UserProfile.fromJson(userData);
      _user = updatedUser;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', json.encode(userData));
      notifyListeners();
    }
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user');
    final savedToken = prefs.getString('token');
    if (saved != null && savedToken != null) {
      _user = UserProfile.fromJson(json.decode(saved));
      _token = savedToken;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    await prefs.remove('token');
    notifyListeners();
  }

  // ── Usage Data ───────────────────────────────────────────────────────
  UsageData _todayUsage = UsageData(
    date: DateTime.now(),
    screenTime: 0.0,
    appUsage: 0.0,
    nightUsage: 0.0,
    unlockCount: 0,
    notificationCount: 0,
    appBreakdown: {},
  );

  List<UsageData> _weeklyUsage = [];

  UsageData get todayUsage => _todayUsage;
  List<UsageData> get weeklyUsage => _weeklyUsage;
  bool _isLoadingUsage = false;
  bool _usagePermissionGranted = false;

  bool get isLoadingUsage => _isLoadingUsage;
  bool get usagePermissionGranted => _usagePermissionGranted;
  String? get activeTrackingSessionStart => _activeTrackingSessionStart;

  Future<void> refreshUsage() async {
    _isLoadingUsage = true;
    notifyListeners();

    try {
      final hasUsagePermission = await UsageService.hasUsageStatsPermission();
      _usagePermissionGranted = hasUsagePermission;

      if (hasUsagePermission && !(await AutoSensingService.isTracking())) {
        await AutoSensingService.startTracking();
      }

      final usageData = await AutoSensingService.forceRefresh();
      _syncTrackingSessionMeta(usageData);
      final usageDate = _usageBucketDate(usageData);

      _todayUsage = UsageData(
        date: usageDate,
        screenTime:
            ((usageData['total_screen_time_minutes'] as num?)?.toDouble() ??
                    0.0) /
                60.0,
        appUsage: _calculateSocialAppHours(
          Map<String, double>.from(usageData['app_breakdown'] ?? {}),
        ),
        nightUsage:
            ((usageData['night_usage_minutes'] as num?)?.toDouble() ?? 0.0) /
                60.0,
        unlockCount: (usageData['total_unlocks'] as int?) ?? 0,
        notificationCount: (usageData['total_notifications'] as int?) ?? 0,
        appBreakdown:
            Map<String, double>.from(usageData['app_breakdown'] ?? {}),
        hasPermission: hasUsagePermission,
      );

      await _persistCurrentUsageSnapshot();

      _weeklyUsage = [_todayUsage];

      // Add historical data for weekly view
      await _populateWeeklyUsageData();

      _usagePermissionGranted = hasUsagePermission;
      await _maybeAutoRunCompletedSessionPrediction();
    } catch (e) {
      _usagePermissionGranted = false;

      // Don't set default values - only show real data when permission is granted
      _todayUsage = UsageData(
        date: DateTime.now(),
        screenTime: 0.0,
        appUsage: 0.0,
        nightUsage: 0.0,
        unlockCount: 0,
        notificationCount: 0,
        appBreakdown: {},
        hasPermission: false,
      );

      _weeklyUsage = [_todayUsage];
    } finally {
      _isLoadingUsage = false;
      notifyListeners();
    }
  }

  Future<void> requestUsagePermission() async {
    try {
      final hasUsagePermission = await UsageService.hasUsageStatsPermission();
      _usagePermissionGranted = hasUsagePermission;

      // Start auto-sensing if permissions granted and not already tracking
      if (_usagePermissionGranted && !(await AutoSensingService.isTracking())) {
        await AutoSensingService.startTracking();
        // Auto-sensing started
      }

      notifyListeners();
    } catch (e) {
      // Error checking permissions: $e
    }
  }

  // Debug permission override - force enable data sensing
  Future<void> enableDebugPermissionOverride() async {
    await requestUsagePermission();
    await refreshUsage();
  }

  // Load existing Android usage data immediately
  Future<void> _loadExistingAndroidUsageImmediately() async {
    try {
      // Get today's existing usage statistics from Android immediately
      final existingData = await AutoSensingService.forceRefresh();
      _syncTrackingSessionMeta(existingData);
      final usageDate = _usageBucketDate(existingData);

      // Update today's usage with real Android data immediately
      _todayUsage = UsageData(
        date: usageDate,
        screenTime:
            ((existingData['total_screen_time_minutes'] as num?)?.toDouble() ??
                    0.0) /
                60.0,
        appUsage: _calculateSocialAppHours(
          Map<String, double>.from(existingData['app_breakdown'] ?? {}),
        ),
        nightUsage:
            ((existingData['night_usage_minutes'] as num?)?.toDouble() ?? 0.0) /
                60.0,
        unlockCount: (existingData['total_unlocks'] as int?) ?? 0,
        notificationCount: (existingData['total_notifications'] as int?) ?? 0,
        appBreakdown:
            Map<String, double>.from(existingData['app_breakdown'] ?? {}),
        hasPermission: true,
      );

      await _persistCurrentUsageSnapshot();

      // Update weekly usage with today's real data
      _weeklyUsage = [_todayUsage];

      // Add historical data for weekly view
      await _populateWeeklyUsageData();

      // Force immediate UI update
      notifyListeners();
      await _maybeAutoRunCompletedSessionPrediction();

      // Loaded existing Android data immediately: Screen: ${_todayUsage.screenTime}h, Apps: ${_todayUsage.appUsage}, Unlocks: ${_todayUsage.unlockCount}
    } catch (e) {
      // Error loading existing Android data: $e
    }
  }

  // Manual permission marking - trust user confirmation
  Future<void> markPermissionsManuallyGranted() async {
    try {
      final hasUsagePermission = await UsageService.hasUsageStatsPermission();
      _usagePermissionGranted = hasUsagePermission;

      if (_usagePermissionGranted && !(await AutoSensingService.isTracking())) {
        await AutoSensingService.startTracking();
      }

      await refreshUsage();
      notifyListeners();
    } catch (e) {
      // Error marking permissions manually: $e
    }
  }

  // ── Survey Data ───────────────────────────────────────────────────────
  int _stress = 3;
  int _anxiety = 3;
  int _depression = 3;

  int get stress => _stress;
  int get anxiety => _anxiety;
  int get depression => _depression;

  Future<void> updateSurvey({
    required int stress,
    required int anxiety,
    required int depression,
  }) async {
    _stress = stress;
    _anxiety = anxiety;
    _depression = depression;
    final p = await SharedPreferences.getInstance();
    await p.setInt('survey_stress', stress);
    await p.setInt('survey_anxiety', anxiety);
    await p.setInt('survey_depression', depression);
    notifyListeners();
  }

  Future<void> _loadSurvey() async {
    final p = await SharedPreferences.getInstance();
    _stress = p.getInt('survey_stress') ?? 1;
    _anxiety = p.getInt('survey_anxiety') ?? 1;
    _depression = p.getInt('survey_depression') ?? 1;
  }

  // ── Prediction ────────────────────────────────────────────────────────
  PredictionStatus _predictionStatus = PredictionStatus.idle;
  String? _predictionError;
  PredictionResult? _lastPrediction;
  List<PredictionResult> _history = [];
  Map<String, PredictionResult> _dailyPredictions = {}; // date -> prediction
  Map<String, UsageData> _dailyUsageData = {}; // date -> usage data

  PredictionStatus get predictionStatus => _predictionStatus;
  String? get predictionError => _predictionError;
  PredictionResult? get lastPrediction => _lastPrediction;
  List<PredictionResult> get history => _history;
  Map<String, PredictionResult> get dailyPredictions => _dailyPredictions;
  Map<String, UsageData> get dailyUsageData => _dailyUsageData;

  // Get today's prediction
  PredictionResult? get todayPrediction {
    return _dailyPredictions[_dateKeyFor(_todayUsage.date)];
  }

  // Check if today's prediction is ready
  bool get hasTodayPrediction => todayPrediction != null;

  Future<void> runDailyPrediction({
    BuildContext? context,
    bool rotateSessionAfterPrediction = false,
    bool syncFromSensors = true,
    String? recordKeyOverride,
    String? predictedSessionStart,
    UsageData? usageOverride,
  }) async {
    if (syncFromSensors) {
      await _syncTodayUsageFromSensors();
    }

    final usageForPrediction = usageOverride ?? _todayUsage;

    if (usageForPrediction.screenTime == 0) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No usage data available for daily prediction'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_predictionStatus == PredictionStatus.loading) return;
    _predictionStatus = PredictionStatus.loading;
    _predictionError = null;
    notifyListeners();

    try {
      // Calculate social app usage
      final socialAppHours = usageForPrediction.appBreakdown.entries
              .where((entry) => _isSocialApp(entry.key))
              .fold(0.0, (sum, entry) => sum + entry.value) /
          60.0;

      // Get prediction using our new PredictionService
      final prediction = await PredictionService.generatePrediction(
        screenTimeHours: usageForPrediction.screenTime,
        socialAppHours: socialAppHours,
        nightUsageHours: usageForPrediction.nightUsage,
        unlockCount: usageForPrediction.unlockCount,
        notificationCount: usageForPrediction.notificationCount,
        appBreakdown: usageForPrediction.appBreakdown,
        stressLevel: _stress,
        anxietyLevel: _anxiety,
        depressionLevel: _depression,
      );

      final recordKey = recordKeyOverride ?? _predictionRecordKey();
      _dailyPredictions[recordKey] = prediction;
      _dailyUsageData[recordKey] = usageForPrediction;
      _lastPrediction = prediction;
      _history.insert(0, prediction);
      _predictionStatus = PredictionStatus.success;
      _lastPredictedSessionStart =
          predictedSessionStart ?? _activeTrackingSessionStart ?? recordKey;

      // Save daily predictions and usage data to storage
      await _saveDailyPredictions();
      await _saveDailyUsageData();
      await _saveLastPredictedSessionStart();
      await _savePredictionToBackend(prediction, usageForPrediction);

      if (prediction.addictionLevel == 'High') {
        await NotificationService.sendHighRiskAlert(
            confidence: prediction.confidenceScore);
      }

      // Show success message if context is available
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Daily prediction ready: ${prediction.addictionLevel} Risk'),
            backgroundColor: prediction.addictionLevel == 'High'
                ? Colors.red.shade600
                : prediction.addictionLevel == 'Medium'
                    ? Colors.orange.shade600
                    : Colors.green.shade600,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      if (rotateSessionAfterPrediction) {
        await _resetDailyCountsAfterPrediction();
      }
    } catch (e) {
      _predictionStatus = PredictionStatus.error;
      _predictionError = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Helper method to check if app is social media
  bool _isSocialApp(String packageName) {
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

  Future<void> _loadPredictions() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('predictions');
    if (saved != null) {
      final List<dynamic> jsonList = json.decode(saved);
      _history = jsonList.map((e) => PredictionResult.fromJson(e)).toList();
    }

    // Load daily predictions
    final dailySaved = p.getString('daily_predictions');
    if (dailySaved != null) {
      final Map<String, dynamic> dailyJson = json.decode(dailySaved);
      _dailyPredictions = dailyJson
          .map((key, value) => MapEntry(key, PredictionResult.fromJson(value)));
    }

    // Load daily usage data
    final usageSaved = p.getString('daily_usage_data');
    if (usageSaved != null) {
      final Map<String, dynamic> usageJson = json.decode(usageSaved);
      _dailyUsageData = usageJson.map((key, value) {
        final parsedUsage = UsageData.fromJson(value);
        final keyDate = _dateFromKey(key) ??
            DateTime(
              parsedUsage.date.year,
              parsedUsage.date.month,
              parsedUsage.date.day,
            );
        return MapEntry(
          key,
          UsageData(
            date: keyDate,
            screenTime: parsedUsage.screenTime,
            appUsage: parsedUsage.appUsage,
            nightUsage: parsedUsage.nightUsage,
            unlockCount: parsedUsage.unlockCount,
            notificationCount: parsedUsage.notificationCount,
            appBreakdown: Map<String, double>.from(parsedUsage.appBreakdown),
            hasPermission: parsedUsage.hasPermission,
          ),
        );
      });
    }
  }

  // Populate weekly usage data with historical values
  Future<void> _populateWeeklyUsageData() async {
    final today = DateTime(
      _todayUsage.date.year,
      _todayUsage.date.month,
      _todayUsage.date.day,
    );
    final earliestIncluded = today.subtract(const Duration(days: 6));
    final weeklyByKey = <String, UsageData>{};

    for (final entry in _dailyUsageData.entries) {
      final usage = entry.value;
      final normalizedDate = _dateFromKey(entry.key) ??
          DateTime(
            usage.date.year,
            usage.date.month,
            usage.date.day,
          );
      if (normalizedDate.isBefore(earliestIncluded) ||
          normalizedDate.isAfter(today)) {
        continue;
      }
      weeklyByKey[entry.key] = UsageData(
        date: normalizedDate,
        screenTime: usage.screenTime,
        appUsage: usage.appUsage,
        nightUsage: usage.nightUsage,
        unlockCount: usage.unlockCount,
        notificationCount: usage.notificationCount,
        appBreakdown: Map<String, double>.from(usage.appBreakdown),
        hasPermission: usage.hasPermission,
      );
    }

    weeklyByKey[_dateKeyFor(today)] = UsageData(
      date: today,
      screenTime: _todayUsage.screenTime,
      appUsage: _todayUsage.appUsage,
      nightUsage: _todayUsage.nightUsage,
      unlockCount: _todayUsage.unlockCount,
      notificationCount: _todayUsage.notificationCount,
      appBreakdown: Map<String, double>.from(_todayUsage.appBreakdown),
      hasPermission: _todayUsage.hasPermission,
    );

    _weeklyUsage = weeklyByKey.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> _persistCurrentUsageSnapshot() async {
    if (!_todayUsage.hasPermission) {
      return;
    }

    final calendarKey = _dateKeyFor(_todayUsage.date);
    _dailyUsageData[calendarKey] = UsageData(
      date: DateTime(
        _todayUsage.date.year,
        _todayUsage.date.month,
        _todayUsage.date.day,
      ),
      screenTime: _todayUsage.screenTime,
      appUsage: _todayUsage.appUsage,
      nightUsage: _todayUsage.nightUsage,
      unlockCount: _todayUsage.unlockCount,
      notificationCount: _todayUsage.notificationCount,
      appBreakdown: Map<String, double>.from(_todayUsage.appBreakdown),
      hasPermission: _todayUsage.hasPermission,
    );
    await _saveDailyUsageData();
  }

  // Reset daily counts after successful prediction
  Future<void> _resetDailyCountsAfterPrediction() async {
    try {
      UsageMonitorService.resetDailyFlags();
      _activeTrackingSessionStart = null;
      _activeTrackingSessionEnd = null;
      await refreshUsage();
    } catch (e) {
      // Error resetting daily counts after prediction: $e
    }
  }

  Future<void> _saveDailyPredictions() async {
    final p = await SharedPreferences.getInstance();
    final dailyJson =
        _dailyPredictions.map((key, value) => MapEntry(key, value.toJson()));
    await p.setString('daily_predictions', json.encode(dailyJson));
  }

  Future<void> _saveDailyUsageData() async {
    final p = await SharedPreferences.getInstance();
    final usageJson =
        _dailyUsageData.map((key, value) => MapEntry(key, value.toJson()));
    await p.setString('daily_usage_data', json.encode(usageJson));
  }

  Future<void> _loadTrackingSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    _lastPredictedSessionStart =
        prefs.getString('last_predicted_session_start');
  }

  Future<void> _saveLastPredictedSessionStart() async {
    final prefs = await SharedPreferences.getInstance();
    if (_lastPredictedSessionStart == null) {
      await prefs.remove('last_predicted_session_start');
    } else {
      await prefs.setString(
          'last_predicted_session_start', _lastPredictedSessionStart!);
    }
  }

  void _syncTrackingSessionMeta(Map<String, dynamic> usageData) {
    final sessionStart = usageData['tracking_session_start']?.toString();
    final sessionEnd = usageData['tracking_session_end']?.toString();
    if (sessionStart != null && sessionStart.isNotEmpty) {
      _activeTrackingSessionStart = sessionStart;
    }
    if (sessionEnd != null && sessionEnd.isNotEmpty) {
      _activeTrackingSessionEnd = sessionEnd;
    }
    _scheduleTrackingSessionPrediction(usageData);
  }

  String _predictionRecordKey() {
    final start = _trackingSessionLocalDateTime(_activeTrackingSessionStart) ??
        _todayUsage.date;
    return _dateKeyFor(start);
  }

  String? _usageDataSessionEnd() {
    return _activeTrackingSessionEnd;
  }

  Future<void> _syncTodayUsageFromSensors() async {
    try {
      final usageData = await AutoSensingService.forceRefresh();
      _syncTrackingSessionMeta(usageData);
      final usageDate = _usageBucketDate(usageData);
      _todayUsage = UsageData(
        date: usageDate,
        screenTime:
            ((usageData['total_screen_time_minutes'] as num?)?.toDouble() ??
                    0.0) /
                60.0,
        appUsage: _calculateSocialAppHours(
          Map<String, double>.from(usageData['app_breakdown'] ?? {}),
        ),
        nightUsage:
            ((usageData['night_usage_minutes'] as num?)?.toDouble() ?? 0.0) /
                60.0,
        unlockCount: (usageData['total_unlocks'] as int?) ?? 0,
        notificationCount: (usageData['total_notifications'] as int?) ?? 0,
        appBreakdown:
            Map<String, double>.from(usageData['app_breakdown'] ?? {}),
        hasPermission: (usageData['permission_granted'] ?? false) == true,
      );
    } catch (e) {
      print('[AppState] Failed to sync usage before prediction: $e');
    }
  }

  Future<void> _savePredictionToBackend(
    PredictionResult prediction,
    UsageData usage,
  ) async {
    if (_token == null || _token!.isEmpty) {
      return;
    }

    try {
      final api = ApiService()..setToken(_token!);
      await api.savePrediction({
        'prediction_result': prediction.addictionLevel,
        'confidence_score': prediction.confidenceScore,
        'risk_level': prediction.addictionLevel,
        'recommendations': prediction.recommendations,
        'input_features': {
          'screen_time_hours': usage.screenTime,
          'app_usage_hours': usage.appUsage,
          'night_usage_hours': usage.nightUsage,
          'unlock_count': usage.unlockCount,
          'notification_count': usage.notificationCount,
          'app_breakdown': usage.appBreakdown,
          'stress': _stress,
          'anxiety': _anxiety,
          'depression': _depression,
        },
      });
    } catch (e) {
      print('[AppState] Failed to save prediction to backend: $e');
    }
  }

  double _calculateSocialAppHours(Map<String, double> appBreakdown) {
    final socialMinutes = appBreakdown.entries
        .where((entry) => _isSocialApp(entry.key))
        .fold<double>(0.0, (sum, entry) => sum + entry.value);
    return socialMinutes / 60.0;
  }

  DateTime _usageBucketDate(Map<String, dynamic> usageData) {
    final sessionStart = _trackingSessionLocalDateTime(
      usageData['tracking_session_start']?.toString(),
    );
    final value = sessionStart ?? DateTime.now();
    return DateTime(value.year, value.month, value.day);
  }

  String _dateKeyFor(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .toIso8601String()
        .split('T')
        .first;
  }

  DateTime? _trackingSessionLocalDateTime(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(rawValue);
    if (parsed == null) {
      return null;
    }
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  DateTime? _dateFromKey(String key) {
    final parsed = DateTime.tryParse(key);
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  void _scheduleTrackingSessionPrediction(Map<String, dynamic> usageData) {
    _sessionPredictionTimer?.cancel();
    _dailyPredictionTimer?.cancel();

    final sessionEnd =
        DateTime.tryParse(usageData['tracking_session_end']?.toString() ?? '');
    final sessionStart = usageData['tracking_session_start']?.toString();

    if (sessionStart == null || sessionStart.isEmpty) {
      return;
    }

    if (sessionEnd == null) {
      return;
    }

    final now = DateTime.now();
    final predictionAt = sessionEnd.subtract(const Duration(seconds: 1));
    final durationUntilPrediction = predictionAt.difference(now);
    if (!durationUntilPrediction.isNegative) {
      _sessionPredictionTimer = Timer(durationUntilPrediction, () async {
        await _runScheduledPredictionForSession(sessionStart);
      });
    }

    final refreshAt = sessionEnd.add(const Duration(seconds: 1));
    final durationUntilRefresh = refreshAt.difference(now);
    if (!durationUntilRefresh.isNegative) {
      _dailyPredictionTimer = Timer(durationUntilRefresh, () async {
        UsageMonitorService.resetDailyFlags();
        await refreshUsage();
      });
    }
  }

  Future<void> _maybeAutoRunCompletedSessionPrediction() async {
    if (_predictionStatus == PredictionStatus.loading) {
      return;
    }

    final snapshot = await AutoSensingService.forceRefresh();
    final currentSessionStart = snapshot['tracking_session_start']?.toString();

    if (currentSessionStart == null || currentSessionStart.isEmpty) {
      return;
    }

    final currentBucketDate =
        _trackingSessionLocalDateTime(currentSessionStart) ?? DateTime.now();
    final previousDayKey =
        _dateKeyFor(currentBucketDate.subtract(const Duration(days: 1)));

    if (_dailyPredictions.containsKey(previousDayKey)) {
      return;
    }

    final previousUsage = _dailyUsageData[previousDayKey];
    if (previousUsage == null || previousUsage.screenTime <= 0) {
      return;
    }

    await runDailyPrediction(
      rotateSessionAfterPrediction: false,
      syncFromSensors: false,
      recordKeyOverride: previousDayKey,
      predictedSessionStart: previousDayKey,
      usageOverride: previousUsage,
    );
  }

  Future<void> _runScheduledPredictionForSession(String sessionStart) async {
    if (_predictionStatus == PredictionStatus.loading) {
      return;
    }

    final recordKey = _predictionDateKeyForSessionStart(sessionStart);
    if (_dailyPredictions.containsKey(recordKey) ||
        _lastPredictedSessionStart == sessionStart) {
      return;
    }

    await runDailyPrediction(
      rotateSessionAfterPrediction: false,
      syncFromSensors: true,
      recordKeyOverride: recordKey,
      predictedSessionStart: sessionStart,
    );
  }

  String _predictionDateKeyForSessionStart(String sessionStart) {
    final start =
        _trackingSessionLocalDateTime(sessionStart) ?? _todayUsage.date;
    return _dateKeyFor(start);
  }

// Trigger prediction from current usage data (for testing and immediate results)
  Future<void> triggerPredictionFromCurrentData({BuildContext? context}) async {
    if (_predictionStatus == PredictionStatus.loading) return;
    _predictionStatus = PredictionStatus.loading;
    _predictionError = null;
    notifyListeners();

    try {
      await _syncTodayUsageFromSensors();

      // Use PredictionService to generate prediction from current usage
      final prediction =
          await PredictionService.generatePredictionFromCurrentUsage();

      // Store prediction with today's date
      final recordKey = _predictionRecordKey();
      _dailyPredictions[recordKey] = prediction;
      _dailyUsageData[recordKey] = _todayUsage;
      _lastPrediction = prediction;
      _history.insert(0, prediction);
      _predictionStatus = PredictionStatus.success;

      // Save daily predictions to storage
      await _saveDailyPredictions();
      await _saveDailyUsageData();
      await _savePredictionToBackend(prediction, _todayUsage);

      if (prediction.addictionLevel == 'High') {
        await NotificationService.sendHighRiskAlert(
            confidence: prediction.confidenceScore);
      }

      // Show success message if context is available
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Prediction ready: ${prediction.addictionLevel} Risk (${(prediction.confidenceScore * 100).toStringAsFixed(0)}% confidence)'),
            backgroundColor: prediction.addictionLevel == 'High'
                ? Colors.red.shade600
                : prediction.addictionLevel == 'Medium'
                    ? Colors.orange.shade600
                    : Colors.green.shade600,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      _predictionStatus = PredictionStatus.error;
      _predictionError = e.toString();

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prediction failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      notifyListeners();
    }
  }

// ... (rest of the code remains the same)
  Future<void> triggerDailyPrediction({BuildContext? context}) async {
    await runDailyPrediction(context: context);
  }

  // ── Goals & Settings ───────────────────────────────────────────────
  double _goalHours = 4.0;
  int _notifThreshold = 200;
  int _unlockThreshold = 80;

  double get goalHours => _goalHours;
  int get notifThreshold => _notifThreshold;
  int get unlockThreshold => _unlockThreshold;

  Future<void> setGoalHours(double hours) async {
    _goalHours = hours;
    final p = await SharedPreferences.getInstance();
    await p.setDouble('screen_time_goal', hours);
    notifyListeners();
  }

  Future<void> setNotifThreshold(int threshold) async {
    _notifThreshold = threshold;
    final p = await SharedPreferences.getInstance();
    await p.setInt('notif_threshold', threshold);
    notifyListeners();
  }

  Future<void> setUnlockThreshold(int threshold) async {
    _unlockThreshold = threshold;
    final p = await SharedPreferences.getInstance();
    await p.setInt('unlock_threshold', threshold);
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    _goalHours = p.getDouble('screen_time_goal') ?? 4.0;
    _notifThreshold = p.getInt('notif_threshold') ?? 200;
    _unlockThreshold = p.getInt('unlock_threshold') ?? 80;
  }

  // ── Gamification ───────────────────────────────────────────────────────
  int _points = 0;
  int _streak = 0;

  int get points => _points;
  int get streak => _streak;

  Future<void> addPoints(int points) async {
    _points += points;
    final p = await SharedPreferences.getInstance();
    await p.setInt('points', _points);
    notifyListeners();
  }

  Future<void> incrementStreak() async {
    _streak++;
    final p = await SharedPreferences.getInstance();
    await p.setInt('streak', _streak);
    notifyListeners();
  }

  Future<void> resetStreak() async {
    _streak = 0;
    final p = await SharedPreferences.getInstance();
    await p.setInt('streak', _streak);
    notifyListeners();
  }

  Future<void> _loadGamification() async {
    final p = await SharedPreferences.getInstance();
    _points = p.getInt('points') ?? 0;
    _streak = p.getInt('streak') ?? 0;
  }

  // Load manual permission status on app startup
  Future<void> _loadManualPermissionStatus() async {
    await _checkAndEnablePermissions();
  }

  // Aggressive permission checking and auto-enable
  Future<void> _checkAndEnablePermissions() async {
    try {
      bool hasUsagePermission = false;

      // Try usage permission detection multiple times
      for (int i = 0; i < 3; i++) {
        hasUsagePermission = await UsageService.hasUsageStatsPermission();
        if (hasUsagePermission) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Auto-enable if usage permission is detected
      if (hasUsagePermission) {
        _usagePermissionGranted = true;

        // Start auto-sensing immediately
        if (!(await AutoSensingService.isTracking())) {
          await AutoSensingService.startTracking();
        }

        await refreshUsage();
      }
    } catch (e) {
      // Error in aggressive permission checking: $e
    }
  }

  // ── INIT ───────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _resetUsageStateIfAppUpdated();
    await _loadPrefs();
    await _loadManualPermissionStatus(); // Load manual permission flag
    await NotificationService.initialize();
    await NotificationService.requestPermission();
    await NotificationService.scheduleDailyCheckin();
    await NotificationService.scheduleMorningSummary();

    // CRITICAL FIX: Start usage monitoring regardless of login status
    // Data sensing should work even without user account
    UsageMonitorService.start();
    await refreshUsage();
  }

  Future<void> _loadPrefs() async {
    await _loadTheme();
    await _loadUser();
    await _loadSurvey();
    await _loadPredictions();
    await _loadSettings();
    await _loadGamification();
    await _loadTrackingSessionState();
  }

  Future<void> _resetUsageStateIfAppUpdated() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUpdateTime = await UsageService.getAppLastUpdateTime();
    final storedUpdateTime =
        int.tryParse(prefs.getString('app_last_update_time') ?? '') ?? -1;

    if (currentUpdateTime <= 0 || storedUpdateTime == currentUpdateTime) {
      return;
    }

    _history = [];
    _dailyPredictions = {};
    _dailyUsageData = {};
    _lastPrediction = null;
    _predictionStatus = PredictionStatus.idle;
    _predictionError = null;
    _lastPredictedSessionStart = null;
    _activeTrackingSessionStart = null;
    _activeTrackingSessionEnd = null;

    await prefs.remove('predictions');
    await prefs.remove('daily_predictions');
    await prefs.remove('daily_usage_data');
    await prefs.remove('last_predicted_session_start');
    await prefs.setString('app_last_update_time', currentUpdateTime.toString());
  }
}
