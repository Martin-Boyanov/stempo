import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/playlist_models.dart';
import '../state/spotify_models.dart';

enum SpotifyConnectionStatus { disconnected, connecting, connected, error }

class SpotifyAuthController extends ChangeNotifier {
  static const _authorizeEndpoint = 'https://accounts.spotify.com/authorize';
  static const _tokenEndpoint = 'https://accounts.spotify.com/api/token';
  static const _clientIdKey = 'SPOTIFY_CLIENT_ID';
  static const _redirectUriKey = 'SPOTIFY_REDIRECT_URI';
  static const _defaultRedirectUri = 'stempo://spotify-callback';
  static const _defaultAndroidBackendBaseUrl = 'http://10.0.2.2:8010';
  static const _defaultLocalBackendBaseUrl = 'http://localhost:8010';
  static const _defaultUserCadence = 108;
  static const _defaultBpmTolerance = 6;
  
  int _userCadence = _defaultUserCadence;
  int _bpmTolerance = _defaultBpmTolerance;
  static const _backendRequestTimeout = Duration(seconds: 20);
  static const _bpmBatchChunkSize = 10;
  static const _spotifyRequestTimeout = Duration(seconds: 12);
  static const _scopes = [
    'app-remote-control',
    'user-read-private',
    'user-read-email',
    'playlist-read-private',
    'playlist-read-collaborative',
    'playlist-modify-private',
    'playlist-modify-public',
    'user-library-read',
    'user-read-playback-state',
    'user-modify-playback-state',
  ];
  static const _verifierAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  final Random _random = Random.secure();

  SpotifyConnectionStatus _status = SpotifyConnectionStatus.disconnected;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  String? _errorMessage;
  SpotifyUserProfile? _profile;
  List<TempoPlaylist> _playlists = const [];
  List<SpotifySearchEntry> _searchEntries = const [];
  final Map<String, List<SpotifyTrack>> _playlistTracks = {};
  final Map<String, String> _playlistTrackErrors = {};
  final Set<String> _loadingPlaylistIds = <String>{};
  final Map<String, _SessionPlaylistCacheEntry> _sessionPlaylistCache = {};
  int _lastResolvedBpmCount = 0;
  bool _lastBackendTimedOut = false;
  bool _isLoadingData = false;
  String? _pendingVerifier;
  bool _isHandlingCallback = false;

  SpotifyAuthController();

  SpotifyConnectionStatus get status => _status;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  DateTime? get expiresAt => _expiresAt;
  String? get errorMessage => _errorMessage;
  SpotifyUserProfile? get profile => _profile;
  List<TempoPlaylist> get playlists => _playlists;
  int get userCadence => _userCadence;
  int get bpmTolerance => _bpmTolerance;
  
  set userCadence(int value) {
    if (_userCadence == value) return;
    _userCadence = value;
    unawaited(_saveSettings());
    notifyListeners();
  }

  set bpmTolerance(int value) {
    if (_bpmTolerance == value) return;
    _bpmTolerance = value;
    unawaited(_saveSettings());
    notifyListeners();
  }
  final Map<String, TempoPlaylist> _playlistCache = {};

  TempoPlaylist? findPlaylistById(String id) {
    for (final p in _playlists) {
      if (p.id == id) return p;
    }
    return _playlistCache[id];
  }

  void cachePlaylist(TempoPlaylist playlist) {
    _playlistCache[playlist.id] = playlist;
  }
  List<SpotifySearchEntry> get searchEntries => _searchEntries;
  List<SpotifyTrack> tracksForPlaylist(String playlistId) =>
      _playlistTracks[playlistId] ?? const [];
  String? trackErrorForPlaylist(String playlistId) =>
      _playlistTrackErrors[playlistId];
  bool isLoadingTracksForPlaylist(String playlistId) =>
      _loadingPlaylistIds.contains(playlistId);
  bool get isLoadingData => _isLoadingData;
  bool get isConnected =>
      _status == SpotifyConnectionStatus.connected &&
      _accessToken != null &&
      _expiresAt != null &&
      _expiresAt!.isAfter(DateTime.now());

  String get _clientId => dotenv.env[_clientIdKey] ?? '';
  String get _redirectUri =>
      dotenv.env[_redirectUriKey] ?? _defaultRedirectUri;
  String get _backendBaseUrl {
    final configured = (dotenv.env['BACKEND_BASE_URL'] ?? '').trim();
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return _defaultLocalBackendBaseUrl;
    if (Platform.isAndroid) return _defaultAndroidBackendBaseUrl;
    return _defaultLocalBackendBaseUrl;
  }

  Future<bool> _ensureValidAccessToken() async {
    final token = _accessToken;
    if (token == null || token.isEmpty) return false;
    final expiresAt = _expiresAt;
    if (expiresAt == null) return true;
    final refreshThreshold = DateTime.now().add(const Duration(seconds: 30));
    if (expiresAt.isAfter(refreshThreshold)) return true;
    return refreshAccessToken();
  }
  Future<bool> connectWithSpotifyPkce() async {
    final clientId = _clientId;

    if (clientId.isEmpty) {
      _status = SpotifyConnectionStatus.error;
      _errorMessage =
          'Missing Spotify client ID in .env.';
      notifyListeners();
      return false;
    }

    _status = SpotifyConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    final verifier = _generateCodeVerifier();
    _pendingVerifier = verifier;
    final challenge = _buildCodeChallenge(verifier);

    final authUri = Uri.parse(_authorizeEndpoint).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'code_challenge_method': 'S256',
        'code_challenge': challenge,
        'scope': _scopes.join(' '),
        'show_dialog': 'true',
      },
    );

    try {
      final callbackUrl = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: 'stempo',
      );

      final callbackUri = Uri.parse(callbackUrl);
      final code = callbackUri.queryParameters['code'];
      final error = callbackUri.queryParameters['error'];

      if (error != null) {
        _status = SpotifyConnectionStatus.error;
        _errorMessage = 'Spotify login was cancelled or denied: $error';
        notifyListeners();
        return false;
      }

      if (code == null || code.isEmpty) {
        _status = SpotifyConnectionStatus.error;
        _errorMessage = 'Spotify did not return an authorization code.';
        notifyListeners();
        return false;
      }

      return _exchangeAuthorizationCode(clientId: clientId, code: code, verifier: verifier);
    } catch (_) {
      // If we are currently handling the callback via deep link,
      // or we already connected, do not show an error here.
      // We add a tiny delay to give the deep link router time to trigger.
      await Future.delayed(const Duration(milliseconds: 300));
      if (_isHandlingCallback ||
          _status == SpotifyConnectionStatus.connected ||
          _status == SpotifyConnectionStatus.connecting) {
        return false;
      }
      
      _status = SpotifyConnectionStatus.error;
      _errorMessage = 'Spotify sign-in failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeAuthorizationCallback(Uri callbackUri) async {
    final clientId = _clientId;
    final code = callbackUri.queryParameters['code'];
    final error = callbackUri.queryParameters['error'];

    if (error != null) {
      _status = SpotifyConnectionStatus.error;
      _errorMessage = 'Spotify login was cancelled or denied: $error';
      notifyListeners();
      return false;
    }

    if (clientId.isEmpty || code == null || code.isEmpty || _pendingVerifier == null) {
      _status = SpotifyConnectionStatus.error;
      _errorMessage = 'Spotify callback could not be completed.';
      notifyListeners();
      return false;
    }

    _isHandlingCallback = true;
    _status = SpotifyConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _exchangeAuthorizationCode(
        clientId: clientId,
        code: code,
        verifier: _pendingVerifier!,
      );
    } finally {
      _isHandlingCallback = false;
    }
  }

  Future<bool> refreshAccessToken() async {
    final clientId = _clientId;

    if (clientId.isEmpty || _refreshToken == null || _refreshToken!.isEmpty) {
      _status = SpotifyConnectionStatus.error;
      _errorMessage = 'No Spotify refresh token is available yet.';
      notifyListeners();
      return false;
    }

    _status = SpotifyConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    final client = HttpClient();

    try {
      final request = await client.postUrl(Uri.parse(_tokenEndpoint));
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(
        'grant_type=refresh_token'
        '&refresh_token=${Uri.encodeQueryComponent(_refreshToken!)}'
        '&client_id=${Uri.encodeQueryComponent(clientId)}',
      );

      final response = await request.close();
      final payload = await response.transform(utf8.decoder).join();
      return _handleTokenResponse(response.statusCode, payload);
    } on SocketException {
      _status = SpotifyConnectionStatus.error;
      _errorMessage =
          'Could not reach Spotify. Check your internet connection and try again.';
      notifyListeners();
      return false;
    } on TimeoutException {
      _status = SpotifyConnectionStatus.error;
      _errorMessage = 'Spotify took too long to respond. Try again.';
      notifyListeners();
      return false;
    } catch (_) {
      _status = SpotifyConnectionStatus.error;
      _errorMessage = 'Spotify refresh failed. Try again.';
      notifyListeners();
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> disconnect() async {
    _status = SpotifyConnectionStatus.disconnected;
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _errorMessage = null;
    _profile = null;
    _playlists = const [];
    _searchEntries = const [];
    _playlistTracks.clear();
    _playlistTrackErrors.clear();
    _sessionPlaylistCache.clear();
    _loadingPlaylistIds.clear();
    _pendingVerifier = null;
    await _clearSession();
    notifyListeners();
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) await prefs.setString('spotify_access_token', _accessToken!);
    if (_refreshToken != null) await prefs.setString('spotify_refresh_token', _refreshToken!);
    if (_expiresAt != null) {
      await prefs.setString('spotify_expires_at', _expiresAt!.toIso8601String());
    }
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_cadence', _userCadence);
    await prefs.setInt('bpm_tolerance', _bpmTolerance);
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('spotify_access_token');
    _refreshToken = prefs.getString('spotify_refresh_token');
    final expiresAtStr = prefs.getString('spotify_expires_at');
    if (expiresAtStr != null) {
      _expiresAt = DateTime.parse(expiresAtStr);
    }

    if (_accessToken != null && _expiresAt != null && _expiresAt!.isAfter(DateTime.now())) {
      _status = SpotifyConnectionStatus.connected;
      unawaited(loadUserData());
    } else if (_refreshToken != null) {
      await refreshAccessToken();
    }
    
    _userCadence = prefs.getInt('user_cadence') ?? _defaultUserCadence;
    _bpmTolerance = prefs.getInt('bpm_tolerance') ?? _defaultBpmTolerance;
    
    notifyListeners();
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('spotify_access_token');
    await prefs.remove('spotify_refresh_token');
    await prefs.remove('spotify_expires_at');
    await prefs.remove('last_location');
    await prefs.remove('user_cadence');
    await prefs.remove('bpm_tolerance');
  }


  Future<bool> _exchangeAuthorizationCode({
    required String clientId,
    required String code,
    required String verifier,
  }) async {
    final client = HttpClient();

    try {
      final request = await client.postUrl(Uri.parse(_tokenEndpoint));
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(
        'grant_type=authorization_code'
        '&code=${Uri.encodeQueryComponent(code)}'
        '&redirect_uri=${Uri.encodeQueryComponent(_redirectUri)}'
        '&client_id=${Uri.encodeQueryComponent(clientId)}'
        '&code_verifier=${Uri.encodeQueryComponent(verifier)}',
      );

      final response = await request.close();
      final payload = await response.transform(utf8.decoder).join();
      return _handleTokenResponse(response.statusCode, payload);
    } on SocketException {
      _status = SpotifyConnectionStatus.error;
      _errorMessage =
          'Could not reach Spotify. Check your internet connection and try again.';
      notifyListeners();
      return false;
    } on TimeoutException {
      _status = SpotifyConnectionStatus.error;
      _errorMessage = 'Spotify took too long to respond. Try again.';
      notifyListeners();
      return false;
    } catch (_) {
      _status = SpotifyConnectionStatus.error;
      _errorMessage = 'Spotify token exchange failed. Try again.';
      notifyListeners();
      return false;
    } finally {
      client.close(force: true);
    }
  }

  bool _handleTokenResponse(int statusCode, String payload) {
    final json = jsonDecode(payload);

    if (statusCode != 200) {
      _status = SpotifyConnectionStatus.error;
      _errorMessage = json is Map<String, dynamic>
          ? (json['error_description'] as String?) ??
                (json['error'] as String?) ??
                'Spotify token request failed.'
          : 'Spotify token request failed.';
      notifyListeners();
      return false;
    }

    if (json is! Map<String, dynamic>) {
      _status = SpotifyConnectionStatus.error;
      _errorMessage = 'Spotify returned an unexpected response.';
      notifyListeners();
      return false;
    }

    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    _accessToken = json['access_token'] as String?;
    _refreshToken = (json['refresh_token'] as String?) ?? _refreshToken;
    _pendingVerifier = null;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    _status = _accessToken == null
        ? SpotifyConnectionStatus.error
        : SpotifyConnectionStatus.connected;
    _errorMessage = _accessToken == null
        ? 'Spotify token response did not include an access token.'
        : null;
    notifyListeners();
    if (_status == SpotifyConnectionStatus.connected) {
      unawaited(_saveSession());
      unawaited(loadUserData());
    }
    return _status == SpotifyConnectionStatus.connected;
  }

  Future<void> loadUserData() async {
    if (!await _ensureValidAccessToken()) return;

    _isLoadingData = true;
    notifyListeners();

    try {
      final profileJson = await _getJson('https://api.spotify.com/v1/me');
      final playlistsJson = await _getJson(
        'https://api.spotify.com/v1/me/playlists?limit=20',
      );

      _profile = _parseProfile(profileJson);
      _playlists = _parsePlaylists(playlistsJson);
      _searchEntries = _playlists.map(spotifyPlaylistToSearchEntry).toList(growable: false);
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Spotify connected, but your account data could not be loaded.';
    } finally {
      _isLoadingData = false;
      notifyListeners();
    }
  }

  Future<void> loadTracksForPlaylist(String playlistId, {int? targetBpm}) async {
    final cachedTracks = _playlistTracks[playlistId];
    if (playlistId.isEmpty ||
        (cachedTracks != null && cachedTracks.isNotEmpty) ||
        _loadingPlaylistIds.contains(playlistId)) {
      return;
    }
    if (!await _ensureValidAccessToken()) {
      _playlistTrackErrors[playlistId] =
          'Spotify token is missing or expired. Reconnect Spotify and try again.';
      notifyListeners();
      return;
    }

    final cached = findPlaylistById(playlistId);
    final spotifyUri = cached?.spotifyUri;
    String realId = playlistId;
    if (spotifyUri != null && spotifyUri.isNotEmpty) {
      if (spotifyUri.startsWith('spotify:playlist:')) {
        realId = spotifyUri.split(':').last;
      } else {
        final spotifyUriParsed = Uri.tryParse(spotifyUri);
        if (spotifyUriParsed != null &&
            (spotifyUriParsed.host == 'open.spotify.com' ||
                spotifyUriParsed.host == 'play.spotify.com')) {
          final segments = spotifyUriParsed.pathSegments
              .where((segment) => segment.isNotEmpty)
              .toList(growable: false);
          if (segments.length >= 2 && segments.first == 'playlist') {
            realId = segments[1];
          }
        }
      }
    } else if (playlistId.startsWith('search-') || playlistId.startsWith('recent-')) {
      realId = playlistId;
    }

    if (realId.isEmpty) return;
    final looksLikeSpotifyPlaylistId = RegExp(
      r'^[A-Za-z0-9]{22}$',
    ).hasMatch(realId);
    if (!looksLikeSpotifyPlaylistId) {
      _playlistTrackErrors[playlistId] =
          'This playlist has no valid Spotify playlist ID, so tracks cannot be loaded.';
      _debugTrackLoad(
        'skip playlist=$playlistId reason=invalid_playlist_id realId=$realId uri=${spotifyUri ?? '(none)'}',
      );
      notifyListeners();
      return;
    }

    _loadingPlaylistIds.add(playlistId);
    _lastResolvedBpmCount = 0;
    _lastBackendTimedOut = false;
    _playlistTrackErrors.remove(playlistId);
    notifyListeners();

    try {
      _debugTrackLoad('start playlist=$playlistId spotifyPlaylistId=$realId');
      final json = await _getJson(
        'https://api.spotify.com/v1/playlists/$realId/tracks?limit=50&offset=0',
      );
      final items = json['items'] as List<dynamic>? ?? const [];
      final rawTracks = items
          .whereType<Map<String, dynamic>>()
          .toList(growable: false)
          .asMap()
          .entries
           .map((entry) => (index: entry.key, item: entry.value))
           .map((entry) => (
                 index: entry.index,
                 track: entry.item['track'] ?? entry.item['item'],
               ))
          .where((entry) => entry.track is Map<String, dynamic>)
          .map((entry) => (
                index: entry.index,
                track: entry.track as Map<String, dynamic>,
              ))
          .where((entry) => (entry.track['type'] as String?) == 'track')
          .map(
            (entry) => spotifyTrackFromJson(
              entry.track,
              playlistPosition: entry.index,
            ),
          )
          .where((track) => track.spotifyUri.isNotEmpty && track.id.isNotEmpty)
          .toList(growable: false);
      _debugTrackLoad(
        'spotify_tracks playlist=$playlistId total=${rawTracks.length}',
      );

      final usedTargetBpm = targetBpm ?? _userCadence;
      final minBpm = usedTargetBpm - _bpmTolerance;
      final maxBpm = usedTargetBpm + _bpmTolerance;
      final filteredTracks = await _filterTracksByBpm(
        tracks: rawTracks,
        minBpm: minBpm,
        maxBpm: maxBpm,
      );
      _playlistTracks[playlistId] = filteredTracks;
      if (rawTracks.isNotEmpty && filteredTracks.isEmpty) {
        if (_lastBackendTimedOut && _lastResolvedBpmCount == 0) {
          _playlistTrackErrors[playlistId] =
              'Backend BPM lookup timed out. Make sure backend is running and try again.';
        } else {
          _playlistTrackErrors[playlistId] =
              'No tracks in $minBpm-$maxBpm BPM were found for this playlist.';
        }
      }
      _debugTrackLoad(
        'done playlist=$playlistId kept=${filteredTracks.length} range=$minBpm-$maxBpm',
      );
    } on _ApiRequestException catch (e) {
      _playlistTrackErrors[playlistId] =
          'Track loading failed (${e.statusCode ?? 'network'}): ${e.message}';
      _debugTrackLoad(
        'error playlist=$playlistId stage=spotify status=${e.statusCode ?? 'network'} url=${e.url} detail=${e.message}',
      );
      _errorMessage = 'Could not load tracks for this playlist yet.';
    } catch (e) {
      _playlistTrackErrors[playlistId] = 'Track loading failed: $e';
      _debugTrackLoad('error playlist=$playlistId stage=unknown detail=$e');
      _errorMessage = 'Could not load tracks for this playlist yet.';
    } finally {
      _loadingPlaylistIds.remove(playlistId);
      notifyListeners();
    }
  }

  Future<String?> ensureSessionPlaylistForBpm({
    required TempoPlaylist sourcePlaylist,
    required List<SpotifyTrack> tracks,
    required int minBpm,
    required int maxBpm,
  }) async {
    if (tracks.isEmpty) return null;
    if (!await _ensureValidAccessToken()) return null;

    final signatureSeed = tracks.map((track) => track.id).join(',');
    final signature = sha1.convert(utf8.encode(signatureSeed)).toString();
    final cacheKey = '${sourcePlaylist.id}|$minBpm|$maxBpm';
    final cached = _sessionPlaylistCache[cacheKey];
    if (cached != null &&
        cached.signature == signature &&
        DateTime.now().difference(cached.createdAt) <
            const Duration(hours: 2)) {
      _debugTrackLoad(
        'session_playlist_reuse source=${sourcePlaylist.id} uri=${cached.playlistUri}',
      );
      return cached.playlistUri;
    }

    final targetBpm = (minBpm + maxBpm) ~/ 2;
    final playlistTitle = '${sourcePlaylist.title} $targetBpm BPM';
    final description =
        'Auto-generated by stempo from "${sourcePlaylist.title}" for $targetBpm BPM ($minBpm-$maxBpm range).';
    _debugTrackLoad(
      'session_playlist_create_start source=${sourcePlaylist.id} name="$playlistTitle" tracks=${tracks.length}',
    );

    try {
      if (_profile == null) {
        await loadUserData();
      }
      final userId = _profile?.id;
      if (userId == null) {
        _debugTrackLoad('session_playlist_create_failed reason=no_user_id');
        return null;
      }

      final existingPlaylist = await _findExistingGeneratedPlaylist(
        userId: userId,
        playlistTitle: playlistTitle,
      );
      if (existingPlaylist != null) {
        _sessionPlaylistCache[cacheKey] = _SessionPlaylistCacheEntry(
          playlistUri: existingPlaylist.playlistUri,
          signature: signature,
          createdAt: DateTime.now(),
        );
        _debugTrackLoad(
          'session_playlist_reuse_existing source=${sourcePlaylist.id} playlistId=${existingPlaylist.playlistId} uri=${existingPlaylist.playlistUri}',
        );
        return existingPlaylist.playlistUri;
      }

      final created = await _postJson(
        'https://api.spotify.com/v1/users/$userId/playlists',
        {
          'name': playlistTitle,
          'description': description,
          'public': false,
        },
      );
      final playlistId = created['id'] as String? ?? '';
      final playlistUri = created['uri'] as String? ?? '';
      if (playlistId.isEmpty || playlistUri.isEmpty) {
        _debugTrackLoad(
          'session_playlist_create_failed source=${sourcePlaylist.id} reason=missing_id_or_uri payload=$created',
        );
        return null;
      }
      _debugTrackLoad(
        'session_playlist_create_ok source=${sourcePlaylist.id} playlistId=$playlistId uri=$playlistUri',
      );

      final uris = tracks
          .map((track) => track.spotifyUri)
          .where((uri) => uri.isNotEmpty)
          .toList(growable: false);
      if (uris.isEmpty) return null;

      const chunkSize = 100;
      for (var offset = 0; offset < uris.length; offset += chunkSize) {
        final end = min(offset + chunkSize, uris.length);
        final chunk = uris.sublist(offset, end);
        _debugTrackLoad(
          'session_playlist_add_chunk playlistId=$playlistId count=${chunk.length}',
        );
        await _postJson(
          'https://api.spotify.com/v1/playlists/$playlistId/tracks',
          {
            'uris': chunk,
          },
        );
      }

      _sessionPlaylistCache[cacheKey] = _SessionPlaylistCacheEntry(
        playlistUri: playlistUri,
        signature: signature,
        createdAt: DateTime.now(),
      );
      _debugTrackLoad(
        'session_playlist_ready source=${sourcePlaylist.id} uri=$playlistUri',
      );
      return playlistUri;
    } on _ApiRequestException catch (e) {
      _debugTrackLoad(
        'session_playlist_error source=${sourcePlaylist.id} status=${e.statusCode ?? 'network'} url=${e.url} detail=${e.message}',
      );
      return null;
    } catch (e) {
      _debugTrackLoad('session_playlist_error source=${sourcePlaylist.id} detail=$e');
      return null;
    }
  }

  Future<bool> startPlaylistPlaybackAtTrack({
    required String playlistUri,
    required String trackUri,
  }) async {
    if (playlistUri.isEmpty || trackUri.isEmpty) return false;
    if (!await _ensureValidAccessToken()) return false;

    final client = HttpClient()..connectionTimeout = _spotifyRequestTimeout;
    const url = 'https://api.spotify.com/v1/me/player/play';
    try {
      final request = await client
          .putUrl(Uri.parse(url))
          .timeout(_spotifyRequestTimeout);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $_accessToken',
      );
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'context_uri': playlistUri,
          'offset': {'uri': trackUri},
        }),
      );
      final response = await request.close().timeout(_spotifyRequestTimeout);
      final payload = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_spotifyRequestTimeout);

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok) {
        _debugTrackLoad(
          'player_play_error status=${response.statusCode} body=$payload',
        );
      } else {
        _debugTrackLoad(
          'player_play_ok context=$playlistUri offset=$trackUri',
        );
      }
      return ok;
    } catch (e) {
      _debugTrackLoad('player_play_exception detail=$e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<SpotifyTrack>> _filterTracksByBpm({
    required List<SpotifyTrack> tracks,
    required int minBpm,
    required int maxBpm,
  }) async {
    final uniqueTrackIds = tracks
        .map((track) => track.id)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final bpmFetchResult = await _fetchTrackBpmsBatch(uniqueTrackIds);
    _lastResolvedBpmCount = bpmFetchResult.items.length;
    _lastBackendTimedOut = bpmFetchResult.timedOut;

    final resolvedTracks = tracks.map((track) {
      final bpm = bpmFetchResult.items[track.id];
      if (bpm == null || bpm < minBpm || bpm > maxBpm) {
        return null;
      }
      return SpotifyTrack(
        id: track.id,
        title: track.title,
        artistLine: track.artistLine,
        imageUrl: track.imageUrl,
        spotifyUri: track.spotifyUri,
        durationMs: track.durationMs,
        bpm: bpm.round(),
        playlistPosition: track.playlistPosition,
      );
    }).toList(growable: false);
    return resolvedTracks.whereType<SpotifyTrack>().toList(growable: false);
  }

  Future<_BpmBatchFetchResult> _fetchTrackBpmsBatch(
    List<String> spotifyIds,
  ) async {
    if (spotifyIds.isEmpty ||
        _backendBaseUrl.isEmpty) {
      return const _BpmBatchFetchResult(items: <String, double?>{});
    }
    if (!await _ensureValidAccessToken()) {
      return const _BpmBatchFetchResult(items: <String, double?>{});
    }

    final bpmById = <String, double?>{};
    for (var offset = 0; offset < spotifyIds.length; offset += _bpmBatchChunkSize) {
      final end = min(offset + _bpmBatchChunkSize, spotifyIds.length);
      final chunk = spotifyIds.sublist(offset, end);
      final chunkResult = await _fetchTrackBpmsChunk(chunk);
      bpmById.addAll(chunkResult.items);
      if (chunkResult.timedOut) {
        _debugTrackLoad(
          'backend_timeout_stopping early_after=${bpmById.length}',
        );
        return _BpmBatchFetchResult(items: bpmById, timedOut: true);
      }
    }
    return _BpmBatchFetchResult(items: bpmById);
  }

  Future<_BpmBatchFetchResult> _fetchTrackBpmsChunk(
    List<String> spotifyIds,
  ) async {
    final client = HttpClient()..connectionTimeout = _backendRequestTimeout;
    try {
      final baseUrl = _backendBaseUrl.endsWith('/')
          ? _backendBaseUrl.substring(0, _backendBaseUrl.length - 1)
          : _backendBaseUrl;
      final uri = Uri.parse('$baseUrl/soundcharts/song/bpm/batch');
      _debugTrackLoad('backend_request url=$uri ids=${spotifyIds.length}');
      final request = await client.postUrl(uri).timeout(_backendRequestTimeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $_accessToken',
      );
      request.write(
        jsonEncode({'spotify_ids': spotifyIds}),
      );
      final response = await request.close().timeout(_backendRequestTimeout);
      final payload = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_backendRequestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _debugTrackLoad(
          'backend_error status=${response.statusCode} body=$payload',
        );
        return const _BpmBatchFetchResult(items: <String, double?>{});
      }

      final json = jsonDecode(payload);
      if (json is! Map<String, dynamic>) {
        return const _BpmBatchFetchResult(items: <String, double?>{});
      }
      final items = json['items'];
      if (items is! List) {
        return const _BpmBatchFetchResult(items: <String, double?>{});
      }
      final bpmById = <String, double?>{};
      for (final item in items.whereType<Map<String, dynamic>>()) {
        final spotifyId = item['spotify_id'] as String? ?? '';
        if (spotifyId.isEmpty) continue;
        final tempo = item['tempo'];
        bpmById[spotifyId] = tempo is num ? tempo.toDouble() : null;
      }
      _debugTrackLoad(
        'backend_success mapped=${bpmById.length} ids=${spotifyIds.length}',
      );
      return _BpmBatchFetchResult(items: bpmById);
    } on TimeoutException catch (e) {
      _debugTrackLoad('backend_exception detail=$e');
      return const _BpmBatchFetchResult(
        items: <String, double?>{},
        timedOut: true,
      );
    } catch (e) {
      _debugTrackLoad('backend_exception detail=$e');
      return const _BpmBatchFetchResult(items: <String, double?>{});
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final client = HttpClient()..connectionTimeout = _spotifyRequestTimeout;
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(_spotifyRequestTimeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_accessToken');
      final response = await request.close().timeout(_spotifyRequestTimeout);
      final payload = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_spotifyRequestTimeout);
      final json = jsonDecode(payload);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _ApiRequestException(
          url: url,
          statusCode: response.statusCode,
          message: payload,
        );
      }
      if (json is! Map<String, dynamic>) {
        throw _ApiRequestException(
          url: url,
          statusCode: response.statusCode,
          message: 'Response is not a JSON object.',
        );
      }
      return json;
    } on SocketException catch (e) {
      throw _ApiRequestException(url: url, message: e.message);
    } on TimeoutException {
      throw _ApiRequestException(url: url, message: 'Request timed out.');
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient()..connectionTimeout = _spotifyRequestTimeout;
    try {
      final request = await client
          .postUrl(Uri.parse(url))
          .timeout(_spotifyRequestTimeout);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $_accessToken',
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close().timeout(_spotifyRequestTimeout);
      final payload = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_spotifyRequestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _ApiRequestException(
          url: url,
          statusCode: response.statusCode,
          message: payload,
        );
      }
      final json = jsonDecode(payload);
      if (json is! Map<String, dynamic>) {
        throw _ApiRequestException(
          url: url,
          statusCode: response.statusCode,
          message: 'Response is not a JSON object.',
        );
      }
      return json;
    } on SocketException catch (e) {
      throw _ApiRequestException(url: url, message: e.message);
    } on TimeoutException {
      throw _ApiRequestException(url: url, message: 'Request timed out.');
    } finally {
      client.close(force: true);
    }
  }

  Future<_ExistingPlaylistMatch?> _findExistingGeneratedPlaylist({
    required String userId,
    required String playlistTitle,
  }) async {
    final normalizedTitle = playlistTitle.trim().toLowerCase();

    String? nextUrl = 'https://api.spotify.com/v1/me/playlists?limit=50';
    var pageCount = 0;

    while (nextUrl != null && pageCount < 8) {
      final payload = await _getJson(nextUrl);
      final items = payload['items'] as List<dynamic>? ?? const [];
      for (final item in items.whereType<Map<String, dynamic>>()) {
        final name = (item['name'] as String? ?? '').trim().toLowerCase();
        if (name != normalizedTitle) continue;

        final owner = item['owner'] as Map<String, dynamic>? ?? const {};
        final ownerId = owner['id'] as String? ?? '';
        if (ownerId != userId) continue;

        final playlistUri = item['uri'] as String? ?? '';
        final playlistId = item['id'] as String? ?? '';
        if (playlistUri.isEmpty || playlistId.isEmpty) continue;

        return _ExistingPlaylistMatch(
          playlistId: playlistId,
          playlistUri: playlistUri,
        );
      }

      final next = payload['next'] as String?;
      nextUrl = (next != null && next.isNotEmpty) ? next : null;
      pageCount++;
    }

    return null;
  }

  SpotifyUserProfile _parseProfile(Map<String, dynamic> json) {
    final images = json['images'] as List<dynamic>? ?? const [];
    final firstImage = images.isNotEmpty ? images.first as Map<String, dynamic>? : null;
    return SpotifyUserProfile(
      id: json['id'] as String? ?? 'spotify-user',
      displayName:
          (json['display_name'] as String?) ??
          (json['email'] as String?) ??
          'Spotify listener',
      email: json['email'] as String?,
      avatarUrl: firstImage?['url'] as String?,
    );
  }

  List<TempoPlaylist> _parsePlaylists(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .toList(growable: false)
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final item = entry.value;
          final images = item['images'] as List<dynamic>? ?? const [];
          final firstImage = images.isNotEmpty ? images.first as Map<String, dynamic>? : null;
          final owner = item['owner'] as Map<String, dynamic>? ?? const {};
          final subtitle = owner['display_name'] as String? ?? 'Spotify playlist';
          final tracks = item['tracks'] as Map<String, dynamic>? ?? const {};

          return spotifyPlaylistToTempoPlaylist(
            id: item['id'] as String? ?? 'playlist-$index',
            title: item['name'] as String? ?? 'Playlist',
            subtitle: subtitle,
            imageUrl: firstImage?['url'] as String? ?? '',
            trackCount: (tracks['total'] as num?)?.toInt() ?? 0,
            isPinned: index == 0,
            wasRecentlyPlayed: index < 5,
          );
        })
        .where((playlist) => playlist.title.isNotEmpty)
        .toList(growable: false);
  }

  void _debugTrackLoad(String message) {
    if (!kDebugMode) return;
    debugPrint('[PlaylistTracks] $message');
  }

  String _generateCodeVerifier() {
    final codeUnits = List<int>.generate(
      96,
      (_) => _verifierAlphabet.codeUnitAt(
        _random.nextInt(_verifierAlphabet.length),
      ),
    );
    return String.fromCharCodes(codeUnits);
  }

  String _buildCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}

class _ApiRequestException implements Exception {
  const _ApiRequestException({
    required this.url,
    required this.message,
    this.statusCode,
  });

  final String url;
  final int? statusCode;
  final String message;
}

class _BpmBatchFetchResult {
  const _BpmBatchFetchResult({
    required this.items,
    this.timedOut = false,
  });

  final Map<String, double?> items;
  final bool timedOut;
}

class _SessionPlaylistCacheEntry {
  const _SessionPlaylistCacheEntry({
    required this.playlistUri,
    required this.signature,
    required this.createdAt,
  });

  final String playlistUri;
  final String signature;
  final DateTime createdAt;
}

class _ExistingPlaylistMatch {
  const _ExistingPlaylistMatch({
    required this.playlistId,
    required this.playlistUri,
  });

  final String playlistId;
  final String playlistUri;
}
