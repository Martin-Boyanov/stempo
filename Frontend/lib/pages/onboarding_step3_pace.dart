import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/auth_providers.dart';
import '../ui/theme/colors.dart';
import '../ui/widgets/primary_button.dart';

class OnboardingPace extends StatefulWidget {
  const OnboardingPace({super.key});

  @override
  State<OnboardingPace> createState() => _OnboardingPaceState();
}

class _OnboardingPaceState extends State<OnboardingPace> {
  static const int _suggestedTargetBpm = 105;
  static const int _suggestedTolerance = 10;

  double? _targetBpm;
  double? _tolerance;

  int get _minBpm =>
      (_targetBpm!.round() - _tolerance!.round()).clamp(80, 140);
  int get _maxBpm =>
      (_targetBpm!.round() + _tolerance!.round()).clamp(80, 140);

  void _syncFromAuthIfNeeded() {
    if (_targetBpm != null && _tolerance != null) return;
    final auth = AuthScope.read(context);
    _targetBpm = auth.userCadence.toDouble();
    _tolerance = auth.bpmTolerance.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    _syncFromAuthIfNeeded();
    return Scaffold(
      appBar: AppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "What's your walking pace?",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                      height: 1.15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "(You'll be able to set different modes later)",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'Target BPM',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _targetBpm!.round().toString(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text(
                            'Tolerance',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '+/- ${_tolerance!.round()}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(
                      context,
                    ).copyWith(showValueIndicator: ShowValueIndicator.never),
                    child: Slider(
                      value: _targetBpm!,
                      min: 80,
                      max: 140,
                      divisions: 60,
                      activeColor: AppColors.primary,
                      onChanged: (value) => setState(() => _targetBpm = value),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Range: $_minBpm-$_maxBpm BPM',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(
                      context,
                    ).copyWith(showValueIndicator: ShowValueIndicator.never),
                    child: Slider(
                      value: _tolerance!,
                      min: 4,
                      max: 20,
                      divisions: 16,
                      activeColor: AppColors.warning,
                      onChanged: (value) => setState(() => _tolerance = value),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      _targetBpm = _suggestedTargetBpm.toDouble();
                      _tolerance = _suggestedTolerance.toDouble();
                    }),
                    child: const Text(
                      'Use suggested target (105 BPM +/- 10)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Text(
                    "A lot of people don't know this yet, so we picked a common walking range to start.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 40),
                  PrimaryButton(
                    text: 'Finish setup',
                    onPressed: () {
                      final auth = AuthScope.read(context);
                      auth.userCadence = _targetBpm!.round();
                      auth.bpmTolerance = _tolerance!.round();
                      context.go('/home');
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
