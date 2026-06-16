package com.example.wear_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class WearMessageListenerService : WearableListenerService() {

    companion object {
        private const val WEAR_SYNC_PATH = "/hike_sync"
        private const val CHANNEL_ID = "navigation_channel"
        private const val NOTIFICATION_ID = 1001
    }

    override fun onCreate() {
        super.onCreate()
        android.util.Log.d("WatchSync", "WearMessageListenerService created")
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        android.util.Log.d("WatchSync", "Path=${messageEvent.path}")

        when (messageEvent.path) {
            "/start-watch-app" -> {
                // Brings the watch app out of stopped state
                val intent = Intent(this, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
            }
            WEAR_SYNC_PATH -> {
                val payload = String(messageEvent.data)
                when {
                    payload == "N:navigation" -> {
                        val activity = MainActivity.instance
                        if (activity != null) {
                            //App already open
                            activity.openNavigationScreen()
                        } else {
                            //App closed - launch with flag so that it opens navigation on start
                            val intent = Intent(this, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                putExtra("open_navigation", true)
                            }
                            startActivity(intent)
                        }
                    }

                    payload.startsWith("S:") || payload.startsWith("T:") || payload.startsWith("O:") -> {
                        val activity = MainActivity.instance
                        if (activity != null) {
                            activity.onMessageFromPhone(payload)
                        } else {
                            android.util.Log.d("WatchSync", "MainActivity not running, caching payload")
                            val prefs = getSharedPreferences("hike_wear_cache", MODE_PRIVATE)
                            when {
                                payload.startsWith("S:") ->
                                    prefs.edit().putString("last_stats", payload.removePrefix("S:")).apply()
                                payload.startsWith("T:") ->
                                    prefs.edit().putString("last_status", payload.removePrefix("T:")).apply()
                            }
                        }
                    }
                    else -> android.util.Log.w("WatchSync", "Unknown payload prefix: $payload")
                }
            }

            else -> android.util.Log.w("WatchSync", "Ignored message on unexpected path: ${messageEvent.path}")
        }
    }

    private fun showNavigationNotification() {
        createChannel()

        val openIntent = Intent(this, NavigationNotificationReceiver::class.java)

        val openPendingIntent = PendingIntent.getBroadcast(
            this, 1, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_map)
            .setContentTitle("Navigation started")
            .setContentText("Open navigation on watch?")
            .setAutoCancel(true)
            .addAction(0, "Open", openPendingIntent)
            .build()

        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, notification)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID, "Navigation", NotificationManager.IMPORTANCE_HIGH
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}