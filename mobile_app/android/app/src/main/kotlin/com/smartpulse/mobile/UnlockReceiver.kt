package com.smartpulse.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class UnlockReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "UnlockReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        val safeContext = context ?: return
        if (intent?.action == Intent.ACTION_USER_PRESENT) {
            Log.d(TAG, "Unlock event detected")
            SmartPulseUsageRepository.incrementUnlockCount(safeContext)
            SmartPulseDataBridge.publishLatest(safeContext)
        }
    }
}
