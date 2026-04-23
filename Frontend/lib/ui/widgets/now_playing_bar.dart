import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../controllers/spotify_remote_service.dart';
import '../../pages/now_playing_page.dart';
import '../../state/auth_providers.dart';
import '../../ui/theme/app_fx.dart';
import '../../ui/theme/colors.dart';
import 'media_cover.dart';

class StempoNowPlayingBar extends StatefulWidget {
  const StempoNowPlayingBar({
    super.key,
    required this.userCadence,
    this.initialTrackTitle = '',
    this.initialTrackArtist = '',
    this.initialTrackImageAsset = '',
    this.initialTrackBpm = 0,
    this.allowedTrackUris = const <String>[],
    this.trackBpmsByUri = const <String, int>{},
  });

  final int userCadence;
  final String initialTrackTitle;
  final String initialTrackArtist;
  final String initialTrackImageAsset;
  final int initialTrackBpm;
  final List<String> allowedTrackUris;
  final Map<String, int> trackBpmsByUri;

  @override
  State<StempoNowPlayingBar> createState() => _StempoNowPlayingBarState();
}

class _StempoNowPlayingBarState extends State<StempoNowPlayingBar> {
  final SpotifyRemoteService _remote = SpotifyRemoteService.instance;
  StreamSubscription<SpotifyRemotePlayerState>? _playerSub;
  bool _isPaused = true;
  bool _isLoaded = false;
  String _trackUri = '';
  String? _title;
  String? _artist;
  String? _image;
  int? _trackBpm;
  Color _accentColor = AppColors.primary;
  Color _bgColor = AppColors.surfaceFloating;
  String? _lastPaletteImage;

  @override
  void initState() {
    super.initState();
    _title = widget.initialTrackTitle;
    _artist = widget.initialTrackArtist;
    _image = widget.initialTrackImageAsset;
    _trackBpm = widget.initialTrackBpm > 0 ? widget.initialTrackBpm : null;
    _bindRemote();
    if ((_image ?? '').isNotEmpty) {
      unawaited(_updateSongPalette(_image));
    }
  }

  @override
  void didUpdateWidget(covariant StempoNowPlayingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_trackUri.isEmpty) return;
    final mappedBpm = widget.trackBpmsByUri[_trackUri];
    if (mappedBpm != null && mappedBpm > 0 && mappedBpm != _trackBpm) {
      setState(() => _trackBpm = mappedBpm);
    }
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    super.dispose();
  }

  Future<void> _bindRemote() async {
    _playerSub = _remote.playerStateStream().listen(_applyPlayerState);

    try {
      final playerState = await _remote.getPlayerState();
      if (!mounted) return;
      if (playerState == null) {
        setState(() => _isLoaded = true);
        return;
      }
      _applyPlayerState(playerState);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoaded = true);
    }
  }

  void _applyPlayerState(SpotifyRemotePlayerState state) {
    if (!mounted) return;
    setState(() {
      _isLoaded = true;
      _isPaused = state.isPaused;
      if (state.trackUri.isEmpty || state.trackName.isEmpty) {
        _trackUri = '';
        _title = null;
        _artist = null;
        _image = null;
        _trackBpm = null;
        return;
      }
      _trackUri = state.trackUri;
      _title = state.trackName;
      _artist = state.artistName;
      _image = state.resolvedImageUrl;
      _trackBpm = widget.trackBpmsByUri[state.trackUri] ?? _trackBpm;
    });
    unawaited(_resolveTrackBpm(state.trackUri));
    unawaited(_updateSongPalette(state.resolvedImageUrl));
  }

  Future<void> _resolveTrackBpm(String trackUri) async {
    final mappedBpm = widget.trackBpmsByUri[trackUri];
    if (mappedBpm != null && mappedBpm > 0) {
      if (mounted && _trackBpm != mappedBpm) {
        setState(() => _trackBpm = mappedBpm);
      }
      return;
    }

    final resolvedBpm = await AuthScope.read(context).resolveTrackBpm(trackUri);
    if (!mounted || _trackUri != trackUri || resolvedBpm == null) return;
    setState(() => _trackBpm = resolvedBpm);
  }

  Future<void> _updateSongPalette(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == _lastPaletteImage) {
      return;
    }
    _lastPaletteImage = imageUrl;

    final imageProvider = imageUrl.startsWith('http')
        ? NetworkImage(imageUrl)
        : AssetImage(imageUrl) as ImageProvider;

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
          palette.mutedColor?.color ??
          AppColors.primary;
      final dominant =
          palette.dominantColor?.color ??
          palette.darkMutedColor?.color ??
          Colors.black;
      final luminance = dominant.computeLuminance();

      setState(() {
        _accentColor = _ensureVisible(mainColor);
        if (luminance < 0.05) {
          _bgColor = Color.alphaBlend(
            Colors.white.withValues(alpha: 0.15),
            dominant.withValues(alpha: 0.92),
          );
        } else if (luminance > 0.35) {
          _bgColor = Color.alphaBlend(
            Colors.black.withValues(alpha: 0.75),
            dominant.withValues(alpha: 0.92),
          );
        } else {
          _bgColor = dominant.withValues(alpha: 0.9);
        }
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
    final title = _title ?? widget.initialTrackTitle;
    if (title.isEmpty) return;
    context.push(
      '/now-playing',
      extra: NowPlayingPageArgs(
        trackTitle: title,
        trackArtist: _artist ?? widget.initialTrackArtist,
        trackImageAsset: _image ?? widget.initialTrackImageAsset,
        trackBpm: _trackBpm ?? widget.initialTrackBpm,
        userCadence: widget.userCadence,
        spotifyUri: _trackUri.isNotEmpty ? _trackUri : null,
        allowedTrackUris: widget.allowedTrackUris,
        trackBpmsByUri: widget.trackBpmsByUri,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _title ?? widget.initialTrackTitle;
    if ((!_isLoaded && title.isEmpty) || title.isEmpty) {
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
            colors: [_bgColor, _bgColor.withValues(alpha: 0.8)],
          ),
          glowColor: _accentColor.withValues(alpha: 0.18),
        ),
        child: Row(
          children: [
            MediaCover(
              imageAsset: _image ?? widget.initialTrackImageAsset,
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
                    _artist ?? widget.initialTrackArtist,
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
            _TrackPaceBadge(
              trackBpm: _trackBpm ?? widget.initialTrackBpm,
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

class _TrackPaceBadge extends StatelessWidget {
  const _TrackPaceBadge({required this.trackBpm, required this.userCadence});

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
