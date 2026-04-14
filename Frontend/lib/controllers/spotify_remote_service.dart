import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SpotifyRemotePlayerState {
  const SpotifyRemotePlayerState({
    required this.trackUri,
    required this.trackName,
    required this.artistName,
    required this.isPaused,
    required this.playbackPositionMs,
    required this.durationMs,
    this.imageUri,
  });

  final String trackUri;
  final String trackName;
  final String artistName;
  final bool isPaused;
  final int playbackPositionMs;
  final int durationMs;
  final String? imageUri;

  factory SpotifyRemotePlayerState.fromMap(Map<dynamic, dynamic> map) {
    return SpotifyRemotePlayerState(
      trackUri: map['trackUri'] as String? ?? '',
      trackName: map['trackName'] as String? ?? '',
      artistName: map['artistName'] as String? ?? '',
      isPaused: map['isPaused'] as bool? ?? true,
      playbackPositionMs: (map['playbackPositionMs'] as num?)?.toInt() ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      imageUri: map['imageUri'] as String?,
    );
  }

  String? get resolvedImageUrl {
    if (imageUri == null || imageUri!.isEmpty) return null;
    final String uri = imageUri!;
    if (uri.startsWith('http')) return uri;
    if (uri.startsWith('spotify:image:')) {
      final imageId = uri.substring('spotify:image:'.length);
      return 'https://i.scdn.co/image/$imageId';
    }
    if (RegExp(r'^[a-zA-Z0-9]{20,}$').hasMatch(uri)) {
      return 'https://i.scdn.co/image/$uri';
    }
    return null;
  }
}

class SpotifyRemoteService {
  SpotifyRemoteService._();

  static final SpotifyRemoteService instance = SpotifyRemoteService._();

  static const MethodChannel _methodChannel = MethodChannel(
    'stempo/spotify_remote',
  );
  static const EventChannel _eventChannel = EventChannel(
    'stempo/spotify_remote/events',
  );

  Stream<SpotifyRemotePlayerState>? _playerStateStream;

  String get _clientId => dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  String get _redirectUri =>
      dotenv.env['SPOTIFY_REDIRECT_URI'] ?? 'stempo://spotify-callback';

  Map<String, dynamic> get _credentials => {
    'clientId': _clientId,
    'redirectUri': _redirectUri,
  };

  bool get hasConfig => _clientId.isNotEmpty && _redirectUri.isNotEmpty;

  Stream<SpotifyRemotePlayerState> playerStateStream() {
    return _playerStateStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => SpotifyRemotePlayerState.fromMap(event as Map));
  }

  Future<bool> connect({bool showAuthView = true}) async {
    if (!hasConfig) return false;
    final result = await _methodChannel.invokeMethod<bool>('connect', {
      ..._credentials,
      'showAuthView': showAuthView,
    });
    return result ?? false;
  }

  Future<bool> playUri(String spotifyUri) async {
    if (!hasConfig || spotifyUri.isEmpty) return false;
    final result = await _methodChannel.invokeMethod<bool>('playUri', {
      ..._credentials,
      'uri': spotifyUri,
    });
    return result ?? false;
  }

  Future<void> pause() => _methodChannel.invokeMethod<void>('pause');

  Future<void> resume() => _methodChannel.invokeMethod<void>('resume');

  Future<void> skipNext() => _methodChannel.invokeMethod<void>('skipNext');

  Future<void> skipPrevious() =>
      _methodChannel.invokeMethod<void>('skipPrevious');

  Future<void> seekTo(int positionMs) =>
      _methodChannel.invokeMethod<void>('seekTo', {'position': positionMs});

  Future<void> disconnect() => _methodChannel.invokeMethod<void>('disconnect');

  Future<SpotifyRemotePlayerState?> getPlayerState() async {
    final map = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getPlayerState',
    );
    if (map == null) return null;
    return SpotifyRemotePlayerState.fromMap(map);
  }
}
