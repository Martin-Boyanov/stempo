import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import '../state/auth_providers.dart';
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
    final auth = AuthScope.watch(context);
    final isConnecting = auth.status == SpotifyConnectionStatus.connecting;
    final isConnected = auth.isConnected;

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
                        fontSize: 32,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            if (auth.errorMessage != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0x22FF5A5F),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x44FF5A5F)),
                ),
                child: Text(
                  auth.errorMessage!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            if (isConnected) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0x221DB954),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x441DB954)),
                ),
                child: const Text(
                  'Spotify account connected. You can continue with your real Spotify session now.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            PrimaryButton(
              text: isConnecting
                  ? "Connecting to Spotify..."
                  : (isConnected ? "Continue" : "Login with Spotify"),
              onPressed: isConnecting
                  ? () {}
                  : () async {
                      if (isConnected) {
                        if (!mounted) return;
                        context.push('/motion');
                        return;
                      }

                      final authController = AuthScope.read(context);
                      final router = GoRouter.of(context);
                      final success =
                          await authController.connectWithSpotifyPkce();

                      if (!mounted || !success) return;
                      router.push('/motion');
                    },
            ),
          ],
        ),
      ),
    );
  }
}
