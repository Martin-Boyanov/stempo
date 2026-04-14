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
  static const _scopes = [
    'user-read-private',
    'user-read-email',
    'playlist-read-private',
    'playlist-read-collaborative',
    'user-library-read',
    'user-read-playback-state',
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
  final Set<String> _loadingPlaylistIds = <String>{};
  bool _isLoadingData = false;
  String? _pendingVerifier;

  SpotifyAuthController();

  SpotifyConnectionStatus get status => _status;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  DateTime? get expiresAt => _expiresAt;
  String? get errorMessage => _errorMessage;
  SpotifyUserProfile? get profile => _profile;
  List<TempoPlaylist> get playlists => _playlists;
  List<SpotifySearchEntry> get searchEntries => _searchEntries;
  List<SpotifyTrack> tracksForPlaylist(String playlistId) =>
      _playlistTracks[playlistId] ?? const [];
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

    _status = SpotifyConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    return _exchangeAuthorizationCode(
      clientId: clientId,
      code: code,
      verifier: _pendingVerifier!,
    );
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

  void disconnect() {
    _status = SpotifyConnectionStatus.disconnected;
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _errorMessage = null;
    _profile = null;
    _playlists = const [];
    _searchEntries = const [];
    _playlistTracks.clear();
    _loadingPlaylistIds.clear();
    _pendingVerifier = null;
    _clearSession();
    notifyListeners();
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) await prefs.setString('spotify_access_token', _accessToken!);
    if (_refreshToken != null) await prefs.setString('spotify_refresh_token', _refreshToken!);
    if (_expiresAt != null) {
      await prefs.setString('spotify_expires_at', _expiresAt!.toIso8601String());
    }
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
    notifyListeners();
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('spotify_access_token');
    await prefs.remove('spotify_refresh_token');
    await prefs.remove('spotify_expires_at');
    await prefs.remove('last_location');
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
    if (_accessToken == null) return;

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

  Future<void> loadTracksForPlaylist(String playlistId) async {
    if (_accessToken == null ||
        playlistId.isEmpty ||
        _playlistTracks.containsKey(playlistId) ||
        _loadingPlaylistIds.contains(playlistId)) {
      return;
    }

    _loadingPlaylistIds.add(playlistId);
    notifyListeners();

    try {
      final json = await _getJson(
        'https://api.spotify.com/v1/playlists/$playlistId/tracks?limit=50',
      );
      final items = json['items'] as List<dynamic>? ?? const [];
      final tracks = items
          .whereType<Map<String, dynamic>>()
          .map((item) => item['track'])
          .whereType<Map<String, dynamic>>()
          .where((track) => (track['type'] as String?) == 'track')
          .map(spotifyTrackFromJson)
          .where((track) => track.spotifyUri.isNotEmpty)
          .toList(growable: false);
      _playlistTracks[playlistId] = tracks;
    } catch (_) {
      _errorMessage = 'Could not load tracks for this playlist yet.';
    } finally {
      _loadingPlaylistIds.remove(playlistId);
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_accessToken');
      final response = await request.close();
      final payload = await response.transform(utf8.decoder).join();
      final json = jsonDecode(payload);

      if (response.statusCode < 200 || response.statusCode >= 300 || json is! Map<String, dynamic>) {
        throw const FormatException('Invalid Spotify response');
      }
      return json;
    } finally {
      client.close(force: true);
    }
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
