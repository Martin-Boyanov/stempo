import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/spotify_remote_service.dart';
import '../state/auth_providers.dart';
import '../state/playlist_models.dart';
import '../state/spotify_models.dart';
import '../ui/theme/app_fx.dart';
import '../ui/theme/colors.dart';
import '../ui/widgets/media_cover.dart';
import 'now_playing_page.dart';

class PlaylistPageArgs {
  const PlaylistPageArgs({required this.playlist, required this.userCadence});

  final TempoPlaylist playlist;
  final int userCadence;
}

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key, required this.args});

  final PlaylistPageArgs args;

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  bool _requestedTracks = false;
  bool _isLaunching = false;
  late Color _accentColor;
  late Color _secondaryColor;

  @override
  void initState() {
    super.initState();
    _accentColor = widget.args.playlist.colors.last;
    _secondaryColor = AppColors.cinemaRed;
    _updatePalette();
  }

  Future<void> _updatePalette() async {
    final imagePath = widget.args.playlist.imageAsset;
    if (imagePath.isEmpty) return;

    final imageProvider = imagePath.startsWith('http')
        ? NetworkImage(imagePath)
        : AssetImage(imagePath) as ImageProvider;

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 20,
      );
      if (!mounted) return;

      final mainColor = palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.dominantColor?.color ??
          widget.args.playlist.colors.last;

      final sideColor = palette.mutedColor?.color ??
          palette.darkVibrantColor?.color ??
          AppColors.cinemaRed;

      setState(() {
        _accentColor = _ensureVisible(mainColor);
        _secondaryColor = _ensureVisible(sideColor);
      });
    } catch (_) {}
  }

  Color _ensureVisible(Color color) {
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness < 0.2) {
      return hsl.withLightness(0.5).withSaturation(0.8).toColor();
    }
    return color;
  }

  _BpmRange get _effectiveBpmRange {
    final titleMatch = RegExp(
      r'(\d{2,3})\s*-\s*(\d{2,3})\s*BPM$',
      caseSensitive: false,
    ).firstMatch(widget.args.playlist.title);
    final minFromTitle = int.tryParse(titleMatch?.group(1) ?? '');
    final maxFromTitle = int.tryParse(titleMatch?.group(2) ?? '');
    if (minFromTitle != null &&
        maxFromTitle != null &&
        minFromTitle <= maxFromTitle) {
      return _BpmRange(min: minFromTitle, max: maxFromTitle);
    }

    final targetBpm = widget.args.userCadence;
    return _BpmRange(min: targetBpm - 10, max: targetBpm + 10);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedTracks) return;
    final auth = AuthScope.watch(context);
    if (auth.accessToken == null || auth.accessToken!.isEmpty) return;
    final range = _effectiveBpmRange;
    _requestedTracks = true;
    auth.loadTracksForPlaylist(
      widget.args.playlist.id,
      targetBpm: (range.min + range.max) ~/ 2,
    );
  }

  Future<bool> _openSpotifyUri(String spotifyUri) async {
    if (spotifyUri.isEmpty || _isLaunching) return false;
    setState(() => _isLaunching = true);

    try {
      final remotePlayed = await SpotifyRemoteService.instance.playUri(
        spotifyUri,
      );
      if (remotePlayed) {
        return true;
      }

      final openedInSpotifyApp = await _openInSpotifyApp(spotifyUri);
      if (openedInSpotifyApp) {
        return true;
      }

      final webUrl = _webUrlFromSpotifyUri(spotifyUri);
      final webUri = Uri.parse(webUrl);
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      final openedInSpotifyApp = await _openInSpotifyApp(spotifyUri);
      if (openedInSpotifyApp) {
        return true;
      }
      try {
        final webUrl = _webUrlFromSpotifyUri(spotifyUri);
        return await launchUrl(
          Uri.parse(webUrl),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        debugPrint('Failed to open Spotify URI: $spotifyUri ($e)');
        return false;
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  Future<void> _playTrack(SpotifyTrack track) async {
    final auth = AuthScope.read(context);
    final tracks = auth.tracksForPlaylist(widget.args.playlist.id);
    final range = _effectiveBpmRange;
    final minBpm = range.min;
    final maxBpm = range.max;
    final sessionPlaylistUri = await auth.ensureSessionPlaylistForBpm(
      sourcePlaylist: widget.args.playlist,
      tracks: tracks,
      minBpm: minBpm,
      maxBpm: maxBpm,
    );

    var opened = false;
    if (sessionPlaylistUri != null && sessionPlaylistUri.isNotEmpty) {
      opened = await auth.startPlaylistPlaybackAtTrack(
        playlistUri: sessionPlaylistUri,
        trackUri: track.spotifyUri,
      );
    } else if ((widget.args.playlist.spotifyUri ?? '').isNotEmpty) {
      opened = await auth.startPlaylistPlaybackAtTrack(
        playlistUri: widget.args.playlist.spotifyUri!,
        trackUri: track.spotifyUri,
      );
    }

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not jump directly to this track in playlist context. Keep Spotify active and try again.',
          ),
        ),
      );
      return;
    }
    if (!opened || !mounted) return;
  }

  Future<void> _startSession(List<SpotifyTrack> tracks) async {
    bool opened = false;
    final range = _effectiveBpmRange;
    final minBpm = range.min;
    final maxBpm = range.max;

    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No tracks in $minBpm-$maxBpm BPM were found for this playlist.'),
        ),
      );
      return;
    }

    final auth = AuthScope.read(context);
    final sessionPlaylistUri = await auth.ensureSessionPlaylistForBpm(
      sourcePlaylist: widget.args.playlist,
      tracks: tracks,
      minBpm: minBpm,
      maxBpm: maxBpm,
    );

    if (sessionPlaylistUri != null && sessionPlaylistUri.isNotEmpty) {
      opened = await _openSpotifyUri(sessionPlaylistUri);
    } else {
      // If playlist creation failed, show a hint but keep going with the first track
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note: Could not create Spotify playlist. Playing tracks individually.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      opened = await _openSpotifyUri(tracks.first.spotifyUri);
    }

    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not start playback. Open Spotify on your phone and try again.',
          ),
        ),
      );
      return;
    }

    final displayTrack = tracks.isNotEmpty ? tracks.first : null;
    context.push(
      '/now-playing',
      extra: NowPlayingPageArgs(
        trackTitle: displayTrack?.title ?? widget.args.playlist.title,
        trackArtist:
            displayTrack?.artistLine ??
            '${widget.args.playlist.mood} ${widget.args.playlist.category}',
        trackImageAsset:
            displayTrack?.imageUrl.isNotEmpty == true
                ? displayTrack!.imageUrl
                : widget.args.playlist.imageAsset,
        trackBpm: displayTrack?.bpm ?? widget.args.playlist.bpm,
        userCadence: widget.args.userCadence,
        spotifyUri: sessionPlaylistUri ?? displayTrack?.spotifyUri,
        allowedTrackUris: tracks
            .map((track) => track.spotifyUri)
            .where((uri) => uri.isNotEmpty)
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.args.playlist;
    final auth = AuthScope.watch(context);
    final tracks = auth.tracksForPlaylist(playlist.id);
    final isLoadingTracks = auth.isLoadingTracksForPlaylist(playlist.id);
    final trackLoadError = auth.trackErrorForPlaylist(playlist.id);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AtmosphereBackground(
              accent: _accentColor,
              secondaryAccent: _secondaryColor,
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 208),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _RoundIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/home');
                              }
                            },
                          ),
                          const Spacer(),
                          const Text(
                            'Playlist',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          _RoundIconButton(
                            icon: Icons.open_in_new_rounded,
                            onTap: playlist.spotifyUri == null
                                ? null
                                : () => _openSpotifyUri(playlist.spotifyUri!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _PlaylistArtwork(
                        playlist: playlist,
                        glowColor: _accentColor,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        playlist.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 32,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        playlist.subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: _isLaunching ? 'Opening...' : 'Start Session',
                              filled: true,
                              onTap: () => _startSession(tracks),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              label: 'Open Playlist',
                              onTap: playlist.spotifyUri == null
                                  ? () => context.go('/home')
                                  : () => _openSpotifyUri(playlist.spotifyUri!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _PlaylistTrackSection(
                        tracks: tracks,
                        isLoading: isLoadingTracks,
                        loadError: trackLoadError,
                        onPlayTrack: _playTrack,
                        onRetry: () => auth.loadTracksForPlaylist(
                          playlist.id,
                          targetBpm:
                              (_effectiveBpmRange.min + _effectiveBpmRange.max) ~/
                              2,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _PlaylistNowPlayingBar(
                          userCadence: widget.args.userCadence,
                          trackBpm: widget.args.playlist.bpm,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _PlaylistBottomNav(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          width: 46,
          height: 46,
          decoration: AppFx.glassDecoration(
            radius: 18,
            glowColor: AppColors.cinemaRed,
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}

class _PlaylistArtwork extends StatelessWidget {
  const _PlaylistArtwork({required this.playlist, required this.glowColor});

  final TempoPlaylist playlist;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.45),
              blurRadius: 72,
              spreadRadius: 4,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: glowColor.withValues(alpha: 0.22),
              blurRadius: 110,
              spreadRadius: 0,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: MediaCover(
          imageAsset: playlist.imageAsset,
          size: double.infinity,
          borderRadius: 34,
        ),
      ),
    );
  }
}

class _PlaylistTrackSection extends StatelessWidget {
  const _PlaylistTrackSection({
    required this.tracks,
    required this.isLoading,
    required this.loadError,
    required this.onPlayTrack,
    required this.onRetry,
  });

  final List<SpotifyTrack> tracks;
  final bool isLoading;
  final String? loadError;
  final Future<void> Function(SpotifyTrack track) onPlayTrack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 28,
      padding: const EdgeInsets.all(18),
      glowColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Tracks',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              Text(
                'Play in Spotify',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryBright,
                ),
              ),
            )
          else if (loadError != null && loadError!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loadError!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryBright,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            )
          else if (tracks.isEmpty)
            const Text(
              'Tracks will appear here once Spotify finishes loading this playlist.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...(() {
            final visibleTracks = tracks.take(12).toList(growable: false);
            return visibleTracks.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SpotifyTrackRow(
                  track: entry.value,
                  onPlay: () => onPlayTrack(entry.value),
                ),
              ),
            );
          })(),
        ],
      ),
    );
  }
}

class _SpotifyTrackRow extends StatelessWidget {
  const _SpotifyTrackRow({required this.track, required this.onPlay});

  final SpotifyTrack track;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 22,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          MediaCover(
            imageAsset: track.imageUrl,
            size: 58,
            borderRadius: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  track.artistLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDuration(track.durationMs),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onPlay,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryBright, AppColors.primary],
                    ),
                    boxShadow: AppFx.softGlow(
                      AppColors.primaryBright,
                      strength: 0.18,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.background,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: filled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryBright, AppColors.primary],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x661A2320), Color(0x33211B20)],
                ),
          boxShadow: filled
              ? AppFx.softGlow(AppColors.primary, strength: 0.22)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistBottomNav extends StatelessWidget {
  const _PlaylistBottomNav();

  @override
  Widget build(BuildContext context) {
    final items = <_PlaylistNavItem>[
      const _PlaylistNavItem(
        label: 'Home',
        icon: Icons.home_rounded,
        targetRoute: '/home',
      ),
      const _PlaylistNavItem(
        label: 'Search',
        icon: Icons.search_rounded,
        targetRoute: '/home',
      ),
      const _PlaylistNavItem(
        label: 'Library',
        icon: Icons.library_music_rounded,
        targetRoute: '/home',
      ),
      const _PlaylistNavItem(
        label: 'Stats',
        icon: Icons.bar_chart_rounded,
        targetRoute: '/steps',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212).withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go(items[i].targetRoute),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: i == 0
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 24,
                        color: i == 0
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          color: i == 0
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (i != items.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _PlaylistNowPlayingBar extends StatefulWidget {
  const _PlaylistNowPlayingBar({
    required this.userCadence,
    required this.trackBpm,
  });

  final int userCadence;
  final int trackBpm;

  @override
  State<_PlaylistNowPlayingBar> createState() => _PlaylistNowPlayingBarState();
}

class _PlaylistNowPlayingBarState extends State<_PlaylistNowPlayingBar> {
  final SpotifyRemoteService _remote = SpotifyRemoteService.instance;
  StreamSubscription<SpotifyRemotePlayerState>? _playerSub;
  bool _isPaused = true;
  bool _isLoaded = false;
  String? _title;
  String? _artist;
  String? _image;

  @override
  void initState() {
    super.initState();
    _bindRemote();
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    super.dispose();
  }

  Future<void> _bindRemote() async {
    _playerSub = _remote.playerStateStream().listen((state) {
      if (!mounted) return;
      setState(() {
        _isLoaded = true;
        _isPaused = state.isPaused;
        if (state.trackUri.isEmpty || state.trackName.isEmpty) {
          _title = null;
          _artist = null;
          _image = null;
          return;
        }
        _title = state.trackName;
        _artist = state.artistName;
        _image = state.resolvedImageUrl;
      });
    });

    try {
      final playerState = await _remote.getPlayerState();
      if (!mounted) return;
      setState(() {
        _isLoaded = true;
        if (playerState == null ||
            playerState.trackUri.isEmpty ||
            playerState.trackName.isEmpty) {
          _title = null;
          _artist = null;
          _image = null;
          _isPaused = true;
          return;
        }
        _isPaused = playerState.isPaused;
        _title = playerState.trackName;
        _artist = playerState.artistName;
        _image = playerState.resolvedImageUrl;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoaded = true);
    }
  }

  Future<void> _togglePlayback() async {
    final wasPaused = _isPaused;
    setState(() => _isPaused = !wasPaused);
    try {
      if (wasPaused) {
        await _remote.resume();
      } else {
        await _remote.pause();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPaused = wasPaused);
    }
  }

  void _navigateToNowPlaying() {
    final title = _title;
    if (title == null || title.isEmpty) return;
    context.push(
      '/now-playing',
      extra: NowPlayingPageArgs(
        trackTitle: title,
        trackArtist: _artist ?? '',
        trackImageAsset: _image ?? '',
        trackBpm: widget.trackBpm,
        userCadence: widget.userCadence,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _title;
    if (!_isLoaded || title == null || title.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _navigateToNowPlaying,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: AppFx.glassDecoration(
          radius: 12,
          elevated: true,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceFloating,
              AppColors.surfaceFloating.withValues(alpha: 0.8),
            ],
          ),
          glowColor: AppColors.primary.withValues(alpha: 0.18),
        ),
        child: Row(
          children: [
            MediaCover(
              imageAsset: _image ?? '',
              size: 42,
              borderRadius: 10,
              child: _isPaused
                  ? const SizedBox.shrink()
                  : const Center(
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _artist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayback,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  boxShadow: AppFx.softGlow(AppColors.primary, strength: 0.35),
                ),
                child: Icon(
                  _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: AppColors.background,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistNavItem {
  const _PlaylistNavItem({
    required this.label,
    required this.icon,
    required this.targetRoute,
  });

  final String label;
  final IconData icon;
  final String targetRoute;
}

class _BpmRange {
  const _BpmRange({required this.min, required this.max});

  final int min;
  final int max;
}


String _webUrlFromSpotifyUri(String spotifyUri) {
  final segments = spotifyUri.split(':');
  if (segments.length >= 3) {
    return 'https://open.spotify.com/${segments[1]}/${segments[2]}';
  }
  return 'https://open.spotify.com/';
}

Future<bool> _openInSpotifyApp(String spotifyUri) async {
  try {
    return await SpotifyRemoteService.instance.openUriInSpotifyApp(spotifyUri);
  } catch (_) {
    return false;
  }
}

String _formatDuration(int durationMs) {
  final totalSeconds = (durationMs / 1000).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
