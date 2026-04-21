import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/auth_providers.dart';
import '../controllers/auth_controller.dart';
import '../pages/home_page.dart';
import '../pages/now_playing_page.dart';
import '../pages/onboarding_step1_spotify.dart';
import '../pages/onboarding_step2_motion.dart';
import '../pages/onboarding_step3_pace.dart';
import '../pages/playlist_page.dart';
import '../pages/settings_page.dart';

class AppRouter {
  static const Set<String> _restorableRoutes = {
    '/home',
    '/motion',
    '/pace',
    '/settings',
  };

  static bool _isRestorableRoute(String location) =>
      _restorableRoutes.contains(location);

  static int _homeTabFromQuery(Uri uri) {
    switch (uri.queryParameters['tab']) {
      case 'search':
        return 1;
      case 'library':
        return 2;
      case 'modes':
        return 3;
      case 'home':
      default:
        return 0;
    }
  }

  static GoRouter createRouter(SpotifyAuthController auth) => GoRouter(
    refreshListenable: auth,
    redirect: (context, state) async {
      final uri = state.uri;
      if (uri.scheme == 'stempo' && uri.host == 'spotify-callback') {
        final query = uri.query.isEmpty ? '' : '?${uri.query}';
        return '/spotify-callback$query';
      }

      final auth = AuthScope.read(context);
      final isAtStart = state.matchedLocation == '/' || state.matchedLocation == '/spotify';
      
      // If we are at the start and already connected, try to go to last location
      if (isAtStart && auth.isConnected) {
        final prefs = await SharedPreferences.getInstance();
        final lastLoc = prefs.getString('last_location');
        if (lastLoc != null && _isRestorableRoute(lastLoc)) {
          return lastLoc;
        }
        return '/home';
      }

      // Save current location if it's not a start/callback screen
      final isTransitionScreen = state.matchedLocation == '/' || 
                               state.matchedLocation == '/spotify' || 
                               state.matchedLocation == '/spotify-callback';
      if (!isTransitionScreen && _isRestorableRoute(state.matchedLocation)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_location', state.matchedLocation);
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
      GoRoute(
        path: '/home',
        builder: (context, state) => HomePage(
          initialTab: _homeTabFromQuery(state.uri),
        ),
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
      GoRoute(
        path: '/playlist/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          final args = state.extra;

          if (args is PlaylistPageArgs) {
            return PlaylistPage(args: args);
          }

          if (id != null) {
            final auth = AuthScope.read(context);
            final playlist = auth.findPlaylistById(id);
            if (playlist != null) {
              final cadenceStr = state.uri.queryParameters['cadence'];
              final cadence = int.tryParse(cadenceStr ?? '') ?? 110;
              return PlaylistPage(
                args: PlaylistPageArgs(
                  playlist: playlist,
                  userCadence: cadence,
                  sourceTab: PlaylistSourceTab.library,
                ),
              );
            }
          }

          return const HomePage();
        },
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
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
