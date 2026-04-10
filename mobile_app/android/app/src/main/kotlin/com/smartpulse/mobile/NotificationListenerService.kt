package com.smartpulse.mobile

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.Collections

class SmartPulseNotificationListenerService : NotificationListenerService() {
    companion object {
        private const val TAG = "SmartPulseNotifSvc"
        private val activeNotificationKeys =
            Collections.synchronizedSet(mutableSetOf<String>())
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Notification listener created")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        synchronized(activeNotificationKeys) {
            activeNotificationKeys.clear()
            activeNotifications?.forEach { notification ->
                activeNotificationKeys.add(notification.key)
            }
        }
        Log.d(TAG, "Notification listener connected with ${activeNotificationKeys.size} active notifications")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)

        try {
            val notification = sbn ?: return
            val key = notification.key ?: return
            val packageName = notification.packageName
            val isNewNotification = synchronized(activeNotificationKeys) {
                activeNotificationKeys.add(key)
            }
            if (!isNewNotification) {
                Log.d(TAG, "Ignoring updated notification for $packageName")
                return
            }

            SmartPulseUsageRepository.incrementNotificationCount(applicationContext, packageName)
            SmartPulseDataBridge.publishLatest(applicationContext)
            Log.d(TAG, "Notification received from $packageName")
        } catch (error: Exception) {
            Log.e(TAG, "Error processing notification", error)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        val key = sbn?.key ?: return
        synchronized(activeNotificationKeys) {
            activeNotificationKeys.remove(key)
        }
    }

    override fun onDestroy() {
        synchronized(activeNotificationKeys) {
            activeNotificationKeys.clear()
        }
        super.onDestroy()
        Log.d(TAG, "Notification listener destroyed")
    }
}
