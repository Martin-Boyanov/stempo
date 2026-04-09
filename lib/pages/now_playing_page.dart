import 'package:flutter/material.dart';

import '../ui/theme/colors.dart';

class NowPlayingPageArgs {
  const NowPlayingPageArgs({
    required this.trackTitle,
    required this.trackArtist,
    required this.trackBpm,
    required this.userCadence,
  });

  final String trackTitle;
  final String trackArtist;
  final int trackBpm;
  final int userCadence;
}

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({
    super.key,
    required this.args,
  });

  final NowPlayingPageArgs args;

  int get _cadenceGap => (args.trackBpm - args.userCadence).abs();

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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0D1718),
                      AppColors.background,
                    ],
                  ),
                ),
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
                      const _TopActionButton(
                        icon: Icons.more_horiz_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _ArtworkHero(
                    trackTitle: args.trackTitle,
                    trackBpm: args.trackBpm,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    args.trackTitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    args.trackArtist,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ProgressCard(
                    matchLabel: _matchLabel,
                    matchColor: _matchColor,
                    message: _matchMessage,
                    trackBpm: args.trackBpm,
                    userCadence: args.userCadence,
                  ),
                  const SizedBox(height: 20),
                  const _PlaybackTimeline(),
                  const SizedBox(height: 18),
                  const _PlaybackControls(),
                  const SizedBox(height: 24),
                  _ActionCard(
                    trackBpm: args.trackBpm,
                    userCadence: args.userCadence,
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
  const _TopActionButton({
    required this.icon,
    this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 24),
      ),
    );
  }
}

class _ArtworkHero extends StatelessWidget {
  const _ArtworkHero({
    required this.trackTitle,
    required this.trackBpm,
  });

  final String trackTitle;
  final int trackBpm;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, AppColors.primary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.24),
              blurRadius: 42,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: 20,
              top: 18,
              child: Text(
                '$trackBpm BPM',
                style: const TextStyle(
                  color: AppColors.background,
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
                  color: AppColors.background,
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
                color: AppColors.background.withValues(alpha: 0.14),
              ),
            ),
          ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                child: _StatBlock(
                  label: 'Track BPM',
                  value: '$trackBpm',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBlock(
                  label: 'Your cadence',
                  value: '$userCadence',
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
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
      ),
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
  const _PlaybackTimeline();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: 0.36,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Text(
              '1:09',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Spacer(),
            Text(
              '3:18',
              style: TextStyle(
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
  const _PlaybackControls();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(Icons.shuffle_rounded, color: AppColors.textSecondary, size: 24),
        Icon(Icons.skip_previous_rounded, color: AppColors.textPrimary, size: 36),
        _PlayPauseButton(),
        Icon(Icons.skip_next_rounded, color: AppColors.textPrimary, size: 36),
        Icon(Icons.repeat_rounded, color: AppColors.textSecondary, size: 24),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.textPrimary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.pause_rounded,
          color: AppColors.background,
          size: 40,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
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
