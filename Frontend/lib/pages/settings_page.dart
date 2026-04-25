import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../state/auth_providers.dart';
import '../ui/theme/app_fx.dart';
import '../ui/theme/colors.dart';
import '../pages/playlist_page.dart'; // For AtmosphereBackground and RoundIconButton if exported, but I'll redefine or use global ones

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.watch(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: AtmosphereBackground(
              accent: AppColors.primary,
              secondaryAccent: AppColors.cinemaRed,
              child: SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      _SettingsIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Settings',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 46), // Balance the back button
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(title: 'BPM Configuration'),
                        const SizedBox(height: 16),
                        _BpmSettingsCard(
                          currentBpm: auth.userCadence,
                          currentTolerance: auth.bpmTolerance,
                          onBpmChanged: (val) => auth.userCadence = val,
                          onToleranceChanged: (val) => auth.bpmTolerance = val,
                        ),
                        const SizedBox(height: 32),
                        const _SectionHeader(title: 'Account'),
                        const SizedBox(height: 16),
                        _SettingsActionCard(
                          title: 'Logout',
                          subtitle: 'Disconnect from Spotify and clear session',
                          icon: Icons.logout_rounded,
                          color: AppColors.cinemaRed,
                          onTap: () async {
                            await auth.disconnect();
                            if (context.mounted) {
                              context.go('/spotify');
                            }
                          },
                        ),
                        const SizedBox(height: 40),
                        Center(
                          child: Opacity(
                            opacity: 0.5,
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/images/Logo.png',
                                  height: 32,
                                  filterQuality: FilterQuality.high,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'STEMPO v1.0.0',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: AppColors.textPrimary.withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _BpmSettingsCard extends StatelessWidget {
  const _BpmSettingsCard({
    required this.currentBpm,
    required this.currentTolerance,
    required this.onBpmChanged,
    required this.onToleranceChanged,
  });

  final int currentBpm;
  final int currentTolerance;
  final ValueChanged<int> onBpmChanged;
  final ValueChanged<int> onToleranceChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FrostedPanel(
          radius: 28,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.speed_rounded,
                      color: AppColors.primaryBright,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Target Cadence',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$currentBpm',
                              style: const TextStyle(
                                color: AppColors.primaryBright,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const TextSpan(
                              text: ' BPM',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                ),
                child: Slider(
                  value: currentBpm.toDouble(),
                  min: 80,
                  max: 165,
                  divisions: 85,
                  activeColor: AppColors.primaryBright,
                  inactiveColor: Colors.white.withValues(alpha: 0.08),
                  onChanged: (val) => onBpmChanged(val.round()),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _CompactStatPill(
                      label: 'Range Min',
                      value: '${currentBpm - currentTolerance}',
                      accent: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CompactStatPill(
                      label: 'Variance',
                      value: '±$currentTolerance',
                      accent: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CompactStatPill(
                      label: 'Range Max',
                      value: '${currentBpm + currentTolerance}',
                      accent: AppColors.cinemaRed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FrostedPanel(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Discovery Tolerance',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: AppColors.accent,
                  thumbColor: AppColors.accent,
                ),
                child: Slider(
                  value: currentTolerance.toDouble(),
                  min: 2,
                  max: 20,
                  divisions: 18,
                  onChanged: (val) => onToleranceChanged(val.round()),
                  inactiveColor: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactStatPill extends StatelessWidget {
  const _CompactStatPill({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionCard extends StatelessWidget {
  const _SettingsActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FrostedPanel(
        radius: 24,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsIconButton extends StatelessWidget {
  const _SettingsIconButton({required this.icon, this.onTap});

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
          glowColor: AppColors.primary,
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}
