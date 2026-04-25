import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/spotify_models.dart';
import '../state/playlist_models.dart';
import '../state/auth_providers.dart';
import '../ui/theme/app_fx.dart';
import '../ui/theme/colors.dart';
import '../ui/widgets/media_cover.dart';
import 'playlist_page.dart';

enum SearchResultType {
  playlist('Playlists'),
  track('Tracks'),
  artist('Artists');

  const SearchResultType(this.sectionTitle);

  final String sectionTitle;
}

enum SearchDurationFilter {
  short('Under 20 min'),
  medium('20-40 min'),
  long('40+ min');

  const SearchDurationFilter(this.label);

  final String label;

  bool matches(int minutes) {
    switch (this) {
      case SearchDurationFilter.short:
        return minutes < 20;
      case SearchDurationFilter.medium:
        return minutes >= 20 && minutes <= 40;
      case SearchDurationFilter.long:
        return minutes > 40;
    }
  }
}

class SearchRecentSession {
  const SearchRecentSession({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.bpm,
    required this.imageAsset,
  });

  final String title;
  final String subtitle;
  final String detail;
  final int bpm;
  final String imageAsset;
}

class SearchCatalogEntry {
  const SearchCatalogEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.type,
    required this.bpm,
    required this.useCase,
    required this.mood,
    required this.durationMinutes,
    required this.keywords,
  });

  factory SearchCatalogEntry.fromSpotify(SpotifySearchEntry entry) {
    return SearchCatalogEntry(
      id: entry.id,
      title: entry.title,
      subtitle: entry.subtitle,
      imageUrl: entry.imageUrl,
      type: switch (entry.type) {
        SpotifySearchEntryType.playlist => SearchResultType.playlist,
        SpotifySearchEntryType.track => SearchResultType.track,
        SpotifySearchEntryType.artist => SearchResultType.artist,
      },
      bpm: entry.bpm,
      useCase: entry.useCase,
      mood: entry.mood,
      durationMinutes: entry.durationMinutes,
      keywords: entry.keywords,
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final SearchResultType type;
  final int? bpm;
  final String useCase;
  final String mood;
  final int durationMinutes;
  final List<String> keywords;
}

enum _PaceFilterMode { currentPace, manualRange }

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.targetBpm,
    required this.paceRange,
    required this.recentSessions,
    this.catalogEntries,
  });

  final int targetBpm;
  final RangeValues paceRange;
  final List<SearchRecentSession> recentSessions;
  final List<SearchCatalogEntry>? catalogEntries;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _useCases = [
    _UseCaseData(
      title: 'Night walk',
      description: 'Dark pulse, city lights, and a smooth locked pace.',
      bpmLabel: '108-114 BPM',
    ),
    _UseCaseData(
      title: 'Focus',
      description: 'Steady grooves for work blocks and clear-headed walks.',
      bpmLabel: '102-110 BPM',
    ),
    _UseCaseData(
      title: 'Warm up',
      description: 'A gentle ramp that lets your cadence settle in.',
      bpmLabel: '96-106 BPM',
    ),
    _UseCaseData(
      title: 'Recovery',
      description: 'Softer edges for cooldowns and easy movement days.',
      bpmLabel: '92-102 BPM',
    ),
    _UseCaseData(
      title: 'Steady run',
      description: 'Confident, repeatable energy for longer efforts.',
      bpmLabel: '112-120 BPM',
    ),
  ];

  static const _moods = ['Focused', 'Calm', 'Driven', 'Dark', 'Euphoric'];
  static const _fallbackCatalog = [
    _SearchItem(
      id: 'fallback-1',
      title: 'Night Tempo Walk',
      subtitle: 'For focused city walks',
      imageAsset: 'assets/images/musicCover1.webp',
      type: SearchResultType.playlist,
      bpm: 112,
      useCase: 'Night walk',
      mood: 'Focused',
      durationMinutes: 34,
      keywords: ['night', 'city', 'focus', 'walk'],
    ),
    _SearchItem(
      id: 'fallback-2',
      title: 'Recovery Loop',
      subtitle: 'Soft reset after long days',
      imageAsset: 'assets/images/musicCover3.webp',
      type: SearchResultType.playlist,
      bpm: 98,
      useCase: 'Recovery',
      mood: 'Calm',
      durationMinutes: 22,
      keywords: ['cooldown', 'easy', 'recovery', 'reset'],
    ),
    _SearchItem(
      id: 'fallback-3',
      title: 'Sunline Start',
      subtitle: 'Ease into your first kilometer',
      imageAsset: 'assets/images/musicCover4.webp',
      type: SearchResultType.playlist,
      bpm: 104,
      useCase: 'Warm up',
      mood: 'Driven',
      durationMinutes: 18,
      keywords: ['warm', 'start', 'easy', 'morning'],
    ),
    _SearchItem(
      id: 'fallback-4',
      title: 'Steady Asphalt',
      subtitle: 'Locked pace for everyday runs',
      imageAsset: 'assets/images/musicCover2.webp',
      type: SearchResultType.playlist,
      bpm: 116,
      useCase: 'Steady run',
      mood: 'Driven',
      durationMinutes: 43,
      keywords: ['run', 'steady', 'tempo', 'asphalt'],
    ),
    _SearchItem(
      id: 'fallback-5',
      title: 'Moonlit Motion',
      subtitle: 'Dark pulse for after-hours walks',
      imageAsset: 'assets/images/musicCover5.webp',
      type: SearchResultType.playlist,
      bpm: 110,
      useCase: 'Night walk',
      mood: 'Dark',
      durationMinutes: 29,
      keywords: ['night', 'dark', 'late', 'walk'],
    ),
    _SearchItem(
      id: 'fallback-6',
      title: 'Seremise',
      subtitle: 'NITE SHIFT, Luma Cove',
      imageAsset: 'assets/images/musicCover8.webp',
      type: SearchResultType.track,
      bpm: 112,
      useCase: 'Night walk',
      mood: 'Focused',
      durationMinutes: 4,
      keywords: ['night', 'focus', 'city', 'steady'],
    ),
    _SearchItem(
      id: 'fallback-7',
      title: 'Afterglow',
      subtitle: 'Evening Runner',
      imageAsset: 'assets/images/musicCover9.webp',
      type: SearchResultType.track,
      bpm: 118,
      useCase: 'Steady run',
      mood: 'Euphoric',
      durationMinutes: 5,
      keywords: ['run', 'bright', 'finish', 'push'],
    ),
    _SearchItem(
      id: 'fallback-8',
      title: 'Mirage',
      subtitle: 'Sunset Tempo',
      imageAsset: 'assets/images/musicCover10.webp',
      type: SearchResultType.track,
      bpm: 105,
      useCase: 'Warm up',
      mood: 'Calm',
      durationMinutes: 4,
      keywords: ['warm', 'sunset', 'glide', 'easy'],
    ),
    _SearchItem(
      id: 'fallback-9',
      title: 'Glass City',
      subtitle: 'Night Tempo Walk',
      imageAsset: 'assets/images/musicCover6.webp',
      type: SearchResultType.track,
      bpm: 110,
      useCase: 'Night walk',
      mood: 'Dark',
      durationMinutes: 4,
      keywords: ['night', 'city', 'late', 'tempo'],
    ),
    _SearchItem(
      id: 'fallback-10',
      title: 'Halo Steps',
      subtitle: 'Dawn Arcade',
      imageAsset: 'assets/images/musicCover7.webp',
      type: SearchResultType.track,
      bpm: 99,
      useCase: 'Recovery',
      mood: 'Calm',
      durationMinutes: 3,
      keywords: ['recovery', 'easy', 'cooldown', 'light'],
    ),
    _SearchItem(
      id: 'fallback-11',
      title: 'Circuit Bloom',
      subtitle: 'Pace District',
      imageAsset: 'assets/images/musicCover4.webp',
      type: SearchResultType.track,
      bpm: 108,
      useCase: 'Focus',
      mood: 'Focused',
      durationMinutes: 4,
      keywords: ['focus', 'work', 'steady', 'clean'],
    ),
    _SearchItem(
      id: 'fallback-12',
      title: 'NITE SHIFT',
      subtitle: 'Night-walk edits and steady BPM pockets',
      imageAsset: 'assets/images/musicCover8.webp',
      type: SearchResultType.artist,
      bpm: null,
      useCase: 'Night walk',
      mood: 'Dark',
      durationMinutes: 0,
      keywords: ['night', 'city', 'after hours'],
    ),
    _SearchItem(
      id: 'fallback-13',
      title: 'Tempo Atlas',
      subtitle: 'Playlist-first curator for locked-in runs',
      imageAsset: 'assets/images/musicCover2.webp',
      type: SearchResultType.artist,
      bpm: null,
      useCase: 'Steady run',
      mood: 'Driven',
      durationMinutes: 0,
      keywords: ['tempo', 'run', 'steady', 'playlists'],
    ),
    _SearchItem(
      id: 'fallback-14',
      title: 'Luma Cove',
      subtitle: 'Warm neon textures for focused sessions',
      imageAsset: 'assets/images/musicCover1.webp',
      type: SearchResultType.artist,
      bpm: null,
      useCase: 'Focus',
      mood: 'Focused',
      durationMinutes: 0,
      keywords: ['focus', 'warm', 'glow', 'session'],
    ),
  ];

  List<_SearchItem> get _catalog {
    final customEntries = widget.catalogEntries;
    if (customEntries == null || customEntries.isEmpty) {
      return _fallbackCatalog;
    }

    return customEntries
        .map(
          (entry) => _SearchItem(
            id: entry.id,
            title: entry.title,
            subtitle: entry.subtitle,
            imageAsset: entry.imageUrl,
            type: entry.type,
            bpm: entry.bpm,
            useCase: entry.useCase,
            mood: entry.mood,
            durationMinutes: entry.durationMinutes,
            keywords: entry.keywords,
          ),
        )
        .toList(growable: false);
  }

  final TextEditingController _searchController = TextEditingController();

  late RangeValues _paceRange;
  late double _manualTargetBpm;
  late double _manualTolerance;
  String _query = '';
  String? _selectedUseCase;
  String? _selectedMood;
  SearchDurationFilter? _selectedDuration;
  _PaceFilterMode _paceFilterMode = _PaceFilterMode.currentPace;

  @override
  void initState() {
    super.initState();
    _paceRange = widget.paceRange;
    _manualTargetBpm = ((widget.paceRange.start + widget.paceRange.end) / 2)
        .toDouble();
    _manualTolerance = ((widget.paceRange.end - widget.paceRange.start) / 2)
        .toDouble();
  }

  RangeValues _rangeFromTargetAndTolerance(double target, double tolerance) {
    final start = (target - tolerance).clamp(88, 126).toDouble();
    final end = (target + tolerance).clamp(88, 126).toDouble();
    return RangeValues(start, end);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasCustomPaceRange =>
      _paceRange.start != widget.paceRange.start ||
      _paceRange.end != widget.paceRange.end;

  bool get _usesCurrentPacePreset =>
      _paceFilterMode == _PaceFilterMode.currentPace;

  bool get _showingResults =>
      _query.trim().isNotEmpty ||
      _selectedUseCase != null ||
      _selectedMood != null ||
      _selectedDuration != null ||
      (_paceFilterMode == _PaceFilterMode.manualRange && _hasCustomPaceRange);

  int get _activeFilterCount {
    var count = 0;
    if (_selectedUseCase != null) count++;
    if (_selectedMood != null) count++;
    if (_selectedDuration != null) count++;
    if (_paceFilterMode == _PaceFilterMode.manualRange && _hasCustomPaceRange) {
      count++;
    }
    return count;
  }

  List<_SearchItem> get _filteredItems {
    final query = _query.trim().toLowerCase();
    final items = _catalog
        .where((item) {
          final haystack = [
            item.title,
            item.subtitle,
            item.useCase,
            item.mood,
            ...item.keywords,
          ].join(' ').toLowerCase();
          final queryMatch = query.isEmpty || haystack.contains(query);
          final useCaseMatch =
              _selectedUseCase == null || item.useCase == _selectedUseCase;
          final moodMatch = _selectedMood == null || item.mood == _selectedMood;
          final durationMatch =
              _selectedDuration == null ||
              _selectedDuration!.matches(item.durationMinutes);
          final activePaceRange = _usesCurrentPacePreset
              ? widget.paceRange
              : _paceRange;
          final paceMatch = switch (item.bpm) {
            final bpm? =>
              bpm >= activePaceRange.start.round() &&
                  bpm <= activePaceRange.end.round(),
            null => query.isNotEmpty,
          };
          if (!queryMatch || !useCaseMatch || !moodMatch || !durationMatch) {
            return false;
          }
          if (_usesCurrentPacePreset ||
              (_paceFilterMode == _PaceFilterMode.manualRange &&
                  _hasCustomPaceRange)) {
            return paceMatch;
          }
          return true;
        })
        .toList(growable: false);
    items.sort(_compareItems);
    return items;
  }

  int _compareItems(_SearchItem a, _SearchItem b) {
    final typeCompare = _typeOrder(a.type).compareTo(_typeOrder(b.type));
    if (typeCompare != 0) return typeCompare;
    final fitCompare = _fitDelta(a).compareTo(_fitDelta(b));
    if (fitCompare != 0) return fitCompare;
    return a.title.compareTo(b.title);
  }

  int _typeOrder(SearchResultType type) {
    switch (type) {
      case SearchResultType.playlist:
        return 0;
      case SearchResultType.track:
        return 1;
      case SearchResultType.artist:
        return 2;
    }
  }

  int _fitDelta(_SearchItem item) =>
      item.bpm == null ? 999 : (item.bpm! - widget.targetBpm).abs();

  String _fitLabel(_SearchItem item) {
    if (item.bpm == null) return 'Artist pick';
    final delta = item.bpm! - widget.targetBpm;
    final absolute = delta.abs();
    if (absolute <= 2) return 'Perfect fit';
    if (absolute <= 5) return 'Good match';
    return delta > 0 ? '+$absolute BPM' : '-$absolute BPM';
  }

  void _clearSearchQuery() {
    setState(() {
      _searchController.clear();
      _query = '';
    });
  }

  void _handleRecentSessionTap(SearchRecentSession session) {
    final playlist = TempoPlaylist(
      id: 'recent-${session.title.hashCode}',
      title: session.title,
      subtitle: session.subtitle,
      imageAsset: session.imageAsset,
      bpm: session.bpm,
      trackCount: 12,
      durationMinutes: 34,
      category: 'Recent',
      mood: 'Focused',
      colors: [AppColors.primary, AppColors.primaryBright],
      wasRecentlyPlayed: true,
    );
    context.push(
      '/playlist/${playlist.id}?cadence=${widget.targetBpm}',
      extra: PlaylistPageArgs(
        playlist: playlist,
        userCadence: widget.targetBpm,
        sourceTab: PlaylistSourceTab.search,
      ),
    );
  }

  void _handleSearchItemTap(_SearchItem item) {
    if (item.type == SearchResultType.artist) return;

    final playlist = TempoPlaylist(
      id: item.id.isEmpty ? 'search-${item.title.hashCode}' : item.id,
      title: item.title,
      subtitle: item.subtitle,
      imageAsset: item.imageAsset,
      bpm: item.bpm ?? widget.targetBpm,
      trackCount: item.durationMinutes > 0
          ? (item.durationMinutes / 3).round()
          : 12,
      durationMinutes: item.durationMinutes,
      category: item.useCase,
      mood: item.mood,
      colors: [AppColors.primary, AppColors.primaryBright],
    );

    final auth = AuthScope.read(context);
    auth.cachePlaylist(playlist);

    context.push(
      '/playlist/${playlist.id}?cadence=${widget.targetBpm}',
      extra: PlaylistPageArgs(
        playlist: playlist,
        userCadence: widget.targetBpm,
        sourceTab: PlaylistSourceTab.search,
      ),
    );
  }

  Future<void> _openFiltersSheet() async {
    var selectedUseCase = _selectedUseCase;
    var selectedMood = _selectedMood;
    var selectedDuration = _selectedDuration;
    var paceFilterMode = _paceFilterMode;
    var paceRange = _paceRange;
    var manualTargetBpm = _manualTargetBpm;
    var manualTolerance = _manualTolerance;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppFx.raisedPanelGradient,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: AppFx.softGlow(
                      AppColors.primary,
                      strength: 0.14,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Tune your search',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sheetLabel('Pace source'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _sheetChip(
                                      label: 'Use current pace',
                                      selected:
                                          paceFilterMode ==
                                          _PaceFilterMode.currentPace,
                                      onTap: () {
                                        setModalState(() {
                                          paceFilterMode =
                                              _PaceFilterMode.currentPace;
                                          paceRange = widget.paceRange;
                                        });
                                      },
                                    ),
                                    _sheetChip(
                                      label: 'Manual range',
                                      selected:
                                          paceFilterMode ==
                                          _PaceFilterMode.manualRange,
                                      onTap: () {
                                        setModalState(() {
                                          paceFilterMode =
                                              _PaceFilterMode.manualRange;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _sheetLabel('Use case'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final useCase in _useCases)
                                      _sheetChip(
                                        label: useCase.title,
                                        selected:
                                            selectedUseCase == useCase.title,
                                        onTap: () {
                                          setModalState(() {
                                            selectedUseCase =
                                                selectedUseCase == useCase.title
                                                ? null
                                                : useCase.title;
                                          });
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _sheetLabel('Mood'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final mood in _moods)
                                      _sheetChip(
                                        label: mood,
                                        selected: selectedMood == mood,
                                        onTap: () {
                                          setModalState(() {
                                            selectedMood = selectedMood == mood
                                                ? null
                                                : mood;
                                          });
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _sheetLabel('Duration'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final duration
                                        in SearchDurationFilter.values)
                                      _sheetChip(
                                        label: duration.label,
                                        selected: selectedDuration == duration,
                                        onTap: () {
                                          setModalState(() {
                                            selectedDuration =
                                                selectedDuration == duration
                                                ? null
                                                : duration;
                                          });
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _sheetLabel('Pace range'),
                                const SizedBox(height: 6),
                                Text(
                                  paceFilterMode == _PaceFilterMode.currentPace
                                      ? 'Using your current pace: '
                                            '${widget.paceRange.start.round()}-${widget.paceRange.end.round()} BPM'
                                      : '${manualTargetBpm.round()} BPM (${paceRange.start.round()}-${paceRange.end.round()})',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Slider(
                                  value: manualTargetBpm,
                                  min: 88,
                                  max: 126,
                                  divisions: 38,
                                  activeColor: AppColors.primary,
                                  inactiveColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                  onChanged: (value) {
                                    setModalState(() {
                                      paceFilterMode =
                                          _PaceFilterMode.manualRange;
                                      manualTargetBpm = value;
                                      paceRange = _rangeFromTargetAndTolerance(
                                        manualTargetBpm,
                                        manualTolerance,
                                      );
                                    });
                                  },
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tolerance: +/- ${manualTolerance.round()} BPM',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Slider(
                                  value: manualTolerance,
                                  min: 4,
                                  max: 18,
                                  divisions: 14,
                                  activeColor: AppColors.warning,
                                  inactiveColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                  onChanged: (value) {
                                    setModalState(() {
                                      paceFilterMode =
                                          _PaceFilterMode.manualRange;
                                      manualTolerance = value;
                                      paceRange = _rangeFromTargetAndTolerance(
                                        manualTargetBpm,
                                        manualTolerance,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  paceFilterMode = _PaceFilterMode.currentPace;
                                  selectedUseCase = null;
                                  selectedMood = null;
                                  selectedDuration = null;
                                  paceRange = widget.paceRange;
                                  manualTargetBpm =
                                      ((widget.paceRange.start +
                                                  widget.paceRange.end) /
                                              2)
                                          .toDouble();
                                  manualTolerance =
                                      ((widget.paceRange.end -
                                                  widget.paceRange.start) /
                                              2)
                                          .toDouble();
                                });
                              },
                              child: const Text(
                                'Clear all',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.background,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _paceFilterMode = paceFilterMode;
                                      _selectedUseCase = selectedUseCase;
                                      _selectedMood = selectedMood;
                                      _selectedDuration = selectedDuration;
                                      _paceRange = paceRange;
                                      _manualTargetBpm = manualTargetBpm;
                                      _manualTolerance = manualTolerance;
                                    });
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text(
                                    'Apply filters',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    final topResult = filteredItems.firstWhere(
      (item) => item.type != SearchResultType.artist,
      orElse: () => const _SearchItem.empty(),
    );
    final hasTopResult =
        topResult.type != SearchResultType.artist || topResult.title.isNotEmpty;
    final remainingItems = filteredItems
        .where((item) => !identical(item, topResult))
        .toList(growable: false);
    final playlists = remainingItems
        .where((item) => item.type == SearchResultType.playlist)
        .toList(growable: false);
    final tracks = remainingItems
        .where((item) => item.type == SearchResultType.track)
        .toList(growable: false);
    final artists = remainingItems
        .where((item) => item.type == SearchResultType.artist)
        .toList(growable: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 172),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 20),
            if (_showingResults)
              _buildResultsView(
                filteredItems: filteredItems,
                hasTopResult: hasTopResult,
                topResult: topResult,
                playlists: playlists,
                tracks: tracks,
                artists: artists,
              )
            else
              _buildBrowseView(filteredItems),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return FrostedPanel(
      radius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      glowColor: AppColors.primary,
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const ValueKey('search-field'),
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: AppColors.primaryBright,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Tracks, playlists, artists, moods',
                hintStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              onPressed: _clearSearchQuery,
              icon: const Icon(Icons.close_rounded),
              color: AppColors.textSecondary,
            ),
          GestureDetector(
            key: const ValueKey('search-filter-button'),
            onTap: _openFiltersSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: _activeFilterCount == 0
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x661A221E), Color(0x33211D20)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xAA1ED760), Color(0x66FF5A5F)],
                      ),
                boxShadow: _activeFilterCount == 0
                    ? null
                    : AppFx.softGlow(AppColors.primary, strength: 0.18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                  if (_activeFilterCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$_activeFilterCount',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseView(List<_SearchItem> filteredItems) {
    final bestForPace = filteredItems
        .where((item) => item.type != SearchResultType.artist)
        .take(4)
        .toList(growable: false);
    final freshForRange = _catalog
        .where(
          (item) =>
              item.type != SearchResultType.artist &&
              item.bpm != null &&
              item.bpm! >= widget.paceRange.start.round() - 4 &&
              item.bpm! <= widget.paceRange.end.round() + 4,
        )
        .take(3)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recently played'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < widget.recentSessions.length; i++) ...[
                _recentSessionCard(widget.recentSessions[i]),
                if (i != widget.recentSessions.length - 1)
                  const SizedBox(width: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionHeader('Best for your pace'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < bestForPace.length; i++) ...[
                _mixedCard(bestForPace[i]),
                if (i != bestForPace.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionHeader('Fresh picks'),
        const SizedBox(height: 12),
        Column(
          children: [
            for (var i = 0; i < freshForRange.length; i++) ...[
              _resultCard(freshForRange[i]),
              if (i != freshForRange.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildResultsView({
    required List<_SearchItem> filteredItems,
    required bool hasTopResult,
    required _SearchItem topResult,
    required List<_SearchItem> playlists,
    required List<_SearchItem> tracks,
    required List<_SearchItem> artists,
  }) {
    if (filteredItems.isEmpty) {
      return FrostedPanel(
        radius: 30,
        padding: const EdgeInsets.all(22),
        glowColor: AppColors.cinemaRed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No matches yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try the filter button or widen the pace range.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _StaticHintChip(label: 'Try the filter button'),
                _StaticHintChip(label: 'Use current pace'),
                _StaticHintChip(label: 'Widen duration'),
              ],
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _query = '';
                  _paceFilterMode = _PaceFilterMode.currentPace;
                  _selectedUseCase = null;
                  _selectedMood = null;
                  _selectedDuration = null;
                  _paceRange = widget.paceRange;
                });
              },
              child: const Text(
                'Clear filters and search again',
                style: TextStyle(
                  color: AppColors.primaryBright,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTopResult) ...[
          _sectionHeader('Top match'),
          const SizedBox(height: 12),
          _topMatchCard(topResult),
          const SizedBox(height: 18),
        ],
        if (playlists.isNotEmpty) ...[
          _sectionHeader('Playlists'),
          const SizedBox(height: 12),
          for (var i = 0; i < playlists.length; i++) ...[
            _resultCard(playlists[i]),
            if (i != playlists.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 18),
        ],
        if (tracks.isNotEmpty) ...[
          _sectionHeader('Tracks'),
          const SizedBox(height: 12),
          for (var i = 0; i < tracks.length; i++) ...[
            _resultCard(tracks[i]),
            if (i != tracks.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 18),
        ],
        if (artists.isNotEmpty) ...[
          _sectionHeader('Artists'),
          const SizedBox(height: 12),
          for (var i = 0; i < artists.length; i++) ...[
            _resultCard(artists[i]),
            if (i != artists.length - 1) const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _sectionHeader(String title) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _mixedCard(_SearchItem item) => GestureDetector(
    onTap: () => _handleSearchItemTap(item),
    behavior: HitTestBehavior.opaque,
    child: SizedBox(
      width: 170,
      height: 178,
      child: FrostedPanel(
        radius: 24,
        padding: const EdgeInsets.all(12),
        glowColor: item.type == SearchResultType.artist
            ? AppColors.cinemaRed
            : AppColors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _largeMediaBadge(item),
            const Spacer(),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.bpm != null ? '${item.bpm} BPM' : item.type.sectionTitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _recentSessionCard(SearchRecentSession session) => GestureDetector(
    onTap: () => _handleRecentSessionTap(session),
    behavior: HitTestBehavior.opaque,
    child: SizedBox(
      width: 170,
      height: 180,
      child: FrostedPanel(
        radius: 24,
        padding: const EdgeInsets.all(12),
        glowColor: AppColors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _recentMediaBadge(session),
            const Spacer(),
            Text(
              session.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${session.bpm} BPM',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _topMatchCard(_SearchItem item) => GestureDetector(
    onTap: () => _handleSearchItemTap(item),
    behavior: HitTestBehavior.opaque,
    child: FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(16),
      elevated: true,
      glowColor: AppColors.primary,
      child: Row(
        children: [
          _heroMediaBadge(item),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.bpm != null)
                      _pill('${item.bpm} BPM', AppColors.textPrimary),
                    _pill(
                      item.type == SearchResultType.playlist
                          ? 'Playlist'
                          : 'Track',
                      AppColors.textPrimary,
                    ),
                    _pill(_fitLabel(item), AppColors.primaryBright),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _resultCard(_SearchItem item) => GestureDetector(
    onTap: () => _handleSearchItemTap(item),
    behavior: HitTestBehavior.opaque,
    child: FrostedPanel(
      radius: 24,
      padding: const EdgeInsets.all(14),
      glowColor: item.type == SearchResultType.artist
          ? AppColors.cinemaRed
          : AppColors.primary,
      child: Row(
        children: [
          _compactMediaBadge(item),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.bpm != null)
                      _pill('${item.bpm} BPM', AppColors.textPrimary),
                    _pill(_fitLabel(item), AppColors.primaryBright),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pill(String label, Color textColor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _largeMediaBadge(_SearchItem item) => MediaCover(
    imageAsset: item.imageAsset,
    size: 72,
    borderRadius: 20,
    child: Stack(
      children: [
        Positioned(
          right: -8,
          top: -6,
          child: Icon(
            switch (item.type) {
              SearchResultType.playlist => Icons.queue_music_rounded,
              SearchResultType.track => Icons.music_note_rounded,
              SearchResultType.artist => Icons.mic_rounded,
            },
            size: 42,
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
        if (item.bpm != null)
          Positioned(
            left: 10,
            bottom: 8,
            child: Text(
              '${item.bpm}',
              style: const TextStyle(
                color: AppColors.background,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _recentMediaBadge(SearchRecentSession session) => MediaCover(
    imageAsset: session.imageAsset,
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
            color: Colors.white.withValues(alpha: 0.14),
          ),
        ),
        Positioned(
          left: 10,
          bottom: 8,
          child: Text(
            '${session.bpm}',
            style: const TextStyle(
              color: AppColors.background,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _heroMediaBadge(_SearchItem item) => MediaCover(
    imageAsset: item.imageAsset,
    size: 92,
    borderRadius: 24,
    child: Stack(
      children: [
        Positioned(
          right: -6,
          top: -4,
          child: Icon(
            switch (item.type) {
              SearchResultType.playlist => Icons.queue_music_rounded,
              SearchResultType.track => Icons.music_note_rounded,
              SearchResultType.artist => Icons.mic_rounded,
            },
            size: 56,
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
        if (item.bpm != null)
          Positioned(
            left: 12,
            bottom: 10,
            child: Text(
              '${item.bpm}',
              style: const TextStyle(
                color: AppColors.background,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _compactMediaBadge(_SearchItem item) => MediaCover(
    imageAsset: item.imageAsset,
    size: 54,
    borderRadius: 16,
    child: Center(
      child: Icon(
        switch (item.type) {
          SearchResultType.playlist => Icons.queue_music_rounded,
          SearchResultType.track => Icons.music_note_rounded,
          SearchResultType.artist => Icons.mic_rounded,
        },
        color: item.type == SearchResultType.artist
            ? AppColors.textPrimary
            : AppColors.background,
        size: 24,
      ),
    ),
  );

  Widget _sheetLabel(String title) => Text(
    title,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _sheetChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xAA1ED760), Color(0x66FF5A5F)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x661B2420), Color(0x33202422)],
              ),
        boxShadow: selected
            ? AppFx.softGlow(AppColors.primary, strength: 0.14)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _UseCaseData {
  const _UseCaseData({
    required this.title,
    required this.description,
    required this.bpmLabel,
  });

  final String title;
  final String description;
  final String bpmLabel;
}

class _StaticHintChip extends StatelessWidget {
  const _StaticHintChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SearchItem {
  const _SearchItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.type,
    required this.bpm,
    required this.useCase,
    required this.mood,
    required this.durationMinutes,
    required this.keywords,
  });

  const _SearchItem.empty()
    : id = '',
      title = '',
      subtitle = '',
      imageAsset = '',
      type = SearchResultType.artist,
      bpm = null,
      useCase = '',
      mood = '',
      durationMinutes = 0,
      keywords = const [];

  final String id;
  final String title;
  final String subtitle;
  final String imageAsset;
  final SearchResultType type;
  final int? bpm;
  final String useCase;
  final String mood;
  final int durationMinutes;
  final List<String> keywords;
}
