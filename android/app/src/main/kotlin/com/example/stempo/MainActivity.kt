package com.example.stempo

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "stempo/spotify_remote"
        private const val EVENT_CHANNEL = "stempo/spotify_remote/events"
        private const val TAG = "StempoSpotifyRemote"
        private const val SDK_MISSING_MESSAGE =
            "Spotify App Remote Android SDK is not installed. Add spotify-app-remote-release-0.8.0.aar under android/spotify-android-sdk/app-remote-lib to enable native remote controls."
    }

    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        ).setMethodCallHandler(::handleMethodCall)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    override fun onStart() {
        super.onStart()
    }

    override fun onStop() {
        super.onStop()
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val clientId = call.argument<String>("clientId")
                val redirectUri = call.argument<String>("redirectUri")
                if (clientId.isNullOrBlank() || redirectUri.isNullOrBlank()) {
                    result.error("invalid_args", "Spotify client ID or redirect URI is missing.", null)
                    return
                }
                logSdkUnavailable()
                result.success(false)
            }

            "playUri" -> {
                val clientId = call.argument<String>("clientId")
                val redirectUri = call.argument<String>("redirectUri")
                val uri = call.argument<String>("uri")
                if (clientId.isNullOrBlank() || redirectUri.isNullOrBlank() || uri.isNullOrBlank()) {
                    result.error("invalid_args", "Missing Spotify playback arguments.", null)
                    return
                }
                logSdkUnavailable()
                result.success(false)
            }

            "pause" -> result.error("spotify_sdk_unavailable", SDK_MISSING_MESSAGE, null)

            "resume" -> result.error("spotify_sdk_unavailable", SDK_MISSING_MESSAGE, null)

            "skipNext" -> result.error("spotify_sdk_unavailable", SDK_MISSING_MESSAGE, null)

            "skipPrevious" -> result.error("spotify_sdk_unavailable", SDK_MISSING_MESSAGE, null)

            "getPlayerState" -> result.success(null)

            "disconnect" -> {
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    private fun logSdkUnavailable() {
        Log.w(TAG, SDK_MISSING_MESSAGE)
        eventSink?.error("spotify_sdk_unavailable", SDK_MISSING_MESSAGE, null)
    }
}
