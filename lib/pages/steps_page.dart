import 'dart:async';

import 'package:flutter/material.dart';

import '../services/step_service.dart';
import '../ui/theme/app_fx.dart';
import '../ui/theme/colors.dart';

class StepsPage extends StatelessWidget {
  const StepsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StepsView();
  }
}

class StepsView extends StatefulWidget {
  const StepsView({
    super.key,
    this.embedded = false,
    this.showBackButton = true,
  });

  final bool embedded;
  final bool showBackButton;

  @override
  State<StepsView> createState() => _StepsViewState();
}

class _StepsViewState extends State<StepsView> {
  final StepService _stepService = StepService();

  Timer? _refreshTimer;
  int _steps = 0;
  bool _loading = true;
  String? _errorMessage;
  DateTime? _lastUpdatedAt;

  @override
  void initState() {
    super.initState();
    _loadSteps();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadSteps(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSteps({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final granted = await _stepService.requestPermissions();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage =
              'Health Connect permission is required to read your steps.';
        });
        return;
      }

      final steps = await _stepService.getTodaySteps();
      if (!mounted) return;
      setState(() {
        _steps = steps;
        _loading = false;
        _errorMessage = null;
        _lastUpdatedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'Unable to read steps right now. Check Health Connect and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: AtmosphereBackground(
            accent: AppColors.primary,
            secondaryAccent: AppColors.accent,
            child: SizedBox.expand(),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              widget.embedded ? 16 : 12,
              20,
              widget.embedded ? 172 : 32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Header(
                  embedded: widget.embedded,
                  showBackButton: widget.showBackButton,
                ),
                const SizedBox(height: 28),
                FrostedPanel(
                  radius: 36,
                  elevated: true,
                  glowColor: AppColors.primary,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _StepRing(loading: _loading, steps: _steps),
                      const SizedBox(height: 24),
                      const Text(
                        'Steps today',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _buildValueContent(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _buildStatusText(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _loadSteps,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(_loading ? 'Refreshing...' : 'Refresh'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FrostedPanel(
                  radius: 28,
                  glowColor: AppColors.accent,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.health_and_safety_rounded,
                          color: AppColors.primaryBright,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Reading live step totals from Health Connect so Samsung Health data stays in sync.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(body: SafeArea(child: content));
  }

  Widget _buildValueContent() {
    if (_loading) {
      return const SizedBox(
        key: ValueKey('loading'),
        height: 60,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              color: AppColors.primaryBright,
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return const Icon(
        Icons.lock_outline_rounded,
        key: ValueKey('error'),
        color: AppColors.cinemaRed,
        size: 52,
      );
    }

    return Text(
      _formatSteps(_steps),
      key: ValueKey(_steps),
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 54,
        height: 0.95,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String _buildStatusText() {
    if (_errorMessage != null) {
      return _errorMessage!;
    }
    if (_loading) {
      return 'Checking permissions and syncing your latest movement.';
    }
    if (_steps == 0) {
      return 'No data yet';
    }
    if (_lastUpdatedAt == null) {
      return 'Updated just now';
    }

    final hour = _lastUpdatedAt!.hour.toString().padLeft(2, '0');
    final minute = _lastUpdatedAt!.minute.toString().padLeft(2, '0');
    return 'Last updated at $hour:$minute';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.embedded, required this.showBackButton});

  final bool embedded;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBackButton)
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 46,
              height: 46,
              decoration: AppFx.glassDecoration(
                radius: 18,
                glowColor: AppColors.cinemaRed,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
          )
        else
          const SizedBox(width: 46),
        Expanded(
          child: Column(
            children: [
              Text(
                embedded ? 'Daily Steps' : 'Steps',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Health Connect',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 46),
      ],
    );
  }
}

class _StepRing extends StatelessWidget {
  const _StepRing({required this.loading, required this.steps});

  final bool loading;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final progress = steps <= 0 ? 0.08 : (steps / 10000).clamp(0.08, 1.0);

    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 210,
            height: 210,
            child: CircularProgressIndicator(
              value: loading ? null : progress,
              strokeWidth: 14,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryBright,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_walk_rounded,
                color: loading
                    ? AppColors.textSecondary
                    : AppColors.primaryBright,
                size: 34,
              ),
              const SizedBox(height: 8),
              Text(
                loading ? 'Syncing' : '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'toward 10,000',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatSteps(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}
