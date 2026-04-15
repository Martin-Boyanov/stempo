import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:palette_generator/palette_generator.dart';

import '../controllers/spotify_remote_service.dart';
import '../ui/theme/app_fx.dart';
import '../ui/theme/colors.dart';
import '../ui/widgets/media_cover.dart';

class NowPlayingPageArgs {
  const NowPlayingPageArgs({
    required this.trackTitle,
    required this.trackArtist,
    required this.trackImageAsset,
    required this.trackBpm,
    required this.userCadence,
    this.spotifyUri,
    this.allowedTrackUris = const <String>[],
  });

  final String trackTitle;
  final String trackArtist;
  final String trackImageAsset;
  final int trackBpm;
  final int userCadence;
  final String? spotifyUri;
  final List<String> allowedTrackUris;
}

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key, required this.args});

  final NowPlayingPageArgs args;

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final SpotifyRemoteService _remote = SpotifyRemoteService.instance;
  StreamSubscription<SpotifyRemotePlayerState>? _playerStateSubscription;
  Timer? _playbackTimer;

  late String _trackTitle;
  late String _trackArtist;
  late int _trackBpm;
  late bool _isPaused;
  bool _isShuffling = false;
  int _repeatMode = 0;
  String? _actualImage;
  int _playbackPositionMs = 69000;
  int _durationMs = 198000;
  bool _isDragging = false;
  Color _accentColor = AppColors.primary;
  Color _secondaryColor = AppColors.cinemaRed;
  late final List<String> _allowedTrackUrisOrdered;
  late final Set<String> _allowedTrackUris;
  late final bool _usesSpotifyPlaylistContext;
  bool _isAutoSkipping = false;
  bool _isAutoAdvancing = false;
  String _currentTrackUri = '';
  String _lastRejectedTrackUri = '';
  String _lastAutoAdvancedSourceUri = '';
  int _currentAllowedIndex = 0;

  void _setStateSafely(VoidCallback updater) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(updater);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(updater);
    });
  }

  @override
  void initState() {
    super.initState();
    _trackTitle = widget.args.trackTitle;
    _trackArtist = widget.args.trackArtist;
    _trackBpm = widget.args.trackBpm;
    _allowedTrackUrisOrdered = widget.args.allowedTrackUris;
    _allowedTrackUris = widget.args.allowedTrackUris.toSet();
    _usesSpotifyPlaylistContext =
        (widget.args.spotifyUri ?? '').startsWith('spotify:playlist:');
    final initialTrackUri = widget.args.spotifyUri ?? '';
    final initialIndex = _allowedTrackUrisOrdered.indexOf(initialTrackUri);
    _currentAllowedIndex = initialIndex >= 0 ? initialIndex : 0;
    _isPaused = false;
    _startTimer();
    _bindSpotifyRemote();
    _updatePalette();
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _bindSpotifyRemote() async {
    _playerStateSubscription = _remote.playerStateStream().listen((state) {
      if (!mounted) return;
      unawaited(_enforceOrderedPlayback(state));
      _setStateSafely(() {
        if (_currentTrackUri != state.trackUri) {
          _lastAutoAdvancedSourceUri = '';
        }
        _currentTrackUri = state.trackUri;
        if (state.trackName.isNotEmpty) {
          _trackTitle = state.trackName;
        }
        if (state.artistName.isNotEmpty) {
          _trackArtist = state.artistName;
        }
        print('NOW PLAYING PAGE REM: "${state.imageUri}" -> "${state.resolvedImageUrl}"');
        if (state.resolvedImageUrl != null) {
          _actualImage = state.resolvedImageUrl;
        }
        _isPaused = state.isPaused;
        _playbackPositionMs = state.playbackPositionMs;
        if (state.durationMs > 0) {
          _durationMs = state.durationMs;
        }
        _isShuffling = state.isShuffling;
        _repeatMode = state.repeatMode;
        _updatePalette();
      });
    });

    try {
      await _remote.connect(showAuthView: false);
      final playerState = await _remote.getPlayerState();
      if (!mounted || playerState == null) return;
      _setStateSafely(() {
        _currentTrackUri = playerState.trackUri;
        if (playerState.trackName.isNotEmpty) {
          _trackTitle = playerState.trackName;
        }
        if (playerState.artistName.isNotEmpty) {
          _trackArtist = playerState.artistName;
        }
        print('NOW PLAYING PAGE INIT: "${playerState.imageUri}" -> "${playerState.resolvedImageUrl}"');
        if (playerState.resolvedImageUrl != null) {
          _actualImage = playerState.resolvedImageUrl;
        }
        _isPaused = playerState.isPaused;
        _playbackPositionMs = playerState.playbackPositionMs;
        if (playerState.durationMs > 0) {
          _durationMs = playerState.durationMs;
        }
        _isShuffling = playerState.isShuffling;
        _repeatMode = playerState.repeatMode;
        _updatePalette();
      });
      unawaited(_enforceOrderedPlayback(playerState));
    } catch (_) {
      // Keep the screen usable even when the remote player is unavailable.
    }
  }

  Future<void> _enforceOrderedPlayback(SpotifyRemotePlayerState state) async {
    if (_allowedTrackUrisOrdered.isEmpty) return;
    final currentTrackUri = state.trackUri;
    if (currentTrackUri.isEmpty) return;

    final currentIndex = _allowedTrackUrisOrdered.indexOf(currentTrackUri);
    if (currentIndex >= 0) {
      _currentAllowedIndex = currentIndex;
      _lastRejectedTrackUri = '';
    }

    if (_usesSpotifyPlaylistContext) {
      // Keep native Spotify playlist context; do not jump via track URIs.
      return;
    }

    if (_allowedTrackUris.isEmpty ||
        currentTrackUri.isEmpty ||
        _isAutoSkipping) {
      return;
    }

    if (!_allowedTrackUris.contains(currentTrackUri)) {
      if (_lastRejectedTrackUri == currentTrackUri) return;
      _lastRejectedTrackUri = currentTrackUri;
      final safeIndex = _currentAllowedIndex.clamp(
        0,
        _allowedTrackUrisOrdered.length - 1,
      ) as int;
      await _playAllowedUri(
        _allowedTrackUrisOrdered[safeIndex],
        trackIndex: safeIndex,
      );
      return;
    }

    if (state.isPaused || state.durationMs <= 0 || _isAutoAdvancing) return;
    const nearEndThresholdMs = 1500;
    final isNearEnd = (state.durationMs - state.playbackPositionMs) <=
        nearEndThresholdMs;
    if (!isNearEnd) return;
    if (_lastAutoAdvancedSourceUri == currentTrackUri) return;

    final nextIndex = (currentIndex + 1) % _allowedTrackUrisOrdered.length;
    if (nextIndex == currentIndex) return;
    _lastAutoAdvancedSourceUri = currentTrackUri;
    _isAutoAdvancing = true;
    try {
      await _playAllowedUri(
        _allowedTrackUrisOrdered[nextIndex],
        trackIndex: nextIndex,
      );
    } finally {
      _isAutoAdvancing = false;
    }
  }

  void _startTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && !_isDragging && mounted) {
        setState(() {
          _playbackPositionMs += 1000;
          if (_playbackPositionMs > _durationMs) {
            _playbackPositionMs = _durationMs;
          }
        });
      }
    });
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

  Future<void> _skipNext() async {
    try {
      if (_usesSpotifyPlaylistContext) {
        await _remote.skipNext();
        return;
      }
      if (_allowedTrackUrisOrdered.isNotEmpty) {
        final currentIndex = _allowedTrackUrisOrdered.indexOf(_currentTrackUri);
        final resolvedIndex = currentIndex >= 0 ? currentIndex : _currentAllowedIndex;
        final nextIndex = (resolvedIndex + 1) % _allowedTrackUrisOrdered.length;
        final targetUri = _allowedTrackUrisOrdered[nextIndex];
        await _playAllowedUri(targetUri, trackIndex: nextIndex);
        return;
      }
      await _remote.skipNext();
    } catch (_) {}
  }

  Future<void> _skipPrevious() async {
    try {
      if (_usesSpotifyPlaylistContext) {
        await _remote.skipPrevious();
        return;
      }
      if (_allowedTrackUrisOrdered.isNotEmpty) {
        final currentIndex = _allowedTrackUrisOrdered.indexOf(_currentTrackUri);
        final resolvedIndex = currentIndex >= 0 ? currentIndex : _currentAllowedIndex;
        final prevIndex = resolvedIndex <= 0
            ? _allowedTrackUrisOrdered.length - 1
            : resolvedIndex - 1;
        final targetUri = _allowedTrackUrisOrdered[prevIndex];
        await _playAllowedUri(targetUri, trackIndex: prevIndex);
        return;
      }
      await _remote.skipPrevious();
    } catch (_) {}
  }

  Future<bool> _playAllowedUri(String targetUri, {int? trackIndex}) async {
    if (targetUri.isEmpty) return false;
    if (_currentTrackUri == targetUri) return true;
    _isAutoSkipping = true;
    try {
      final played = await _remote.playUri(targetUri);
      if (played) {
        _setStateSafely(() {
          _currentTrackUri = targetUri;
          final resolvedIndex = trackIndex ?? _allowedTrackUrisOrdered.indexOf(targetUri);
          if (resolvedIndex >= 0) {
            _currentAllowedIndex = resolvedIndex;
          }
        });
      }
      return played;
    } catch (_) {
      return false;
    } finally {
      _isAutoSkipping = false;
    }
  }

  Future<void> _toggleShuffle() async {
    final newShuffle = !_isShuffling;
    setState(() => _isShuffling = newShuffle);
    try {
      await _remote.setShuffle(newShuffle);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isShuffling = !newShuffle);
    }
  }

  Future<void> _toggleRepeat() async {
    final newRepeatMode = (_repeatMode + 1) % 3;
    final oldRepeatMode = _repeatMode;
    setState(() => _repeatMode = newRepeatMode);
    try {
      await _remote.setRepeat(newRepeatMode);
    } catch (_) {
      if (!mounted) return;
      setState(() => _repeatMode = oldRepeatMode);
    }
  }

  void _onSeekStarted(double value) {
    setState(() => _isDragging = true);
  }

  void _onSeeking(double value) {
    setState(() => _playbackPositionMs = value.toInt());
  }

  Future<void> _onSeekEnded(double value) async {
    final position = value.toInt();
    setState(() {
      _playbackPositionMs = position;
      _isDragging = false;
    });
    try {
      await _remote.seekTo(position);
    } catch (_) {}
  }

  Color _ensureVisible(Color color) {
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness < 0.2) {
      // If color is too dark, boost it to be a visible accent
      return hsl.withLightness(0.5).withSaturation(0.8).toColor();
    }
    return color;
  }

  Future<void> _updatePalette() async {
    final imagePath = _actualImage ?? widget.args.trackImageAsset;
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
      
      // Prioritize vibrant swatches for the "glow" effect
      final mainColor = palette.vibrantColor?.color ?? 
                       palette.lightVibrantColor?.color ?? 
                       palette.dominantColor?.color ?? 
                       AppColors.primary;

      final sideColor = palette.mutedColor?.color ?? 
                       palette.darkVibrantColor?.color ?? 
                       AppColors.cinemaRed;

      setState(() {
        _accentColor = _ensureVisible(mainColor);
        _secondaryColor = _ensureVisible(sideColor);
      });
    } catch (_) {}
  }

  int get _cadenceGap => (widget.args.trackBpm - widget.args.userCadence).abs();

  String get _matchLabel {
    if (_cadenceGap <= 2) return 'Perfect fit';
    if (_cadenceGap <= 6) return 'Close';
    return 'Off pace';
  }

  Color get _matchColor {
    if (_cadenceGap <= 2) return AppColors.primaryBright;
    if (_cadenceGap <= 6) return AppColors.warning;
    return AppColors.textMuted;
  }

  String get _matchMessage {
    if (_cadenceGap <= 2) {
      return 'This track is almost exactly on your rhythm. Great pick to sync with.';
    }
    if (_cadenceGap <= 6) {
      return 'This one is close enough to feel natural, with only a small pace adjustment.';
    }
    return 'The song is drifting from your target cadence, so it is better for casual listening than a synced run.';
  }

  @override
  Widget build(BuildContext context) {
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
                      _TopActionButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/Logo.png',
                            height: 20,
                            filterQuality: FilterQuality.high,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'STEMPO',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(width: 46),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _ArtworkHero(
                    trackTitle: _trackTitle,
                    trackImageAsset: _actualImage ?? widget.args.trackImageAsset,
                    trackBpm: _trackBpm,
                    glowColor: _accentColor,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _trackTitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _trackArtist,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _PlaybackTimeline(
                    playbackPositionMs: _playbackPositionMs,
                    durationMs: _durationMs,
                    onChanged: _onSeeking,
                    onChangeStart: _onSeekStarted,
                    onChangeEnd: _onSeekEnded,
                  ),
                  const SizedBox(height: 18),
                  _PlaybackControls(
                    isPaused: _isPaused,
                    isShuffling: _isShuffling,
                    repeatMode: _repeatMode,
                    accentColor: _accentColor,
                    onTogglePlayback: _togglePlayback,
                    onSkipNext: _skipNext,
                    onSkipPrevious: _skipPrevious,
                    onToggleShuffle: _toggleShuffle,
                    onToggleRepeat: _toggleRepeat,
                  ),
                  const SizedBox(height: 24),
                  _ProgressCard(
                    matchLabel: _matchLabel,
                    matchColor: _matchColor,
                    message: _matchMessage,
                    trackBpm: _trackBpm,
                    userCadence: widget.args.userCadence,
                    glowColor: _accentColor,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: AppFx.glassDecoration(
          radius: 18,
          glowColor: (context.findAncestorStateOfType<_NowPlayingPageState>()?._accentColor) ?? AppColors.cinemaRed,
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 24),
      ),
    );
  }
}

class _ArtworkHero extends StatelessWidget {
  const _ArtworkHero({
    required this.trackTitle,
    required this.trackImageAsset,
    required this.trackBpm,
    this.glowColor,
  });

  final String trackTitle;
  final String trackImageAsset;
  final int trackBpm;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: (glowColor ?? AppColors.primary).withValues(alpha: 0.45),
              blurRadius: 72,
              spreadRadius: 4,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: (glowColor ?? AppColors.primary).withValues(alpha: 0.22),
              blurRadius: 110,
              spreadRadius: 0,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: MediaCover(
          imageAsset: trackImageAsset,
          size: double.infinity,
          borderRadius: 34,
          child: Stack(
            children: [
              Positioned(
                right: 20,
                top: 18,
                child: Text(
                  '$trackBpm BPM',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                left: 22,
                bottom: 20,
                right: 22,
                child: Text(
                  trackTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 34,
                    height: 0.95,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                left: 30,
                top: 36,
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 136,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.matchLabel,
    required this.matchColor,
    required this.message,
    required this.trackBpm,
    required this.userCadence,
    this.glowColor,
  });

  final String matchLabel;
  final Color matchColor;
  final String message;
  final int trackBpm;
  final int userCadence;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(20),
      elevated: true,
      glowColor: glowColor ?? AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      HSLColor.fromColor(glowColor ?? AppColors.primary).withLightness(0.6).toColor(),
                      glowColor ?? AppColors.primary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: (glowColor ?? AppColors.primary).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  matchLabel.toUpperCase(),
                  style: TextStyle(
                    color: (glowColor ?? AppColors.primary).computeLuminance() > 0.6 ? Colors.black : Colors.white,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'Tempo match',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'Track BPM', 
                  value: '$trackBpm',
                  glowColor: glowColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBlock(
                  label: 'Your cadence', 
                  value: '$userCadence',
                  glowColor: glowColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label, 
    required this.value,
    this.glowColor,
  });

  final String label;
  final String value;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 22,
      padding: const EdgeInsets.all(16),
      glowColor: glowColor ?? AppColors.cinemaRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: glowColor ?? AppColors.primary,
              fontSize: 32,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackTimeline extends StatelessWidget {
  const _PlaybackTimeline({
    required this.playbackPositionMs,
    required this.durationMs,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  final int playbackPositionMs;
  final int durationMs;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final safeDurationMs = durationMs <= 0 ? 1 : durationMs;
    final progress = (playbackPositionMs / safeDurationMs).clamp(0.0, 1.0);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.textPrimary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: AppColors.textPrimary,
            overlayColor: AppColors.primary.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: playbackPositionMs.toDouble().clamp(0, durationMs.toDouble()),
            min: 0,
            max: durationMs.toDouble(),
            onChanged: onChanged,
            onChangeStart: onChangeStart,
            onChangeEnd: onChangeEnd,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              _formatTime(playbackPositionMs),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              _formatTime(durationMs),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.isPaused,
    required this.isShuffling,
    required this.repeatMode,
    required this.accentColor,
    required this.onTogglePlayback,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
  });

  final bool isPaused;
  final bool isShuffling;
  final int repeatMode;
  final Color accentColor;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function() onSkipNext;
  final Future<void> Function() onSkipPrevious;
  final Future<void> Function() onToggleShuffle;
  final Future<void> Function() onToggleRepeat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: onToggleShuffle,
          child: Icon(
            Icons.shuffle_rounded,
            color: isShuffling ? accentColor : AppColors.textSecondary,
            size: 24,
          ),
        ),
        GestureDetector(
          onTap: onSkipPrevious,
          child: const Icon(
            Icons.skip_previous_rounded,
            color: AppColors.textPrimary,
            size: 36,
          ),
        ),
        _PlayPauseButton(
          isPaused: isPaused,
          accentColor: accentColor,
          onTap: onTogglePlayback,
        ),
        GestureDetector(
          onTap: onSkipNext,
          child: const Icon(
            Icons.skip_next_rounded,
            color: AppColors.textPrimary,
            size: 36,
          ),
        ),
        GestureDetector(
          onTap: onToggleRepeat,
          child: Icon(
            repeatMode == 1
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: repeatMode > 0 ? accentColor : AppColors.textSecondary,
            size: 24,
          ),
        ),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPaused,
    required this.onTap,
    required this.accentColor,
  });

  final bool isPaused;
  final Future<void> Function() onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        height: 72,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HSLColor.fromColor(accentColor).withLightness(0.65).toColor(),
                accentColor,
              ],
            ),
            boxShadow: AppFx.softGlow(accentColor, strength: 0.28),
          ),
          child: Icon(
            isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: AppColors.background,
            size: 40,
          ),
        ),
      ),
    );
  }
}



String _formatTime(int durationMs) {
  final totalSeconds = (durationMs / 1000).floor().clamp(0, 59999);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
