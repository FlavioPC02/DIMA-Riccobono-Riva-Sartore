package com.example.wear_app

import android.Manifest
import android.app.ComponentCaller
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "hike/wear_sync"       // same as phone
        private const val WEAR_COMMAND_PATH = "/hike_command" // outgoing commands to phone

        @Volatile //reads the last value not cached ones
        var instance: MainActivity? = null
    }

    private lateinit var methodChannel: MethodChannel
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var pendingNavigation = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        requestNotificationPermissionIfNeeded()
        if (intent?.getBooleanExtra("open_navigation", false) == true) {
            pendingNavigation = true
        }
        android.util.Log.d("WatchSync", "MainModule created")
    }

    override fun onNewIntent(intent: Intent, caller: ComponentCaller) {
        super.onNewIntent(intent, caller)
        if (intent.getBooleanExtra("open_navigation", false)) {
            openNavigationScreen()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        // Handle calls coming FROM Dart (e.g WatchWearSyncService.sendPause).
        // The watch Dart layer sends control commands; we forward them to the phone.
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pauseRecording"  -> { sendCommandToPhone("pause");  result.success(null) }
                "resumeRecording" -> { sendCommandToPhone("resume"); result.success(null) }
                "stopRecording"   -> { sendCommandToPhone("stop");   result.success(null) }
                "getLastKnownStats" -> {
                    val prefs = getSharedPreferences("hike_wear_cache", MODE_PRIVATE)
                    result.success(mapOf(
                        "stats" to prefs.getString("last_stats", null),
                        "status" to prefs.getString("last_status", null)
                    ))
                }
                "shouldOpenNavigation" -> {
                    val should = pendingNavigation
                    pendingNavigation = false
                    if (should) replayCachedPayloads()
                    result.success(should)
                }
                else -> result.notImplemented()
            }
        }
        replayCachedPayloads()
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    0
                )
            }
        }
    }

    // ── Incoming messages from phone ──────────────────────────────────────

    /// Called by WearMessageListenerService when a message arrives from the phone.
    /// Parses the prefix to distinguish stats ("S:") from status ("T:"),
    /// then forwards the payload to Dart via invokeMethod.
    fun onMessageFromPhone(payload: String) {
        runOnUiThread {
            when {
                // Stats update: strip the "S:" prefix and send JSON to Dart.
                // Dart's WatchWearSyncService handles it in case 'onStatsUpdate'.
                payload.startsWith("S:") -> {
                    val json = payload.removePrefix("S:")
                    methodChannel.invokeMethod("onStatsUpdate", json)
                }

                // Status update: strip the "T:" prefix and send the status name.
                // Dart's WatchWearSyncService handles it in case 'onStatusChange'.
                payload.startsWith("T:") -> {
                    val status = payload.removePrefix("T:")
                    methodChannel.invokeMethod("onStatusChange", status)
                }

                else -> android.util.Log.w("WatchMainActivity", "Unknown payload: $payload")
            }
        }
    }

    fun openNavigationScreen() {
        runOnUiThread {
            methodChannel.invokeMethod("openNavigationScreen", null)
        }
    }

    private fun replayCachedPayloads() {
        val prefs = getSharedPreferences("hike_wear_cache", MODE_PRIVATE)
        val stats  = prefs.getString("last_stats",  null)
        val status = prefs.getString("last_status", null)

        // Post to main thread — methodChannel may not be ready yet at the
        // exact moment configureFlutterEngine returns.
        runOnUiThread {
            stats?.let  { methodChannel.invokeMethod("onStatsUpdate",  it) }
            status?.let { methodChannel.invokeMethod("onStatusChange", it) }
        }
        android.util.Log.d("WatchSync", "Replayed cache: stats=${stats != null} status=${status != null}")
    }

    // ── Outgoing commands to phone ─────────────────────────────────────────

    /// Sends a control command string ("pause", "resume", "stop") to the phone
    /// via the Wearable Message API.
    private fun sendCommandToPhone(command: String) {
        scope.launch {
            try {
                val nodes = Wearable.getNodeClient(this@MainActivity)
                    .connectedNodes
                    .await()

                nodes.forEach { node ->
                    Wearable.getMessageClient(this@MainActivity)
                        .sendMessage(node.id, WEAR_COMMAND_PATH, command.toByteArray())
                        .await()
                }
            } catch (e: Exception) {
                android.util.Log.e("WatchMainActivity", "sendCommandToPhone failed: ${e.message}")
            }
        }
    }

    override fun onDestroy() {
        instance = null
        scope.cancel()
        super.onDestroy()
    }
}

