import 'package:go_router/go_router.dart';

import '../pages/home_page.dart';
import '../pages/now_playing_page.dart';
import '../pages/onboarding_step1_spotify.dart';
import '../pages/onboarding_step2_motion.dart';
import '../pages/onboarding_step3_pace.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/spotify',
    routes: [
      GoRoute(
        path: '/spotify',
        builder: (context, state) => const OnboardingSpotify(),
      ),
      GoRoute(
        path: '/motion',
        builder: (context, state) => const OnboardingMotion(),
      ),
      GoRoute(
        path: '/pace',
        builder: (context, state) => const OnboardingPace(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/now-playing',
        builder: (context, state) {
          final args = state.extra;
          if (args is! NowPlayingPageArgs) {
            return const HomePage();
          }
          return NowPlayingPage(args: args);
        },
      ),
    ],
  );
}
