package com.example.application

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class WearCommandListenerService : WearableListenerService() {

    companion object {
        private const val WEAR_COMMAND_PATH = "/hike_command"
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        android.util.Log.d("PhoneSync", "Path=${messageEvent.path}")
        when(messageEvent.path) {
            WEAR_COMMAND_PATH -> {
                val command = String(messageEvent.data)
                android.util.Log.d("PhoneSync", "Received command: $command")

                val activity = MainActivity.instance
                if (activity != null) {
                    activity.onCommandFromWatch(command)
                } else {
                    android.util.Log.d("PhoneSync", "MainActivity not running, dropping command")
                }
            }
            else -> android.util.Log.w("PhoneSync", "Ignored message on unexpected path: ${messageEvent.path}")
        }
    }
}