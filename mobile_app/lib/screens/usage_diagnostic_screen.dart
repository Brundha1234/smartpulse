import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../services/usage_service.dart';

class UsageDiagnosticScreen extends StatefulWidget {
  const UsageDiagnosticScreen({super.key});

  @override
  State<UsageDiagnosticScreen> createState() => _UsageDiagnosticScreenState();
}

class _UsageDiagnosticScreenState extends State<UsageDiagnosticScreen> {
  final List<String> _logs = [];
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _logs.add("[${DateTime.now().toString().substring(11, 19)}] $message");
      if (_logs.length > 50) _logs.removeAt(0);
    });
    print(message);
  }

  Future<void> _runComprehensiveDiagnostic() async {
    setState(() => _isRunning = true);
    _addLog("=== COMPREHENSIVE USAGE DIAGNOSTIC ===");

    try {
      // Test 1: Basic Permission Check
      _addLog("1. TESTING BASIC PERMISSION...");
      await _testBasicPermission();

      // Test 2: Native Android Direct Test
      _addLog("\n2. TESTING NATIVE ANDROID DIRECT...");
      await _testNativeDirect();

      // Test 3: Flutter Plugin Test
      _addLog("\n3. TESTING FLUTTER USAGE_STATS PLUGIN...");
      await _testFlutterPlugin();

      // Test 4: Device Information
      _addLog("\n4. COLLECTING DEVICE INFORMATION...");
      await _collectDeviceInfo();

      // Test 5: Manual Usage Access Test
      _addLog("\n5. TESTING MANUAL USAGE ACCESS...");
      await _testManualUsageAccess();
    } catch (e) {
      _addLog("DIAGNOSTIC ERROR: $e");
    }

    _addLog("\n=== DIAGNOSTIC COMPLETE ===");
    setState(() => _isRunning = false);
  }

  Future<void> _testBasicPermission() async {
    try {
      const platform = MethodChannel('com.example.smartpulse/usage');
      final hasPermission =
          await platform.invokeMethod('checkUsageAccessPermission');
      final hasNotificationPermission =
          await platform.invokeMethod('hasNotificationPermission');
      final ignoringBatteryOptimizations =
          await platform.invokeMethod('isIgnoringBatteryOptimizations');
      _addLog("   Permission status: $hasPermission");
      _addLog("   Notification access: $hasNotificationPermission");
      _addLog(
          "   Battery optimization ignored: $ignoringBatteryOptimizations");

      if (hasPermission == true) {
        _addLog("   Permission appears to be GRANTED");
      } else {
        _addLog("   Permission appears to be DENIED");
        _addLog("   ACTION REQUIRED: Enable Usage Access in Android Settings");
      }
    } catch (e) {
      _addLog("   Permission check failed: $e");
    }
  }

  Future<void> _testNativeDirect() async {
    try {
      final result = await UsageService.testUsageStatsDirect();
      if (result == null) {
        _addLog("   Native test returned no result");
        return;
      }

      if (result['anyDataFound'] == true) {
        _addLog("   NATIVE TEST: SUCCESS - Data found!");
        _addLog("   Native UsageStats returned real app activity");

        // Show found data
        final snapshot = Map<String, dynamic>.from(result['last24Hours'] ?? {});
        _addLog(
            "   Last 24h screen time: ${snapshot['total_screen_time_minutes'] ?? 0} min");
        _addLog("   Unlocks: ${snapshot['total_unlocks'] ?? 0}");
        _addLog("   Notifications: ${snapshot['total_notifications'] ?? 0}");
        _addLog(
            "   Top apps found: ${(snapshot['top_apps'] as List?)?.length ?? 0}");
      } else {
        _addLog("   NATIVE TEST: NO DATA FOUND");
        _addLog("   This means UsageStats is not working on this device");
      }

      // Show device info
      if (result['systemInfo'] != null) {
        final info = result['systemInfo'];
        _addLog("   Device: ${info['manufacturer']} ${info['model']}");
        _addLog(
            "   Android: ${info['androidVersion']} (API ${info['sdkVersion']})");
      }
    } catch (e) {
      _addLog("   Native test failed: $e");
    }
  }

  Future<void> _testFlutterPlugin() async {
    _addLog("   Flutter now uses native MethodChannel + EventChannel sensing.");
    _addLog("   Legacy plugin path is no longer the primary realtime source.");
  }

  Future<void> _collectDeviceInfo() async {
    try {
      _addLog("   Platform: ${Platform.operatingSystem}");
      _addLog("   Current time: ${DateTime.now()}");

      // Try to get Android-specific info
      try {
        final result = await UsageService.testUsageStatsDirect();
        if (result != null && result['systemInfo'] != null) {
          final info = result['systemInfo'];
          _addLog("   Package name: ${info['package']}");
          _addLog("   SDK Version: ${info['sdkVersion']}");
        }
      } catch (e) {
        _addLog("   Could not get Android info: $e");
      }
    } catch (e) {
      _addLog("   Device info collection failed: $e");
    }
  }

  Future<void> _testManualUsageAccess() async {
    try {
      _addLog("   Checking if Usage Access is properly enabled...");
      final snapshot = await UsageService.getUsageStatistics();
      _addLog(
          "   Current snapshot status: ${snapshot['status']} (${snapshot['data_quality']})");
      _addLog(
          "   Screen time sensed: ${snapshot['total_screen_time_minutes']} min");
      _addLog("   Unlocks sensed: ${snapshot['total_unlocks']}");
      _addLog("   Notifications sensed: ${snapshot['total_notifications']}");

      _addLog("   MANUAL CHECK REQUIRED:");
      _addLog("   1. Go to Android Settings");
      _addLog("   2. Apps & Notifications");
      _addLog("   3. Special Access");
      _addLog("   4. Usage Access");
      _addLog("   5. Find SmartPulse and ensure it's ENABLED");
    } catch (e) {
      _addLog("   Manual usage access test failed: $e");
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Usage Diagnostic Tool"),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _runComprehensiveDiagnostic,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: _isRunning
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text("DIAGNOSING..."),
                            ],
                          )
                        : const Text("RUN COMPREHENSIVE DIAGNOSTIC"),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _clearLogs,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("CLEAR"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Diagnostic Results:",
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
                      color: Colors.lime,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "If no data is found after this diagnostic, UsageStats may not be supported on your device.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
