import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/widgets/primary_button.dart';

class OnboardingMotion extends StatelessWidget {
  const OnboardingMotion({super.key});

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
              "Let’s sync your steps.",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 12),
            const Text(
              "We’ll use motion sensors to track your walking rhythm (steps per minute).",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),

            const SizedBox(height: 40),

            PrimaryButton(
              text: "Allow Motion Access",
              onPressed: () => context.push('/pace'), // <-- FIXED
            ),

            const SizedBox(height: 16),

            PrimaryButton(
              text: "Skip for now",
              color: Color(0xFF3A3A3A),
              onPressed: () => context.push('/pace'), // <-- FIXED
            ),
          ],
        ),
      ),
    );
  }
}
