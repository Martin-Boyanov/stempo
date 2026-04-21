import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import '../state/auth_providers.dart';
import '../ui/widgets/loader.dart';
import '../ui/widgets/primary_button.dart';

class OnboardingSpotify extends StatefulWidget {
  const OnboardingSpotify({super.key});

  @override
  State<OnboardingSpotify> createState() => _OnboardingSpotifyState();
}

class _OnboardingSpotifyState extends State<OnboardingSpotify> {

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.watch(context);
    final isConnecting = auth.status == SpotifyConnectionStatus.connecting;
    final isConnected = auth.isConnected;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WalkingLoader(
                    title: 'Walk to your rhythm',
                    center: false,
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
                  PrimaryButton(
                    text: isConnecting || isConnected
                        ? "Connecting to Spotify..."
                        : "Login with Spotify",
                    onPressed: isConnecting || isConnected
                        ? () {}
                        : () async {
                            final authController = AuthScope.read(context);
                            final router = GoRouter.of(context);
                            final success = await authController
                                .connectWithSpotifyPkce();

                            if (!mounted || !success) return;
                            router.push('/motion');
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
