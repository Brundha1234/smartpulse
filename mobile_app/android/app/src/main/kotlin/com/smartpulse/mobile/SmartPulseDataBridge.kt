package com.smartpulse.mobile

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.EventChannel

object SmartPulseDataBridge : EventChannel.StreamHandler {
    private const val TAG = "SmartPulseDataBridge"

    @Volatile
    private var eventSink: EventChannel.EventSink? = null
    private var lastPayload: Map<String, Any?>? = null

    fun attachEventChannel(channel: EventChannel) {
        channel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "Flutter listener attached")
        eventSink = events
        lastPayload?.let { payload ->
            events?.success(payload)
        }
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "Flutter listener detached")
        eventSink = null
    }

    fun publishLatest(context: Context) {
        publish(SmartPulseUsageRepository.buildSnapshot(context.applicationContext))
    }

    fun publish(payload: Map<String, Any?>) {
        lastPayload = payload
        Log.d(
            TAG,
            "Publishing snapshot: status=${payload["status"]} screen=${payload["total_screen_time_minutes"]}"
        )
        eventSink?.success(payload)
    }
}
