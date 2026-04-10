package com.smartpulse.mobile

import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

object SmartPulseUsageRepository {
    private const val TAG = "SmartPulseUsageRepo"
    private const val PREFS_NAME = "smartpulse_monitor"
    private const val TRACKING_ENABLED_KEY = "tracking_enabled"
    private const val TRACKING_SESSION_START_KEY = "tracking_session_start"
    private const val USAGE_PERMISSION_SESSION_ALIGNED_KEY = "usage_permission_session_aligned"
    private const val AGGREGATE_BASELINE_USAGE_KEY = "aggregate_baseline_usage"
    private const val AGGREGATE_BASELINE_DAY_START_KEY = "aggregate_baseline_day_start"
    private const val APK_LAST_UPDATE_TIME_KEY = "apk_last_update_time"
    private const val LAST_EVENT_TIMESTAMP_KEY = "last_event_ts"
    private const val CURRENT_FOREGROUND_PACKAGE_KEY = "current_fg_pkg"
    private const val CURRENT_FOREGROUND_START_KEY = "current_fg_start"
    private const val USAGE_BY_APP_KEY = "usage_by_app_ms"
    private const val OPEN_COUNTS_KEY = "open_counts"
    private const val PEAK_HOUR_BUCKETS_KEY = "peak_hour_buckets"
    private const val NIGHT_USAGE_MS_KEY = "night_usage_ms"
    private const val UNLOCK_COUNT_KEY = "unlock_count"
    private const val LAST_UNLOCK_EVENT_TS_KEY = "last_unlock_event_ts"
    private const val LAST_KEYGUARD_LOCKED_KEY = "last_keyguard_locked"
    private const val NOTIFICATION_TOTAL_KEY = "notification_total"
    private const val NOTIFICATION_BY_APP_KEY = "notification_by_app"
    private const val SESSION_DURATION_MS = 24L * 60L * 60L * 1000L
    private const val UNLOCK_DEDUP_WINDOW_MS = 1500L

    private val excludedPackages = setOf(
        "android",
        "com.android.systemui",
        "com.google.android.permissioncontroller",
        "com.sec.android.app.launcher",
        "com.sec.android.app.samsungapps",
        "com.samsung.android.launcher",
        "com.google.android.apps.nexuslauncher",
        "com.android.launcher",
        "com.miui.home",
        "com.oppo.launcher",
        "com.coloros.launcher",
        "com.vivo.launcher"
    )

    fun setTrackingEnabled(context: Context, enabled: Boolean) {
        ensureRepositoryState(context)
        val prefs = prefs(context)
        val wasEnabled = prefs.getBoolean(TRACKING_ENABLED_KEY, false)
        prefs.edit().putBoolean(TRACKING_ENABLED_KEY, enabled).apply()
        if (enabled) {
            ensureTrackingSession(context, forceNewSession = !wasEnabled)
        }
        mirrorFlutterInt(context, "tracking_enabled", if (enabled) 1 else 0)
    }

    fun isTrackingEnabled(context: Context): Boolean {
        ensureRepositoryState(context)
        return prefs(context).getBoolean(TRACKING_ENABLED_KEY, false)
    }

    fun hasUsageAccessPermission(context: Context): Boolean {
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (error: Exception) {
            Log.e(TAG, "Failed to check usage access permission", error)
            false
        }
    }

    fun hasNotificationAccessPermission(context: Context): Boolean {
        val enabledListeners = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        val expected =
            ComponentName(context, SmartPulseNotificationListenerService::class.java).flattenToString()
        return enabledListeners.contains(expected)
    }

    fun incrementUnlockCount(context: Context) {
        ensureRepositoryState(context)
        ensureTrackingSession(context, forceNewSession = false)
        val prefs = prefs(context)
        val now = System.currentTimeMillis()
        val lastUnlockTs = prefs.getLong(LAST_UNLOCK_EVENT_TS_KEY, 0L)
        if (now - lastUnlockTs < UNLOCK_DEDUP_WINDOW_MS) {
            return
        }

        val current = prefs.getInt(UNLOCK_COUNT_KEY, 0) + 1
        prefs.edit()
            .putInt(UNLOCK_COUNT_KEY, current)
            .putLong(LAST_UNLOCK_EVENT_TS_KEY, now)
            .apply()
        mirrorFlutterInt(context, "unlock_count", current)
        Log.d(TAG, "Unlock count incremented to $current")
    }

    fun getUnlockCount(context: Context): Int {
        ensureRepositoryState(context)
        ensureTrackingSession(context, forceNewSession = false)
        return prefs(context).getInt(UNLOCK_COUNT_KEY, 0)
    }

    fun incrementNotificationCount(context: Context, packageName: String) {
        ensureRepositoryState(context)
        ensureTrackingSession(context, forceNewSession = false)
        val prefs = prefs(context)
        val total = prefs.getInt(NOTIFICATION_TOTAL_KEY, 0) + 1
        val perApp = readIntMap(prefs.getString(NOTIFICATION_BY_APP_KEY, null))
        perApp[packageName] = (perApp[packageName] ?: 0) + 1

        prefs.edit()
            .putInt(NOTIFICATION_TOTAL_KEY, total)
            .putString(NOTIFICATION_BY_APP_KEY, JSONObject(perApp as Map<*, *>).toString())
            .apply()

        mirrorFlutterInt(context, "notification_count", total)
        Log.d(TAG, "Notification count incremented to $total for $packageName")
    }

    fun resetCounters(context: Context) {
        ensureRepositoryState(context)
        ensureTrackingSession(context, forceNewSession = true)
        mirrorFlutterInt(context, "unlock_count", 0)
        mirrorFlutterInt(context, "notification_count", 0)
    }

    fun refreshTrackingState(context: Context) {
        ensureRepositoryState(context)
        if (!isTrackingEnabled(context)) {
            return
        }
        if (!hasUsageAccessPermission(context)) {
            return
        }

        val sessionStart = ensureTrackingSession(context, forceNewSession = false)
        val sessionEnd = sessionStart + SESSION_DURATION_MS
        val now = minOf(System.currentTimeMillis(), sessionEnd)
        val prefs = prefs(context)
        var lastEventTs = prefs.getLong(LAST_EVENT_TIMESTAMP_KEY, sessionStart)
        if (lastEventTs < sessionStart) {
            lastEventTs = sessionStart
        }
        if (lastEventTs >= now) {
            return
        }

        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val usageByApp = readLongMap(prefs.getString(USAGE_BY_APP_KEY, null))
        val openCounts = readIntMap(prefs.getString(OPEN_COUNTS_KEY, null))
        val hourlyBuckets = readHourlyBuckets(prefs.getString(PEAK_HOUR_BUCKETS_KEY, null))
        var nightUsageMs = prefs.getLong(NIGHT_USAGE_MS_KEY, 0L)
        var currentForegroundPackage = prefs.getString(CURRENT_FOREGROUND_PACKAGE_KEY, null)
        var currentForegroundStart = prefs.getLong(CURRENT_FOREGROUND_START_KEY, 0L)

        val events = usageStatsManager.queryEvents(lastEventTs, now)
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            val eventTs = event.timeStamp

            when {
                isResumeEvent(event.eventType) -> {
                    if (currentForegroundPackage != null && currentForegroundStart > 0L) {
                        val segmentEnd = minOf(eventTs, now)
                        if (segmentEnd > currentForegroundStart) {
                            addUsageSegment(
                                usageByApp,
                                currentForegroundPackage,
                                currentForegroundStart,
                                segmentEnd
                            )
                            nightUsageMs += calculateNightOverlap(currentForegroundStart, segmentEnd)
                        }
                    }

                    if (shouldIncludeApp(context, packageName)) {
                        currentForegroundPackage = packageName
                        currentForegroundStart = eventTs
                        openCounts[packageName] = (openCounts[packageName] ?: 0) + 1
                        val hour = Calendar.getInstance().apply {
                            timeInMillis = eventTs
                        }.get(Calendar.HOUR_OF_DAY)
                        hourlyBuckets[hour] = hourlyBuckets[hour] + 1
                    } else {
                        currentForegroundPackage = null
                        currentForegroundStart = 0L
                    }
                }

                isPauseEvent(event.eventType) -> {
                    if (currentForegroundPackage == packageName && currentForegroundStart > 0L) {
                        val segmentEnd = minOf(eventTs, now)
                        if (segmentEnd > currentForegroundStart) {
                            addUsageSegment(
                                usageByApp,
                                packageName,
                                currentForegroundStart,
                                segmentEnd
                            )
                            nightUsageMs += calculateNightOverlap(currentForegroundStart, segmentEnd)
                        }
                        currentForegroundPackage = null
                        currentForegroundStart = 0L
                    }
                }
            }
        }

        prefs.edit()
            .putLong(LAST_EVENT_TIMESTAMP_KEY, now)
            .putString(USAGE_BY_APP_KEY, JSONObject(usageByApp as Map<*, *>).toString())
            .putString(OPEN_COUNTS_KEY, JSONObject(openCounts as Map<*, *>).toString())
            .putString(PEAK_HOUR_BUCKETS_KEY, JSONArray(hourlyBuckets.toList()).toString())
            .putLong(NIGHT_USAGE_MS_KEY, nightUsageMs)
            .putString(CURRENT_FOREGROUND_PACKAGE_KEY, currentForegroundPackage)
            .putLong(CURRENT_FOREGROUND_START_KEY, currentForegroundStart)
            .apply()
    }

    fun buildSnapshot(context: Context): Map<String, Any?> {
        ensureRepositoryState(context)
        val now = System.currentTimeMillis()
        val trackingEnabled = isTrackingEnabled(context)
        val usageGranted = hasUsageAccessPermission(context)
        val notificationGranted = hasNotificationAccessPermission(context)
        val ignoringBatteryOptimizations = isIgnoringBatteryOptimizations(context)
        val sessionStart = if (trackingEnabled) {
            ensureUsagePermissionAlignedSession(context, usageGranted)
        } else {
            0L
        }
        val sessionEnd = if (sessionStart > 0L) sessionStart + SESSION_DURATION_MS else 0L
        val effectiveEnd = if (sessionStart > 0L) minOf(now, sessionEnd) else now
        val sessionComplete = sessionStart > 0L && now >= sessionEnd

        if (trackingEnabled) {
            updateUnlockStateFromKeyguard(context)
        }

        val prefs = prefs(context)
        val usageByApp = mutableMapOf<String, Long>()
        val openCounts = mutableMapOf<String, Int>()
        val hourlyBuckets = IntArray(24)
        var nightUsageMs = 0L

        if (trackingEnabled && usageGranted && sessionStart > 0L) {
            val usageComputation = computeUsageFromEvents(
                context = context,
                start = sessionStart,
                end = effectiveEnd
            )
            usageByApp.putAll(usageComputation.usageByApp)
            openCounts.putAll(usageComputation.openCounts)
            usageComputation.hourlyBuckets.forEachIndexed { index, value ->
                hourlyBuckets[index] = value
            }
            nightUsageMs = usageComputation.nightUsageMs

            val exactAggregateUsage = queryAggregateUsageDelta(
                context = context,
                sessionStart = sessionStart,
                end = effectiveEnd
            )
            exactAggregateUsage.forEach { (packageName, aggregateForegroundMs) ->
                val currentValue = usageByApp[packageName] ?: 0L
                if (aggregateForegroundMs > currentValue) {
                    usageByApp[packageName] = aggregateForegroundMs
                }
            }
        }
        val usageEntries = usageByApp.entries
            .filter { it.value > 0L }
            .sortedByDescending { it.value }

        val appBreakdown = linkedMapOf<String, Double>()
        val topApps = mutableListOf<Map<String, Any>>()
        var totalScreenTimeMinutes = 0.0

        usageEntries.forEach { entry ->
            val minutes = entry.value.toDouble() / 1000.0 / 60.0
            totalScreenTimeMinutes += minutes
            appBreakdown[entry.key] = minutes
            val label = getAppLabel(entry.key)
            if (topApps.size < 5 && shouldDisplayTopApp(entry.key, label, minutes)) {
                topApps.add(
                    mapOf(
                        "name" to label,
                        "package" to entry.key,
                        "usage_time" to minutes.toInt(),
                        "open_count" to (openCounts[entry.key] ?: 0),
                        "icon" to getAppIcon(entry.key)
                    )
                )
            }
        }

        val peakHour = hourlyBuckets.indices.maxByOrNull { hourlyBuckets[it] }
            ?.takeIf { hourlyBuckets[it] > 0 }
            ?: Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

        val status: String
        val fallbackMessage: String
        when {
            !usageGranted -> {
                status = "permission_required"
                fallbackMessage = "Usage access permission is required to read device activity."
            }

            !trackingEnabled || sessionStart <= 0L -> {
                status = "waiting_for_tracking"
                fallbackMessage =
                    "SmartPulse will begin sensing as soon as tracking starts after permissions are granted."
            }

            topApps.isEmpty() -> {
                status = "empty_data"
                fallbackMessage =
                    "Tracking is active, but SmartPulse has not yet observed enough foreground app events in this session."
            }

            else -> {
                status = "ok"
                fallbackMessage = ""
            }
        }

        val perAppNotifications = readIntMap(prefs.getString(NOTIFICATION_BY_APP_KEY, null))
        val totalNotifications = prefs.getInt(NOTIFICATION_TOTAL_KEY, 0)
        val unlockCount = prefs.getInt(UNLOCK_COUNT_KEY, 0)

        val snapshot = linkedMapOf<String, Any?>(
            "status" to status,
            "fallback_message" to fallbackMessage,
            "service_running" to SmartPulseForegroundService.isRunning,
            "tracking_enabled" to trackingEnabled,
            "tracking_session_start" to if (sessionStart > 0L) isoString(sessionStart) else null,
            "tracking_session_end" to if (sessionStart > 0L) isoString(sessionEnd) else null,
            "tracking_session_complete" to sessionComplete,
            "tracking_session_remaining_ms" to
                if (sessionStart > 0L) maxOf(0L, sessionEnd - now) else 0L,
            "usage_access_granted" to usageGranted,
            "notification_permission_granted" to notificationGranted,
            "permission_granted" to usageGranted,
            "battery_optimization_ignored" to ignoringBatteryOptimizations,
            "screen_time_minutes" to totalScreenTimeMinutes,
            "total_screen_time_minutes" to totalScreenTimeMinutes,
            "unlock_count" to unlockCount,
            "total_unlocks" to unlockCount,
            "notification_count" to totalNotifications,
            "total_notifications" to totalNotifications,
            "notification_breakdown" to perAppNotifications.mapValues { it.value.toDouble() },
            "total_apps_used" to appBreakdown.size.toDouble(),
            "app_breakdown" to appBreakdown,
            "top_apps" to topApps,
            "night_usage_minutes" to (nightUsageMs.toDouble() / 1000.0 / 60.0),
            "peak_hour" to peakHour,
            "is_weekend" to isWeekend(),
            "query_period" to mapOf(
                "start" to if (sessionStart > 0L) isoString(sessionStart) else null,
                "end" to if (sessionStart > 0L) isoString(effectiveEnd) else null,
                "description" to "Active 24-hour tracking session"
            ),
            "data_quality" to if (status == "ok") "native_foreground_service" else status,
            "last_updated" to isoString(now)
        )

        Log.d(
            TAG,
            "Snapshot built: status=$status screen=${totalScreenTimeMinutes.toInt()} unlocks=$unlockCount notifications=$totalNotifications apps=${topApps.size}"
        )
        return snapshot
    }

    private fun ensureTrackingSession(context: Context, forceNewSession: Boolean): Long {
        ensureRepositoryState(context)
        val prefs = prefs(context)
        val now = System.currentTimeMillis()
        val existingStart = prefs.getLong(TRACKING_SESSION_START_KEY, 0L)
        val needsNewSession =
            forceNewSession || existingStart <= 0L || now >= existingStart + SESSION_DURATION_MS

        if (!needsNewSession) {
            return existingStart
        }

        val editor = prefs.edit()
        clearSessionData(editor)
        editor
            .putLong(TRACKING_SESSION_START_KEY, now)
            .putLong(LAST_EVENT_TIMESTAMP_KEY, now)
            .putBoolean(LAST_KEYGUARD_LOCKED_KEY, currentKeyguardLocked(context))
            .putBoolean(USAGE_PERMISSION_SESSION_ALIGNED_KEY, false)
            .apply()

        mirrorFlutterInt(context, "unlock_count", 0)
        mirrorFlutterInt(context, "notification_count", 0)
        Log.d(TAG, "Started new tracking session at $now")
        return now
    }

    private fun computeUsageFromEvents(
        context: Context,
        start: Long,
        end: Long
    ): UsageComputation {
        val usageByApp = mutableMapOf<String, Long>()
        val openCounts = mutableMapOf<String, Int>()
        val hourlyBuckets = IntArray(24)
        var nightUsageMs = 0L
        var currentForegroundPackage: String? = null
        var currentForegroundStart = 0L

        if (end <= start) {
            return UsageComputation(usageByApp, openCounts, hourlyBuckets, nightUsageMs)
        }

        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usageStatsManager.queryEvents(start, end)
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            val eventTs = event.timeStamp

            when {
                isResumeEvent(event.eventType) -> {
                    if (currentForegroundPackage != null && currentForegroundStart > 0L) {
                        val segmentEnd = minOf(eventTs, end)
                        if (segmentEnd > currentForegroundStart) {
                            addUsageSegment(
                                usageByApp,
                                currentForegroundPackage,
                                currentForegroundStart,
                                segmentEnd
                            )
                            nightUsageMs += calculateNightOverlap(currentForegroundStart, segmentEnd)
                        }
                    }

                    if (shouldIncludeApp(context, packageName)) {
                        val isNewForeground =
                            currentForegroundPackage != packageName || currentForegroundStart <= 0L
                        currentForegroundPackage = packageName
                        currentForegroundStart = eventTs
                        if (isNewForeground) {
                            openCounts[packageName] = (openCounts[packageName] ?: 0) + 1
                            val hour = Calendar.getInstance().apply {
                                timeInMillis = eventTs
                            }.get(Calendar.HOUR_OF_DAY)
                            hourlyBuckets[hour] = hourlyBuckets[hour] + 1
                        }
                    } else {
                        currentForegroundPackage = null
                        currentForegroundStart = 0L
                    }
                }

                isPauseEvent(event.eventType) -> {
                    if (currentForegroundPackage == packageName && currentForegroundStart > 0L) {
                        val segmentEnd = minOf(eventTs, end)
                        if (segmentEnd > currentForegroundStart) {
                            addUsageSegment(
                                usageByApp,
                                packageName,
                                currentForegroundStart,
                                segmentEnd
                            )
                            nightUsageMs += calculateNightOverlap(currentForegroundStart, segmentEnd)
                        }
                        currentForegroundPackage = null
                        currentForegroundStart = 0L
                    }
                }
            }
        }

        if (currentForegroundPackage != null && currentForegroundStart > 0L && end > currentForegroundStart) {
            addUsageSegment(usageByApp, currentForegroundPackage, currentForegroundStart, end)
            nightUsageMs += calculateNightOverlap(currentForegroundStart, end)
        }

        return UsageComputation(usageByApp, openCounts, hourlyBuckets, nightUsageMs)
    }

    private fun ensureRepositoryState(context: Context) {
        val prefs = prefs(context)
        val currentLastUpdateTime = getApkLastUpdateTime(context)
        val storedLastUpdateTime = prefs.getLong(APK_LAST_UPDATE_TIME_KEY, -1L)
        if (storedLastUpdateTime == currentLastUpdateTime) {
            return
        }

        val editor = prefs.edit()
        clearSessionData(editor)
        editor
            .putLong(APK_LAST_UPDATE_TIME_KEY, currentLastUpdateTime)
            .putBoolean(TRACKING_ENABLED_KEY, false)
            .putLong(TRACKING_SESSION_START_KEY, 0L)
            .apply()

        mirrorFlutterInt(context, "tracking_enabled", 0)
        mirrorFlutterInt(context, "unlock_count", 0)
        mirrorFlutterInt(context, "notification_count", 0)
        Log.d(TAG, "Reset SmartPulse tracking state after app install/update")
    }

    private fun clearSessionData(editor: android.content.SharedPreferences.Editor) {
        editor
            .putLong(LAST_EVENT_TIMESTAMP_KEY, 0L)
            .putString(CURRENT_FOREGROUND_PACKAGE_KEY, null)
            .putLong(CURRENT_FOREGROUND_START_KEY, 0L)
            .putString(USAGE_BY_APP_KEY, JSONObject().toString())
            .putString(OPEN_COUNTS_KEY, JSONObject().toString())
            .putString(PEAK_HOUR_BUCKETS_KEY, JSONArray(List(24) { 0 }).toString())
            .putLong(NIGHT_USAGE_MS_KEY, 0L)
            .putInt(UNLOCK_COUNT_KEY, 0)
            .putLong(LAST_UNLOCK_EVENT_TS_KEY, 0L)
            .remove(LAST_KEYGUARD_LOCKED_KEY)
            .remove(USAGE_PERMISSION_SESSION_ALIGNED_KEY)
            .remove(AGGREGATE_BASELINE_USAGE_KEY)
            .remove(AGGREGATE_BASELINE_DAY_START_KEY)
            .putInt(NOTIFICATION_TOTAL_KEY, 0)
            .putString(NOTIFICATION_BY_APP_KEY, JSONObject().toString())
    }

    private fun updateUnlockStateFromKeyguard(context: Context) {
        val prefs = prefs(context)
        val currentLocked = currentKeyguardLocked(context)
        if (!prefs.contains(LAST_KEYGUARD_LOCKED_KEY)) {
            prefs.edit().putBoolean(LAST_KEYGUARD_LOCKED_KEY, currentLocked).apply()
            return
        }

        val previousLocked = prefs.getBoolean(LAST_KEYGUARD_LOCKED_KEY, currentLocked)
        if (previousLocked && !currentLocked) {
            incrementUnlockCount(context)
        }
        prefs.edit().putBoolean(LAST_KEYGUARD_LOCKED_KEY, currentLocked).apply()
    }

    private fun currentKeyguardLocked(context: Context): Boolean {
        return try {
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.isKeyguardLocked
        } catch (error: Exception) {
            Log.w(TAG, "Unable to read keyguard state", error)
            false
        }
    }

    private fun getApkLastUpdateTime(context: Context): Long {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(context.packageName, 0)
            }
            packageInfo.lastUpdateTime
        } catch (error: Exception) {
            Log.w(TAG, "Unable to read APK update time", error)
            0L
        }
    }

    private fun addUsageSegment(
        usageByApp: MutableMap<String, Long>,
        packageName: String,
        start: Long,
        end: Long
    ) {
        if (end <= start) {
            return
        }
        usageByApp[packageName] = (usageByApp[packageName] ?: 0L) + (end - start)
    }

    private fun calculateNightOverlap(start: Long, end: Long): Long {
        if (end <= start) {
            return 0L
        }

        var overlap = 0L
        val cursor = Calendar.getInstance().apply { timeInMillis = start }
        while (cursor.timeInMillis < end) {
            val dayStart = Calendar.getInstance().apply {
                timeInMillis = cursor.timeInMillis
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            val morningNightStart = dayStart.timeInMillis
            dayStart.set(Calendar.HOUR_OF_DAY, 6)
            val morningNightEnd = dayStart.timeInMillis
            val morningWindowStart = maxOf(start, morningNightStart)
            val morningWindowEnd = minOf(end, morningNightEnd)
            if (morningWindowEnd > morningWindowStart) {
                overlap += morningWindowEnd - morningWindowStart
            }

            val eveningNightStart = Calendar.getInstance().apply {
                timeInMillis = morningNightStart
                set(Calendar.HOUR_OF_DAY, 22)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val nextDayStart = Calendar.getInstance().apply {
                timeInMillis = morningNightStart
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val eveningWindowStart = maxOf(start, eveningNightStart)
            val eveningWindowEnd = minOf(end, nextDayStart)
            if (eveningWindowEnd > eveningWindowStart) {
                overlap += eveningWindowEnd - eveningWindowStart
            }

            cursor.add(Calendar.DAY_OF_YEAR, 1)
            cursor.set(Calendar.HOUR_OF_DAY, 0)
            cursor.set(Calendar.MINUTE, 0)
            cursor.set(Calendar.SECOND, 0)
            cursor.set(Calendar.MILLISECOND, 0)
        }
        return overlap
    }

    private fun isResumeEvent(eventType: Int): Boolean {
        return eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
            eventType == UsageEvents.Event.ACTIVITY_RESUMED
    }

    private fun isPauseEvent(eventType: Int): Boolean {
        return eventType == UsageEvents.Event.MOVE_TO_BACKGROUND ||
            eventType == UsageEvents.Event.ACTIVITY_PAUSED
    }

    private fun shouldIncludeApp(context: Context, packageName: String): Boolean {
        if (packageName == context.packageName) {
            return false
        }
        if (excludedPackages.contains(packageName)) {
            return false
        }
        return !isClearlyInternalPackage(packageName)
    }

    private fun ensureUsagePermissionAlignedSession(context: Context, usageGranted: Boolean): Long {
        val prefs = prefs(context)
        if (!usageGranted) {
            prefs.edit()
                .putBoolean(USAGE_PERMISSION_SESSION_ALIGNED_KEY, false)
                .remove(AGGREGATE_BASELINE_USAGE_KEY)
                .remove(AGGREGATE_BASELINE_DAY_START_KEY)
                .apply()
            return ensureTrackingSession(context, forceNewSession = false)
        }

        val aligned = prefs.getBoolean(USAGE_PERMISSION_SESSION_ALIGNED_KEY, false)
        val sessionStart = if (aligned) {
            ensureTrackingSession(context, forceNewSession = false)
        } else {
            ensureTrackingSession(context, forceNewSession = true).also {
                captureAggregateBaseline(context, it)
                prefs.edit().putBoolean(USAGE_PERMISSION_SESSION_ALIGNED_KEY, true).apply()
            }
        }

        if (!prefs.contains(AGGREGATE_BASELINE_USAGE_KEY)) {
            captureAggregateBaseline(context, sessionStart)
        }
        return sessionStart
    }

    private fun queryAggregateUsageDelta(
        context: Context,
        sessionStart: Long,
        end: Long
    ): Map<String, Long> {
        if (end <= sessionStart) {
            return emptyMap()
        }

        val prefs = prefs(context)
        val queryDayStart = startOfDayEpoch(end)
        val baselineDayStart = prefs.getLong(AGGREGATE_BASELINE_DAY_START_KEY, -1L)
        if (baselineDayStart != queryDayStart) {
            captureAggregateBaseline(context, end)
            return emptyMap()
        }

        val baselineUsage = readLongMap(prefs.getString(AGGREGATE_BASELINE_USAGE_KEY, null))
        val currentUsage = queryDailyAggregateForegroundUsage(
            context = context,
            start = queryDayStart,
            end = end
        )

        return buildMap {
            currentUsage.forEach { (packageName, foregroundMs) ->
                val baselineMs = baselineUsage[packageName] ?: 0L
                val deltaMs = maxOf(0L, foregroundMs - baselineMs)
                if (deltaMs > 0L) {
                    put(packageName, deltaMs)
                }
            }
        }
    }

    private fun queryDailyAggregateForegroundUsage(
        context: Context,
        start: Long,
        end: Long
    ): Map<String, Long> {
        if (end <= start) {
            return emptyMap()
        }

        return try {
            val usageStatsManager =
                context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val usageStats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                start,
                end
            )
            buildMap {
                usageStats.orEmpty().forEach { stats ->
                    val packageName = stats.packageName ?: return@forEach
                    if (!shouldIncludeApp(context, packageName)) {
                        return@forEach
                    }
                    val foregroundMs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        maxOf(stats.totalTimeInForeground, stats.totalTimeVisible)
                    } else {
                        stats.totalTimeInForeground
                    }
                    if (foregroundMs > 0L) {
                        val currentValue = this[packageName] ?: 0L
                        put(packageName, maxOf(currentValue, foregroundMs))
                    }
                }
            }
        } catch (error: Exception) {
            Log.w(TAG, "Failed to read aggregate foreground usage", error)
            emptyMap()
        }
    }

    private fun captureAggregateBaseline(context: Context, captureTime: Long) {
        val dayStart = startOfDayEpoch(captureTime)
        val baselineUsage = queryDailyAggregateForegroundUsage(
            context = context,
            start = dayStart,
            end = captureTime
        )
        prefs(context).edit()
            .putLong(AGGREGATE_BASELINE_DAY_START_KEY, dayStart)
            .putString(
                AGGREGATE_BASELINE_USAGE_KEY,
                JSONObject(baselineUsage.mapValues { it.value }).toString()
            )
            .apply()
    }

    private fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        return try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(context.packageName)
        } catch (error: Exception) {
            Log.w(TAG, "Unable to check battery optimizations", error)
            false
        }
    }

    private fun getAppLabel(packageName: String): String {
        val normalized = packageName.lowercase(Locale.US)
        return when {
            normalized.contains("instagram") -> "Instagram"
            normalized.contains("whatsapp") -> "WhatsApp"
            normalized.contains("telegram") -> "Telegram"
            normalized.contains("youtube") -> "YouTube"
            normalized.contains("facebook") -> "Facebook"
            normalized.contains("messenger") -> "Messenger"
            normalized.contains("snapchat") -> "Snapchat"
            normalized.contains("linkedin") -> "LinkedIn"
            normalized.contains("truecaller") -> "Truecaller"
            normalized.contains("chatgpt") -> "ChatGPT"
            normalized.contains("spotify") -> "Spotify"
            normalized.contains("chrome") -> "Chrome"
            normalized.contains("gmail") || normalized == "com.google.android.gm" -> "Gmail"
            normalized.contains("photos") -> "Photos"
            normalized.contains("calendar") -> "Calendar"
            normalized.contains("phonepe") -> "PhonePe"
            normalized.contains("paytm") -> "Paytm"
            normalized.contains("amazon") -> "Amazon"
            normalized.contains("netflix") -> "Netflix"
            normalized.contains("reddit") -> "Reddit"
            normalized.contains("discord") -> "Discord"
            normalized.contains("twitter") || normalized.contains("x.android") -> "X"
            normalized.contains("music") -> "Music"
            else -> prettifyPackageName(packageName)
        }
    }

    private fun getAppIcon(packageName: String): String {
        return when {
            packageName.contains("whatsapp") -> "chat"
            packageName.contains("instagram") -> "photo"
            packageName.contains("youtube") -> "video"
            packageName.contains("facebook") -> "social"
            packageName.contains("spotify") -> "music"
            packageName.contains("chrome") -> "web"
            packageName.contains("gmail") -> "mail"
            else -> "app"
        }
    }

    private fun shouldDisplayTopApp(
        packageName: String,
        label: String,
        minutes: Double
    ): Boolean {
        if (minutes < 1.0) {
            return false
        }

        val normalizedPackage = packageName.lowercase(Locale.US)
        val normalizedLabel = label.lowercase(Locale.US)
        if (
            isClearlyInternalPackage(normalizedPackage) ||
            normalizedLabel.contains("digital wellbeing") ||
            normalizedLabel.contains("package installer") ||
            normalizedLabel.contains("settings services") ||
            normalizedLabel.contains("permission controller")
        ) {
            return false
        }

        return true
    }

    private fun isClearlyInternalPackage(packageName: String): Boolean {
        val normalized = packageName.lowercase(Locale.US)
        val exactBlocked = setOf(
            "android",
            "com.android.systemui",
            "com.google.android.permissioncontroller",
            "com.google.android.apps.wellbeing",
            "com.samsung.android.forest",
            "com.android.packageinstaller",
            "com.google.android.packageinstaller",
            "com.samsung.android.packageinstaller",
            "com.google.android.settings.intelligence",
            "com.samsung.android.app.settings.bixby",
            "com.samsung.android.game.gos",
            "com.google.android.as"
        )
        if (exactBlocked.contains(normalized)) {
            return true
        }

        val blockedFragments = listOf(
            "wellbeing",
            "packageinstaller",
            "permissioncontroller",
            "launcher",
            "systemui",
            "settings.intelligence",
            ".bixby",
            ".forest",
            ".gos"
        )
        return blockedFragments.any(normalized::contains)
    }

    private fun prettifyPackageName(packageName: String): String {
        val preferredToken = packageName
            .split('.')
            .lastOrNull { part ->
                part.isNotBlank() &&
                    part !in setOf("com", "org", "net", "app", "android", "mobile")
            }
            ?: packageName.substringAfterLast('.')

        return preferredToken
            .split('_', '-', '.')
            .filter { it.isNotBlank() }
            .joinToString(" ") { token ->
                token.lowercase(Locale.US).replaceFirstChar { first ->
                    if (first.isLowerCase()) {
                        first.titlecase(Locale.US)
                    } else {
                        first.toString()
                    }
                }
            }
            .ifBlank { packageName }
    }

    private fun startOfDayEpoch(timeMillis: Long): Long {
        return Calendar.getInstance().apply {
            timeInMillis = timeMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun isKnownTrackableApp(packageName: String): Boolean {
        val normalized = packageName.lowercase(Locale.US)
        val fragments = listOf(
            "instagram",
            "youtube",
            "telegram",
            "whatsapp",
            "snapchat",
            "facebook",
            "messenger",
            "twitter",
            "linkedin",
            "discord",
            "reddit",
            "chrome",
            "gmail",
            "google",
            "spotify",
            "netflix",
            "amazon",
            "phonepe",
            "paytm"
        )
        return fragments.any(normalized::contains)
    }

    private fun readLongMap(json: String?): MutableMap<String, Long> {
        if (json.isNullOrBlank()) {
            return mutableMapOf()
        }
        return try {
            val objectValue = JSONObject(json)
            val map = mutableMapOf<String, Long>()
            objectValue.keys().forEach { key ->
                map[key] = objectValue.optLong(key, 0L)
            }
            map
        } catch (error: Exception) {
            Log.w(TAG, "Failed to parse long map", error)
            mutableMapOf()
        }
    }

    private fun readIntMap(json: String?): MutableMap<String, Int> {
        if (json.isNullOrBlank()) {
            return mutableMapOf()
        }
        return try {
            val objectValue = JSONObject(json)
            val map = mutableMapOf<String, Int>()
            objectValue.keys().forEach { key ->
                map[key] = objectValue.optInt(key, 0)
            }
            map
        } catch (error: Exception) {
            Log.w(TAG, "Failed to parse int map", error)
            mutableMapOf()
        }
    }

    private fun readHourlyBuckets(json: String?): IntArray {
        if (json.isNullOrBlank()) {
            return IntArray(24)
        }
        return try {
            val array = JSONArray(json)
            IntArray(24) { index -> if (index < array.length()) array.optInt(index, 0) else 0 }
        } catch (error: Exception) {
            Log.w(TAG, "Failed to parse hourly buckets", error)
            IntArray(24)
        }
    }

    private fun isoString(epochMillis: Long): String {
        return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ", Locale.US).format(Date(epochMillis))
    }

    private fun isWeekend(): Boolean {
        val day = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
        return day == Calendar.SATURDAY || day == Calendar.SUNDAY
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun mirrorFlutterInt(context: Context, key: String, value: Int) {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putInt("flutter.$key", value)
            .apply()
    }

    private data class UsageComputation(
        val usageByApp: MutableMap<String, Long>,
        val openCounts: MutableMap<String, Int>,
        val hourlyBuckets: IntArray,
        val nightUsageMs: Long
    )
}
