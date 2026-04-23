import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controllers/auth_controller.dart';
import '../controllers/spotify_remote_service.dart';
import '../services/step_service.dart';
import '../state/auth_providers.dart';
import '../state/mock_playlists.dart';
import '../state/playlist_models.dart';
import '../ui/theme/app_fx.dart';
import '../ui/theme/colors.dart';
import '../ui/widgets/loader.dart';
import '../ui/widgets/media_cover.dart';
import '../ui/widgets/now_playing_bar.dart';
import 'library_page.dart';
import 'now_playing_page.dart';
import 'playlist_page.dart';
import 'search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialTab = 0});

  final int initialTab;

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
  int? _initialPedometerCount;
  int _liveAddedSteps = 0;

  int _syncGap(int userCadence) {
    final trackBpm = _currentTrackBpm ?? _mockState.trackBpm;
    return (trackBpm - userCadence).abs();
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

  StreamSubscription<SpotifyRemotePlayerState>? _playerSubscription;
  SpotifyRemotePlayerState? _playerState;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, _tabs.length - 1);
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
        if (_initialPedometerCount == null) {
          _initialPedometerCount = event.steps;
          debugPrint('PEDOMETER INITIALIZED: $_initialPedometerCount');
          return;
        }
        setState(() {
          _liveAddedSteps = event.steps - _initialPedometerCount!;
          debugPrint('PEDOMETER LIVE ADDED: $_liveAddedSteps');
        });
      },
      onError: (error) {
        debugPrint('PEDOMETER ERROR: $error');
      },
    );
  }

  @override
  void dispose() {
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
          // Reset live tracking offset so we don't double count
          _initialPedometerCount = null;
          _liveAddedSteps = 0;
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

    return Scaffold(
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
                            initialTrackArtist: _playerState?.artistName ?? '',
                            initialTrackImageAsset:
                                _playerState?.resolvedImageUrl ?? '',
                            initialTrackBpm:
                                _currentTrackBpm ?? _mockState.trackBpm,
                            userCadence: auth.userCadence,
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
          todaySteps: _todaySteps + _liveAddedSteps,
          trackBpm: _currentTrackBpm ?? _mockState.trackBpm,
          syncGap: _syncGap(auth.userCadence),
          recentPlaylists: playlists,
          onGoToLibrary: _goToLibraryTab,
          onChangeBpm: _openBpmPicker,
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
          catalogEntries: auth.searchEntries
              .map(SearchCatalogEntry.fromSpotify)
              .toList(growable: false),
          onOpenPlaylist: (playlist) =>
              _openPlaylist(playlist, sourceTab: PlaylistSourceTab.modes),
        );
      default:
        return _HomeTabView(
          key: const ValueKey('home'),
          state: _mockState,
          pulse: _pulseController,
          userCadence: auth.userCadence,
          todaySteps: _todaySteps + _liveAddedSteps,
          trackBpm: _currentTrackBpm ?? _mockState.trackBpm,
          syncGap: _syncGap(auth.userCadence),
          recentPlaylists: playlists,
          onGoToLibrary: _goToLibraryTab,
          onChangeBpm: _openBpmPicker,
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
  final ValueChanged<TempoPlaylist> onOpenPlaylist;
  final VoidCallback onRefreshPlaylists;

  bool _isBpmSpecificPlaylist(TempoPlaylist playlist) {
    return playlist.title.toLowerCase().contains('bpm');
  }

  @override
  Widget build(BuildContext context) {
    final regularRecents = recentPlaylists
        .where((playlist) => !_isBpmSpecificPlaylist(playlist))
        .toList(growable: false);
    final bpmRecents = recentPlaylists
        .where(_isBpmSpecificPlaylist)
        .toList(growable: false);

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
    required this.catalogEntries,
    required this.onOpenPlaylist,
  });

  final List<TempoPlaylist> playlists;
  final List<SearchCatalogEntry> catalogEntries;
  final ValueChanged<TempoPlaylist> onOpenPlaylist;

  @override
  State<_ModesTabView> createState() => _ModesTabViewState();
}

class _ModesTabViewState extends State<_ModesTabView> {
  late final PageController _pageController;
  _ModeOption _selectedMode = _modeOptions[1];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _chooseMode(_ModeOption mode) async {
    setState(() => _selectedMode = mode);
    await _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  Future<void> _backToChooser() {
    return _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _ModesChooserScreen(
              selectedMode: _selectedMode,
              onChooseMode: _chooseMode,
            ),
            _ModesResultsScreen(
              mode: _selectedMode,
              playlists: widget.playlists,
              catalogEntries: widget.catalogEntries,
              onBack: _backToChooser,
              onOpenPlaylist: widget.onOpenPlaylist,
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 152,
          child: Center(
            child: FrostedPanel(
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              glowColor: AppColors.primary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 2; i++) ...[
                    AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, _) {
                        final page = _pageController.hasClients
                            ? (_pageController.page ??
                                  _pageController.initialPage.toDouble())
                            : 0.0;
                        final isActive = (page.round() == i);
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
                    if (i != 1) const SizedBox(width: 8),
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
    required this.onChooseMode,
  });

  final _ModeOption selectedMode;
  final ValueChanged<_ModeOption> onChooseMode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 188),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FrostedPanel(
            radius: 34,
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
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
                  width: 68,
                  height: 68,
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
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Modes',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 34,
                    height: 0.96,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose how you are moving right now and we will only show playlists and tracks inside that BPM lane.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
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
          const SizedBox(height: 18),
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

class _ModesResultsScreen extends StatelessWidget {
  const _ModesResultsScreen({
    required this.mode,
    required this.playlists,
    required this.catalogEntries,
    required this.onBack,
    required this.onOpenPlaylist,
  });

  final _ModeOption mode;
  final List<TempoPlaylist> playlists;
  final List<SearchCatalogEntry> catalogEntries;
  final Future<void> Function() onBack;
  final ValueChanged<TempoPlaylist> onOpenPlaylist;

  List<TempoPlaylist> get _filteredPlaylists => playlists
      .where((playlist) => mode.matches(playlist.bpm))
      .toList(growable: false);

  List<_ModeTrackEntry> get _filteredTracks {
    final liveTracks = catalogEntries
        .where((entry) => entry.type == SearchResultType.track)
        .where((entry) => entry.bpm != null && mode.matches(entry.bpm!))
        .map(
          (entry) => _ModeTrackEntry(
            title: entry.title,
            artist: entry.subtitle,
            bpm: entry.bpm ?? 0,
            imageAsset: entry.imageUrl,
            mood: entry.mood,
          ),
        )
        .toList(growable: false);
    if (liveTracks.isNotEmpty) return liveTracks;
    return _fallbackModeTracks
        .where((track) => mode.matches(track.bpm))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlaylists = _filteredPlaylists;
    final filteredTracks = _filteredTracks;

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
                      onTap: () => onBack(),
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
                            mode.label,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mode.description,
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
                    _HeaderPill(label: mode.rangeLabel, accent: mode.accent),
                    _HeaderPill(
                      label: '${filteredPlaylists.length} playlists',
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
            title: 'Playlists',
            trailing: 'Filtered for ${mode.rangeLabel}',
          ),
          const SizedBox(height: 12),
          if (filteredPlaylists.isEmpty)
            const _InlineEmptyState(
              title: 'No playlists in this mode yet',
              subtitle: 'Try another mode or connect more Spotify playlists.',
            )
          else
            Column(
              children: [
                for (var i = 0; i < filteredPlaylists.length; i++) ...[
                  _ModePlaylistCard(
                    playlist: filteredPlaylists[i],
                    mode: mode,
                    onTap: () => onOpenPlaylist(filteredPlaylists[i]),
                  ),
                  if (i != filteredPlaylists.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
            ),
          const SizedBox(height: 18),
          _SectionLabel(title: 'Tracks', trailing: 'Inside the same BPM lane'),
          const SizedBox(height: 12),
          if (filteredTracks.isEmpty)
            const _InlineEmptyState(
              title: 'No track previews here yet',
              subtitle:
                  'Load more playlists and this mode will fill in with songs too.',
            )
          else
            Column(
              children: [
                for (var i = 0; i < filteredTracks.length; i++) ...[
                  _ModeTrackCard(track: filteredTracks[i], accent: mode.accent),
                  if (i != filteredTracks.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
        ],
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
        radius: 28,
        padding: const EdgeInsets.all(18),
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
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: mode.accent.withValues(alpha: 0.18),
              ),
              child: Icon(mode.icon, color: mode.accent, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.rangeLabel,
                    style: TextStyle(
                      color: mode.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mode.description,
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
            const SizedBox(width: 12),
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

class _ModePlaylistCard extends StatelessWidget {
  const _ModePlaylistCard({
    required this.playlist,
    required this.mode,
    required this.onTap,
  });

  final TempoPlaylist playlist;
  final _ModeOption mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: FrostedPanel(
        radius: 24,
        padding: const EdgeInsets.all(14),
        glowColor: mode.accent,
        child: Row(
          children: [
            MediaCover(
              imageAsset: playlist.imageAsset,
              size: 72,
              borderRadius: 18,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    playlist.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeaderPill(
                        label: '${playlist.bpm} BPM',
                        accent: mode.accent,
                      ),
                      _HeaderPill(
                        label: '${playlist.trackCount} tracks',
                        accent: AppColors.primaryBright,
                      ),
                    ],
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

class _ModeTrackCard extends StatelessWidget {
  const _ModeTrackCard({required this.track, required this.accent});

  final _ModeTrackEntry track;
  final Color accent;

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
    required this.title,
    required this.artist,
    required this.bpm,
    required this.imageAsset,
    required this.mood,
  });

  final String title;
  final String artist;
  final int bpm;
  final String imageAsset;
  final String mood;
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

const _fallbackModeTracks = [
  _ModeTrackEntry(
    title: 'Northern Avenue',
    artist: 'Marlow Fade',
    bpm: 96,
    imageAsset: 'assets/images/musicCover6.webp',
    mood: 'Calm',
  ),
  _ModeTrackEntry(
    title: 'Ocean Drive',
    artist: 'Duke Dumont',
    bpm: 112,
    imageAsset: 'assets/images/musicCover5.webp',
    mood: 'Euphoric',
  ),
  _ModeTrackEntry(
    title: 'Afterlight Steps',
    artist: 'Luma Cove',
    bpm: 118,
    imageAsset: 'assets/images/musicCover8.webp',
    mood: 'Focused',
  ),
  _ModeTrackEntry(
    title: 'Push Forward',
    artist: 'Vector Bloom',
    bpm: 128,
    imageAsset: 'assets/images/musicCover2.webp',
    mood: 'Driven',
  ),
  _ModeTrackEntry(
    title: 'Momentum Line',
    artist: 'Night Shift',
    bpm: 138,
    imageAsset: 'assets/images/musicCover7.webp',
    mood: 'Driven',
  ),
  _ModeTrackEntry(
    title: 'Seven Nation Army',
    artist: 'The White Stripes',
    bpm: 154,
    imageAsset: 'assets/images/musicCover3.webp',
    mood: 'Dark',
  ),
  _ModeTrackEntry(
    title: 'Runaway Pulse',
    artist: 'Neon Harbor',
    bpm: 176,
    imageAsset: 'assets/images/musicCover4.webp',
    mood: 'Euphoric',
  ),
];

class _StatsTabView extends StatefulWidget {
  const _StatsTabView({required this.snapshot});

  final _StatsSnapshot snapshot;

  @override
  State<_StatsTabView> createState() => _StatsTabViewState();
}

class _StatsTabViewState extends State<_StatsTabView> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int index) {
    return _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _pageIndex = index),
          children: [
            _StatsIntroScreen(
              snapshot: widget.snapshot,
              isActive: _pageIndex == 0,
              onNext: () => _goToPage(1),
            ),
            _StatsFeatureScreen(
              snapshot: widget.snapshot,
              isActive: _pageIndex == 1,
              title: 'Your pace has a signature',
              eyebrow: 'Average BPM',
              value: '${widget.snapshot.averageBpm}',
              suffix: 'BPM',
              accent: AppColors.primaryBright,
              secondaryAccent: AppColors.primary,
              chartValues: widget.snapshot.weeklyBpmTrend,
              chartLabels: const ['W1', 'W2', 'W3', 'W4'],
              onNext: () => _goToPage(2),
            ),
            _StatsSplitStoryScreen(
              snapshot: widget.snapshot,
              isActive: _pageIndex == 2,
              onNext: () => _goToPage(3),
            ),
            _StatsSummaryScreen(snapshot: widget.snapshot),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 152,
          child: IgnorePointer(
            ignoring: _pageIndex == 3,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _pageIndex == 3 ? 0 : 1,
              child: Center(child: _StatsPagerDots(activeIndex: _pageIndex)),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsSummaryScreen extends StatelessWidget {
  const _StatsSummaryScreen({required this.snapshot});

  final _StatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 172),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatsHeader(snapshot: snapshot),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatsHeroCard(
                    eyebrow: 'Average BPM',
                    value: '${snapshot.averageBpm}',
                    suffix: 'BPM',
                    insight: snapshot.averageBpmInsight,
                    accent: AppColors.primaryBright,
                    secondaryAccent: AppColors.primary,
                    chartValues: snapshot.weeklyBpmTrend,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatsHeroCard(
                    eyebrow: 'Favorite range',
                    value: snapshot.favoriteRangeLabel,
                    insight: snapshot.favoriteRangeInsight,
                    accent: AppColors.cinemaRed,
                    secondaryAccent: AppColors.cinemaRed,
                    chartValues: snapshot.bpmZoneShares,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatsMiniCard(
                    label: 'Sync quality',
                    value: '${snapshot.syncScore}%',
                    caption: snapshot.syncInsight,
                    accent: AppColors.primary,
                    icon: Icons.graphic_eq_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatsMiniCard(
                    label: 'Top playlist',
                    value: snapshot.topPlaylistTitle,
                    caption: snapshot.topPlaylistInsight,
                    accent: AppColors.accent,
                    icon: Icons.library_music_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatsMiniCard(
                    label: 'Most-played mood',
                    value: snapshot.topMood,
                    caption: snapshot.moodInsight,
                    accent: AppColors.warning,
                    icon: Icons.favorite_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatsMiniCard(
                    label: 'Avg session',
                    value: '${snapshot.averageSessionMinutes} min',
                    caption: snapshot.sessionInsight,
                    accent: AppColors.primaryBright,
                    icon: Icons.timer_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _SectionLabel(title: 'Momentum', trailing: 'Last 30 days'),
            const SizedBox(height: 12),
            _StatsTrendCard(snapshot: snapshot),
            const SizedBox(height: 12),
            _StatsDonutCard(snapshot: snapshot, height: 228, compact: false),
            const SizedBox(height: 18),
            const _SectionLabel(
              title: 'Interesting facts',
              trailing: 'For you',
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.88,
              children: [
                for (final fact in snapshot.facts)
                  _StatsFactCard(
                    title: fact.title,
                    value: fact.value,
                    caption: fact.caption,
                    accent: fact.accent,
                    icon: fact.icon,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.snapshot});

  final _StatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      padding: const EdgeInsets.all(22),
      radius: 30,
      glowColor: AppColors.primary,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stats',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your month in motion',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderStatChip(
                label: snapshot.hasStepPermission ? 'Today steps' : 'Sync',
                value: snapshot.hasStepPermission
                    ? _formatSteps(snapshot.todaySteps)
                    : '${snapshot.syncScore}%',
                accent: AppColors.primaryBright,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderPill(
                label: snapshot.favoriteRangeLabel,
                accent: AppColors.primaryBright,
              ),
              _HeaderPill(
                label: snapshot.topPlaylistTitle,
                accent: AppColors.accent,
              ),
              _HeaderPill(
                label: '${snapshot.walkShare}% walk',
                accent: AppColors.cinemaRed,
              ),
              _HeaderPill(
                label: snapshot.hasStepPermission
                    ? '${((snapshot.todaySteps / snapshot.goalSteps) * 100).round().clamp(0, 100)}% goal'
                    : 'Health Connect',
                accent: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsIntroScreen extends StatelessWidget {
  const _StatsIntroScreen({
    required this.snapshot,
    required this.isActive,
    required this.onNext,
  });
  final _StatsSnapshot snapshot;
  final bool isActive;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: isActive ? 1 : 0.96,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 188),
        child: FrostedPanel(
          radius: 34,
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          elevated: true,
          glowColor: AppColors.primary,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xB814221B), Color(0x8A111413), Color(0xCC080A09)],
          ),
          child: Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 102,
                height: 102,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryBright.withValues(alpha: 0.72),
                      AppColors.primary.withValues(alpha: 0.24),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background.withValues(alpha: 0.76),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      size: 30,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'Your month in motion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 36,
                  height: 0.96,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${snapshot.averageBpm} BPM average | ${snapshot.syncScore}% sync | ${snapshot.topPlaylistTitle}',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _HeaderPill(
                    label: snapshot.favoriteRangeLabel,
                    accent: AppColors.primaryBright,
                  ),
                  _HeaderPill(
                    label:
                        '${snapshot.walkShare}% walk / ${snapshot.runShare}% run',
                    accent: AppColors.cinemaRed,
                  ),
                ],
              ),
              const Spacer(),
              _StoryCtaButton(
                label: 'Start exploring',
                icon: Icons.arrow_forward_rounded,
                onTap: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsFeatureScreen extends StatelessWidget {
  const _StatsFeatureScreen({
    required this.snapshot,
    required this.isActive,
    required this.title,
    required this.eyebrow,
    required this.value,
    required this.suffix,
    required this.accent,
    required this.secondaryAccent,
    required this.chartValues,
    required this.chartLabels,
    required this.onNext,
  });
  final _StatsSnapshot snapshot;
  final bool isActive;
  final String title;
  final String eyebrow;
  final String value;
  final String suffix;
  final Color accent;
  final Color secondaryAccent;
  final List<int> chartValues;
  final List<String> chartLabels;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    final maxValue = chartValues.reduce(math.max).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 188),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FrostedPanel(
              radius: 36,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              elevated: true,
              glowColor: accent,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.44),
                  secondaryAccent.withValues(alpha: 0.22),
                  AppColors.background.withValues(alpha: 0.92),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      height: 0.96,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: isActive ? 1 : 0),
                    duration: const Duration(milliseconds: 1450),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, _) {
                      return SizedBox(
                        height: 124,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < chartValues.length; i++) ...[
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${chartValues[i]}',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          width: double.infinity,
                                          height:
                                              (((chartValues[i] / maxValue) *
                                                      92)
                                                  .clamp(26, 92) *
                                              progress),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            color: accent,
                                            boxShadow: AppFx.softGlow(
                                              accent,
                                              strength: 0.16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      chartLabels[i],
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (i != chartValues.length - 1)
                                const SizedBox(width: 12),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 46,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: ' $suffix',
                          style: TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.averageBpmInsight,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _StoryCtaButton(
            label: 'Keep discovering',
            icon: Icons.keyboard_double_arrow_down_rounded,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _StatsSplitStoryScreen extends StatelessWidget {
  const _StatsSplitStoryScreen({
    required this.snapshot,
    required this.isActive,
    required this.onNext,
  });
  final _StatsSnapshot snapshot;
  final bool isActive;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    final total = math.max(1, snapshot.walkShare + snapshot.runShare);
    final walkRatio = snapshot.walkShare / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 188),
      child: Column(
        children: [
          Expanded(
            child: FrostedPanel(
              radius: 36,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              elevated: true,
              glowColor: AppColors.cinemaRed,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x99111714), Color(0xCC090A0A)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Session split',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'How your month was built',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      height: 0.96,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: isActive ? walkRatio : 0),
                    duration: const Duration(milliseconds: 1350),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, _) {
                      return Center(
                        child: SizedBox(
                          width: 190,
                          height: 190,
                          child: CustomPaint(
                            painter: _StatsRingPainter(
                              progress: progress,
                              primary: AppColors.primaryBright,
                              secondary: AppColors.cinemaRed,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${snapshot.walkShare}% / ${snapshot.runShare}%',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 26,
                                      height: 1,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'walk / run',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _StatsSplitFeature(
                          label: 'Walk',
                          value: '${snapshot.walkShare}%',
                          accent: AppColors.primaryBright,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatsSplitFeature(
                          label: 'Run',
                          value: '${snapshot.runShare}%',
                          accent: AppColors.cinemaRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _StoryCtaButton(
            label: 'Open full summary',
            icon: Icons.auto_graph_rounded,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _StatsPagerDots extends StatelessWidget {
  const _StatsPagerDots({required this.activeIndex});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      glowColor: AppColors.primary,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: i == activeIndex ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: i == activeIndex
                    ? AppColors.primaryBright
                    : Colors.white.withValues(alpha: 0.22),
              ),
            ),
            if (i != 2) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _StoryCtaButton extends StatelessWidget {
  const _StoryCtaButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xCC1ED760), Color(0x66FF5A5F)],
          ),
          boxShadow: AppFx.softGlow(AppColors.primary, strength: 0.16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: AppColors.textPrimary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _StatsSplitFeature extends StatelessWidget {
  const _StatsSplitFeature({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsHeroCard extends StatelessWidget {
  const _StatsHeroCard({
    required this.eyebrow,
    required this.value,
    required this.insight,
    required this.accent,
    required this.secondaryAccent,
    required this.chartValues,
    this.suffix,
  });

  final String eyebrow;
  final String value;
  final String? suffix;
  final String insight;
  final Color accent;
  final Color secondaryAccent;
  final List<int> chartValues;

  @override
  Widget build(BuildContext context) {
    final maxValue = chartValues.isEmpty
        ? 1
        : chartValues.reduce(math.max).toDouble();

    return FrostedPanel(
      padding: const EdgeInsets.all(18),
      radius: 26,
      glowColor: accent,
      elevated: true,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.42),
          secondaryAccent.withValues(alpha: 0.22),
          AppColors.background.withValues(alpha: 0.82),
        ],
      ),
      child: SizedBox(
        height: 176,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 46,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < chartValues.length; i++) ...[
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: ((chartValues[i] / maxValue) * 44).clamp(
                            10,
                            44,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                accent.withValues(alpha: 0.95),
                                secondaryAccent.withValues(alpha: 0.5),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (i != chartValues.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (suffix != null)
                    TextSpan(
                      text: ' $suffix',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              insight,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsMiniCard extends StatelessWidget {
  const _StatsMiniCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      padding: const EdgeInsets.all(16),
      radius: 24,
      glowColor: accent,
      child: SizedBox(
        height: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsTrendCard extends StatelessWidget {
  const _StatsTrendCard({required this.snapshot});

  final _StatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final maxWeek = snapshot.weeklyBpmTrend.reduce(math.max).toDouble();
    final maxZone = snapshot.bpmZoneShares.reduce(math.max).toDouble();

    return FrostedPanel(
      padding: const EdgeInsets.all(20),
      radius: 28,
      glowColor: AppColors.primary,
      elevated: true,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xAA11231A), Color(0xCC0A0C0B)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'BPM trend',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                snapshot.favoriteRangeLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < snapshot.weeklyBpmTrend.length; i++) ...[
                Expanded(
                  child: _VerticalTrendBar(
                    label: 'W${i + 1}',
                    value: snapshot.weeklyBpmTrend[i],
                    maxValue: maxWeek,
                    accent: i == snapshot.weeklyBpmTrend.length - 1
                        ? AppColors.primaryBright
                        : AppColors.primary,
                  ),
                ),
                if (i != snapshot.weeklyBpmTrend.length - 1)
                  const SizedBox(width: 14),
              ],
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Zones',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < snapshot.bpmZoneLabels.length; i++) ...[
            _HorizontalShareBar(
              label: snapshot.bpmZoneLabels[i],
              value: snapshot.bpmZoneShares[i],
              maxValue: maxZone,
              accent: i == 1 ? AppColors.primaryBright : AppColors.cinemaRed,
            ),
            if (i != snapshot.bpmZoneLabels.length - 1)
              const SizedBox(height: 10),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatsSplitChip(
                  label: 'Walk sessions',
                  value: '${snapshot.walkShare}%',
                  accent: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatsSplitChip(
                  label: 'Run sessions',
                  value: '${snapshot.runShare}%',
                  accent: AppColors.cinemaRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsDonutCard extends StatelessWidget {
  const _StatsDonutCard({
    required this.snapshot,
    this.height = 276,
    this.compact = true,
  });

  final _StatsSnapshot snapshot;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, snapshot.walkShare + snapshot.runShare);
    final walkRatio = snapshot.walkShare / total;

    return FrostedPanel(
      radius: 28,
      padding: const EdgeInsets.all(16),
      glowColor: AppColors.cinemaRed,
      elevated: true,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x99111514), Color(0xCC090A0A)],
      ),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session split',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: compact ? 128 : 156,
                  height: compact ? 128 : 156,
                  child: CustomPaint(
                    painter: _StatsRingPainter(
                      progress: walkRatio,
                      primary: AppColors.primaryBright,
                      secondary: AppColors.cinemaRed,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${snapshot.walkShare}/${snapshot.runShare}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'walk / run',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatsLegendRow(
                    label: 'Walk',
                    value: '${snapshot.walkShare}%',
                    accent: AppColors.primaryBright,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatsLegendRow(
                    label: 'Run',
                    value: '${snapshot.runShare}%',
                    accent: AppColors.cinemaRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsLegendRow extends StatelessWidget {
  const _StatsLegendRow({
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
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _VerticalTrendBar extends StatelessWidget {
  const _VerticalTrendBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.accent,
  });

  final String label;
  final int value;
  final double maxValue;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.22, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 84,
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: ratio,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: 0.92),
                    accent.withValues(alpha: 0.38),
                  ],
                ),
                boxShadow: AppFx.softGlow(accent, strength: 0.16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HorizontalShareBar extends StatelessWidget {
  const _HorizontalShareBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.accent,
  });

  final String label;
  final int value;
  final double maxValue;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.08, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 12,
              color: Colors.white.withValues(alpha: 0.06),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [accent, accent.withValues(alpha: 0.36)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatsSplitChip extends StatelessWidget {
  const _StatsSplitChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x592A3530), Color(0x33202422)],
        ),
      ),
      child: Row(
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
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsFactCard extends StatelessWidget {
  const _StatsFactCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final String caption;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      padding: const EdgeInsets.all(16),
      radius: 24,
      glowColor: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const Spacer(),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: accent.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

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

class _StartSessionCard extends StatelessWidget {
  const _StartSessionCard({
    required this.state,
    required this.userCadence,
    required this.trackBpm,
    required this.syncGap,
    required this.onGoToLibrary,
    required this.onChangeBpm,
  });

  final _HomeMockState state;
  final int userCadence;
  final int trackBpm;
  final int syncGap;
  final VoidCallback onGoToLibrary;
  final VoidCallback onChangeBpm;

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

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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

class _JumpBackCard extends StatelessWidget {
  const _JumpBackCard({required this.item, required this.onTap});

  final TempoPlaylist item;
  final VoidCallback onTap;

  bool _isBpmPlaylist(String title) => title.toLowerCase().contains('bpm');

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
                  Text(
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
                  if (isBpmPlaylist && bpmFooterText != null) ...[
                    const Spacer(),
                    Text(
                      bpmFooterText,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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

class _NowPlayingBar extends StatefulWidget {
  const _NowPlayingBar({
    required this.trackTitle,
    required this.trackArtist,
    required this.trackImageAsset,
    required this.accentColor,
    required this.bgColor,
    required this.trackBpm,
    required this.userCadence,
  });

  final String trackTitle;
  final String trackArtist;
  final String trackImageAsset;
  final Color accentColor;
  final Color bgColor;
  final int trackBpm;
  final int userCadence;

  @override
  State<_NowPlayingBar> createState() => _NowPlayingBarState();
}

class _NowPlayingBarState extends State<_NowPlayingBar> {
  final SpotifyRemoteService _remote = SpotifyRemoteService.instance;
  StreamSubscription<SpotifyRemotePlayerState>? _playerSub;
  bool _isPaused = true;
  String? _actualTitle;
  String? _actualArtist;
  String? _actualImage;

  void _setStateSafely(VoidCallback updater) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(updater);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(updater);
    });
  }

  @override
  void initState() {
    super.initState();
    _bindRemote();
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    super.dispose();
  }

  Future<void> _bindRemote() async {
    _playerSub = _remote.playerStateStream().listen((state) {
      if (!mounted) return;
      _setStateSafely(() {
        _isPaused = state.isPaused;
        if (state.trackUri.isEmpty || state.trackName.isEmpty) {
          _actualTitle = null;
          _actualArtist = null;
          _actualImage = null;
          return;
        }
        _actualTitle = state.trackName;
        _actualArtist = state.artistName;
        _actualImage = state.resolvedImageUrl;
      });
    });

    try {
      final playerState = await _remote.getPlayerState();
      if (!mounted || playerState == null) return;
      _setStateSafely(() {
        _isPaused = playerState.isPaused;
        if (playerState.trackUri.isEmpty || playerState.trackName.isEmpty) {
          _actualTitle = null;
          _actualArtist = null;
          _actualImage = null;
          return;
        }
        _actualTitle = playerState.trackName;
        _actualArtist = playerState.artistName;
        _actualImage = playerState.resolvedImageUrl;
      });
    } catch (_) {}
  }

  Future<void> _togglePlayback() async {
    final wasPaused = _isPaused;
    setState(() => _isPaused = !wasPaused);
    try {
      if (wasPaused) {
        await _remote.resume();
      } else {
        await _remote.pause();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPaused = wasPaused);
    }
  }

  void _navigateToNowPlaying() {
    final title = _actualTitle ?? widget.trackTitle;
    if (title.isEmpty) return;
    context.push(
      '/now-playing',
      extra: NowPlayingPageArgs(
        trackTitle: title,
        trackArtist: _actualArtist ?? widget.trackArtist,
        trackImageAsset: _actualImage ?? widget.trackImageAsset,
        trackBpm: widget.trackBpm,
        userCadence: widget.userCadence,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _actualTitle ?? widget.trackTitle;
    if (title.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _navigateToNowPlaying,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: AppFx.glassDecoration(
          radius: 12,
          elevated: true,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [widget.bgColor, widget.bgColor.withValues(alpha: 0.8)],
          ),
          glowColor: widget.accentColor.withValues(alpha: 0.18),
        ),
        child: Row(
          children: [
            MediaCover(
              imageAsset: _actualImage ?? widget.trackImageAsset,
              size: 42,
              borderRadius: 10,
              child: _isPaused
                  ? const SizedBox.shrink()
                  : const Center(
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _actualArtist ?? widget.trackArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _TrackPaceBadge(
              trackBpm: widget.trackBpm,
              userCadence: widget.userCadence,
              accent: widget.accentColor,
            ),
            const SizedBox(width: 12),
            // Play/Pause toggle button
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayback,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  boxShadow: AppFx.softGlow(AppColors.primary, strength: 0.35),
                ),
                child: Icon(
                  _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: AppColors.background,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackPaceBadge extends StatelessWidget {
  const _TrackPaceBadge({
    required this.trackBpm,
    required this.userCadence,
    required this.accent,
  });

  final int trackBpm;
  final int userCadence;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (trackBpm <= 0) return const SizedBox.shrink();

    final diff = (trackBpm - userCadence).abs();
    final bool isMet = diff <= 2;
    final color = isMet ? AppColors.primaryBright : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$trackBpm',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'BPM',
            style: TextStyle(
              color: color.withValues(alpha: 0.6),
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
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

class _StatsSnapshot {
  const _StatsSnapshot({
    required this.todaySteps,
    required this.goalSteps,
    required this.hasStepPermission,
    required this.averageBpm,
    required this.favoriteRangeLabel,
    required this.averageBpmInsight,
    required this.favoriteRangeInsight,
    required this.syncScore,
    required this.syncInsight,
    required this.topPlaylistTitle,
    required this.topPlaylistInsight,
    required this.topMood,
    required this.moodInsight,
    required this.averageSessionMinutes,
    required this.sessionInsight,
    required this.walkShare,
    required this.runShare,
    required this.weeklyBpmTrend,
    required this.bpmZoneLabels,
    required this.bpmZoneShares,
    required this.summary,
    required this.facts,
  });

  final int todaySteps;
  final int goalSteps;
  final bool hasStepPermission;
  final int averageBpm;
  final String favoriteRangeLabel;
  final String averageBpmInsight;
  final String favoriteRangeInsight;
  final int syncScore;
  final String syncInsight;
  final String topPlaylistTitle;
  final String topPlaylistInsight;
  final String topMood;
  final String moodInsight;
  final int averageSessionMinutes;
  final String sessionInsight;
  final int walkShare;
  final int runShare;
  final List<int> weeklyBpmTrend;
  final List<String> bpmZoneLabels;
  final List<int> bpmZoneShares;
  final String summary;
  final List<_StatsFact> facts;
}

class _StatsFact {
  const _StatsFact({
    required this.title,
    required this.value,
    required this.caption,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final String caption;
  final Color accent;
  final IconData icon;
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

// ignore: unused_element
_StatsSnapshot _buildStatsSnapshot({
  required List<TempoPlaylist> playlists,
  required int userCadence,
  required int todaySteps,
  required int goalSteps,
  required bool hasStepPermission,
}) {
  final recent = playlists
      .where((playlist) => playlist.wasRecentlyPlayed)
      .toList();
  final source = recent.isEmpty ? playlists : recent;

  final averageBpm =
      (source.fold<int>(0, (sum, playlist) => sum + playlist.bpm) /
              source.length)
          .round();
  final favoriteStart = ((averageBpm - 4) ~/ 2) * 2;
  final favoriteEnd = favoriteStart + 8;
  final averageDuration =
      (source.fold<int>(0, (sum, playlist) => sum + playlist.durationMinutes) /
              source.length)
          .round();
  final syncScoreRaw =
      (source
                  .map(
                    (playlist) =>
                        100 - ((playlist.bpm - userCadence).abs() * 6),
                  )
                  .reduce((a, b) => a + b) /
              source.length)
          .round();
  final syncScore = syncScoreRaw.clamp(52, 98);

  final topPlaylist = source.reduce((a, b) {
    final aScore =
        (a.trackCount * 2) + a.durationMinutes + (a.isPinned ? 12 : 0);
    final bScore =
        (b.trackCount * 2) + b.durationMinutes + (b.isPinned ? 12 : 0);
    return aScore >= bScore ? a : b;
  });

  final moodCounts = <String, int>{};
  for (final playlist in source) {
    moodCounts.update(playlist.mood, (value) => value + 1, ifAbsent: () => 1);
  }
  final topMoodEntry = moodCounts.entries.reduce(
    (a, b) => a.value >= b.value ? a : b,
  );

  final walkCount = source
      .where((playlist) => playlist.category.toLowerCase() == 'walking')
      .length;
  final runCount = source
      .where((playlist) => playlist.category.toLowerCase() == 'running')
      .length;
  final totalSessions = math.max(1, walkCount + runCount);
  final walkShare = ((walkCount / totalSessions) * 100).round();
  final runShare = 100 - walkShare;

  final recoveryZone = source.where((playlist) => playlist.bpm < 104).length;
  final cruiseZone = source
      .where((playlist) => playlist.bpm >= 104 && playlist.bpm <= 114)
      .length;
  final pushZone = source.where((playlist) => playlist.bpm > 114).length;

  final weeklyBpmTrend = [
    math.max(92, averageBpm - 5),
    math.max(94, averageBpm - 2),
    averageBpm,
    math.min(132, averageBpm + 3),
  ];

  final monthlySteps = todaySteps * 30;
  final monthlyGoal = goalSteps * 30;
  final monthlyStepProgress = (((monthlySteps / monthlyGoal) * 100).round())
      .clamp(0, 100);

  return _StatsSnapshot(
    todaySteps: todaySteps,
    goalSteps: goalSteps,
    hasStepPermission: hasStepPermission,
    averageBpm: averageBpm,
    favoriteRangeLabel: '$favoriteStart-$favoriteEnd BPM',
    averageBpmInsight:
        'You stay closest to your pace when the tempo sits just above easy-run range.',
    favoriteRangeInsight:
        'Most of your repeat plays land in this pocket for steady sessions.',
    syncScore: syncScore,
    syncInsight:
        'Your recent sessions stayed within ${(averageBpm - userCadence).abs()} BPM of target on average.',
    topPlaylistTitle: topPlaylist.title,
    topPlaylistInsight:
        '${topPlaylist.trackCount} tracks keeps this one in heavy rotation.',
    topMood: topMoodEntry.key,
    moodInsight:
        'This mood shows up most often when you come back for another session.',
    averageSessionMinutes: averageDuration,
    sessionInsight:
        'Your sessions usually settle into a $averageDuration minute rhythm.',
    walkShare: walkShare,
    runShare: runShare,
    weeklyBpmTrend: weeklyBpmTrend,
    bpmZoneLabels: const ['Recovery', 'Cruise', 'Push'],
    bpmZoneShares: [recoveryZone, cruiseZone, pushZone],
    summary: hasStepPermission
        ? 'Today you are at ${_formatSteps(todaySteps)} steps, while your recent sessions gravitated toward $averageBpm BPM and a $syncScore% pace match.'
        : 'Over the last 30 days you gravitated toward $averageBpm BPM, kept a $syncScore% pace match, and returned most often to ${topPlaylist.title}.',
    facts: [
      _StatsFact(
        title: 'Sweet spot',
        value: '$favoriteStart-$favoriteEnd BPM',
        caption: 'Your pace lines up best when tracks live in this zone.',
        accent: AppColors.primaryBright,
        icon: Icons.multitrack_audio_rounded,
      ),
      _StatsFact(
        title: hasStepPermission ? 'Today steps' : 'Step access',
        value: hasStepPermission ? _formatSteps(todaySteps) : 'Connect',
        caption: hasStepPermission
            ? '${((todaySteps / goalSteps) * 100).round().clamp(0, 100)}% of your ${_formatSteps(goalSteps)} step goal.'
            : 'Open the dedicated Steps page to grant Health Connect access.',
        accent: AppColors.accent,
        icon: Icons.directions_walk_rounded,
      ),
      _StatsFact(
        title: 'Projected month',
        value: _formatSteps(monthlySteps),
        caption:
            '$monthlyStepProgress% of your projected ${_formatSteps(monthlyGoal)} monthly goal at today’s pace.',
        accent: AppColors.primary,
        icon: Icons.calendar_month_rounded,
      ),
      _StatsFact(
        title: 'Fastest energy',
        value: '${source.map((playlist) => playlist.bpm).reduce(math.max)} BPM',
        caption:
            'You reach for higher-BPM tracks most on your run-leaning days.',
        accent: AppColors.cinemaRed,
        icon: Icons.local_fire_department_rounded,
      ),
      _StatsFact(
        title: 'Repeat return',
        value: topPlaylist.title,
        caption: 'This is the playlist you are most likely to jump back into.',
        accent: AppColors.warning,
        icon: Icons.replay_rounded,
      ),
      _StatsFact(
        title: 'Dominant mood',
        value: topMoodEntry.key,
        caption:
            'That mood anchors most of your last-30-day listening sessions.',
        accent: AppColors.primaryBright,
        icon: Icons.auto_awesome_rounded,
      ),
    ],
  );
}

class _HeaderStatChip extends StatelessWidget {
  const _HeaderStatChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.24),
            AppColors.background.withValues(alpha: 0.54),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
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

class _StatsRingPainter extends CustomPainter {
  const _StatsRingPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
  });

  final double progress;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.12;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.08);

    final primaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = primary;

    final secondaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = secondary;

    const startAngle = -math.pi / 2;
    final primarySweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    final secondarySweep = (math.pi * 2) - primarySweep;

    canvas.drawCircle(center, radius, basePaint);
    canvas.drawArc(rect, startAngle, primarySweep, false, primaryPaint);
    canvas.drawArc(
      rect,
      startAngle + primarySweep + 0.08,
      math.max(0, secondarySweep - 0.08),
      false,
      secondaryPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StatsRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary;
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
