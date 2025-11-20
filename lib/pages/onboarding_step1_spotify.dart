import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/widgets/primary_button.dart';
import 'package:lottie/lottie.dart';

class OnboardingSpotify extends StatefulWidget {
  const OnboardingSpotify({super.key});

  @override
  State<OnboardingSpotify> createState() => _OnboardingSpotifyState();
}

class _OnboardingSpotifyState extends State<OnboardingSpotify>
    with TickerProviderStateMixin {

  late AnimationController waveController;
  late Animation<double> slideAnim;

  @override
  void initState() {
    super.initState();

    waveController = AnimationController(
      duration: const Duration(milliseconds: 1200), // ~100 bpm
      vsync: this,
    )..repeat(reverse: true);

    slideAnim = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: waveController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Walking animation - NOT inside ShaderMask
            Center(
              child: SizedBox(
                height: 200,
                child: Lottie.asset(
                  'assets/animations/walking.json',
                  repeat: true,
                  animate: true,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Only shimmer the text, not the animation
            AnimatedBuilder(
              animation: slideAnim,
              builder: (_, __) {
                final t = slideAnim.value;
                return ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: Alignment(t, 0),
                      end: Alignment(t + 2, 0),
                      tileMode: TileMode.mirror,
                      colors: const [
                        Color(0xFF3AFF8C),
                        Color(0xFF1DB954),
                        Color(0xFF0D4C23),
                        Color(0xFF1DB954),
                        Color(0xFF3AFF8C),
                      ],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.srcATop,
                  child: const Center(
                    child: Text(
                      "Walk to your rhythm",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            PrimaryButton(
              text: "Login with Spotify",
              onPressed: () => context.push('/motion'),
            ),
          ],
        ),
      ),
    );
  }
}
