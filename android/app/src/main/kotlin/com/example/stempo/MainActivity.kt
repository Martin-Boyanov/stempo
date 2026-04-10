package com.example.stempo

import android.util.Log
import com.spotify.android.appremote.api.ConnectionParams
import com.spotify.android.appremote.api.Connector
import com.spotify.android.appremote.api.SpotifyAppRemote
import com.spotify.protocol.client.Subscription
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
    private var playerStateSubscription: Subscription<PlayerState>? = null
    private var eventSink: EventChannel.EventSink? = null
    private var lastClientId: String? = null
    private var lastRedirectUri: String? = null

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
                    emitCurrentPlayerState()
                    subscribeToPlayerState()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    override fun onStart() {
        super.onStart()
        val clientId = lastClientId
        val redirectUri = lastRedirectUri
        if (clientId != null && redirectUri != null && spotifyAppRemote?.isConnected != true) {
            connectToSpotify(
                clientId = clientId,
                redirectUri = redirectUri,
                showAuthView = false,
                onConnected = {},
                onError = {},
            )
        }
    }

    override fun onStop() {
        super.onStop()
        playerStateSubscription?.cancel()
        playerStateSubscription = null
        spotifyAppRemote?.let { SpotifyAppRemote.disconnect(it) }
        spotifyAppRemote = null
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val clientId = call.argument<String>("clientId")
                val redirectUri = call.argument<String>("redirectUri")
                val showAuthView = call.argument<Boolean>("showAuthView") ?: true
                if (clientId.isNullOrBlank() || redirectUri.isNullOrBlank()) {
                    result.error("invalid_args", "Spotify client ID or redirect URI is missing.", null)
                    return
                }
                connectToSpotify(
                    clientId = clientId,
                    redirectUri = redirectUri,
                    showAuthView = showAuthView,
                    onConnected = { result.success(true) },
                    onError = { throwable ->
                        result.error(
                            "spotify_connect_failed",
                            throwable.message ?: "Could not connect to Spotify App Remote.",
                            null,
                        )
                    },
                )
            }

            "playUri" -> {
                val clientId = call.argument<String>("clientId")
                val redirectUri = call.argument<String>("redirectUri")
                val uri = call.argument<String>("uri")
                if (clientId.isNullOrBlank() || redirectUri.isNullOrBlank() || uri.isNullOrBlank()) {
                    result.error("invalid_args", "Missing Spotify playback arguments.", null)
                    return
                }
                connectToSpotify(
                    clientId = clientId,
                    redirectUri = redirectUri,
                    showAuthView = true,
                    onConnected = {
                        spotifyAppRemote?.playerApi?.play(uri)
                            ?.setResultCallback { result.success(true) }
                            ?.setErrorCallback { throwable ->
                                result.error(
                                    "spotify_play_failed",
                                    throwable.message ?: "Could not start playback.",
                                    null,
                                )
                            }
                    },
                    onError = { throwable ->
                        result.error(
                            "spotify_connect_failed",
                            throwable.message ?: "Could not connect to Spotify App Remote.",
                            null,
                        )
                    },
                )
            }

            "pause" -> withRemote(result) { remote ->
                remote.playerApi.pause()
                    .setResultCallback { result.success(true) }
                    .setErrorCallback { throwable ->
                        result.error("spotify_pause_failed", throwable.message, null)
                    }
            }

            "resume" -> withRemote(result) { remote ->
                remote.playerApi.resume()
                    .setResultCallback { result.success(true) }
                    .setErrorCallback { throwable ->
                        result.error("spotify_resume_failed", throwable.message, null)
                    }
            }

            "skipNext" -> withRemote(result) { remote ->
                remote.playerApi.skipNext()
                    .setResultCallback { result.success(true) }
                    .setErrorCallback { throwable ->
                        result.error("spotify_skip_next_failed", throwable.message, null)
                    }
            }

            "skipPrevious" -> withRemote(result) { remote ->
                remote.playerApi.skipPrevious()
                    .setResultCallback { result.success(true) }
                    .setErrorCallback { throwable ->
                        result.error("spotify_skip_previous_failed", throwable.message, null)
                    }
            }

            "getPlayerState" -> withRemote(result) { remote ->
                remote.playerApi.playerState
                    .setResultCallback { playerState -> result.success(playerStateToMap(playerState)) }
                    .setErrorCallback { throwable ->
                        result.error("spotify_player_state_failed", throwable.message, null)
                    }
            }

            "disconnect" -> {
                playerStateSubscription?.cancel()
                playerStateSubscription = null
                spotifyAppRemote?.let { SpotifyAppRemote.disconnect(it) }
                spotifyAppRemote = null
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    private fun withRemote(
        result: MethodChannel.Result,
        action: (SpotifyAppRemote) -> Unit,
    ) {
        val remote = spotifyAppRemote
        if (remote?.isConnected == true) {
            action(remote)
        } else {
            result.error(
                "spotify_not_connected",
                "Spotify App Remote is not connected. Start playback from a playlist first.",
                null,
            )
        }
    }

    private fun connectToSpotify(
        clientId: String,
        redirectUri: String,
        showAuthView: Boolean,
        onConnected: (SpotifyAppRemote) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        val currentRemote = spotifyAppRemote
        if (currentRemote?.isConnected == true) {
            onConnected(currentRemote)
            return
        }

        lastClientId = clientId
        lastRedirectUri = redirectUri

        val connectionParams = ConnectionParams.Builder(clientId)
            .setRedirectUri(redirectUri)
            .showAuthView(showAuthView)
            .build()

        SpotifyAppRemote.connect(
            this,
            connectionParams,
            object : Connector.ConnectionListener {
                override fun onConnected(appRemote: SpotifyAppRemote) {
                    spotifyAppRemote = appRemote
                    subscribeToPlayerState()
                    emitCurrentPlayerState()
                    onConnected(appRemote)
                }

                override fun onFailure(throwable: Throwable) {
                    Log.e(TAG, throwable.message ?: "Spotify App Remote error", throwable)
                    onError(throwable)
                }
            },
        )
    }

    private fun subscribeToPlayerState() {
        val remote = spotifyAppRemote ?: return
        playerStateSubscription?.cancel()
        val subscription = remote.playerApi.subscribeToPlayerState()
        playerStateSubscription = subscription
        subscription.setEventCallback { playerState ->
            eventSink?.success(playerStateToMap(playerState))
        }
        subscription.setErrorCallback { throwable ->
            eventSink?.error(
                "spotify_player_state_subscription_failed",
                throwable.message,
                null,
            )
        }
    }

    private fun emitCurrentPlayerState() {
        val remote = spotifyAppRemote ?: return
        remote.playerApi.playerState
            .setResultCallback { playerState ->
                eventSink?.success(playerStateToMap(playerState))
            }
            .setErrorCallback {
                // Keep this quiet. The stream can be attached before Spotify is ready.
            }
    }

    private fun playerStateToMap(playerState: PlayerState): Map<String, Any?> {
        val track = playerState.track
        return mapOf(
            "trackUri" to track.uri,
            "trackName" to track.name,
            "artistName" to track.artist.name,
            "isPaused" to playerState.isPaused,
            "playbackPositionMs" to playerState.playbackPosition,
            "durationMs" to track.duration,
        )
    }
}
