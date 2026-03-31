import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/theme/colors.dart';
import '../ui/widgets/primary_button.dart';

class OnboardingPace extends StatefulWidget {
  const OnboardingPace({super.key});

  @override
  State<OnboardingPace> createState() => _OnboardingPaceState();
}

class _OnboardingPaceState extends State<OnboardingPace> {
  static const RangeValues _suggestedPaceRange = RangeValues(95, 115);

  RangeValues paceRange = _suggestedPaceRange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
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
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text(
                      'Lower limit',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      paceRange.start.toInt().toString(),
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
                      'Upper limit',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      paceRange.end.toInt().toString(),
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
              data: SliderTheme.of(context).copyWith(
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: RangeSlider(
                values: paceRange,
                min: 80,
                max: 140,
                divisions: 60,
                activeColor: AppColors.primary,
                onChanged: (values) => setState(() => paceRange = values),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => paceRange = _suggestedPaceRange),
              child: const Text(
                'Use suggested range (95-115)',
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
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
    );
  }
}
