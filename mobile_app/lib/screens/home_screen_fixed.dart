import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usage_data.dart';
import '../models/user_profile.dart';
import '../services/app_state.dart';
import '../services/auto_sensing_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';

class HomeScreenFixed extends StatefulWidget {
  const HomeScreenFixed({super.key});

  @override
  State<HomeScreenFixed> createState() => _HomeScreenFixedState();
}

class _HomeScreenFixedState extends State<HomeScreenFixed>
    with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _permissionTimer;
  Map<String, dynamic>? _usageData;
  bool _loading = true;
  double _screenTimeGoal = 4.0;
  int _notificationThreshold = 10;
  int _unlockThreshold = 50;
  double _draftScreenTimeGoal = 4.0;
  int _draftNotificationThreshold = 10;
  int _draftUnlockThreshold = 50;
  bool _isEditingGoals = true;
  String? _goalStatusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGoals();
    _initializeRealtimeTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _permissionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  Future<void> _initializeRealtimeTracking() async {
    await AutoSensingService.initialize();
    await AutoSensingService.startTracking();

    _subscription = AutoSensingService.realtimeDataStream.listen((data) {
      if (!mounted) {
        return;
      }
      setState(() {
        _usageData = data;
        _loading = false;
      });
    });

    await _refreshData();

    _permissionTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final data = await AutoSensingService.forceRefresh();
      if (!mounted) {
        return;
      }
      setState(() {
        _usageData = data;
      });
    });
  }

  Future<void> _refreshData() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
    });

    final data = await AutoSensingService.forceRefresh();
    if (!mounted) {
      return;
    }
    setState(() {
      _usageData = data;
      _loading = false;
    });
    await context.read<AppState>().refreshUsage();
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _screenTimeGoal = prefs.getDouble('screen_time_goal') ?? 4.0;
      _notificationThreshold = prefs.getInt('notif_threshold') ?? 10;
      _unlockThreshold = prefs.getInt('unlock_threshold') ?? 50;
      _draftScreenTimeGoal = _screenTimeGoal;
      _draftNotificationThreshold = _notificationThreshold;
      _draftUnlockThreshold = _unlockThreshold;
      _isEditingGoals = false;
      _goalStatusMessage =
          'Daily goals are set. Tap Reset Goals to edit the limits.';
    });
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('screen_time_goal', _draftScreenTimeGoal);
    await prefs.setInt('notif_threshold', _draftNotificationThreshold);
    await prefs.setInt('unlock_threshold', _draftUnlockThreshold);
    if (!mounted) {
      return;
    }
    setState(() {
      _screenTimeGoal = _draftScreenTimeGoal;
      _notificationThreshold = _draftNotificationThreshold;
      _unlockThreshold = _draftUnlockThreshold;
      _isEditingGoals = false;
      _goalStatusMessage =
          'Daily goals were set. Use Reset Goals to edit the limits.';
    });
  }

  void _resetGoalDrafts() {
    setState(() {
      _draftScreenTimeGoal = _screenTimeGoal;
      _draftNotificationThreshold = _notificationThreshold;
      _draftUnlockThreshold = _unlockThreshold;
      _isEditingGoals = true;
      _goalStatusMessage =
          'Goal editing is enabled. Adjust the limits and tap Set Goals.';
    });
  }

  bool get _hasUnsavedGoalChanges =>
      _draftScreenTimeGoal != _screenTimeGoal ||
      _draftNotificationThreshold != _notificationThreshold ||
      _draftUnlockThreshold != _unlockThreshold;

  Future<void> _applyGoals() async {
    await _saveGoals();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Daily goals were set. Use Reset Goals to edit the limits.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  bool get _hasUsagePermission =>
      (_usageData?['usage_access_granted'] ?? false) == true;

  bool get _hasNotificationPermission =>
      (_usageData?['notification_permission_granted'] ?? false) == true;

  bool get _hasUsageValues {
    final screenTime =
        (_usageData?['total_screen_time_minutes'] as num?)?.toDouble() ?? 0.0;
    final topApps = (_usageData?['top_apps'] as List?) ?? const [];
    final unlocks = (_usageData?['total_unlocks'] as num?)?.toInt() ?? 0;
    final notifications =
        (_usageData?['total_notifications'] as num?)?.toInt() ?? 0;
    return screenTime > 0 ||
        topApps.isNotEmpty ||
        unlocks > 0 ||
        notifications > 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appState = context.watch<AppState>();
    final user = appState.user;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh, color: AppColors.primary),
          ),
          IconButton(
            onPressed: () async {
              await context
                  .read<AppState>()
                  .triggerPredictionFromCurrentData(context: context);
            },
            icon: const Icon(Icons.analytics, color: AppColors.primary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(user, isDark),
            const SizedBox(height: 16),
            _buildStatusCard(isDark),
            const SizedBox(height: 18),
            if (_loading) _buildLoadingState(isDark),
            if (!_loading && !_hasUsagePermission) _buildPermissionCard(isDark),
            if (!_loading && _hasUsagePermission && !_hasUsageValues)
              _buildNoDataCard(isDark),
            if (!_loading && _hasUsagePermission) ...[
              _buildSectionTitle(
                isDark,
                'Live Data Analysis',
                icon: Icons.bar_chart_rounded,
              ),
              const SizedBox(height: 12),
              _buildScreenTimeCard(isDark),
              const SizedBox(height: 16),
              _buildMetricsGrid(isDark),
              const SizedBox(height: 20),
              _buildDailyGoals(isDark),
              const SizedBox(height: 20),
              _buildMostUsedApps(isDark),
              const SizedBox(height: 20),
              _buildSevenDayScreenTime(isDark, appState.weeklyUsage),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(UserProfile? user, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    color: isDark ? AppColors.textDim : Colors.grey[700],
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.name ?? 'User',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatHeaderDate(),
                  style: TextStyle(
                    color: isDark ? AppColors.textDim : Colors.grey[600],
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _refreshData,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            ),
            icon: const Icon(Icons.refresh, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.18),
            child: Text(
              _appInitial(user?.name),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    final trackingEnabled = (_usageData?['tracking_enabled'] ?? false) == true;
    final ignoredBattery =
        (_usageData?['battery_optimization_ignored'] ?? false) == true;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: trackingEnabled
            ? const Color(0xFFEFFAE9)
            : (isDark ? AppColors.cardDark : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: trackingEnabled
              ? const Color(0xFFD6EFC9)
              : Colors.white.withValues(alpha: isDark ? 0.08 : 0.0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            trackingEnabled ? Icons.check_circle : Icons.warning_amber_rounded,
            color: trackingEnabled ? Colors.green : Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trackingEnabled
                      ? 'App is ready to sense data'
                      : 'Realtime sensing needs attention',
                  style: TextStyle(
                    color: trackingEnabled
                        ? const Color(0xFF1F5130)
                        : (isDark ? Colors.white : AppColors.textPrimary),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trackingEnabled
                      ? 'Usage access: ${_hasUsagePermission ? 'granted' : 'missing'} | Notification access: ${_hasNotificationPermission ? 'granted' : 'missing'}'
                      : 'Grant the required permissions so SmartPulse can keep reading your real device activity.',
                  style: TextStyle(
                    color: trackingEnabled
                        ? const Color(0xFF386144)
                        : (isDark ? AppColors.textDim : Colors.grey[600]),
                    height: 1.35,
                  ),
                ),
                if (!ignoredBattery) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Battery optimization is still enabled. Disabling it will keep sensing more stable in background.',
                    style: TextStyle(
                      color: trackingEnabled
                          ? const Color(0xFF386144)
                          : (isDark ? AppColors.textDim : Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await AutoSensingService.openBatteryOptimizationSettings();
                    },
                    child: const Text('Open Battery Settings'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return _buildSurfaceCard(
      isDark,
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Connecting to SmartPulse sensing service...'),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(bool isDark) {
    return _buildSurfaceCard(
      isDark,
      borderColor: Colors.orange.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Access Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              (_usageData?['fallback_message'] as String?) ??
                  'Grant usage access so SmartPulse can read the last 24 hours of app activity.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await UsageService.openUsageAccessSettings();
                  },
                  child: const Text('Open Usage Access'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    await AutoSensingService.openNotificationListenerSettings();
                  },
                  child: const Text('Open Notification Access'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataCard(bool isDark) {
    return _buildSurfaceCard(
      isDark,
      borderColor: Colors.blue.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No Usage Data Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              (_usageData?['fallback_message'] as String?) ??
                  'SmartPulse is running, but Android has not returned foreground usage yet. Open a few apps, unlock the phone, and check again.',
            ),
            const SizedBox(height: 12),
            Text(
              'Unlock count: ${_usageData?['total_unlocks'] ?? 0} | Notifications: ${_usageData?['total_notifications'] ?? 0}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(bool isDark, String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildScreenTimeCard(bool isDark) {
    final screenTimeMinutes =
        (_usageData?['total_screen_time_minutes'] as num?)?.toDouble() ?? 0.0;
    final screenTimeHours = screenTimeMinutes / 60.0;
    final progress =
        _screenTimeGoal == 0 ? 0.0 : (screenTimeHours / _screenTimeGoal);
    final ringColor = progress >= 1
        ? AppColors.riskHigh
        : progress >= 0.8
            ? AppColors.riskMedium
            : AppColors.riskLow;

    return _buildSurfaceCard(
      isDark,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final ring = SizedBox(
              width: 118,
              height: 118,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 106,
                    height: 106,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 10,
                      backgroundColor: ringColor.withValues(alpha: 0.18),
                      valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${screenTimeHours.toStringAsFixed(1)}h',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'of ${_screenTimeGoal.toStringAsFixed(0)}h',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textDim : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            final summaryContent = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${screenTimeHours.toStringAsFixed(1)} hours',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Today's Screen Time",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Daily goal: ${_screenTimeGoal.toStringAsFixed(1)}h',
                  style: TextStyle(
                    color: isDark ? AppColors.textDim : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% of goal',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ringColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Source: ${_usageData?['data_quality'] ?? 'unknown'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textDim : Colors.grey[600],
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: ring),
                  const SizedBox(height: 18),
                  summaryContent,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ring,
                const SizedBox(width: 18),
                Expanded(child: summaryContent),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    final apps = _stringDoubleMap(_usageData?['app_breakdown']);
    final socialHours = apps.entries
            .where((entry) => _isSocialApp(entry.key))
            .fold<double>(0.0, (sum, entry) => sum + entry.value) /
        60.0;
    final nightHours =
        (((_usageData?['night_usage_minutes'] as num?)?.toDouble() ?? 0.0) /
            60.0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                isDark,
                title: 'Social Apps',
                value: '${socialHours.toStringAsFixed(1)}h',
                icon: Icons.people,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                isDark,
                title: 'Night Use',
                value: '${nightHours.toStringAsFixed(1)}h',
                icon: Icons.nights_stay,
                color: Colors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                isDark,
                title: 'Unlocks',
                value: '${_usageData?['total_unlocks'] ?? 0}',
                icon: Icons.lock_open,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                isDark,
                title: 'Notifications',
                value: '${_usageData?['total_notifications'] ?? 0}',
                icon: Icons.notifications_active,
                color: Colors.cyan,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    bool isDark, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return _buildSurfaceCard(
      isDark,
      borderColor: color.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 112,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isDark ? AppColors.textDim : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyGoals(bool isDark) {
    return _buildSurfaceCard(
      isDark,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Goals & Thresholds',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 18),
            _buildGoalSlider(
              isDark,
              icon: Icons.phone_android,
              color: AppColors.primary,
              label: 'Screen Time Goal',
              valueLabel: '${_draftScreenTimeGoal.toStringAsFixed(0)}h',
              value: _draftScreenTimeGoal,
              min: 1.0,
              max: 8.0,
              divisions: 7,
              enabled: _isEditingGoals,
              onChanged: (value) {
                setState(() {
                  _draftScreenTimeGoal = value;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildGoalSlider(
              isDark,
              icon: Icons.notifications,
              color: Colors.amber,
              label: 'Notification Threshold',
              valueLabel: '$_draftNotificationThreshold',
              value: _draftNotificationThreshold.toDouble(),
              min: 10,
              max: 300,
              divisions: 29,
              enabled: _isEditingGoals,
              onChanged: (value) {
                setState(() {
                  _draftNotificationThreshold = value.round();
                });
              },
            ),
            const SizedBox(height: 16),
            _buildGoalSlider(
              isDark,
              icon: Icons.lock,
              color: Colors.cyan,
              label: 'Unlock Threshold',
              valueLabel: '$_draftUnlockThreshold',
              value: _draftUnlockThreshold.toDouble(),
              min: 10,
              max: 200,
              divisions: 19,
              enabled: _isEditingGoals,
              onChanged: (value) {
                setState(() {
                  _draftUnlockThreshold = value.round();
                });
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetGoalDrafts,
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.white : AppColors.textPrimary,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.2),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Reset Goals'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isEditingGoals && _hasUnsavedGoalChanges
                        ? _applyGoals
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Set Goals'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _goalStatusMessage ??
                  'Daily goals are set. Tap Reset Goals to edit the limits.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textDim : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSlider(
    bool isDark, {
    required IconData icon,
    required Color color,
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$label: $valueLabel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: enabled ? color : color.withValues(alpha: 0.45),
            inactiveTrackColor: color.withValues(alpha: 0.18),
            thumbColor: enabled ? color : color.withValues(alpha: 0.45),
            overlayColor:
                enabled ? color.withValues(alpha: 0.12) : Colors.transparent,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  Widget _buildMostUsedApps(bool isDark) {
    final topApps = List<Map<String, dynamic>>.from(
      (_usageData?['top_apps'] ?? const []).where(
        (dynamic app) {
          final map = app is Map ? app : null;
          final minutes = ((map?['usage_time'] as num?)?.toDouble() ?? 0.0);
          if (minutes < 1.0) {
            return false;
          }

          final packageName = (map?['package']?.toString() ?? '').toLowerCase();
          final label = (map?['name']?.toString() ?? '').toLowerCase();
          const blockedFragments = [
            'wellbeing',
            'packageinstaller',
            'permissioncontroller',
            'systemui',
            'launcher',
          ];
          const blockedLabels = [
            'digital wellbeing',
            'package installer',
            'settings services',
            'permission controller',
          ];

          return !blockedFragments.any(packageName.contains) &&
              !blockedLabels.any(label.contains);
        },
      ),
    );
    final maxMinutes = topApps.isEmpty
        ? 1.0
        : topApps
            .map((app) => ((app['usage_time'] as num?)?.toDouble() ?? 0.0))
            .reduce((a, b) => a > b ? a : b);

    return _buildSurfaceCard(
      isDark,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Most Used Apps',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'auto-sensed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? AppColors.textDim : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (topApps.isEmpty)
              Text(
                'No app usage captured yet.',
                style:
                    TextStyle(color: isDark ? AppColors.textDim : Colors.grey),
              )
            else
              ...topApps.map((app) {
                final minutes =
                    ((app['usage_time'] as num?)?.toDouble() ?? 0.0);
                final ratio = maxMinutes == 0 ? 0.0 : minutes / maxMinutes;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          app['name']?.toString() ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 12,
                            backgroundColor:
                                Colors.blueGrey.withValues(alpha: 0.35),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ratio > 0.75 ? Colors.amber : Colors.greenAccent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 58,
                        child: Text(
                          _formatMinutes(minutes),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ratio > 0.75
                                ? Colors.amber
                                : (isDark ? Colors.greenAccent : Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSevenDayScreenTime(bool isDark, List<UsageData> weeklyUsage) {
    final sorted = [...weeklyUsage]..sort((a, b) => a.date.compareTo(b.date));
    final chartData =
        sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;
    if (chartData.isEmpty) {
      return _buildSurfaceCard(
        isDark,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Screen Time',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This chart will appear after SmartPulse has collected real daily screen-time history.',
                style: TextStyle(
                  color: isDark ? AppColors.textDim : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final maxHours = [
      _screenTimeGoal,
      ...chartData.map((item) => item.screenTime),
    ].fold<double>(0, (maxValue, value) => value > maxValue ? value : maxValue);
    final chartTop = (maxHours < 4 ? 4 : maxHours).ceilToDouble() + 1;

    return _buildSurfaceCard(
      isDark,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Screen Time',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Screen hours — auto-sensed from device',
                        style: TextStyle(
                          color:
                              isDark ? AppColors.textDim : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Goal: ${_screenTimeGoal.toStringAsFixed(0)}h',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: chartTop,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color:
                          Colors.white.withValues(alpha: isDark ? 0.10 : 0.08),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: _screenTimeGoal,
                        color: Colors.amber,
                        strokeWidth: 2,
                      ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: 4,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}h',
                          style: TextStyle(
                            color:
                                isDark ? AppColors.textDim : Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= chartData.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _weekdayLabel(chartData[index].date),
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textDim
                                    : Colors.grey[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: chartData.asMap().entries.map((entry) {
                    final hours = entry.value.screenTime;
                    final overGoal = hours >= _screenTimeGoal;
                    final gradient = overGoal
                        ? const LinearGradient(
                            colors: [Color(0xFFFFB36B), Color(0xFFFF8A3D)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF5FE487), Color(0xFFE9D46A)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          );

                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: hours,
                          width: 24,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          gradient: gradient,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurfaceCard(
    bool isDark, {
    required Widget child,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              borderColor ?? Colors.white.withValues(alpha: isDark ? 0.08 : 0),
        ),
      ),
      child: child,
    );
  }

  Map<String, double> _stringDoubleMap(dynamic value) {
    if (value is! Map) {
      return <String, double>{};
    }
    return value.map<String, double>(
      (key, dynamic item) =>
          MapEntry(key.toString(), (item as num?)?.toDouble() ?? 0.0),
    );
  }

  String _formatHeaderDate() {
    final updated = _usageData?['last_updated']?.toString();
    final parsed = DateTime.tryParse(updated ?? '');
    final date = parsed ?? DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  String _formatMinutes(double minutes) {
    final rounded = minutes.round();
    if (rounded >= 60) {
      final hours = rounded ~/ 60;
      final mins = rounded % 60;
      return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
    }
    return '${rounded}m';
  }

  String _weekdayLabel(DateTime date) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[date.weekday - 1];
  }

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
      'whatsapp',
      'instagram',
      'facebook',
      'snapchat',
      'snap',
      'twitter',
      'linkedin',
      'tiktok',
      'reddit',
      'discord',
      'telegram',
      'messenger',
      'chat',
      'musical',
      'pinterest',
    ];
    return directPackages.contains(normalized) ||
        fragments.any(normalized.contains);
  }

  String _appInitial(String? name) {
    if (name == null || name.isEmpty) {
      return '?';
    }
    return name.substring(0, 1).toUpperCase();
  }
}
