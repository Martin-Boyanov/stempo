import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controllers/auth_controller.dart';
import '../controllers/spotify_remote_service.dart';
import '../services/step_service.dart';
import '../state/auth_providers.dart';
import '../state/mock_playlists.dart';
import '../state/playlist_models.dart';
import '../state/spotify_models.dart';
import '../ui/theme/app_fx.dart';
import '../ui/theme/colors.dart';
import '../ui/widgets/loader.dart';
import '../ui/widgets/media_cover.dart';
import '../ui/widgets/now_playing_bar.dart';
import 'library_page.dart';
import 'playlist_page.dart';
import 'search_page.dart';

class HomeModesSnapshot {
  const HomeModesSnapshot({
    this.selectedPlaylistIds = const <String>{},
    this.selectedModeIndex = 1,
    this.currentStep = 0,
  });

  final Set<String> selectedPlaylistIds;
  final int selectedModeIndex;
  final int currentStep;
}

class HomePageArgs {
  const HomePageArgs({
    this.initialTab = 0,
    this.modesSnapshot = const HomeModesSnapshot(),
  });

  final int initialTab;
  final HomeModesSnapshot modesSnapshot;
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.initialTab = 0,
    this.initialModesSnapshot = const HomeModesSnapshot(),
  });

  final int initialTab;
  final HomeModesSnapshot initialModesSnapshot;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    _NavItem(label: 'Home', icon: Icons.home_rounded),
    _NavItem(label: 'Search', icon: Icons.search_rounded),
    _NavItem(label: 'Library', icon: Icons.library_music_rounded),
    _NavItem(label: 'Modes', icon: Icons.directions_run_rounded),
  ];

  final _mockState = const _HomeMockState(
    stepsDone: 8420,
    goalSteps: 10000,
    trackTitle: 'Seremise',
    trackArtist: 'NITE SHIFT, Luma Cove',
    trackImageAsset: 'assets/images/musicCover8.webp',
    trackBpm: 112,
    sessionPrompt:
        'Use quick actions to jump to your playlists or tune BPM for a better pace match.',
  );

  late final AnimationController _pulseController;
  final StepService _stepService = StepService();
  late int _selectedTab;
  int _todaySteps = 0;
  int? _currentTrackBpm;
  String? _currentTrackBpmUri;
  bool _hasStepPermission = false;
  bool _isRefreshingSteps = false;
  StreamSubscription<StepCount>? _stepSubscription;
  int? _lastPedometerCount;
  bool _isTrackingCadence = false;
  bool _isTrackerClosing = false;
  int _trackedSteps = 0;
  int _trackingSecondsRemaining = 20;
  int? _trackingInitialStepCount;
  Timer? _trackingTimer;
  late HomeModesSnapshot _modesSnapshot;

  int _syncGap(int userCadence) {
    final trackBpm = _currentTrackBpm ?? _mockState.trackBpm;
    return (trackBpm - userCadence).abs();
  }

  void _updateModesSnapshot(HomeModesSnapshot snapshot) {
    _modesSnapshot = snapshot;
  }

  void _openPlaylist(
    TempoPlaylist playlist, {
    PlaylistSourceTab sourceTab = PlaylistSourceTab.home,
  }) {
    final auth = AuthScope.read(context);
    context.push(
      '/playlist/${playlist.id}?cadence=${auth.userCadence}',
      extra: PlaylistPageArgs(
        playlist: playlist,
        userCadence: auth.userCadence,
        sourceTab: sourceTab,
      ),
    );
  }

  void _seedMiniNowPlaying(SpotifyTrack track) {
    setState(() {
      _playerState = SpotifyRemotePlayerState(
        trackUri: track.spotifyUri,
        trackName: track.title,
        artistName: track.artistLine,
        isPaused: false,
        playbackPositionMs: 0,
        durationMs: track.durationMs,
        imageUri: track.imageUrl,
      );
      _currentTrackBpm = track.bpm;
      _currentTrackBpmUri = track.spotifyUri;
    });
  }

  void _goToLibraryTab() => setState(() => _selectedTab = 2);

  void _refreshPlaylistsFromSpotify() {
    final auth = AuthScope.read(context);
    if (!auth.isConnected) return;
    unawaited(auth.loadUserData());
  }

  Future<void> _openBpmPicker() async {
    final auth = AuthScope.read(context);
    var tempCadence = auth.userCadence.toDouble();
    final tolerance = auth.bpmTolerance;

    final updated = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                gradient: AppFx.raisedPanelGradient,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: AppFx.softGlow(AppColors.primary, strength: 0.14),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Change BPM Target',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${tempCadence.round()} BPM',
                      style: const TextStyle(
                        color: AppColors.primaryBright,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Range: ${tempCadence.round() - tolerance}-${tempCadence.round() + tolerance} BPM (+/- $tolerance)',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Slider(
                      value: tempCadence,
                      min: 90,
                      max: 130,
                      divisions: 40,
                      activeColor: AppColors.primary,
                      inactiveColor: Colors.white.withValues(alpha: 0.08),
                      onChanged: (value) {
                        setModalState(() => tempCadence = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionPillButton(
                            label: 'Cancel',
                            icon: Icons.close_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionPillButton(
                            label: 'Save BPM',
                            icon: Icons.check_rounded,
                            filled: true,
                            onTap: () =>
                                Navigator.of(context).pop(tempCadence.round()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (updated != null) {
      if (!mounted) return;
      AuthScope.read(context).userCadence = updated;
    }
  }

  Future<void> _startStepBasedBpmTracking() async {
    if (_isTrackingCadence) return;

    var granted = _hasStepPermission;
    if (!granted) {
      granted = await _stepService.requestPermissions();
      if (!mounted) return;
    }

    final activityStatus = await Permission.activityRecognition.status;
    if (!mounted) return;
    if (!granted || activityStatus != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Step access is needed to track BPM automatically.'),
        ),
      );
      return;
    }

    setState(() {
      _hasStepPermission = true;
      _isTrackingCadence = true;
      _isTrackerClosing = false;
      _trackedSteps = 0;
      _trackingSecondsRemaining = 20;
      _trackingInitialStepCount = null;
    });

    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isTrackingCadence) {
        timer.cancel();
        return;
      }

      if (_trackingSecondsRemaining <= 1) {
        timer.cancel();
        _finishStepBasedBpmTracking();
        return;
      }

      setState(() {
        _trackingSecondsRemaining -= 1;
      });
    });
  }

  Future<void> _handleTrackingClosePressed() async {
    if (_isTrackerClosing || !_isTrackingCadence) return;
    _isTrackerClosing = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151B18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          title: const Text(
            'Exit tracking?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'If you exit now, we will not set your steps per minute automatically.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Keep tracking',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.cinemaRed,
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
    _isTrackerClosing = false;
    if (!mounted || shouldExit != true) return;
    _cancelStepBasedBpmTracking();
  }

  void _cancelStepBasedBpmTracking() {
    _trackingTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isTrackingCadence = false;
      _trackedSteps = 0;
      _trackingSecondsRemaining = 20;
      _trackingInitialStepCount = null;
    });
  }

  void _finishStepBasedBpmTracking() {
    if (_trackedSteps <= 0) {
      if (!mounted) return;
      setState(() {
        _isTrackingCadence = false;
        _trackingInitialStepCount = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No steps were detected, so BPM was not changed.'),
        ),
      );
      return;
    }

    final rawBpm = _trackedSteps * 3;
    if (rawBpm < 35) {
      if (!mounted) return;
      setState(() {
        _isTrackingCadence = false;
        _trackingInitialStepCount = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please take more steps so we can calculate your BPM accurately.',
          ),
        ),
      );
      return;
    }

    final targetBpm = switch (rawBpm) {
      >= 35 && <= 69 => rawBpm * 2,
      > 130 => (rawBpm / 2).round(),
      _ => rawBpm,
    };
    AuthScope.read(context).userCadence = targetBpm;

    if (!mounted) return;
    setState(() {
      _isTrackingCadence = false;
      _trackingInitialStepCount = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Target BPM set to $targetBpm from $_trackedSteps steps.',
        ),
      ),
    );
  }

  Future<void> _confirmExitApp() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151B18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          title: const Text(
            'Exit app?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Do you want to leave stempo?',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Stay',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.cinemaRed,
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );

    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
  }

  StreamSubscription<SpotifyRemotePlayerState>? _playerSubscription;
  SpotifyRemotePlayerState? _playerState;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, _tabs.length - 1);
    _modesSnapshot = widget.initialModesSnapshot;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _refreshTodaySteps();
    _initLiveTracking();
    _bindRemote();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTab = widget.initialTab.clamp(0, _tabs.length - 1);
    if (nextTab != _selectedTab) {
      setState(() => _selectedTab = nextTab);
    }
  }

  void _bindRemote() {
    _playerSubscription = SpotifyRemoteService.instance
        .playerStateStream()
        .listen((state) {
          if (!mounted) return;
          setState(() {
            _playerState = state;
            if (state.trackUri.isEmpty) {
              _currentTrackBpm = null;
              _currentTrackBpmUri = null;
            }
          });
          unawaited(_refreshCurrentTrackBpm(state.trackUri));
        });

    unawaited(() async {
      try {
        final initialState = await SpotifyRemoteService.instance
            .getPlayerState();
        if (!mounted || initialState == null) return;
        setState(() {
          _playerState = initialState;
        });
        await _refreshCurrentTrackBpm(initialState.trackUri);
      } catch (_) {}
    }());
  }

  Future<void> _refreshCurrentTrackBpm(String trackUri) async {
    if (!mounted) return;
    final trimmedUri = trackUri.trim();
    if (trimmedUri.isEmpty) {
      if (_currentTrackBpm != null || _currentTrackBpmUri != null) {
        setState(() {
          _currentTrackBpm = null;
          _currentTrackBpmUri = null;
        });
      }
      return;
    }
    if (_currentTrackBpmUri == trimmedUri && _currentTrackBpm != null) return;

    final auth = AuthScope.read(context);
    final resolvedBpm = await auth.resolveTrackBpm(trimmedUri);
    if (!mounted) return;
    if ((_playerState?.trackUri ?? '').trim() != trimmedUri) return;

    setState(() {
      _currentTrackBpmUri = trimmedUri;
      _currentTrackBpm = resolvedBpm;
    });
  }

  void _initLiveTracking() async {
    final status = await Permission.activityRecognition.status;
    if (status != PermissionStatus.granted) {
      debugPrint('ACTIVITY RECOGNITION PERMISSION NOT GRANTED');
      return;
    }

    _stepSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        debugPrint('PEDOMETER EVENT: ${event.steps} steps');
        if (!mounted) return;
        if (_lastPedometerCount == null) {
          _lastPedometerCount = event.steps;
          debugPrint('PEDOMETER INITIALIZED: $_lastPedometerCount');
          unawaited(_refreshTodaySteps(silent: true));
          return;
        }
        final delta = math.max(0, event.steps - _lastPedometerCount!);
        _lastPedometerCount = event.steps;
        setState(() {
          _todaySteps += delta;
          debugPrint('PEDOMETER LIVE DELTA: $delta, total=$_todaySteps');
          if (_isTrackingCadence) {
            _trackingInitialStepCount ??= event.steps;
            _trackedSteps = math.max(
              0,
              event.steps - _trackingInitialStepCount!,
            );
          }
        });
      },
      onError: (error) {
        debugPrint('PEDOMETER ERROR: $error');
      },
    );
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _stepSubscription?.cancel();
    _playerSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _refreshTodaySteps({bool silent = false}) async {
    if (_isRefreshingSteps) return;
    _isRefreshingSteps = true;
    try {
      if (!_hasStepPermission || !silent) {
        final granted = await _stepService.requestPermissions();
        if (!mounted) return;
        if (!granted) {
          if (_hasStepPermission || _todaySteps != 0) {
            setState(() {
              _hasStepPermission = false;
              _todaySteps = 0;
            });
          }
          return;
        }
      }

      final total = await _stepService.getTodaySteps();
      if (!mounted) return;
      if (!silent || total != _todaySteps || !_hasStepPermission) {
        setState(() {
          _hasStepPermission = true;
          _todaySteps = total;
        });
      }
    } catch (_) {
      if (!mounted || silent) return;
      setState(() {
        _hasStepPermission = false;
        _todaySteps = 0;
      });
    } finally {
      _isRefreshingSteps = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.watch(context);
    if (auth.isConnected && auth.isLoadingData && auth.playlists.isEmpty) {
      return const Scaffold(
        body: WalkingLoadingScreen(title: 'Gathering data'),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isTrackingCadence) {
          await _handleTrackingClosePressed();
          return;
        }
        if (_selectedTab != 0) {
          setState(() => _selectedTab = 0);
          return;
        }
        await _confirmExitApp();
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: AtmosphereBackground(
                accent: AppColors.primary,
                secondaryAccent: AppColors.cinemaRed,
                child: SizedBox.expand(),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    child: _buildSelectedTabBody(auth),
                  ),
                  if (_isTrackingCadence)
                    Positioned.fill(
                      child: _StepBpmTrackingOverlay(
                        steps: _trackedSteps,
                        secondsRemaining: _trackingSecondsRemaining,
                        progress: (20 - _trackingSecondsRemaining) / 20,
                        pulse: _pulseController,
                        onClose: _handleTrackingClosePressed,
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((_playerState?.trackUri.isNotEmpty ?? false) &&
                            (_playerState?.trackName.isNotEmpty ?? false)) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: StempoNowPlayingBar(
                              initialTrackTitle: _playerState?.trackName ?? '',
                              initialTrackArtist:
                                  _playerState?.artistName ?? '',
                              initialTrackImageAsset:
                                  _playerState?.resolvedImageUrl ?? '',
                              initialTrackBpm:
                                  _currentTrackBpm ?? _mockState.trackBpm,
                              userCadence: auth.userCadence,
                              returnRoute: switch (_selectedTab) {
                                1 => '/home?tab=search',
                                2 => '/home?tab=library',
                                3 => '/home?tab=modes',
                                _ => '/home?tab=home',
                              },
                              returnExtra: HomePageArgs(
                                initialTab: _selectedTab,
                                modesSnapshot: _modesSnapshot,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _BottomNav(
                          items: _tabs,
                          selectedIndex: _selectedTab,
                          onSelected: (index) =>
                              setState(() => _selectedTab = index),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabBody(SpotifyAuthController auth) {
    final playlists = auth.playlists.isNotEmpty
        ? auth.playlists
        : (auth.isConnected ? const <TempoPlaylist>[] : mockTempoPlaylists);

    switch (_selectedTab) {
      case 0:
        return _HomeTabView(
          key: const ValueKey('home'),
          state: _mockState,
          pulse: _pulseController,
          userCadence: auth.userCadence,
          todaySteps: _todaySteps,
          trackBpm: _currentTrackBpm ?? _mockState.trackBpm,
          syncGap: _syncGap(auth.userCadence),
          recentPlaylists: playlists,
          onGoToLibrary: _goToLibraryTab,
          onChangeBpm: _openBpmPicker,
          onTrackBpm: _startStepBasedBpmTracking,
          onOpenPlaylist: _openPlaylist,
          onRefreshPlaylists: _refreshPlaylistsFromSpotify,
        );
      case 1:
        return SearchPage(
          targetBpm: auth.userCadence,
          paceRange: RangeValues(
            auth.userCadence.toDouble() - auth.bpmTolerance,
            auth.userCadence.toDouble() + auth.bpmTolerance,
          ),
          recentSessions: auth.playlists
              .where((p) => p.wasRecentlyPlayed)
              .map(
                (p) => SearchRecentSession(
                  title: p.title,
                  subtitle: p.subtitle,
                  detail: '${p.bpm} BPM',
                  bpm: p.bpm,
                  imageAsset: p.imageAsset,
                ),
              )
              .toList(),
          catalogEntries: auth.searchEntries
              .map(SearchCatalogEntry.fromSpotify)
              .toList(),
        );
      case 2:
        return LibraryPage(
          userCadence: auth.userCadence,
          playlists: playlists,
          profileName: auth.profile?.displayName,
        );
      case 3:
        return _ModesTabView(
          playlists: playlists,
          initialSnapshot: _modesSnapshot,
          onStateChanged: _updateModesSnapshot,
          onOpenPlaylist: (playlist) =>
              _openPlaylist(playlist, sourceTab: PlaylistSourceTab.modes),
          onTrackStarted: _seedMiniNowPlaying,
        );
      default:
        return _HomeTabView(
          key: const ValueKey('home'),
          state: _mockState,
          pulse: _pulseController,
          userCadence: auth.userCadence,
          todaySteps: _todaySteps,
          trackBpm: _currentTrackBpm ?? _mockState.trackBpm,
          syncGap: _syncGap(auth.userCadence),
          recentPlaylists: playlists,
          onGoToLibrary: _goToLibraryTab,
          onChangeBpm: _openBpmPicker,
          onTrackBpm: _startStepBasedBpmTracking,
          onOpenPlaylist: _openPlaylist,
          onRefreshPlaylists: _refreshPlaylistsFromSpotify,
        );
    }
  }
}

class _HomeTabView extends StatelessWidget {
  const _HomeTabView({
    super.key,
    required this.state,
    required this.pulse,
    required this.userCadence,
    required this.todaySteps,
    required this.trackBpm,
    required this.syncGap,
    required this.recentPlaylists,
    required this.onGoToLibrary,
    required this.onChangeBpm,
    required this.onTrackBpm,
    required this.onOpenPlaylist,
    required this.onRefreshPlaylists,
  });

  final _HomeMockState state;
  final Animation<double> pulse;
  final int userCadence;
  final int todaySteps;
  final int trackBpm;
  final int syncGap;
  final List<TempoPlaylist> recentPlaylists;
  final VoidCallback onGoToLibrary;
  final VoidCallback onChangeBpm;
  final VoidCallback onTrackBpm;
  final ValueChanged<TempoPlaylist> onOpenPlaylist;
  final VoidCallback onRefreshPlaylists;

  bool _isBpmSpecificPlaylist(TempoPlaylist playlist) {
    return isGeneratedBpmPlaylistTitle(playlist.title);
  }

  int _playlistFitDelta(TempoPlaylist playlist) {
    final midpoint = generatedBpmPlaylistMidpoint(playlist.title);
    final effectiveBpm = midpoint ?? playlist.bpm;
    return (effectiveBpm - userCadence).abs();
  }

  @override
  Widget build(BuildContext context) {
    final regularRecents = recentPlaylists
        .where((playlist) => !_isBpmSpecificPlaylist(playlist))
        .toList(growable: false);
    final bpmRecents =
        recentPlaylists.where(_isBpmSpecificPlaylist).toList(growable: false)
          ..sort((a, b) {
            final fitCompare = _playlistFitDelta(
              a,
            ).compareTo(_playlistFitDelta(b));
            if (fitCompare != 0) return fitCompare;
            return a.title.compareTo(b.title);
          });

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 172),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/Logo.png',
                    height: 38,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'STEMPO',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(
                      Icons.settings_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
            _DailyStepsHero(state: state, pulse: pulse, todaySteps: todaySteps),
            const SizedBox(height: 14),
            _SectionLabel(
              title: 'Recents',
              trailing: 'Jump back in',
              onTitleTap: onRefreshPlaylists,
            ),
            const SizedBox(height: 12),
            if (regularRecents.isEmpty)
              const _InlineEmptyState(
                title: 'No recent playlists yet',
                subtitle: 'Start a session in Library and it will show here.',
              )
            else
              _JumpBackInRow(
                items: regularRecents,
                onTapPlaylist: onOpenPlaylist,
              ),
            if (bpmRecents.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionLabel(
                title: 'BPM playlists',
                trailing: '${bpmRecents.length} generated',
                onTitleTap: onRefreshPlaylists,
              ),
              const SizedBox(height: 12),
              _JumpBackInRow(items: bpmRecents, onTapPlaylist: onOpenPlaylist),
            ],
            const SizedBox(height: 18),
            _StartSessionCard(
              state: state,
              userCadence: userCadence,
              trackBpm: trackBpm,
              syncGap: syncGap,
              onGoToLibrary: onGoToLibrary,
              onChangeBpm: onChangeBpm,
              onTrackBpm: onTrackBpm,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModesTabView extends StatefulWidget {
  const _ModesTabView({
    required this.playlists,
    required this.initialSnapshot,
    required this.onStateChanged,
    required this.onOpenPlaylist,
    required this.onTrackStarted,
  });

  final List<TempoPlaylist> playlists;
  final HomeModesSnapshot initialSnapshot;
  final ValueChanged<HomeModesSnapshot> onStateChanged;
  final ValueChanged<TempoPlaylist> onOpenPlaylist;
  final ValueChanged<SpotifyTrack> onTrackStarted;

  @override
  State<_ModesTabView> createState() => _ModesTabViewState();
}

class _ModesTabViewState extends State<_ModesTabView> {
  late final PageStorageBucket _pageStorageBucket;
  late final PageController _pageController;
  late _ModeOption _selectedMode;
  late Set<String> _selectedPlaylistIds;

  @override
  void initState() {
    super.initState();
    _pageStorageBucket = PageStorageBucket();
    final initialModeIndex = widget.initialSnapshot.selectedModeIndex.clamp(
      0,
      _modeOptions.length - 1,
    );
    _selectedMode = _modeOptions[initialModeIndex];
    _selectedPlaylistIds = Set<String>.from(widget.initialSnapshot.selectedPlaylistIds);
    _pageController = PageController(initialPage: widget.initialSnapshot.currentStep);
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitSnapshot());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ModesTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextAvailableIds = _initialSelectedPlaylistIds(widget.playlists);
    final retainedIds = _selectedPlaylistIds
        .where(nextAvailableIds.contains)
        .toSet();
    if (retainedIds.length != _selectedPlaylistIds.length) {
      _selectedPlaylistIds = retainedIds;
      _emitSnapshot();
    }
  }

  void _emitSnapshot() {
    final page = _pageController.hasClients
        ? (_pageController.page?.round() ?? _pageController.initialPage)
        : _pageController.initialPage;
    widget.onStateChanged(
      HomeModesSnapshot(
        selectedPlaylistIds: Set<String>.from(_selectedPlaylistIds),
        selectedModeIndex: _modeOptions.indexOf(_selectedMode),
        currentStep: page,
      ),
    );
  }

  Set<String> _initialSelectedPlaylistIds(List<TempoPlaylist> playlists) => playlists
      .where((playlist) => (playlist.spotifyUri ?? '').startsWith('spotify:playlist:'))
      .map((playlist) => playlist.id)
      .toSet();

  Future<void> _goToModeChooser() async {
    await _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubicEmphasized,
    );
    _emitSnapshot();
  }

  Future<void> _chooseMode(_ModeOption mode) async {
    setState(() => _selectedMode = mode);
    await _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubicEmphasized,
    );
    _emitSnapshot();
  }

  Future<void> _backToPlaylistChooser() async {
    await _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
    _emitSnapshot();
  }

  Future<void> _backToModeChooser() async {
    await _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
    _emitSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    final selectablePlaylists = widget.playlists
        .where(
          (playlist) => (playlist.spotifyUri ?? '').startsWith('spotify:playlist:'),
        )
        .toList(growable: false);
    final selectedPlaylists = selectablePlaylists
        .where((playlist) => _selectedPlaylistIds.contains(playlist.id))
        .toList(growable: false);

    return Column(
      children: [
        Expanded(
          child: PageStorage(
            bucket: _pageStorageBucket,
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ModesPlaylistChooserScreen(
                  playlists: selectablePlaylists,
                  selectedPlaylistIds: _selectedPlaylistIds,
                  onTogglePlaylist: (playlist) {
                    setState(() {
                      if (_selectedPlaylistIds.contains(playlist.id)) {
                        _selectedPlaylistIds.remove(playlist.id);
                      } else {
                        _selectedPlaylistIds.add(playlist.id);
                      }
                    });
                    _emitSnapshot();
                  },
                  onSelectAll: () {
                    setState(() {
                      _selectedPlaylistIds = selectablePlaylists
                          .map((playlist) => playlist.id)
                          .toSet();
                    });
                    _emitSnapshot();
                  },
                  onContinue:
                      selectedPlaylists.isEmpty ? null : _goToModeChooser,
                ),
                _ModesChooserScreen(
                  selectedMode: _selectedMode,
                  selectedPlaylists: selectedPlaylists,
                  onBack: _backToPlaylistChooser,
                  onChooseMode: _chooseMode,
                ),
                _ModesResultsScreen(
                  mode: _selectedMode,
                  playlists: selectedPlaylists,
                  onBack: _backToModeChooser,
                  onTrackStarted: widget.onTrackStarted,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 140),
          child: Center(
            child: FrostedPanel(
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              glowColor: AppColors.primary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, _) {
                        final page = _pageController.hasClients
                            ? (_pageController.page ??
                                  _pageController.initialPage.toDouble())
                            : 0.0;
                        final isActive = page.round() == i;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: isActive ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: isActive
                                ? AppColors.primaryBright
                                : Colors.white.withValues(alpha: 0.22),
                          ),
                        );
                      },
                    ),
                    if (i != 2) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModesChooserScreen extends StatelessWidget {
  const _ModesChooserScreen({
    required this.selectedMode,
    required this.selectedPlaylists,
    required this.onBack,
    required this.onChooseMode,
  });

  final _ModeOption selectedMode;
  final List<TempoPlaylist> selectedPlaylists;
  final Future<void> Function() onBack;
  final ValueChanged<_ModeOption> onChooseMode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FrostedPanel(
            radius: 30,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            elevated: true,
            glowColor: AppColors.primary,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xB814221B), Color(0x8A111413), Color(0xCC080A09)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onBack(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: AppFx.glassDecoration(
                          radius: 16,
                          glowColor: AppColors.primary,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primaryBright.withValues(alpha: 0.78),
                            AppColors.primary.withValues(alpha: 0.26),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.directions_run_rounded,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Pick a mode',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    height: 0.96,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the BPM lane for the playlists you selected.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _HeaderPill(
                      label:
                          '${selectedPlaylists.length} playlist${selectedPlaylists.length == 1 ? '' : 's'} chosen',
                      accent: AppColors.primary,
                    ),
                    _HeaderPill(
                      label: '${selectedMode.label} selected',
                      accent: selectedMode.accent,
                    ),
                    _HeaderPill(
                      label: selectedMode.rangeLabel,
                      accent: AppColors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _modeOptions.length; i++) ...[
            _ModeOptionCard(
              mode: _modeOptions[i],
              isSelected: _modeOptions[i] == selectedMode,
              onTap: () => onChooseMode(_modeOptions[i]),
            ),
            if (i != _modeOptions.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ModesPlaylistChooserScreen extends StatelessWidget {
  const _ModesPlaylistChooserScreen({
    required this.playlists,
    required this.selectedPlaylistIds,
    required this.onTogglePlaylist,
    required this.onSelectAll,
    required this.onContinue,
  });

  final List<TempoPlaylist> playlists;
  final Set<String> selectedPlaylistIds;
  final ValueChanged<TempoPlaylist> onTogglePlaylist;
  final VoidCallback onSelectAll;
  final Future<void> Function()? onContinue;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FrostedPanel(
            radius: 30,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            elevated: true,
            glowColor: AppColors.primary,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xB814221B), Color(0x8A111413), Color(0xCC080A09)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryBright.withValues(alpha: 0.78),
                        AppColors.primary.withValues(alpha: 0.26),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.library_music_rounded,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Choose playlists',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    height: 0.96,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pick which playlists should contribute songs.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _HeaderPill(
                      label:
                          '${selectedPlaylistIds.length} selected',
                      accent: AppColors.primary,
                    ),
                    _HeaderPill(
                      label: '${playlists.length} available',
                      accent: AppColors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Your playlists',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton(
                onPressed: playlists.isEmpty ? null : onSelectAll,
                child: const Text('Select all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (playlists.isEmpty)
            const _InlineEmptyState(
              title: 'No Spotify playlists available',
              subtitle:
                  'Connect Spotify playlists first and they will appear here for mode filtering.',
            )
          else
            SizedBox(
              height: 198,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: playlists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return SizedBox(
                    width: 152,
                    child: _SelectableJumpBackCard(
                      item: playlist,
                      isSelected: selectedPlaylistIds.contains(playlist.id),
                      onTap: () => onTogglePlaylist(playlist),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: _ActionPillButton(
              label: 'Continue To Modes',
              icon: Icons.arrow_forward_rounded,
              filled: true,
              onTap: onContinue == null ? null : () => onContinue!(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModesResultsScreen extends StatefulWidget {
  const _ModesResultsScreen({
    required this.mode,
    required this.playlists,
    required this.onBack,
    required this.onTrackStarted,
  });

  final _ModeOption mode;
  final List<TempoPlaylist> playlists;
  final Future<void> Function() onBack;
  final ValueChanged<SpotifyTrack> onTrackStarted;

  @override
  State<_ModesResultsScreen> createState() => _ModesResultsScreenState();
}

class _ModesResultsScreenState extends State<_ModesResultsScreen>
    with AutomaticKeepAliveClientMixin<_ModesResultsScreen> {
  final Map<String, _ModePreparedData> _modeCache = {};
  bool _isLaunchingTrack = false;
  bool _isPreparingMode = false;
  String? _loadingModeKey;
  double _modeLoadProgress = 0;
  int _modeLoadCompleted = 0;
  int _modeLoadTotal = 0;

  @override
  void didUpdateWidget(covariant _ModesResultsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_playlistSignature(widget.playlists) !=
        _playlistSignature(oldWidget.playlists)) {
      _modeCache.clear();
    }
  }

  String get _modeKey =>
      '${widget.mode.label}|${widget.mode.minBpm}|${widget.mode.maxBpm ?? 999}|${widget.playlists.map((playlist) => playlist.id).join(',')}';

  String _playlistSignature(List<TempoPlaylist> playlists) => playlists
      .map((playlist) => '${playlist.id}:${playlist.spotifyUri ?? ''}')
      .join('|');

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = AuthScope.watch(context);
    final mode = widget.mode;
    final candidatePlaylists = widget.playlists
        .where(
          (playlist) =>
              (playlist.spotifyUri ?? '').startsWith('spotify:playlist:'),
        )
        .toList(growable: false);
    final cachedMode = _modeCache[_modeKey];

    if (cachedMode == null &&
        candidatePlaylists.isNotEmpty &&
        (!_isPreparingMode || _loadingModeKey != _modeKey)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        unawaited(_prepareModeData(context, auth, candidatePlaylists));
      });
    }

    if (candidatePlaylists.isNotEmpty &&
        (cachedMode == null ||
            (_isPreparingMode && _loadingModeKey == _modeKey))) {
      return _ModeProgressLoadingScreen(
        title: mode.label,
        subtitle:
            'Complete the walk to unlock every playlist and track in ${mode.rangeLabel}.',
        accent: mode.accent,
        secondaryAccent: AppColors.primary,
        progress: _modeLoadProgress,
        completed: _modeLoadCompleted,
        total: _modeLoadTotal,
      );
    }

    final filteredTracks = cachedMode?.tracks ?? const <_ModeTrackEntry>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 188),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FrostedPanel(
            radius: 30,
            padding: const EdgeInsets.all(22),
            glowColor: mode.accent,
            elevated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onBack(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: AppFx.glassDecoration(
                          radius: 16,
                          glowColor: mode.accent,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.mode.label,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.mode.description,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _HeaderPill(
                      label: widget.mode.rangeLabel,
                      accent: widget.mode.accent,
                    ),
                    _HeaderPill(
                      label:
                          '${widget.playlists.length} source playlist${widget.playlists.length == 1 ? '' : 's'}',
                      accent: AppColors.primaryBright,
                    ),
                    _HeaderPill(
                      label: '${filteredTracks.length} tracks',
                      accent: AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionLabel(
            title: 'Tracks',
            trailing: 'Ordered exactly like the created playlist',
          ),
          const SizedBox(height: 12),
          if (filteredTracks.isEmpty)
            const _InlineEmptyState(
              title: 'There are no tracks in that range',
              subtitle:
                  'None of the selected playlists had Spotify tracks inside this BPM lane.',
            )
          else
            Column(
              children: [
                for (var i = 0; i < filteredTracks.length; i++) ...[
                  _ModeTrackCard(
                    track: filteredTracks[i],
                    accent: widget.mode.accent,
                    isLaunching: _isLaunchingTrack,
                    onPlay: () =>
                        _playModeTrack(filteredTracks, filteredTracks[i]),
                  ),
                  if (i != filteredTracks.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _prepareModeData(
    BuildContext context,
    SpotifyAuthController auth,
    List<TempoPlaylist> playlists,
  ) async {
    if (_isPreparingMode && _loadingModeKey == _modeKey) return;
    setState(() {
      _isPreparingMode = true;
      _loadingModeKey = _modeKey;
      _modeLoadProgress = 0;
      _modeLoadCompleted = 0;
      _modeLoadTotal = playlists.length;
    });
    try {
      for (var index = 0; index < playlists.length; index++) {
        final playlist = playlists[index];
        if (!context.mounted) return;
        await auth.ensureAllTracksLoadedForPlaylist(
          playlist.id,
          minBpm: widget.mode.minBpm,
          maxBpm: widget.mode.maxBpm ?? 999,
        );
        if (!mounted) return;
        setState(() {
          _modeLoadCompleted = index + 1;
          _modeLoadProgress = playlists.isEmpty
              ? 1
              : (index + 1) / playlists.length;
        });
      }
      final preparedData = _buildPreparedModeData(
        auth: auth,
        playlists: playlists,
      );
      if (!mounted) return;
      setState(() {
        _modeCache[_modeKey] = preparedData;
        _modeLoadProgress = 1;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingMode = false;
          _loadingModeKey = null;
        });
      }
    }
  }

  int _averageBpm(List<SpotifyTrack> tracks) {
    if (tracks.isEmpty) return widget.mode.minBpm;
    final sum = tracks.fold<int>(0, (total, track) => total + track.bpm);
    return (sum / tracks.length).round();
  }

  _ModePreparedData _buildPreparedModeData({
    required SpotifyAuthController auth,
    required List<TempoPlaylist> playlists,
  }) {
    final entries = <_ModeTrackEntry>[];
    final seenTrackKeys = <String>{};
    for (final playlist in playlists) {
      final allTracks = auth.allTracksForPlaylist(playlist.id);
      if (allTracks.isEmpty) continue;
      final playlistFullyEvaluated = !auth.hasMoreTracksForPlaylist(
        playlist.id,
      );
      if (!playlistFullyEvaluated) continue;
      final inRangeTracks = auth
          .tracksForPlaylist(playlist.id)
          .where((track) => widget.mode.matches(track.bpm))
          .toList(growable: false);
      for (final track in inRangeTracks) {
        final trackKey = _modeTrackKey(track);
        if (!seenTrackKeys.add(trackKey)) continue;
        entries.add(
          _ModeTrackEntry(
            id: track.id,
            sourcePlaylistId: playlist.id,
            playlistPosition: track.playlistPosition,
            title: track.title,
            artist: track.artistLine,
            bpm: track.bpm,
            imageAsset: track.imageUrl,
            mood: playlist.mood,
            spotifyUri: track.spotifyUri,
            durationMs: track.durationMs,
          ),
        );
      }
    }
    final orderedSpotifyTracks = entries
        .map(
          (track) => SpotifyTrack(
            id: track.id,
            title: track.title,
            artistLine: track.artist,
            imageUrl: track.imageAsset,
            spotifyUri: track.spotifyUri,
            durationMs: track.durationMs,
            bpm: track.bpm,
            playlistPosition: track.playlistPosition,
          ),
        )
        .toList(growable: false);
    return _ModePreparedData(
      tracks: entries,
      orderedSpotifyTracks: orderedSpotifyTracks,
    );
  }

  String _modeTrackKey(SpotifyTrack track) {
    final uri = track.spotifyUri.trim();
    if (uri.isNotEmpty) return uri;
    final id = track.id.trim();
    if (id.isNotEmpty) return id;
    return '${track.title.toLowerCase()}|${track.artistLine.toLowerCase()}';
  }

  Future<void> _playModeTrack(
    List<_ModeTrackEntry> filteredTracks,
    _ModeTrackEntry selectedTrack,
  ) async {
    if (_isLaunchingTrack || filteredTracks.isEmpty) return;
    setState(() => _isLaunchingTrack = true);

    try {
      final auth = AuthScope.read(context);
      final preparedData = _modeCache[_modeKey];
      final spotifyTracks =
          preparedData?.orderedSpotifyTracks ?? const <SpotifyTrack>[];
      if (spotifyTracks.isEmpty) return;

      final modePlaylist = TempoPlaylist(
        id: 'mode-${widget.mode.label}-${widget.mode.minBpm}-${widget.mode.maxBpm ?? 999}',
        title: widget.mode.label,
        subtitle: 'Tracks collected from your Spotify playlists',
        imageAsset: selectedTrack.imageAsset,
        bpm: _averageBpm(spotifyTracks),
        trackCount: spotifyTracks.length,
        durationMinutes:
            (spotifyTracks.fold<int>(
                      0,
                      (sum, track) => sum + track.durationMs,
                    ) /
                    60000)
                .round(),
        category: 'Mode',
        mood: selectedTrack.mood,
        colors: [widget.mode.accent, AppColors.primaryBright],
      );

      final sessionPlaylistUri = await auth.ensureSessionPlaylistForBpm(
        sourcePlaylist: modePlaylist,
        tracks: spotifyTracks,
        minBpm: widget.mode.minBpm,
        maxBpm: widget.mode.maxBpm ?? 999,
        generatedTitle:
            '${widget.mode.label} ${widget.mode.minBpm} - ${widget.mode.maxBpm ?? 999}bpm',
        generatedDescription:
            'Auto-generated by stempo for ${widget.mode.label} mode in the ${widget.mode.rangeLabel} lane.',
      );

      final selectedSpotifyTrack = spotifyTracks.firstWhere(
        (track) => track.spotifyUri == selectedTrack.spotifyUri,
        orElse: () => spotifyTracks.first,
      );

      bool opened = false;
      if (sessionPlaylistUri != null && sessionPlaylistUri.isNotEmpty) {
        opened = await auth.startPlaylistPlaybackAtTrack(
          playlistUri: sessionPlaylistUri,
          trackUri: selectedSpotifyTrack.spotifyUri,
        );
        if (!opened) {
          opened = await _openInAppOrRemote(sessionPlaylistUri);
        }
      } else {
        opened = await _openInAppOrRemote(selectedSpotifyTrack.spotifyUri);
      }

      if (!mounted) return;
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not start playback. Open Spotify on your phone and try again.',
            ),
          ),
        );
      } else {
        widget.onTrackStarted(selectedSpotifyTrack);
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunchingTrack = false);
      }
    }
  }

  Future<bool> _openInAppOrRemote(String spotifyUri) async {
    try {
      final remotePlayed = await SpotifyRemoteService.instance.playUri(
        spotifyUri,
      );
      if (remotePlayed) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get wantKeepAlive => true;
}

class _ModePreparedData {
  const _ModePreparedData({
    required this.tracks,
    required this.orderedSpotifyTracks,
  });

  final List<_ModeTrackEntry> tracks;
  final List<SpotifyTrack> orderedSpotifyTracks;
}

class _ModeProgressLoadingScreen extends StatelessWidget {
  const _ModeProgressLoadingScreen({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.secondaryAccent,
    required this.progress,
    required this.completed,
    required this.total,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Color secondaryAccent;
  final double progress;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);
    final percent = (safeProgress * 100).round();
    return WalkingLoadingScreen(
      title: title,
      subtitle: subtitle,
      accent: accent,
      secondaryAccent: secondaryAccent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.black.withValues(alpha: 0.26),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: AppFx.softGlow(accent, strength: 0.16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: safeProgress,
                      minHeight: 12,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Walk completion $percent%',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    total <= 0
                        ? 'Preparing your mode...'
                        : 'Checked $completed of $total playlists',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final _ModeOption mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: FrostedPanel(
        radius: 24,
        padding: const EdgeInsets.all(16),
        glowColor: mode.accent,
        elevated: true,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            mode.accent.withValues(alpha: isSelected ? 0.26 : 0.14),
            AppColors.background.withValues(alpha: 0.92),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: mode.accent.withValues(alpha: 0.18),
              ),
              child: Icon(mode.icon, color: mode.accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode.rangeLabel,
                    style: TextStyle(
                      color: mode.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    mode.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.arrow_forward_rounded
                  : Icons.chevron_right_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTrackCard extends StatelessWidget {
  const _ModeTrackCard({
    required this.track,
    required this.accent,
    required this.onPlay,
    this.isLaunching = false,
  });

  final _ModeTrackEntry track;
  final Color accent;
  final VoidCallback onPlay;
  final bool isLaunching;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 22,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          MediaCover(imageAsset: track.imageAsset, size: 58, borderRadius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${track.bpm} BPM',
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                track.mood,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isLaunching ? null : onPlay,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                isLaunching
                    ? Icons.hourglass_top_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOption {
  const _ModeOption({
    required this.label,
    required this.description,
    required this.minBpm,
    this.maxBpm,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String description;
  final int minBpm;
  final int? maxBpm;
  final IconData icon;
  final Color accent;

  String get rangeLabel =>
      maxBpm == null ? '$minBpm+ BPM' : '$minBpm-$maxBpm BPM';

  bool matches(int bpm) {
    if (bpm < minBpm) return false;
    if (maxBpm == null) return true;
    return bpm <= maxBpm!;
  }
}

class _ModeTrackEntry {
  const _ModeTrackEntry({
    required this.id,
    required this.sourcePlaylistId,
    required this.playlistPosition,
    required this.title,
    required this.artist,
    required this.bpm,
    required this.imageAsset,
    required this.mood,
    required this.spotifyUri,
    required this.durationMs,
  });

  final String id;
  final String sourcePlaylistId;
  final int playlistPosition;
  final String title;
  final String artist;
  final int bpm;
  final String imageAsset;
  final String mood;
  final String spotifyUri;
  final int durationMs;
}

const _modeOptions = [
  _ModeOption(
    label: 'Slow Walk',
    description: 'Easy stride and low-key movement for the calmest walks.',
    minBpm: 0,
    maxBpm: 99,
    icon: Icons.airline_stops_rounded,
    accent: AppColors.textMuted,
  ),
  _ModeOption(
    label: 'Normal Walk',
    description: 'Comfortable everyday walking pace with steady rhythm.',
    minBpm: 100,
    maxBpm: 115,
    icon: Icons.directions_walk_rounded,
    accent: AppColors.primaryBright,
  ),
  _ModeOption(
    label: 'Fast Walk',
    description: 'Brisk walking mode with tighter cadence and more lift.',
    minBpm: 115,
    maxBpm: 130,
    icon: Icons.hiking_rounded,
    accent: AppColors.warning,
  ),
  _ModeOption(
    label: 'Transition',
    description: 'Power walk to slow jog territory when you are ramping up.',
    minBpm: 130,
    maxBpm: 145,
    icon: Icons.speed_rounded,
    accent: AppColors.accent,
  ),
  _ModeOption(
    label: 'Running',
    description: 'Locked-in running tempo for repeatable effort and rhythm.',
    minBpm: 145,
    maxBpm: 170,
    icon: Icons.directions_run_rounded,
    accent: AppColors.primary,
  ),
  _ModeOption(
    label: 'Fast Running',
    description: 'High-output pace for intense runs and quicker turnover.',
    minBpm: 170,
    icon: Icons.bolt_rounded,
    accent: AppColors.cinemaRed,
  ),
];

class _DailyStepsHero extends StatelessWidget {
  const _DailyStepsHero({
    required this.state,
    required this.pulse,
    required this.todaySteps,
  });

  final _HomeMockState state;
  final Animation<double> pulse;
  final int todaySteps;

  @override
  Widget build(BuildContext context) {
    final progress = (todaySteps / state.goalSteps).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final progressRing = SizedBox(
      width: 150,
      height: 150,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          return CustomPaint(
            painter: _ProgressRingPainter(
              progress: progress,
              pulse: pulse.value,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'done',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    Widget stepsSummary({required bool isCompact}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily steps',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatSteps(todaySteps),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: isCompact ? 36 : 40,
                height: 0.92,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatSteps(state.goalSteps),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: isCompact ? 24 : 26,
                height: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MetricRow(
            label: 'Remaining',
            value: _formatSteps(math.max(0, state.goalSteps - todaySteps)),
            accent: AppColors.primaryBright,
          ),
          const SizedBox(height: 12),
          const _MetricRow(
            label: 'Goal',
            value: '10,000',
            accent: AppColors.accent,
          ),
        ],
      );
    }

    return FrostedPanel(
      padding: const EdgeInsets.all(24),
      radius: 32,
      glowColor: AppColors.primary,
      elevated: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 320;
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: progressRing),
                const SizedBox(height: 20),
                stepsSummary(isCompact: true),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              progressRing,
              const SizedBox(width: 20),
              Expanded(child: stepsSummary(isCompact: false)),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.trailing,
    this.onTitleTap,
  });

  final String title;
  final String trailing;
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTitleTap,
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        Text(
          trailing,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppFx.glassDecoration(
        radius: 24,
        glowColor: AppColors.accent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return Opacity(
      opacity: isEnabled ? 1 : 0.48,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: filled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryBright, AppColors.primary],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x661B2420), Color(0x44131817)],
                ),
          boxShadow: filled
              ? AppFx.softGlow(AppColors.primary, strength: 0.24)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? AppColors.background : AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: filled ? AppColors.background : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _JumpBackInRow extends StatelessWidget {
  const _JumpBackInRow({required this.items, required this.onTapPlaylist});

  final List<TempoPlaylist> items;
  final ValueChanged<TempoPlaylist> onTapPlaylist;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 198,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: 152,
            child: _JumpBackCard(item: item, onTap: () => onTapPlaylist(item)),
          );
        },
      ),
    );
  }
}

class _StartSessionCard extends StatelessWidget {
  const _StartSessionCard({
    required this.state,
    required this.userCadence,
    required this.trackBpm,
    required this.syncGap,
    required this.onGoToLibrary,
    required this.onChangeBpm,
    required this.onTrackBpm,
  });

  final _HomeMockState state;
  final int userCadence;
  final int trackBpm;
  final int syncGap;
  final VoidCallback onGoToLibrary;
  final VoidCallback onChangeBpm;
  final VoidCallback onTrackBpm;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      padding: const EdgeInsets.all(20),
      radius: 30,
      glowColor: AppColors.cinemaRed,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick actions',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.sessionPrompt,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionPillButton(
                  label: 'Go To Library',
                  icon: Icons.library_music_rounded,
                  filled: true,
                  onTap: onGoToLibrary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionPillButton(
                  label: 'Change BPM',
                  icon: Icons.tune_rounded,
                  onTap: onChangeBpm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _ActionPillButton(
              label: 'Track BPM',
              icon: Icons.directions_walk_rounded,
              onTap: onTrackBpm,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SyncStatPill(
                  label: 'Track BPM',
                  value: '$trackBpm',
                  accent: AppColors.primaryBright,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SyncStatPill(
                  label: 'Cadence',
                  value: '$userCadence',
                  accent: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SyncStatPill(
                  label: 'Gap',
                  value: '$syncGap BPM',
                  accent: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212).withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: i == selectedIndex
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 24,
                        color: i == selectedIndex
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          color: i == selectedIndex
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: i == selectedIndex
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (i != items.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _HomeMockState {
  const _HomeMockState({
    required this.stepsDone,
    required this.goalSteps,
    required this.trackTitle,
    required this.trackArtist,
    required this.trackImageAsset,
    required this.trackBpm,
    required this.sessionPrompt,
  });

  final int stepsDone;
  final int goalSteps;
  final String trackTitle;
  final String trackArtist;
  final String trackImageAsset;
  final int trackBpm;
  final String sessionPrompt;
}

class _JumpBackCard extends StatelessWidget {
  const _JumpBackCard({required this.item, required this.onTap});

  final TempoPlaylist item;
  final VoidCallback onTap;

  bool _isBpmPlaylist(String title) => isGeneratedBpmPlaylistTitle(title);

  ({int? min, int? max, int? single}) _bpmDataFromTitle(String title) {
    final rangeMatch = RegExp(
      r'(\d{2,3})\s*-\s*(\d{2,3})\s*bpm\b',
      caseSensitive: false,
    ).firstMatch(title);
    if (rangeMatch != null) {
      final min = int.tryParse(rangeMatch.group(1) ?? '');
      final max = int.tryParse(rangeMatch.group(2) ?? '');
      if (min != null && max != null) {
        return (min: min, max: max, single: null);
      }
    }

    final singleMatch = RegExp(
      r'(\d{2,3})\s*bpm\b',
      caseSensitive: false,
    ).firstMatch(title);
    final single = int.tryParse(singleMatch?.group(1) ?? '');
    return (min: null, max: null, single: single);
  }

  @override
  Widget build(BuildContext context) {
    final isBpmPlaylist = _isBpmPlaylist(item.title);
    final bpmData = _bpmDataFromTitle(item.title);
    final bpmBannerText = bpmData.min != null && bpmData.max != null
        ? '${((bpmData.min! + bpmData.max!) / 2).round()}'
        : bpmData.single?.toString();
    final bpmFooterText = bpmData.min != null && bpmData.max != null
        ? '${bpmData.min}-${bpmData.max} BPM'
        : bpmData.single != null
        ? '${bpmData.single} BPM'
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: FrostedPanel(
        radius: 24,
        padding: const EdgeInsets.all(12),
        glowColor: item.colors.last,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaCover(
              imageAsset: item.imageAsset,
              size: 72,
              borderRadius: 20,
              child: Stack(
                children: [
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 44,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  if (isBpmPlaylist && bpmBannerText != null)
                    Positioned(
                      left: 10,
                      bottom: 8,
                      child: Text(
                        bpmBannerText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 62,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isBpmPlaylist && bpmFooterText != null)
                    Text(
                      bpmFooterText,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableJumpBackCard extends StatelessWidget {
  const _SelectableJumpBackCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final TempoPlaylist item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _JumpBackCard(item: item, onTap: onTap),
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primaryBright
                    : Colors.black.withValues(alpha: 0.42),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.24),
                ),
                boxShadow: isSelected
                    ? AppFx.softGlow(AppColors.primary, strength: 0.2)
                    : null,
              ),
              child: Icon(
                isSelected
                    ? Icons.check_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: isSelected ? Colors.black : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncStatPill extends StatelessWidget {
  const _SyncStatPill({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x592A3530), Color(0x33202422)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({required this.progress, required this.pulse});

  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final safeProgress = progress.clamp(0.0, 1.0);
    final strokeWidth = size.width * 0.12;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweepAngle = math.pi * 2 * safeProgress;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.08);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + (pulse * 3)
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..color = AppColors.primary.withValues(alpha: 0.18);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primaryBright;

    canvas.drawCircle(center, radius, basePaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pulse != pulse;
  }
}

class _StepBpmTrackingOverlay extends StatelessWidget {
  const _StepBpmTrackingOverlay({
    required this.steps,
    required this.secondsRemaining,
    required this.progress,
    required this.pulse,
    required this.onClose,
  });

  final int steps;
  final int secondsRemaining;
  final double progress;
  final Animation<double> pulse;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xEE09100D),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            children: [
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textPrimary,
                    ),
                    tooltip: 'Exit tracking',
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Tracking BPM',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Walk naturally for 20 seconds. We will use your steps to set your target BPM automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: pulse,
                builder: (context, _) {
                  return SizedBox(
                    width: 220,
                    height: 220,
                    child: CustomPaint(
                      painter: _ProgressRingPainter(
                        progress: progress,
                        pulse: pulse.value,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$secondsRemaining',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 52,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'seconds left',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              Text(
                '$steps',
                style: const TextStyle(
                  color: AppColors.primaryBright,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'steps counted',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatSteps(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}
