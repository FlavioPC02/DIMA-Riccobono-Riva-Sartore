package com.example.wear_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class NavigationNotificationReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val activity = MainActivity.instance

        if (activity != null) {
            activity.openNavigationScreen()
        } else {
            val launchIntent =
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("open_navigation", true)
                }
            context.startActivity(launchIntent)
        }
    }
}