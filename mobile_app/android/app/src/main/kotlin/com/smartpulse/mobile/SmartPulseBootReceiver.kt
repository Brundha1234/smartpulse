package com.smartpulse.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class SmartPulseBootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmartPulseBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            Log.d(TAG, "Received $action")
            if (SmartPulseUsageRepository.isTrackingEnabled(context)) {
                SmartPulseForegroundService.start(context)
            }
        }
    }
}
