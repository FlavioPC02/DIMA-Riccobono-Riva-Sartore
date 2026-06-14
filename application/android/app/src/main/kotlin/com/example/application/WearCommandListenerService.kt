package com.example.application

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class WearCommandListenerService : WearableListenerService() {

    companion object {
        private const val WEAR_COMMAND_PATH = "/hike_command"
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != WEAR_COMMAND_PATH) return

        val command = String(messageEvent.data)

        // Find the running MainActivity and forward the command to it.
        // In a real app you'd use a local broadcast or a shared service
        // instead of casting — this is simplified for clarity.
        val activity = applicationContext as? MainActivity
        activity?.onCommandFromWatch(command)
    }
}