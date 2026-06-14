package com.example.application

import android.os.Bundle
import com.google.android.gms.wearable.ChannelClient
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
import android.util.Log

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "hike/wear_sync"

        // Path used by the Wearable Message API to route messages to the watch.
        // The watch MainActivity listens for messages on this same path.
        private const val WEAR_MESSAGE_PATH = "/hike_sync"
    }

    private lateinit var methodChannel: MethodChannel

    // CoroutineScope for all Wearable API calls.
    // Uses SupervisorJob so a failed send doesn't cancel other coroutines.
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        // Handle calls coming FROM Dart (PhoneWearSyncService.sendStats / sendStatus).
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {

                // Dart is pushing new HikeStats JSON to be forwarded to the watch.
                "sendStatsToWatch" -> {
                    val json = call.arguments as? String
                    if (json != null) {
                        // Prefix "S:" so the watch can distinguish stats from status.
                        sendMessageToWatch("S:$json")
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Expected a JSON string", null)
                    }
                }

                // Dart is pushing an ActivityStatus name (e.g. "paused").
                "sendStatusToWatch" -> {
                    val status = call.arguments as? String
                    if (status != null) {
                        // Prefix "T:" so the watch can distinguish status from stats.
                        sendMessageToWatch("T:$status")
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Expected a status string", null)
                    }
                }

                // Dart is sending a notification to watch to open the navigator app
                "sendNavigationPrompt" -> {
                    sendMessageToWatch("N:navigation")
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    // Wearable Data Layer

    /// Sends payload to all connected Wear OS nodes via the Message API.
    private fun sendMessageToWatch(payload: String) {
        scope.launch {
            try {
                // Get the list of connected watch nodes.
                val nodes = Wearable.getNodeClient(this@MainActivity)
                    .connectedNodes
                    .await()

                Log.d("WearSync", "Found ${nodes.size} nodes")

                // Send to every connected node (typically just one watch).
                nodes.forEach { node ->
                    Log.d("WearSync", "Sending to node ${node.displayName} (${node.id}) payload: ${payload}")
                    Wearable.getMessageClient(this@MainActivity)
                        .sendMessage(node.id, WEAR_MESSAGE_PATH, payload.toByteArray())
                        .await()
                }
            } catch (e: Exception) {
                // Log but don't crash — the watch will show stale data.
                android.util.Log.e("MainActivity", "sendMessageToWatch failed: ${e.message}")
            }
        }
    }

    /// Called by the Wearable MessageListener (registered in a WearableListenerService)
    /// when a command arrives FROM the watch (pause, resume, stop).
    /// This is called from WearCommandListenerService.kt (see below).
    fun onCommandFromWatch(command: String) {
        // We must call invokeMethod on the main thread.
        runOnUiThread {
            when (command) {
                "pause"  -> methodChannel.invokeMethod("pauseRecording", null)
                "resume" -> methodChannel.invokeMethod("resumeRecording", null)
                "stop"   -> methodChannel.invokeMethod("stopRecording", null)
                else     -> android.util.Log.w("MainActivity", "Unknown command: $command")
            }
        }
    }

    //Needed to overcome security restrictions of WearOS
    private fun launchWatchApp() {
        scope.launch {
            try {
                val nodes = Wearable.getNodeClient(this@MainActivity)
                    .connectedNodes.await()
                nodes.forEach { node ->
                    // Sends a special path that opens MainActivity on the watch
                    Wearable.getMessageClient(this@MainActivity)
                        .sendMessage(node.id, "/start-watch-app", byteArrayOf())
                        .await()
                    Log.d("WatchSync", "PHONE: launch intent sent to ${node.id}")
                }
            } catch (e: Exception) {
                Log.e("WatchSync", "PHONE: launchWatchApp failed: ${e.message}")
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Cancel all pending Wearable API coroutines to prevent leaks.
        scope.cancel()
    }
}

