import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/widgets/primary_button.dart';

class OnboardingSpotify extends StatelessWidget {
  const OnboardingSpotify({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(), // back on later screens only
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Walk to your rhythm.",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 40),

            PrimaryButton(
              text: "Login with Spotify",
              onPressed: () => context.push('/motion'), // <-- FIXED
            ),
          ],
        ),
      ),
    );
  }
}
