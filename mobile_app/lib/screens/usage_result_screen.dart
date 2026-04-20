import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auto_sensing_service.dart';
import '../services/app_state.dart';
import '../services/usage_service.dart';

class UsageResultScreen extends StatefulWidget {
  const UsageResultScreen({super.key});

  @override
  State<UsageResultScreen> createState() => _UsageResultScreenState();
}

class _UsageResultScreenState extends State<UsageResultScreen> {
  Map<String, dynamic>? _usageStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsageData();
  }

  Future<void> _loadUsageData() async {
    try {
      // Start auto-sensing if not already active
      final isTracking = await AutoSensingService.isTracking();
      if (!isTracking) {
        await AutoSensingService.startTracking();
      }

      // Get comprehensive usage statistics
      final stats = await AutoSensingService.getComprehensiveUsageStats();
      setState(() {
        _usageStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading usage data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    print('[UsageResultScreen] DEBUG: Manual refresh triggered');
    setState(() {
      _isLoading = true;
    });

    try {
      // First, run the direct native test to debug the issue
      print(
          '[UsageResultScreen] DEBUG: Running direct native UsageStats test...');
      final nativeTestResult = await UsageService.testUsageStatsDirect();

      if (nativeTestResult != null) {
        print('[UsageResultScreen] DEBUG: Native test completed');
        if (nativeTestResult['anyDataFound'] == true) {
          print(
              '[UsageResultScreen] DEBUG: Native test found real usage data');
        } else {
          print(
              '[UsageResultScreen] DEBUG: Native test found NO data - this indicates UsageStats is not working on this device');
        }
      }

      // Force fresh data by clearing any caches first
      print(
          '[UsageResultScreen] DEBUG: Clearing caches and forcing fresh data...');

      // Restart tracking to ensure fresh data
      await AutoSensingService.startTracking();

      // Wait a moment for tracking to initialize
      await Future.delayed(const Duration(seconds: 2));

      // Get fresh comprehensive usage statistics
      final stats = await AutoSensingService.getComprehensiveUsageStats();
      print('[UsageResultScreen] DEBUG: Fresh stats received: ${stats.keys}');
      print(
          '[UsageResultScreen] DEBUG: Screen time: ${stats['total_screen_time_minutes']}');
      print(
          '[UsageResultScreen] DEBUG: Apps found: ${(stats['top_apps'] as List?)?.length ?? 0}');
      print(
          '[UsageResultScreen] DEBUG: Data quality: ${stats['data_quality']}');

      setState(() {
        _usageStats = stats;
        _isLoading = false;
      });

      if (mounted) {
        final appsFound = (stats['top_apps'] as List?)?.length ?? 0;
        final message = nativeTestResult != null &&
                nativeTestResult['anyDataFound'] == true
            ? 'Data refreshed from native sensing. Found $appsFound apps.'
            : 'Refresh complete. Found $appsFound apps.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: appsFound > 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('[UsageResultScreen] DEBUG: Refresh failed: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'High Risk':
        return Colors.red;
      case 'Medium Risk':
        return Colors.orange;
      case 'Low Risk':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_usageStats == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load usage data',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final stats = _usageStats!;
    final riskColor = _getRiskColor(stats['risk_level']);
    final hasPermission = (stats['permission_granted'] ?? false) == true;
    final hasUsageData =
        ((stats['total_screen_time_minutes'] as num?)?.toDouble() ?? 0.0) > 0 ||
            ((stats['top_apps'] as List?)?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Usage Analytics',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2C3E50),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing usage data...'),
                  duration: Duration(seconds: 2),
                ),
              );
              _refreshData();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Usage Data',
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Daily Prediction Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: appState.hasTodayPrediction
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.orange.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              appState.hasTodayPrediction
                                  ? Icons.check_circle
                                  : Icons.schedule,
                              size: 30,
                              color: appState.hasTodayPrediction
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Prediction Status',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2C3E50),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  appState.hasTodayPrediction
                                      ? 'Today\'s prediction is ready!'
                                      : 'Prediction will be generated automatically near midnight',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (appState.hasTodayPrediction) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getRiskColor(appState
                                              .todayPrediction!.addictionLevel)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${appState.todayPrediction!.addictionLevel} Risk',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _getRiskColor(appState
                                            .todayPrediction!.addictionLevel),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!appState.hasTodayPrediction) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              await appState.triggerDailyPrediction(
                                  context: context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Get Daily Prediction Now',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Risk Level Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.warning,
                              size: 30,
                              color: riskColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Risk Level',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  hasPermission
                                      ? (hasUsageData
                                          ? stats['risk_level']
                                          : 'Waiting for Data')
                                      : 'Permission Required',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: riskColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Screen Time',
                        '${(stats['total_screen_time_minutes'] as num?)?.toStringAsFixed(0) ?? '0'} min/day',
                        Icons.access_time,
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatCard(
                        'Total Unlocks',
                        '${stats['total_unlocks']}',
                        Icons.screen_lock_rotation,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Notifications',
                        '${stats['total_notifications']}',
                        Icons.notifications,
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildStatCard(
                        'Apps Used',
                        '${stats['total_apps_used']}',
                        Icons.apps,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                if (!hasPermission)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Text(
                      'Usage access is not granted yet. Open the permission screen and enable Usage Access and Notification Access.',
                    ),
                  ),

                if (hasPermission && !hasUsageData)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      stats['fallback_message'] ??
                          'SmartPulse is running, but Android has not returned enough usage data yet.',
                    ),
                  ),

                const SizedBox(height: 8),

                // Top Apps Section
                Text(
                  'Top Used Apps',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 16),

                // Top Apps List
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: ((stats['top_apps'] as List?) ?? const [])
                            .map((app) => _buildAppTile(
                                Map<String, dynamic>.from(app as Map)))
                            .toList()
                            .cast<Widget>()
                        +
                        (((stats['top_apps'] as List?) ?? const []).isEmpty
                            ? [
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('No app usage captured yet.'),
                                )
                              ]
                            : []),
                  ),
                ),

                const SizedBox(height: 24),

                // Recommendations Section
                Text(
                  'Recommendations',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: _getRecommendations(stats['risk_level']),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTile(Map<String, dynamic> app) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.apps, color: Colors.blue),
      ),
      title: Text(
        app['name'],
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: Text(
        '${app['usage_time']} min • ${app['open_count']} opens',
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey[600],
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getAppUsageColor(app['usage_time']),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${app['usage_time']}m',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Color _getAppUsageColor(int usageTime) {
    if (usageTime > 60) return Colors.red;
    if (usageTime > 30) return Colors.orange;
    return Colors.green;
  }

  List<Widget> _getRecommendations(String riskLevel) {
    switch (riskLevel) {
      case 'High Risk':
        return [
          _buildRecommendation(
            'Limit Screen Time',
            'Set daily screen time limits and use app timers',
            Icons.timer,
          ),
          _buildRecommendation(
            'Take Regular Breaks',
            'Use the 20-20-20 rule: 20min work, 20min break, 20min work',
            Icons.schedule,
          ),
          _buildRecommendation(
            'Enable Digital Wellbeing',
            'Use built-in Android digital wellbeing features',
            Icons.settings,
          ),
        ];
      case 'Medium Risk':
        return [
          _buildRecommendation(
            'Reduce App Usage',
            'Focus on reducing usage of top apps',
            Icons.trending_down,
          ),
          _buildRecommendation(
            'Set Bedtime Mode',
            'Enable grayscale and reduce blue light before bed',
            Icons.bedtime,
          ),
        ];
      case 'Low Risk':
        return [
          _buildRecommendation(
            'Maintain Balance',
            'Keep up the good digital habits',
            Icons.thumb_up,
          ),
          _buildRecommendation(
            'Monitor Usage',
            'Continue tracking your usage patterns',
            Icons.analytics,
          ),
        ];
      default:
        return [
          _buildRecommendation(
            'Grant Permission',
            'Please grant usage access to see recommendations',
            Icons.security,
          ),
        ];
    }
  }

  Widget _buildRecommendation(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
