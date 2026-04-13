import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/auth_providers.dart';
import '../pages/home_page.dart';
import '../pages/now_playing_page.dart';
import '../pages/onboarding_step1_spotify.dart';
import '../pages/onboarding_step2_motion.dart';
import '../pages/onboarding_step3_pace.dart';
import '../pages/playlist_page.dart';
import '../pages/steps_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    redirect: (context, state) {
      final uri = state.uri;
      if (uri.scheme == 'stempo' && uri.host == 'spotify-callback') {
        final query = uri.query.isEmpty ? '' : '?${uri.query}';
        return '/spotify-callback$query';
      }
      if (state.matchedLocation == '/') return '/spotify';
      return null;
    },
    initialLocation: '/spotify',
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/spotify'),
      GoRoute(
        path: '/spotify',
        builder: (context, state) => const OnboardingSpotify(),
      ),
      GoRoute(
        path: '/spotify-callback',
        builder: (context, state) => _SpotifyCallbackPage(uri: state.uri),
      ),
      GoRoute(
        path: '/motion',
        builder: (context, state) => const OnboardingMotion(),
      ),
      GoRoute(
        path: '/pace',
        builder: (context, state) => const OnboardingPace(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
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
      GoRoute(
        path: '/playlist',
        builder: (context, state) {
          final args = state.extra;
          if (args is! PlaylistPageArgs) {
            return const HomePage();
          }
          return PlaylistPage(args: args);
        },
      ),
      GoRoute(path: '/steps', builder: (context, state) => const StepsPage()),
    ],
  );
}

class _SpotifyCallbackPage extends StatefulWidget {
  const _SpotifyCallbackPage({required this.uri});

  final Uri uri;

  @override
  State<_SpotifyCallbackPage> createState() => _SpotifyCallbackPageState();
}

class _SpotifyCallbackPageState extends State<_SpotifyCallbackPage> {
  bool _handled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handled) return;
    _handled = true;
    _complete();
  }

  Future<void> _complete() async {
    final auth = AuthScope.read(context);
    final success = await auth.completeAuthorizationCallback(widget.uri);
    if (!mounted) return;
    context.go(success ? '/motion' : '/spotify');
  }

  @override
  Widget build(BuildContext context) {
    return const OnboardingSpotify();
  }
}
