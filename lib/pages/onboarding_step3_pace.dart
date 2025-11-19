import 'package:flutter/material.dart';
import '../ui/widgets/primary_button.dart';
import 'package:go_router/go_router.dart';

class OnboardingPace extends StatefulWidget {
  const OnboardingPace({super.key});

  @override
  State<OnboardingPace> createState() => _OnboardingPaceState();
}

class _OnboardingPaceState extends State<OnboardingPace> {
  double pace = 100;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(), // <-- ADDED so back arrow works
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "What’s your walking pace?",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),
            const Text(
              "(You'll be able to set different modes later)",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),

            const SizedBox(height: 40),

            Text(
              pace.toInt().toString(),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),

            Slider(
              value: pace,
              min: 80,
              max: 140,
              divisions: 60,
              activeColor: Color(0xFF1DB954),
              onChanged: (value) => setState(() => pace = value),
            ),

            const SizedBox(height: 40),

            PrimaryButton(
              text: "Finish setup",
              onPressed: () {
                // In the future:
                // context.pushReplacement('/home');
              },
            ),
          ],
        ),
      ),
    );
  }
}
