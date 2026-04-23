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
import '../ui/widgets/loader.dart';
import '../ui/widgets/media_cover.dart';
import '../ui/widgets/now_playing_bar.dart';
import 'now_playing_page.dart';

class PlaylistPageArgs {
  const PlaylistPageArgs({
    required this.playlist,
    required this.userCadence,
    this.sourceTab = PlaylistSourceTab.home,
  });

  final TempoPlaylist playlist;
  final int userCadence;
  final PlaylistSourceTab sourceTab;
}

enum PlaylistSourceTab { home, search, library, modes }

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
  final ScrollController _scrollController = ScrollController();

  int get _targetBpm => (_effectiveBpmRange.min + _effectiveBpmRange.max) ~/ 2;

  @override
  void initState() {
    super.initState();
    _accentColor = widget.args.playlist.colors.last;
    _secondaryColor = AppColors.cinemaRed;
    _updatePalette();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
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

      final mainColor =
          palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.dominantColor?.color ??
          widget.args.playlist.colors.last;

      final sideColor =
          palette.mutedColor?.color ??
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
    final tolerance = AuthScope.read(context).bpmTolerance;
    return _BpmRange(min: targetBpm - tolerance, max: targetBpm + tolerance);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedTracks) return;
    final auth = AuthScope.watch(context);
    if (auth.accessToken == null || auth.accessToken!.isEmpty) return;
    _requestedTracks = true;
    unawaited(_loadTracks());
  }

  Future<void> _loadTracks({bool forceRefresh = false}) {
    return AuthScope.read(context).loadTracksForPlaylist(
      widget.args.playlist.id,
      targetBpm: _targetBpm,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _loadMoreTracks() {
    return AuthScope.read(
      context,
    ).loadMoreTracksForPlaylist(widget.args.playlist.id, targetBpm: _targetBpm);
  }

  Future<void> _refreshTracks() => _loadTracks(forceRefresh: true);

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 480) return;
    final auth = AuthScope.read(context);
    if (auth.hasMoreTracksForPlaylist(widget.args.playlist.id) &&
        !auth.isLoadingTracksForPlaylist(widget.args.playlist.id)) {
      unawaited(_loadMoreTracks());
    }
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

  Future<void> _handleStartSession({SpotifyTrack? startTrack}) async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);

    try {
      final auth = AuthScope.read(context);
      await auth.ensureAllTracksLoadedForPlaylist(
        widget.args.playlist.id,
        targetBpm: _targetBpm,
      );
      final tracks = auth.tracksForPlaylist(widget.args.playlist.id);

      if (tracks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No tracks available in the correct BPM range.'),
            ),
          );
        }
        return;
      }

      final range = _effectiveBpmRange;
      final sessionPlaylistUri = await auth.ensureSessionPlaylistForBpm(
        sourcePlaylist: widget.args.playlist,
        tracks: tracks,
        minBpm: range.min,
        maxBpm: range.max,
      );

      bool opened = false;
      if (sessionPlaylistUri != null && sessionPlaylistUri.isNotEmpty) {
        if (startTrack != null) {
          // Try to start at specific track via Connect API
          opened = await auth.startPlaylistPlaybackAtTrack(
            playlistUri: sessionPlaylistUri,
            trackUri: startTrack.spotifyUri,
          );
        }

        if (!opened) {
          // If jump failed or no specific track, launch the playlist context
          // We bypass _openSpotifyUri's internal state management since we manage it here
          opened = await _openInAppOrRemote(sessionPlaylistUri);
        }
      } else {
        // Fallback: Individual track if session playlist creation failed
        final fallbackUri = startTrack?.spotifyUri ?? tracks.first.spotifyUri;
        opened = await _openInAppOrRemote(fallbackUri);
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

      // Navigate to Now Playing
      final displayTrack = startTrack ?? tracks.first;
      context.push(
        '/now-playing',
        extra: NowPlayingPageArgs(
          trackTitle: displayTrack.title,
          trackArtist: displayTrack.artistLine,
          trackImageAsset: displayTrack.imageUrl.isNotEmpty == true
              ? displayTrack.imageUrl
              : widget.args.playlist.imageAsset,
          trackBpm: displayTrack.bpm,
          userCadence: widget.args.userCadence,
          spotifyUri: sessionPlaylistUri ?? displayTrack.spotifyUri,
          allowedTrackUris: tracks
              .map((t) => t.spotifyUri)
              .where((uri) => uri.isNotEmpty)
              .toList(growable: false),
          trackBpmsByUri: {
            for (final track in tracks)
              if (track.spotifyUri.isNotEmpty) track.spotifyUri: track.bpm,
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  /// Helper to try remote playback or deep link without setting local loading state
  /// (since _handleStartSession already manages it)
  Future<bool> _openInAppOrRemote(String spotifyUri) async {
    try {
      final remotePlayed = await SpotifyRemoteService.instance.playUri(
        spotifyUri,
      );
      if (remotePlayed) return true;
      return await _openInSpotifyApp(spotifyUri);
    } catch (_) {
      return await _openInSpotifyApp(spotifyUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.args.playlist;
    final auth = AuthScope.watch(context);
    final tracks = auth.tracksForPlaylist(playlist.id);
    final isLoadingTracks = auth.isLoadingTracksForPlaylist(playlist.id);
    final trackLoadError = auth.trackErrorForPlaylist(playlist.id);
    final hasMoreTracks = auth.hasMoreTracksForPlaylist(playlist.id);

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
                  controller: _scrollController,
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
                          const SizedBox(width: 46),
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
                              label: _isLaunching
                                  ? 'Opening...'
                                  : 'Start Session',
                              filled: true,
                              onTap: () => _handleStartSession(),
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
                        playlistTitle: playlist.title,
                        tracks: tracks,
                        isLoading: isLoadingTracks,
                        hasMoreTracks: hasMoreTracks,
                        loadError: trackLoadError,
                        onRefresh: _refreshTracks,
                        onPlayTrack: (track) =>
                            _handleStartSession(startTrack: track),
                        onRetry: _refreshTracks,
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
                        child: StempoNowPlayingBar(
                          userCadence: widget.args.userCadence,
                          allowedTrackUris: tracks
                              .map((track) => track.spotifyUri)
                              .where((uri) => uri.isNotEmpty)
                              .toList(growable: false),
                          trackBpmsByUri: {
                            for (final track in tracks)
                              if (track.spotifyUri.isNotEmpty)
                                track.spotifyUri: track.bpm,
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PlaylistBottomNav(activeTab: widget.args.sourceTab),
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
    required this.playlistTitle,
    required this.tracks,
    required this.isLoading,
    required this.hasMoreTracks,
    required this.loadError,
    required this.onRefresh,
    required this.onPlayTrack,
    required this.onRetry,
  });

  final String playlistTitle;
  final List<SpotifyTrack> tracks;
  final bool isLoading;
  final bool hasMoreTracks;
  final String? loadError;
  final Future<void> Function() onRefresh;
  final Future<void> Function(SpotifyTrack track) onPlayTrack;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 28,
      padding: const EdgeInsets.all(18),
      glowColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tracks',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: isLoading ? null : () => unawaited(onRefresh()),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: AppColors.textPrimary,
                tooltip: 'Refresh tracks',
                splashRadius: 20,
              ),
              const Text(
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
          if (isLoading && tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: WalkingLoader(
                title: 'Loading tracks',
                subtitle: 'Loading songs from Spotify.',
                compact: true,
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
                  onPressed: () => unawaited(onRetry()),
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
            Text(
              'No songs are available for "$playlistTitle" yet. Try refreshing to re-fetch the playlist.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...tracks.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SpotifyTrackRow(
                  track: entry.value,
                  onPlay: () => onPlayTrack(entry.value),
                ),
              ),
            ),
          if (tracks.isNotEmpty && (isLoading || hasMoreTracks))
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Loading more songs...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else
                    const Text(
                      'Scroll for more songs',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

class _SpotifyTrackRow extends StatelessWidget {
  const _SpotifyTrackRow({required this.track, required this.onPlay});

  final SpotifyTrack track;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final trackNumber = track.playlistPosition >= 0
        ? '${track.playlistPosition + 1}'.padLeft(2, '0')
        : '--';

    return FrostedPanel(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              trackNumber,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 10),
          MediaCover(imageAsset: track.imageUrl, size: 48, borderRadius: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artistLine,
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
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatDuration(track.durationMs),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onPlay,
                child: Container(
                  width: 34,
                  height: 34,
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
                    size: 20,
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
            style: TextStyle(
              color: filled ? Colors.black : AppColors.textPrimary,
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
  const _PlaylistBottomNav({required this.activeTab});

  final PlaylistSourceTab activeTab;

  @override
  Widget build(BuildContext context) {
    final items = <_PlaylistNavItem>[
      const _PlaylistNavItem(
        label: 'Home',
        icon: Icons.home_rounded,
        targetRoute: '/home?tab=home',
        sourceTab: PlaylistSourceTab.home,
      ),
      const _PlaylistNavItem(
        label: 'Search',
        icon: Icons.search_rounded,
        targetRoute: '/home?tab=search',
        sourceTab: PlaylistSourceTab.search,
      ),
      const _PlaylistNavItem(
        label: 'Library',
        icon: Icons.library_music_rounded,
        targetRoute: '/home?tab=library',
        sourceTab: PlaylistSourceTab.library,
      ),
      const _PlaylistNavItem(
        label: 'Modes',
        icon: Icons.directions_run_rounded,
        targetRoute: '/home?tab=modes',
        sourceTab: PlaylistSourceTab.modes,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: items[i].sourceTab == activeTab
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 24,
                        color: items[i].sourceTab == activeTab
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          color: items[i].sourceTab == activeTab
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: items[i].sourceTab == activeTab
                              ? FontWeight.w800
                              : FontWeight.w600,
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
    required this.tracks,
    required this.accentColor,
    required this.bgColor,
  });

  final int userCadence;
  final List<SpotifyTrack> tracks;
  final Color accentColor;
  final Color bgColor;

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
  String _trackUri = '';
  int _trackBpm = 0;

  @override
  void initState() {
    super.initState();
    _bindRemote();
  }

  @override
  void didUpdateWidget(covariant _PlaylistNowPlayingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_trackBpm > 0 ||
        _trackUri.isEmpty ||
        widget.tracks == oldWidget.tracks) {
      return;
    }
    final resolvedBpm = _bpmForTrackUri(_trackUri);
    if (resolvedBpm > 0) {
      setState(() => _trackBpm = resolvedBpm);
    }
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
          _trackUri = '';
          _title = null;
          _artist = null;
          _image = null;
          return;
        }
        _trackUri = state.trackUri;
        _title = state.trackName;
        _artist = state.artistName;
        _image = state.resolvedImageUrl;
        _trackBpm = _bpmForTrackUri(state.trackUri);
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
          _trackUri = '';
          _title = null;
          _artist = null;
          _image = null;
          _isPaused = true;
          return;
        }
        _isPaused = playerState.isPaused;
        _trackUri = playerState.trackUri;
        _title = playerState.trackName;
        _artist = playerState.artistName;
        _image = playerState.resolvedImageUrl;
        _trackBpm = _bpmForTrackUri(playerState.trackUri);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoaded = true);
    }
  }

  int _bpmForTrackUri(String trackUri) {
    if (trackUri.isEmpty) return 0;
    for (final track in widget.tracks) {
      if (track.spotifyUri == trackUri) return track.bpm;
    }
    return widget.tracks.isNotEmpty ? widget.tracks.first.bpm : 0;
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
    final allowedTrackUris = widget.tracks
        .map((track) => track.spotifyUri)
        .where((uri) => uri.isNotEmpty)
        .toList(growable: false);
    final trackBpmsByUri = {
      for (final track in widget.tracks)
        if (track.spotifyUri.isNotEmpty) track.spotifyUri: track.bpm,
    };
    context.push(
      '/now-playing',
      extra: NowPlayingPageArgs(
        trackTitle: title,
        trackArtist: _artist ?? '',
        trackImageAsset: _image ?? '',
        trackBpm: trackBpmsByUri[_trackUri] ?? _trackBpm,
        userCadence: widget.userCadence,
        spotifyUri: _trackUri.isNotEmpty ? _trackUri : null,
        allowedTrackUris: allowedTrackUris,
        trackBpmsByUri: trackBpmsByUri,
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
            colors: [widget.bgColor, widget.bgColor.withValues(alpha: 0.8)],
          ),
          glowColor: widget.accentColor.withValues(alpha: 0.18),
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
            _PlaylistTrackPaceBadge(
              trackBpm: _trackBpm,
              userCadence: widget.userCadence,
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

class _PlaylistTrackPaceBadge extends StatelessWidget {
  const _PlaylistTrackPaceBadge({
    required this.trackBpm,
    required this.userCadence,
  });

  final int trackBpm;
  final int userCadence;

  @override
  Widget build(BuildContext context) {
    if (trackBpm <= 0) return const SizedBox.shrink();

    final diff = (trackBpm - userCadence).abs();
    final color = diff <= 2 ? AppColors.primaryBright : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$trackBpm',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'BPM',
            style: TextStyle(
              color: color.withValues(alpha: 0.6),
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistNavItem {
  const _PlaylistNavItem({
    required this.label,
    required this.icon,
    required this.targetRoute,
    required this.sourceTab,
  });

  final String label;
  final IconData icon;
  final String targetRoute;
  final PlaylistSourceTab sourceTab;
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
