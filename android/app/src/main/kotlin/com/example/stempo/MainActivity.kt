package com.example.stempo

import android.util.Log
import com.spotify.android.appremote.api.ConnectionParams
import com.spotify.android.appremote.api.Connector
import com.spotify.android.appremote.api.SpotifyAppRemote
import com.spotify.protocol.types.PlayerState
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
    }

    private var spotifyAppRemote: SpotifyAppRemote? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingConnectResult: MethodChannel.Result? = null

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
                    subscribeToPlayerState()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    override fun onStop() {
        super.onStop()
        spotifyAppRemote?.let {
            SpotifyAppRemote.disconnect(it)
            spotifyAppRemote = null
        }
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
                connectToSpotify(clientId, redirectUri, result)
            }

            "playUri" -> {
                val clientId = call.argument<String>("clientId")
                val redirectUri = call.argument<String>("redirectUri")
                val uri = call.argument<String>("uri")
                if (clientId.isNullOrBlank() || redirectUri.isNullOrBlank() || uri.isNullOrBlank()) {
                    result.error("invalid_args", "Missing Spotify playback arguments.", null)
                    return
                }
                playUri(clientId, redirectUri, uri, result)
            }

            "pause" -> {
                val remote = spotifyAppRemote
                if (remote == null || !remote.isConnected) {
                    result.error("not_connected", "Spotify App Remote is not connected.", null)
                    return
                }
                remote.playerApi.pause().setResultCallback {
                    result.success(true)
                }.setErrorCallback { error ->
                    result.error("pause_failed", error.message, null)
                }
            }

            "resume" -> {
                val remote = spotifyAppRemote
                if (remote == null || !remote.isConnected) {
                    result.error("not_connected", "Spotify App Remote is not connected.", null)
                    return
                }
                remote.playerApi.resume().setResultCallback {
                    result.success(true)
                }.setErrorCallback { error ->
                    result.error("resume_failed", error.message, null)
                }
            }

            "skipNext" -> {
                val remote = spotifyAppRemote
                if (remote == null || !remote.isConnected) {
                    result.error("not_connected", "Spotify App Remote is not connected.", null)
                    return
                }
                remote.playerApi.skipNext().setResultCallback {
                    result.success(true)
                }.setErrorCallback { error ->
                    result.error("skip_next_failed", error.message, null)
                }
            }

            "skipPrevious" -> {
                val remote = spotifyAppRemote
                if (remote == null || !remote.isConnected) {
                    result.error("not_connected", "Spotify App Remote is not connected.", null)
                    return
                }
                remote.playerApi.skipPrevious().setResultCallback {
                    result.success(true)
                }.setErrorCallback { error ->
                    result.error("skip_previous_failed", error.message, null)
                }
            }

            "getPlayerState" -> {
                val remote = spotifyAppRemote
                if (remote == null || !remote.isConnected) {
                    result.success(null)
                    return
                }
                remote.playerApi.playerState.setResultCallback { state ->
                    result.success(playerStateToMap(state))
                }.setErrorCallback { error ->
                    Log.w(TAG, "getPlayerState failed: ${error.message}")
                    result.success(null)
                }
            }

            "disconnect" -> {
                spotifyAppRemote?.let {
                    SpotifyAppRemote.disconnect(it)
                    spotifyAppRemote = null
                }
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    private fun connectToSpotify(
        clientId: String,
        redirectUri: String,
        result: MethodChannel.Result,
    ) {
        // If already connected, return immediately
        val existing = spotifyAppRemote
        if (existing != null && existing.isConnected) {
            result.success(true)
            return
        }

        val params = ConnectionParams.Builder(clientId)
            .setRedirectUri(redirectUri)
            .showAuthView(true)
            .build()

        SpotifyAppRemote.connect(this, params, object : Connector.ConnectionListener {
            override fun onConnected(remote: SpotifyAppRemote) {
                Log.i(TAG, "Spotify App Remote connected successfully!")
                spotifyAppRemote = remote
                subscribeToPlayerState()
                result.success(true)
            }

            override fun onFailure(throwable: Throwable) {
                Log.e(TAG, "Spotify App Remote connection failed: ${throwable.message}")
                result.success(false)
            }
        })
    }

    private fun playUri(
        clientId: String,
        redirectUri: String,
        uri: String,
        result: MethodChannel.Result,
    ) {
        val remote = spotifyAppRemote
        if (remote != null && remote.isConnected) {
            remote.playerApi.play(uri).setResultCallback {
                Log.i(TAG, "Playing URI: $uri")
                result.success(true)
            }.setErrorCallback { error ->
                Log.e(TAG, "Play failed: ${error.message}")
                result.success(false)
            }
            return
        }

        // Not connected yet – connect first, then play
        val params = ConnectionParams.Builder(clientId)
            .setRedirectUri(redirectUri)
            .showAuthView(true)
            .build()

        SpotifyAppRemote.connect(this, params, object : Connector.ConnectionListener {
            override fun onConnected(remote: SpotifyAppRemote) {
                Log.i(TAG, "Spotify App Remote connected, now playing: $uri")
                spotifyAppRemote = remote
                subscribeToPlayerState()
                remote.playerApi.play(uri).setResultCallback {
                    result.success(true)
                }.setErrorCallback { error ->
                    Log.e(TAG, "Play after connect failed: ${error.message}")
                    result.success(false)
                }
            }

            override fun onFailure(throwable: Throwable) {
                Log.e(TAG, "Connect-then-play failed: ${throwable.message}")
                result.success(false)
            }
        })
    }

    private fun subscribeToPlayerState() {
        val remote = spotifyAppRemote ?: return
        if (!remote.isConnected) return

        remote.playerApi.subscribeToPlayerState().setEventCallback { state ->
            val map = playerStateToMap(state)
            try {
                eventSink?.success(map)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to send player state to Flutter: ${e.message}")
            }
        }.setErrorCallback { error ->
            Log.w(TAG, "Player state subscription error: ${error.message}")
        }
    }

    private fun playerStateToMap(state: PlayerState): Map<String, Any?> {
        val track = state.track
        return mapOf(
            "trackUri" to (track?.uri ?: ""),
            "trackName" to (track?.name ?: ""),
            "artistName" to (track?.artist?.name ?: ""),
            "isPaused" to state.isPaused,
            "playbackPositionMs" to state.playbackPosition,
            "durationMs" to (track?.duration ?: 0L),
        )
    }
}
