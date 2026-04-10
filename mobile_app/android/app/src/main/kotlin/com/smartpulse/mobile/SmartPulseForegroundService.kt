package com.smartpulse.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class SmartPulseForegroundService : Service() {
    companion object {
        private const val TAG = "SmartPulseFgService"
        private const val CHANNEL_ID = "smartpulse_usage_monitor"
        private const val NOTIFICATION_ID = 42001
        private const val ACTION_START = "com.smartpulse.mobile.START_TRACKING"
        private const val ACTION_STOP = "com.smartpulse.mobile.STOP_TRACKING"
        private const val POLL_INTERVAL_MS = 5_000L

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context) {
            val intent = Intent(context, SmartPulseForegroundService::class.java).apply {
                action = ACTION_START
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, SmartPulseForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val unlockReceiver = UnlockReceiver()
    private val pollRunnable = object : Runnable {
        override fun run() {
            try {
                val snapshot = SmartPulseUsageRepository.buildSnapshot(applicationContext)
                SmartPulseDataBridge.publish(snapshot)
                Log.d(TAG, "Foreground poll completed")
            } catch (error: Exception) {
                Log.e(TAG, "Foreground poll failed", error)
            } finally {
                if (isRunning) {
                    handler.postDelayed(this, POLL_INTERVAL_MS)
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        registerUnlockReceiver()
        startForeground(NOTIFICATION_ID, buildNotification())
        isRunning = true
        Log.d(TAG, "Foreground service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopPolling()
                @Suppress("DEPRECATION")
                stopForeground(true)
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_START, null -> {
                SmartPulseUsageRepository.setTrackingEnabled(applicationContext, true)
                startPolling()
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        stopPolling()
        try {
            unregisterReceiver(unlockReceiver)
        } catch (_: IllegalArgumentException) {
        }
        super.onDestroy()
        Log.d(TAG, "Foreground service destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startPolling() {
        isRunning = true
        handler.removeCallbacks(pollRunnable)
        handler.post(pollRunnable)
        Log.d(TAG, "Foreground polling started")
    }

    private fun stopPolling() {
        handler.removeCallbacks(pollRunnable)
        isRunning = false
        Log.d(TAG, "Foreground polling stopped")
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SmartPulse is monitoring device usage")
            .setContentText("Realtime screen time, unlocks, and notifications are being tracked every 5 seconds.")
            .setSmallIcon(android.R.drawable.ic_menu_recent_history)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "SmartPulse Usage Monitor",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps SmartPulse alive for realtime sensing."
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun registerUnlockReceiver() {
        val filter = IntentFilter(Intent.ACTION_USER_PRESENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(unlockReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(unlockReceiver, filter)
        }
    }
}
