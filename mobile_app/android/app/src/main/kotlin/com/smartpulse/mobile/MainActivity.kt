package com.smartpulse.mobile

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.example.smartpulse/usage"
        private const val STREAM_CHANNEL = "com.example.smartpulse/usage_stream"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        SmartPulseDataBridge.attachEventChannel(
            EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    SmartPulseDataBridge.publishLatest(applicationContext)
                    result.success(true)
                }

                "startTracking" -> {
                    try {
                        SmartPulseUsageRepository.setTrackingEnabled(applicationContext, true)
                        SmartPulseForegroundService.start(applicationContext)
                        SmartPulseDataBridge.publishLatest(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error starting tracking", e)
                        result.error("ERROR", "Failed to start tracking", e.message)
                    }
                }

                "stopTracking" -> {
                    try {
                        SmartPulseUsageRepository.setTrackingEnabled(applicationContext, false)
                        SmartPulseForegroundService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error stopping tracking", e)
                        result.error("ERROR", "Failed to stop tracking", e.message)
                    }
                }

                "getRealtimeUsageData", "getCurrentUsageSnapshot" -> {
                    try {
                        result.success(SmartPulseUsageRepository.buildSnapshot(applicationContext))
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting usage data", e)
                        result.error("ERROR", "Failed to get usage data", e.message)
                    }
                }

                "checkUsageAccessPermission", "hasUsageStatsPermission" -> {
                    result.success(SmartPulseUsageRepository.hasUsageAccessPermission(applicationContext))
                }

                "openUsageAccessSettings", "requestUsageStatsPermission" -> {
                    openUsageAccessSettings()
                    result.success(true)
                }

                "hasNotificationPermission" -> {
                    result.success(SmartPulseUsageRepository.hasNotificationAccessPermission(applicationContext))
                }

                "getEnabledNotificationListeners" -> {
                    result.success(
                        Settings.Secure.getString(
                            contentResolver,
                            "enabled_notification_listeners"
                        ) ?: ""
                    )
                }

                "getPackageName" -> result.success(packageName)

                "getAppLastUpdateTime" -> {
                    try {
                        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(
                                packageName,
                                android.content.pm.PackageManager.PackageInfoFlags.of(0)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        result.success(packageInfo.lastUpdateTime)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting app last update time", e)
                        result.success(0L)
                    }
                }

                "requestNotificationPermission",
                "openNotificationListenerSettings",
                "openNotificationSettings",
                "openAppNotificationSettings" -> {
                    openNotificationAccessSettings()
                    result.success(true)
                }

                "simulateUnlock" -> {
                    SmartPulseUsageRepository.incrementUnlockCount(applicationContext)
                    SmartPulseDataBridge.publishLatest(applicationContext)
                    result.success(true)
                }

                "getUnlockCount" -> {
                    result.success(SmartPulseUsageRepository.getUnlockCount(applicationContext))
                }

                "resetUnlockCount", "resetCounters" -> {
                    SmartPulseUsageRepository.resetCounters(applicationContext)
                    SmartPulseDataBridge.publishLatest(applicationContext)
                    result.success(true)
                }

                "isIgnoringBatteryOptimizations" -> {
                    try {
                        val powerManager = getSystemService(PowerManager::class.java)
                        result.success(powerManager?.isIgnoringBatteryOptimizations(packageName) == true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Battery optimization check failed", e)
                        result.success(false)
                    }
                }

                "openBatteryOptimizationSettings" -> {
                    try {
                        openBatteryOptimizationSettings()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error opening battery optimization settings", e)
                        result.error("ERROR", "Could not open battery optimization settings", e.message)
                    }
                }

                "testUsageStatsDirect" -> {
                    try {
                        val snapshot = SmartPulseUsageRepository.buildSnapshot(applicationContext)
                        result.success(
                            mapOf(
                                "anyDataFound" to ((snapshot["top_apps"] as? List<*>)?.isNotEmpty() == true),
                                "systemInfo" to mapOf(
                                    "androidVersion" to Build.VERSION.RELEASE,
                                    "sdkVersion" to Build.VERSION.SDK_INT,
                                    "manufacturer" to Build.MANUFACTURER,
                                    "model" to Build.MODEL,
                                    "package" to packageName,
                                    "currentTime" to System.currentTimeMillis()
                                ),
                                "last24Hours" to snapshot
                            )
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in direct UsageStats test", e)
                        result.error("ERROR", "Direct test failed", e.message)
                    }
                }

                else -> result.notImplemented()
            }
        }

        Log.d(TAG, "MainActivity configured with SmartPulse channels")
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun openNotificationAccessSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun openBatteryOptimizationSettings() {
        val packageUri = Uri.parse("package:$packageName")
        val directIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = packageUri
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            startActivity(directIntent)
        } catch (error: Exception) {
            Log.w(TAG, "Direct battery optimization request failed", error)
            startActivity(fallbackIntent)
        }
    }
}
