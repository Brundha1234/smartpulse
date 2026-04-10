import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/services/auto_sensing_service.dart';
import 'lib/services/usage_service.dart';

void main() {
  runApp(const MaterialApp(
    home: NotificationServiceTestScreen(),
  ));
}

class NotificationServiceTestScreen extends StatefulWidget {
  const NotificationServiceTestScreen({super.key});

  @override
  State<NotificationServiceTestScreen> createState() =>
      _NotificationServiceTestScreenState();
}

class _NotificationServiceTestScreenState
    extends State<NotificationServiceTestScreen> {
  final List<String> _logs = [];
  bool _isTesting = false;

  void _addLog(String message) {
    setState(() {
      _logs.add("[${DateTime.now().toString().substring(11, 19)}] $message");
      if (_logs.length > 25) _logs.removeAt(0);
    });
    print(message);
  }

  Future<void> _runCompleteTest() async {
    setState(() => _isTesting = true);
    _addLog("=== COMPLETE SENSING TEST ===");

    try {
      // Test 1: Usage Access Permission
      _addLog("1. Testing Usage Access Permission...");
      final usagePermission = await UsageService.hasUsageStatsPermission();
      _addLog("   Usage Permission: $usagePermission");

      if (usagePermission) {
        _addLog("   Testing usage data retrieval...");
        final usageData = await UsageService.getUsageStatistics();
        _addLog(
            "   Screen time: ${usageData['total_screen_time_minutes']} minutes");
        _addLog(
            "   Apps found: ${(usageData['top_apps'] as List?)?.length ?? 0}");
      }

      // Test 2: Notification Access Permission
      _addLog("2. Testing Notification Access Permission...");
      final notificationPermission =
          await AutoSensingService.hasNotificationListenerPermission();
      _addLog("   Notification Permission: $notificationPermission");

      // Test 3: Combined Data Test
      _addLog("3. Testing Combined Data Collection...");
      if (usagePermission && notificationPermission) {
        final combinedData =
            await AutoSensingService.getComprehensiveUsageStats();
        _addLog(
            "   Combined screen time: ${combinedData['total_screen_time_minutes']} minutes");
        _addLog("   Combined unlocks: ${combinedData['total_unlocks']}");
        _addLog(
            "   Combined notifications: ${combinedData['total_notifications']}");
        _addLog(
            "   Auto-sensing active: ${combinedData['auto_sensing_active']}");
      } else {
        _addLog("   Skipping combined test - permissions missing");
      }

      // Test 4: Real-time Data Stream
      _addLog("4. Testing Real-time Data Stream...");
      try {
        final realtimeData = await AutoSensingService.getRealtimeUsageData();
        _addLog(
            "   Real-time screen time: ${realtimeData['screen_time_minutes']} minutes");
        _addLog("   Real-time unlocks: ${realtimeData['unlock_count']}");
        _addLog(
            "   Real-time notifications: ${realtimeData['notification_count']}");
      } catch (e) {
        _addLog("   Real-time test failed: $e");
      }

      // Test 5: Today's Summary
      _addLog("5. Testing Today's Summary...");
      try {
        final todaySummary = await AutoSensingService.getTodayUsageSummary();
        _addLog(
            "   Today screen time: ${todaySummary['screen_time_minutes']} minutes");
        _addLog("   Today unlocks: ${todaySummary['unlock_count']}");
        _addLog(
            "   Today notifications: ${todaySummary['notification_count']}");
        _addLog("   Risk level: ${todaySummary['risk_level']}");
      } catch (e) {
        _addLog("   Summary test failed: $e");
      }

      // Final Status
      _addLog("=== TEST RESULTS ===");
      _addLog(
          "Usage Access: ${usagePermission ? '✅ WORKING' : '❌ NOT GRANTED'}");
      _addLog(
          "Notification Access: ${notificationPermission ? '✅ WORKING' : '❌ NOT GRANTED'}");
      _addLog(
          "Complete Sensing: ${(usagePermission && notificationPermission) ? '✅ FULLY FUNCTIONAL' : '⚠️ PARTIAL'}");
    } catch (e) {
      _addLog("ERROR: $e");
    }

    _addLog("=== TEST COMPLETE ===");
    setState(() => _isTesting = false);
  }

  Future<void> _clearCache() async {
    _addLog("Clearing all caches...");
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _addLog("Cache cleared - permissions will be rechecked fresh");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Sensing Test"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTesting ? null : _runCompleteTest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: _isTesting
                        ? const Text("TESTING...")
                        : const Text("RUN COMPLETE TEST"),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _clearCache,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("CLEAR"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Complete Sensing Test Logs:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.black,
                child: SingleChildScrollView(
                  child: Text(
                    _logs.join('\n'),
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
