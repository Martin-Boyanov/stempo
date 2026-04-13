import 'dart:async';

import 'package:flutter/material.dart';

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
  });

  final String trackTitle;
  final String trackArtist;
  final String trackImageAsset;
  final int trackBpm;
  final int userCadence;
  final String? spotifyUri;
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

  late String _trackTitle;
  late String _trackArtist;
  late int _trackBpm;
  late bool _isPaused;
  int _playbackPositionMs = 69000;
  int _durationMs = 198000;

  @override
  void initState() {
    super.initState();
    _trackTitle = widget.args.trackTitle;
    _trackArtist = widget.args.trackArtist;
    _trackBpm = widget.args.trackBpm;
    _isPaused = false;
    _bindSpotifyRemote();
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bindSpotifyRemote() async {
    _playerStateSubscription = _remote.playerStateStream().listen((state) {
      if (!mounted) return;
      setState(() {
        if (state.trackName.isNotEmpty) {
          _trackTitle = state.trackName;
        }
        if (state.artistName.isNotEmpty) {
          _trackArtist = state.artistName;
        }
        _isPaused = state.isPaused;
        _playbackPositionMs = state.playbackPositionMs;
        if (state.durationMs > 0) {
          _durationMs = state.durationMs;
        }
      });
    });

    try {
      await _remote.connect(showAuthView: false);
      final playerState = await _remote.getPlayerState();
      if (!mounted || playerState == null) return;
      setState(() {
        if (playerState.trackName.isNotEmpty) {
          _trackTitle = playerState.trackName;
        }
        if (playerState.artistName.isNotEmpty) {
          _trackArtist = playerState.artistName;
        }
        _isPaused = playerState.isPaused;
        _playbackPositionMs = playerState.playbackPositionMs;
        if (playerState.durationMs > 0) {
          _durationMs = playerState.durationMs;
        }
      });
    } catch (_) {
      // Keep the screen usable even when the remote player is unavailable.
    }
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPaused) {
        await _remote.resume();
      } else {
        await _remote.pause();
      }
      if (!mounted) return;
      setState(() {
        _isPaused = !_isPaused;
      });
    } catch (_) {
      // Leave UI as-is when Spotify App Remote is unavailable.
    }
  }

  Future<void> _skipNext() async {
    try {
      await _remote.skipNext();
    } catch (_) {}
  }

  Future<void> _skipPrevious() async {
    try {
      await _remote.skipPrevious();
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
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: AtmosphereBackground(
                accent: AppColors.primary,
                secondaryAccent: AppColors.cinemaRed,
                child: SizedBox.expand(),
              ),
            ),
            SingleChildScrollView(
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
                      const Text(
                        'Now Playing',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      const _TopActionButton(icon: Icons.more_horiz_rounded),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _ArtworkHero(
                    trackTitle: _trackTitle,
                    trackImageAsset: widget.args.trackImageAsset,
                    trackBpm: _trackBpm,
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
                  ),
                  const SizedBox(height: 18),
                  _PlaybackControls(
                    isPaused: _isPaused,
                    onTogglePlayback: _togglePlayback,
                    onSkipNext: _skipNext,
                    onSkipPrevious: _skipPrevious,
                  ),
                  const SizedBox(height: 24),
                  _ProgressCard(
                    matchLabel: _matchLabel,
                    matchColor: _matchColor,
                    message: _matchMessage,
                    trackBpm: _trackBpm,
                    userCadence: widget.args.userCadence,
                  ),
                  const SizedBox(height: 24),
                  _ActionCard(
                    trackBpm: _trackBpm,
                    userCadence: widget.args.userCadence,
                    matchLabel: _matchLabel,
                  ),
                ],
              ),
            ),
          ],
        ),
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
          glowColor: AppColors.cinemaRed,
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
  });

  final String trackTitle;
  final String trackImageAsset;
  final int trackBpm;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.24),
              blurRadius: 42,
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
  });

  final String matchLabel;
  final Color matchColor;
  final String message;
  final int trackBpm;
  final int userCadence;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(20),
      elevated: true,
      glowColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: matchColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  matchLabel,
                  style: TextStyle(
                    color: matchColor == AppColors.textMuted
                        ? AppColors.textPrimary
                        : matchColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
                child: _StatBlock(label: 'Track BPM', value: '$trackBpm'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBlock(label: 'Your cadence', value: '$userCadence'),
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
  const _StatBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 22,
      padding: const EdgeInsets.all(16),
      glowColor: AppColors.cinemaRed,
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
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w700,
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
  });

  final int playbackPositionMs;
  final int durationMs;

  @override
  Widget build(BuildContext context) {
    final safeDurationMs = durationMs <= 0 ? 1 : durationMs;
    final progress = (playbackPositionMs / safeDurationMs).clamp(0.0, 1.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
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
    required this.onTogglePlayback,
    required this.onSkipNext,
    required this.onSkipPrevious,
  });

  final bool isPaused;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function() onSkipNext;
  final Future<void> Function() onSkipPrevious;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(
          Icons.shuffle_rounded,
          color: AppColors.textSecondary,
          size: 24,
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
        const Icon(Icons.repeat_rounded, color: AppColors.textSecondary, size: 24),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.isPaused, required this.onTap});

  final bool isPaused;
  final Future<void> Function() onTap;

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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryBright, AppColors.primary],
            ),
            boxShadow: AppFx.softGlow(AppColors.primary, strength: 0.24),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.trackBpm,
    required this.userCadence,
    required this.matchLabel,
  });

  final int trackBpm;
  final int userCadence;
  final String matchLabel;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(20),
      glowColor: AppColors.cinemaRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready for later',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This song sits at $trackBpm BPM against your $userCadence target, so right now it reads as $matchLabel.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Text(
                      'Start synced run',
                      style: TextStyle(
                        color: AppColors.background,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Text(
                      'Find better match',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

String _formatTime(int durationMs) {
  final totalSeconds = (durationMs / 1000).floor().clamp(0, 59999);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
