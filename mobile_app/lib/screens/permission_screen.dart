import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../services/auto_sensing_service.dart';
import '../services/usage_service.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _usagePermissionGranted = false;
  bool _notificationPermissionGranted = false;
  bool _batteryOptimizationIgnored = false;
  bool _skipBatteryOptimization = false;
  bool _permissionsValidated = false;
  Timer? _permissionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionStatus();
    _permissionTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _checkPermissionStatus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkPermissionStatus();
        }
      });
    }
  }

  Future<void> _checkPermissionStatus() async {
    if (!mounted) {
      return;
    }

    setState(() => _isLoading = true);

    final hasUsagePermission = await UsageService.hasUsageStatsPermission();
    final hasNotificationPermission =
        await AutoSensingService.hasNotificationListenerPermission();
    final batteryOptimizationIgnored =
        await AutoSensingService.isIgnoringBatteryOptimizations();

    if (!mounted) {
      return;
    }

    setState(() {
      _usagePermissionGranted = hasUsagePermission;
      _notificationPermissionGranted = hasNotificationPermission;
      _batteryOptimizationIgnored = batteryOptimizationIgnored;
      _isLoading = false;
    });

    await context.read<AppState>().requestUsagePermission();

    final readyForHome = hasUsagePermission &&
        hasNotificationPermission &&
        (batteryOptimizationIgnored || _skipBatteryOptimization);
    if (!readyForHome && _permissionsValidated) {
      setState(() {
        _permissionsValidated = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Enable Permissions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.security, size: 48, color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'SmartPulse Needs Permissions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Enable these permissions to start tracking your digital wellbeing',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildPermissionCard(
                icon: Icons.phone_android,
                title: 'Usage Access',
                description:
                    'Allows SmartPulse to track your app usage patterns and screen time.',
                color: Colors.blue,
                onPressed: () async {
                  await UsageService.openUsageAccessSettings();
                  await Future.delayed(const Duration(seconds: 1));
                  await _checkPermissionStatus();
                },
              ),
              const SizedBox(height: 16),
              _buildPermissionCard(
                icon: Icons.notifications,
                title: 'Notification Access',
                description:
                    'Allows SmartPulse to count notifications in realtime.',
                color: Colors.purple,
                onPressed: () async {
                  await AutoSensingService.openNotificationListenerSettings();
                  await Future.delayed(const Duration(seconds: 1));
                  await _checkPermissionStatus();
                },
              ),
              const SizedBox(height: 16),
              _buildPermissionCard(
                icon: Icons.battery_saver,
                title: 'Battery Optimization',
                description:
                    'Disable battery optimization so sensing keeps running in the background.',
                color: Colors.teal,
                onPressed: () async {
                  await AutoSensingService.openBatteryOptimizationSettings();
                  await Future.delayed(const Duration(seconds: 1));
                  await _checkPermissionStatus();
                },
              ),
              const SizedBox(height: 12),
              if (_batteryOptimizationIgnored)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Battery optimization already disabled'),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Already Enabled Permissions?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'If Usage Access and Notification Access are already enabled, refresh below. Battery optimization is recommended but optional.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _checkPermissionStatus,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Usage Access Permission'),
                      subtitle: const Text(
                        'Enabled in Settings > Apps > Special access > Usage access',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      value: _usagePermissionGranted,
                      onChanged: null,
                    ),
                    CheckboxListTile(
                      title: const Text('Notification Listener Permission'),
                      subtitle: const Text(
                        'Enabled in Settings > Apps > Special access > Notification access',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      value: _notificationPermissionGranted,
                      onChanged: null,
                    ),
                    CheckboxListTile(
                      title: const Text('Skip Battery Optimization For Now'),
                      subtitle: const Text(
                        'You can continue now and disable it later if needed.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      value: _skipBatteryOptimization,
                      onChanged: (value) {
                        setState(() {
                          _skipBatteryOptimization = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('I verified the permissions above'),
                      subtitle: const Text(
                        'Continue only after checking this confirmation.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      value: _permissionsValidated,
                      onChanged:
                          (_usagePermissionGranted &&
                                  _notificationPermissionGranted &&
                                  (_batteryOptimizationIgnored ||
                                      _skipBatteryOptimization))
                              ? (value) {
                                  setState(() {
                                    _permissionsValidated = value ?? false;
                                  });
                                }
                              : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_usagePermissionGranted &&
                                _notificationPermissionGranted &&
                                (_batteryOptimizationIgnored ||
                                    _skipBatteryOptimization) &&
                                _permissionsValidated)
                            ? () async {
                                await state.markPermissionsManuallyGranted();
                                if (mounted) {
                                  Navigator.of(context)
                                      .pushReplacementNamed('/home');
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Continue to Home Screen',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
