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

  int get _gap => (widget.args.playlist.bpm - widget.args.userCadence).abs();

  String get _fitLabel {
    if (_gap <= 3) return 'Perfect fit';
    if (_gap <= 8) return 'Close match';
    return 'Off pace';
  }

  Color get _fitColor {
    if (_gap <= 3) return AppColors.primaryBright;
    if (_gap <= 8) return AppColors.warning;
    return AppColors.textMuted;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedTracks) return;
    final auth = AuthScope.watch(context);
    if (auth.accessToken == null || auth.accessToken!.isEmpty) return;
    _requestedTracks = true;
    auth.loadTracksForPlaylist(widget.args.playlist.id);
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
    final opened = await _openSpotifyUri(track.spotifyUri);
    if (!opened || !mounted) return;
  }

  Future<void> _startSession(List<SpotifyTrack> tracks) async {
    bool opened = false;
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tracks in 90-110 BPM were found for this playlist.'),
        ),
      );
      return;
    }

    const minBpm = 90;
    const maxBpm = 110;
    final auth = AuthScope.read(context);
    final sessionPlaylistUri = await auth.ensureSessionPlaylistForBpm(
      sourcePlaylist: widget.args.playlist,
      tracks: tracks,
      minBpm: minBpm,
      maxBpm: maxBpm,
    );

    if (sessionPlaylistUri != null && sessionPlaylistUri.isNotEmpty) {
      opened = await _openSpotifyUri(sessionPlaylistUri);
    }
    if (!opened) {
      // Fallback: open the first matched track directly.
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                  _PlaylistMeta(
                    playlist: playlist,
                    fitLabel: _fitLabel,
                    fitColor: _fitColor,
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
                    onRetry: () => auth.loadTracksForPlaylist(playlist.id),
                  ),
                ],
              ),
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

class _PlaylistMeta extends StatelessWidget {
  const _PlaylistMeta({
    required this.playlist,
    required this.fitLabel,
    required this.fitColor,
  });

  final TempoPlaylist playlist;
  final String fitLabel;
  final Color fitColor;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 26,
      padding: const EdgeInsets.all(18),
      glowColor: fitColor,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Tag(label: fitLabel, background: fitColor.withValues(alpha: 0.16)),
          _Tag(label: playlist.category),
          _Tag(label: playlist.mood),
          _Tag(label: '${playlist.durationMinutes} min'),
        ],
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
                    color: AppColors.textPrimary,
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.background});

  final String label;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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
