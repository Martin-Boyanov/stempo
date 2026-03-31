import 'package:flutter/material.dart';

import '../ui/theme/colors.dart';

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
  });

  final String title;
  final String subtitle;
  final String detail;
  final int bpm;
}

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.targetBpm,
    required this.paceRange,
    required this.recentSessions,
  });

  final int targetBpm;
  final RangeValues paceRange;
  final List<SearchRecentSession> recentSessions;

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
  static const _recentQueries = [
    'night walk',
    'focused 110 bpm',
    'warm up mix',
  ];

  static const _catalog = [
    _SearchItem(
      title: 'Night Tempo Walk',
      subtitle: 'For focused city walks',
      type: SearchResultType.playlist,
      bpm: 112,
      useCase: 'Night walk',
      mood: 'Focused',
      durationMinutes: 34,
      keywords: ['night', 'city', 'focus', 'walk'],
    ),
    _SearchItem(
      title: 'Recovery Loop',
      subtitle: 'Soft reset after long days',
      type: SearchResultType.playlist,
      bpm: 98,
      useCase: 'Recovery',
      mood: 'Calm',
      durationMinutes: 22,
      keywords: ['cooldown', 'easy', 'recovery', 'reset'],
    ),
    _SearchItem(
      title: 'Sunline Start',
      subtitle: 'Ease into your first kilometer',
      type: SearchResultType.playlist,
      bpm: 104,
      useCase: 'Warm up',
      mood: 'Driven',
      durationMinutes: 18,
      keywords: ['warm', 'start', 'easy', 'morning'],
    ),
    _SearchItem(
      title: 'Steady Asphalt',
      subtitle: 'Locked pace for everyday runs',
      type: SearchResultType.playlist,
      bpm: 116,
      useCase: 'Steady run',
      mood: 'Driven',
      durationMinutes: 43,
      keywords: ['run', 'steady', 'tempo', 'asphalt'],
    ),
    _SearchItem(
      title: 'Moonlit Motion',
      subtitle: 'Dark pulse for after-hours walks',
      type: SearchResultType.playlist,
      bpm: 110,
      useCase: 'Night walk',
      mood: 'Dark',
      durationMinutes: 29,
      keywords: ['night', 'dark', 'late', 'walk'],
    ),
    _SearchItem(
      title: 'Seremise',
      subtitle: 'NITE SHIFT, Luma Cove',
      type: SearchResultType.track,
      bpm: 112,
      useCase: 'Night walk',
      mood: 'Focused',
      durationMinutes: 4,
      keywords: ['night', 'focus', 'city', 'steady'],
    ),
    _SearchItem(
      title: 'Afterglow',
      subtitle: 'Evening Runner',
      type: SearchResultType.track,
      bpm: 118,
      useCase: 'Steady run',
      mood: 'Euphoric',
      durationMinutes: 5,
      keywords: ['run', 'bright', 'finish', 'push'],
    ),
    _SearchItem(
      title: 'Mirage',
      subtitle: 'Sunset Tempo',
      type: SearchResultType.track,
      bpm: 105,
      useCase: 'Warm up',
      mood: 'Calm',
      durationMinutes: 4,
      keywords: ['warm', 'sunset', 'glide', 'easy'],
    ),
    _SearchItem(
      title: 'Glass City',
      subtitle: 'Night Tempo Walk',
      type: SearchResultType.track,
      bpm: 110,
      useCase: 'Night walk',
      mood: 'Dark',
      durationMinutes: 4,
      keywords: ['night', 'city', 'late', 'tempo'],
    ),
    _SearchItem(
      title: 'Halo Steps',
      subtitle: 'Dawn Arcade',
      type: SearchResultType.track,
      bpm: 99,
      useCase: 'Recovery',
      mood: 'Calm',
      durationMinutes: 3,
      keywords: ['recovery', 'easy', 'cooldown', 'light'],
    ),
    _SearchItem(
      title: 'Circuit Bloom',
      subtitle: 'Pace District',
      type: SearchResultType.track,
      bpm: 108,
      useCase: 'Focus',
      mood: 'Focused',
      durationMinutes: 4,
      keywords: ['focus', 'work', 'steady', 'clean'],
    ),
    _SearchItem(
      title: 'NITE SHIFT',
      subtitle: 'Night-walk edits and steady BPM pockets',
      type: SearchResultType.artist,
      bpm: null,
      useCase: 'Night walk',
      mood: 'Dark',
      durationMinutes: 0,
      keywords: ['night', 'city', 'after hours'],
    ),
    _SearchItem(
      title: 'Tempo Atlas',
      subtitle: 'Playlist-first curator for locked-in runs',
      type: SearchResultType.artist,
      bpm: null,
      useCase: 'Steady run',
      mood: 'Driven',
      durationMinutes: 0,
      keywords: ['tempo', 'run', 'steady', 'playlists'],
    ),
    _SearchItem(
      title: 'Luma Cove',
      subtitle: 'Warm neon textures for focused sessions',
      type: SearchResultType.artist,
      bpm: null,
      useCase: 'Focus',
      mood: 'Focused',
      durationMinutes: 0,
      keywords: ['focus', 'warm', 'glow', 'session'],
    ),
  ];

  final TextEditingController _searchController = TextEditingController();

  late RangeValues _paceRange;
  String _query = '';
  String? _selectedUseCase;
  String? _selectedMood;
  SearchDurationFilter? _selectedDuration;
  bool _matchMyPace = false;

  @override
  void initState() {
    super.initState();
    _paceRange = widget.paceRange;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasCustomPaceRange =>
      _paceRange.start != widget.paceRange.start ||
      _paceRange.end != widget.paceRange.end;

  bool get _showingResults =>
      _query.trim().isNotEmpty ||
      _matchMyPace ||
      _selectedUseCase != null ||
      _selectedMood != null ||
      _selectedDuration != null ||
      _hasCustomPaceRange;

  int get _activeFilterCount {
    var count = 0;
    if (_selectedUseCase != null) count++;
    if (_selectedMood != null) count++;
    if (_selectedDuration != null) count++;
    if (_hasCustomPaceRange) count++;
    return count;
  }

  List<_SearchItem> get _filteredItems {
    final query = _query.trim().toLowerCase();
    final items = _catalog.where((item) {
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
      final paceMatch = switch (item.bpm) {
        final bpm? =>
          bpm >= _paceRange.start.round() && bpm <= _paceRange.end.round(),
        null => query.isNotEmpty,
      };
      if (!queryMatch || !useCaseMatch || !moodMatch || !durationMatch) {
        return false;
      }
      if (_matchMyPace || _hasCustomPaceRange) {
        return paceMatch;
      }
      return true;
    }).toList(growable: false);
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

  int _fitDelta(_SearchItem item) => item.bpm == null
      ? 999
      : (item.bpm! - widget.targetBpm).abs();

  String _fitLabel(_SearchItem item) {
    if (item.bpm == null) return 'Artist pick';
    final delta = item.bpm! - widget.targetBpm;
    final absolute = delta.abs();
    if (absolute <= 2) return 'Perfect fit';
    if (absolute <= 5) return 'Good match';
    return delta > 0 ? '+$absolute BPM' : '-$absolute BPM';
  }

  void _setUseCaseFilter(String value) {
    setState(() {
      _selectedUseCase = value;
      _matchMyPace = false;
    });
  }

  void _clearSearchQuery() {
    setState(() {
      _searchController.clear();
      _query = '';
    });
  }

  Future<void> _openFiltersSheet() async {
    var selectedUseCase = _selectedUseCase;
    var selectedMood = _selectedMood;
    var selectedDuration = _selectedDuration;
    var paceRange = _paceRange;

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
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF111818),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
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
                          const SizedBox(height: 20),
                          const Text(
                            'Tune your search',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Keep the page clean, but dial in the exact vibe here.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _sheetLabel('Use case'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final useCase in _useCases)
                                _sheetChip(
                                  label: useCase.title,
                                  selected: selectedUseCase == useCase.title,
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
                          const SizedBox(height: 24),
                          _sheetLabel('Mood'),
                          const SizedBox(height: 12),
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
                                      selectedMood =
                                          selectedMood == mood ? null : mood;
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _sheetLabel('Duration'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final duration in SearchDurationFilter.values)
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
                          const SizedBox(height: 24),
                          _sheetLabel('Pace range'),
                          const SizedBox(height: 8),
                          Text(
                            '${paceRange.start.round()}-${paceRange.end.round()} BPM',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          RangeSlider(
                            values: paceRange,
                            min: 88,
                            max: 126,
                            divisions: 38,
                            activeColor: AppColors.primary,
                            inactiveColor: Colors.white.withValues(alpha: 0.1),
                            labels: RangeLabels(
                              paceRange.start.round().toString(),
                              paceRange.end.round().toString(),
                            ),
                            onChanged: (values) {
                              setModalState(() => paceRange = values);
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    selectedUseCase = null;
                                    selectedMood = null;
                                    selectedDuration = null;
                                    paceRange = widget.paceRange;
                                  });
                                },
                                child: const Text(
                                  'Clear all',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 52,
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
                                        _selectedUseCase = selectedUseCase;
                                        _selectedMood = selectedMood;
                                        _selectedDuration = selectedDuration;
                                        _paceRange = paceRange;
                                        _matchMyPace = false;
                                      });
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text(
                                      'Apply filters',
                                      style: TextStyle(
                                        fontSize: 15,
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
    final hasTopResult = topResult.type != SearchResultType.artist ||
        topResult.title.isNotEmpty;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 18),
          _buildMatchMyPaceCard(),
          const SizedBox(height: 14),
          _buildFilterRow(),
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
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
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
                  if (value.trim().isNotEmpty) {
                    _matchMyPace = false;
                  }
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
                color: _activeFilterCount == 0
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
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

  Widget _buildMatchMyPaceCard() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _searchController.clear();
          _query = '';
          _selectedUseCase = null;
          _selectedMood = null;
          _selectedDuration = null;
          _paceRange = widget.paceRange;
          _matchMyPace = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF16362C), Color(0xFF0F1715)],
          ),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
              child: const Icon(
                Icons.flash_on_rounded,
                color: AppColors.primaryBright,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Match my pace',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Start from ${widget.targetBpm} BPM and keep results near '
                    '${_paceRange.start.round()}-${_paceRange.end.round()} BPM.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    Widget chip(String label, {bool emphasized = false}) {
      return GestureDetector(
        onTap: _openFiltersSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: emphasized
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
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
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(_selectedUseCase == null
              ? 'Use case'
              : 'Use case: $_selectedUseCase'),
          const SizedBox(width: 8),
          chip(_selectedMood == null ? 'Mood' : 'Mood: $_selectedMood'),
          const SizedBox(width: 8),
          chip(_selectedDuration == null
              ? 'Duration'
              : 'Duration: ${_selectedDuration!.label}'),
          const SizedBox(width: 8),
          chip(
            _activeFilterCount == 0
                ? 'Filters'
                : 'Filters ($_activeFilterCount)',
            emphasized: _activeFilterCount > 0,
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
        _sectionHeader('Browse by use case', 'Start from intent'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _useCases.length; i++) ...[
                _useCaseCard(_useCases[i]),
                if (i != _useCases.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionHeader('Best for your pace', 'Closest fits first'),
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
        _sectionHeader('Recent searches / Jump back in', 'Keep momentum'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final query in _recentQueries) _queryChip(query),
          ],
        ),
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
        _sectionHeader('Fresh for your range', 'Popular near your pace'),
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No close matches yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try widening the mood or use-case filters, or jump into one of the common lanes below.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _recoveryChip('Night walk'),
                _recoveryChip('Focus'),
                _recoveryChip('Warm up'),
              ],
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _query = '';
                  _selectedUseCase = null;
                  _selectedMood = null;
                  _selectedDuration = null;
                  _paceRange = widget.paceRange;
                  _matchMyPace = false;
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
          _sectionHeader('Best pace-fit', 'Closest match'),
          const SizedBox(height: 12),
          _topMatchCard(topResult),
          const SizedBox(height: 18),
        ],
        if (playlists.isNotEmpty) ...[
          _sectionHeader('Playlists', 'Session-ready'),
          const SizedBox(height: 12),
          for (var i = 0; i < playlists.length; i++) ...[
            _resultCard(playlists[i]),
            if (i != playlists.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 18),
        ],
        if (tracks.isNotEmpty) ...[
          _sectionHeader('Tracks', 'Exact picks'),
          const SizedBox(height: 12),
          for (var i = 0; i < tracks.length; i++) ...[
            _resultCard(tracks[i]),
            if (i != tracks.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 18),
        ],
        if (artists.isNotEmpty) ...[
          _sectionHeader('Artists', 'Secondary matches'),
          const SizedBox(height: 12),
          for (var i = 0; i < artists.length; i++) ...[
            _resultCard(artists[i]),
            if (i != artists.length - 1) const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, String trailing) => Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            trailing,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );

  Widget _useCaseCard(_UseCaseData data) => GestureDetector(
        onTap: () => _setUseCaseFilter(data.title),
        child: Container(
          width: 192,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pill(data.bpmLabel, AppColors.primaryBright),
              const SizedBox(height: 16),
              Text(
                data.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _mixedCard(_SearchItem item) => Container(
        width: 214,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _pill(
                  item.type == SearchResultType.playlist ? 'Playlist' : 'Track',
                  AppColors.textPrimary,
                ),
                if (item.bpm != null)
                  Text(
                    '${item.bpm} BPM',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _fitLabel(item),
              style: const TextStyle(
                color: AppColors.primaryBright,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _queryChip(String query) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          query,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _recentSessionCard(SearchRecentSession session) => Container(
        width: 196,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              session.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${session.bpm} BPM',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _topMatchCard(_SearchItem item) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _pill(_fitLabel(item), AppColors.primaryBright),
                const Spacer(),
                Text(
                  item.type == SearchResultType.playlist ? 'Playlist' : 'Track',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _pill('${item.bpm} BPM', AppColors.textPrimary),
                const SizedBox(width: 8),
                _pill(item.useCase, AppColors.textPrimary),
                const SizedBox(width: 8),
                _pill('Start synced', AppColors.textPrimary),
              ],
            ),
          ],
        ),
      );

  Widget _resultCard(_SearchItem item) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: item.type == SearchResultType.artist
                      ? const [Color(0xFF223633), Color(0xFF111817)]
                      : const [AppColors.accent, AppColors.primary],
                ),
              ),
              child: Icon(
                switch (item.type) {
                  SearchResultType.playlist => Icons.queue_music_rounded,
                  SearchResultType.track => Icons.music_note_rounded,
                  SearchResultType.artist => Icons.mic_rounded,
                },
                color: item.type == SearchResultType.artist
                    ? AppColors.textPrimary
                    : AppColors.background,
              ),
            ),
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
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.bpm != null)
                  Text(
                    '${item.bpm} BPM',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  _fitLabel(item),
                  style: const TextStyle(
                    color: AppColors.primaryBright,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _pill(String label, Color textColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
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

  Widget _recoveryChip(String label) => GestureDetector(
        onTap: () => _setUseCaseFilter(label),
        child: Container(
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
        ),
      );

  Widget _sheetLabel(String title) => Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _sheetChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primaryBright.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primaryBright : AppColors.textPrimary,
              fontSize: 13,
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

class _SearchItem {
  const _SearchItem({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.bpm,
    required this.useCase,
    required this.mood,
    required this.durationMinutes,
    required this.keywords,
  });

  const _SearchItem.empty()
      : title = '',
        subtitle = '',
        type = SearchResultType.artist,
        bpm = null,
        useCase = '',
        mood = '',
        durationMinutes = 0,
        keywords = const [];

  final String title;
  final String subtitle;
  final SearchResultType type;
  final int? bpm;
  final String useCase;
  final String mood;
  final int durationMinutes;
  final List<String> keywords;
}
