import 'package:flutter/material.dart';

import '../ui/theme/colors.dart';

enum LibraryFilter {
  all('All'),
  bestMatch('Best match'),
  running('Running'),
  walking('Walking'),
  recentlyPlayed('Recently played');

  const LibraryFilter(this.label);

  final String label;
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.userCadence,
  });

  final int userCadence;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  static const _playlists = [
    _LibraryPlaylist(
      title: 'Night Tempo Walk',
      subtitle: 'Neon city loops for locked-in evening strides',
      bpm: 110,
      trackCount: 24,
      durationMinutes: 94,
      category: 'Walking',
      mood: 'Focused',
      isPinned: true,
      wasRecentlyPlayed: true,
      colors: [Color(0xFF17363A), Color(0xFF42E07C)],
    ),
    _LibraryPlaylist(
      title: 'Steady Asphalt',
      subtitle: 'Confident BPM pockets for repeatable run days',
      bpm: 116,
      trackCount: 31,
      durationMinutes: 112,
      category: 'Running',
      mood: 'Driven',
      wasRecentlyPlayed: true,
      colors: [Color(0xFF10232B), Color(0xFF6FE7F2)],
    ),
    _LibraryPlaylist(
      title: 'Recovery Loop',
      subtitle: 'Soft reset energy for easy cooldown sessions',
      bpm: 98,
      trackCount: 18,
      durationMinutes: 67,
      category: 'Walking',
      mood: 'Calm',
      wasRecentlyPlayed: true,
      colors: [Color(0xFF24362B), Color(0xFF7AE38D)],
    ),
    _LibraryPlaylist(
      title: 'Warm Street Start',
      subtitle: 'A gentle ramp before the pace starts clicking',
      bpm: 104,
      trackCount: 20,
      durationMinutes: 71,
      category: 'Walking',
      mood: 'Warm up',
      colors: [Color(0xFF332217), Color(0xFFFFC857)],
    ),
    _LibraryPlaylist(
      title: 'After Hours Tempo',
      subtitle: 'Dark pulse and smooth momentum for late runs',
      bpm: 121,
      trackCount: 27,
      durationMinutes: 101,
      category: 'Running',
      mood: 'Dark',
      colors: [Color(0xFF261836), Color(0xFF6B8DFF)],
    ),
    _LibraryPlaylist(
      title: 'Glass Mile',
      subtitle: 'Polished synth edges for focused tempo work',
      bpm: 108,
      trackCount: 22,
      durationMinutes: 79,
      category: 'Running',
      mood: 'Focused',
      wasRecentlyPlayed: true,
      colors: [Color(0xFF17303B), Color(0xFF59D0E3)],
    ),
    _LibraryPlaylist(
      title: 'Sunday Motion',
      subtitle: 'Easygoing picks for longer low-pressure walks',
      bpm: 96,
      trackCount: 16,
      durationMinutes: 58,
      category: 'Walking',
      mood: 'Calm',
      colors: [Color(0xFF243126), Color(0xFF8ACB88)],
    ),
  ];

  LibraryFilter _selectedFilter = LibraryFilter.all;

  List<_LibraryPlaylist> get _filteredPlaylists {
    final items = _playlists.where((playlist) {
      switch (_selectedFilter) {
        case LibraryFilter.all:
          return true;
        case LibraryFilter.bestMatch:
          return _fitRating(playlist) <= 1;
        case LibraryFilter.running:
          return playlist.category == 'Running';
        case LibraryFilter.walking:
          return playlist.category == 'Walking';
        case LibraryFilter.recentlyPlayed:
          return playlist.wasRecentlyPlayed;
      }
    }).toList(growable: false);

    items.sort((a, b) {
      final fitCompare = _fitRating(a).compareTo(_fitRating(b));
      if (fitCompare != 0) return fitCompare;
      return (a.bpm - widget.userCadence).abs().compareTo(
            (b.bpm - widget.userCadence).abs(),
          );
    });
    return items;
  }

  _LibraryPlaylist? get _heroPlaylist {
    if (_filteredPlaylists.isEmpty) return null;
    return _filteredPlaylists.cast<_LibraryPlaylist?>().firstWhere(
          (playlist) => playlist!.isPinned,
          orElse: () => _filteredPlaylists.first,
        );
  }

  List<_LibraryPlaylist> get _mainPlaylists {
    final hero = _heroPlaylist;
    if (hero == null) return const [];
    return _filteredPlaylists
        .where((playlist) => playlist.title != hero.title)
        .toList(growable: false);
  }

  List<_LibraryPlaylist> get _recentlyPlayed {
    return _filteredPlaylists
        .where((playlist) => playlist.wasRecentlyPlayed)
        .toList(growable: false);
  }

  int _fitRating(_LibraryPlaylist playlist) {
    final difference = (playlist.bpm - widget.userCadence).abs();
    if (difference <= 3) return 0;
    if (difference <= 8) return 1;
    return 2;
  }

  String _fitLabel(_LibraryPlaylist playlist) {
    switch (_fitRating(playlist)) {
      case 0:
        return 'Perfect fit';
      case 1:
        return 'Close';
      case 2:
        return 'Off pace';
    }
    throw StateError('Unexpected fit rating for ${playlist.title}');
  }

  Color _fitColor(_LibraryPlaylist playlist) {
    switch (_fitRating(playlist)) {
      case 0:
        return AppColors.primaryBright;
      case 1:
        return AppColors.warning;
      case 2:
        return AppColors.textMuted;
    }
    throw StateError('Unexpected fit color for ${playlist.title}');
  }

  @override
  Widget build(BuildContext context) {
    final hero = _heroPlaylist;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 172),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LibraryHeader(userCadence: widget.userCadence),
          const SizedBox(height: 18),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: LibraryFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final filter = LibraryFilter.values[index];
                final isSelected = filter == _selectedFilter;
                return _LibraryFilterChip(
                  label: filter.label,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedFilter = filter),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          if (hero != null) ...[
            _LibraryHeroCard(
              playlist: hero,
              fitLabel: _fitLabel(hero),
              fitColor: _fitColor(hero),
            ),
            const SizedBox(height: 22),
            const _LibrarySectionLabel(
              title: 'Playlists',
              trailing: 'Tempo-ready',
            ),
            const SizedBox(height: 12),
            if (_mainPlaylists.isEmpty)
              _LibraryEmptyState(
                title: 'No playlists in this view yet',
                message: 'Connect Spotify playlists to build your tempo library.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;
                  if (!isWide) {
                    return Column(
                      children: [
                        for (var i = 0; i < _mainPlaylists.length; i++) ...[
                          _LibraryPlaylistCard(
                            playlist: _mainPlaylists[i],
                            fitLabel: _fitLabel(_mainPlaylists[i]),
                            fitColor: _fitColor(_mainPlaylists[i]),
                          ),
                          if (i != _mainPlaylists.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final playlist in _mainPlaylists)
                        SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: _LibraryPlaylistCard(
                            playlist: playlist,
                            fitLabel: _fitLabel(playlist),
                            fitColor: _fitColor(playlist),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 22),
            const _LibrarySectionLabel(
              title: 'Recently played',
              trailing: 'Jump back in',
            ),
            const SizedBox(height: 12),
            if (_recentlyPlayed.isEmpty)
              const _LibraryEmptyState(
                title: 'Nothing played recently',
                message: 'Start a session from a playlist and it will show up here.',
              )
            else
              SizedBox(
                height: 152,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentlyPlayed.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final playlist = _recentlyPlayed[index];
                    return _LibraryRecentCard(
                      playlist: playlist,
                      fitLabel: _fitLabel(playlist),
                    );
                  },
                ),
              ),
          ] else
            const _LibraryEmptyState(
              title: 'Your library is waiting',
              message: 'Connect Spotify playlists to build your tempo library.',
            ),
        ],
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.userCadence});

  final int userCadence;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Library',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tempo-ready playlists around $userCadence steps/min',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const _LibraryIconButton(icon: Icons.search_rounded),
        const SizedBox(width: 8),
        const _LibraryIconButton(icon: Icons.tune_rounded),
      ],
    );
  }
}

class _LibraryIconButton extends StatelessWidget {
  const _LibraryIconButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: AppColors.textPrimary, size: 22),
    );
  }
}

class _LibraryFilterChip extends StatelessWidget {
  const _LibraryFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBright.withValues(alpha: 0.35)
                : AppColors.border,
          ),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryBright],
                )
              : null,
          color: isSelected ? null : AppColors.surface,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.background : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LibraryHeroCard extends StatelessWidget {
  const _LibraryHeroCard({
    required this.playlist,
    required this.fitLabel,
    required this.fitColor,
  });

  final _LibraryPlaylist playlist;
  final String fitLabel;
  final Color fitColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            playlist.colors.first.withValues(alpha: 0.95),
            playlist.colors.last.withValues(alpha: 0.90),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LibraryCoverArt(
            playlist: playlist,
            size: 112,
            borderRadius: 26,
            icon: Icons.queue_music_rounded,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pinned for your pace',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  playlist.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _LibraryPill(
                      label: '${playlist.bpm} BPM',
                      background: AppColors.background.withValues(alpha: 0.24),
                    ),
                    _LibraryPill(
                      label: '${playlist.trackCount} tracks',
                      background: AppColors.background.withValues(alpha: 0.18),
                    ),
                    _LibraryPill(
                      label: fitLabel,
                      background: fitColor.withValues(alpha: 0.22),
                      textColor: fitColor == AppColors.textMuted
                          ? AppColors.textPrimary
                          : fitColor,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Start session',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${playlist.durationMinutes} min of steady tempo',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryPlaylistCard extends StatelessWidget {
  const _LibraryPlaylistCard({
    required this.playlist,
    required this.fitLabel,
    required this.fitColor,
  });

  final _LibraryPlaylist playlist;
  final String fitLabel;
  final Color fitColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _LibraryCoverArt(
            playlist: playlist,
            size: 84,
            borderRadius: 22,
            icon: playlist.category == 'Running'
                ? Icons.directions_run_rounded
                : Icons.directions_walk_rounded,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _LibraryPill(label: '${playlist.bpm} BPM'),
                    _LibraryPill(label: playlist.category),
                    _LibraryPill(
                      label: fitLabel,
                      background: fitColor.withValues(alpha: 0.14),
                      textColor: fitColor == AppColors.textMuted
                          ? AppColors.textPrimary
                          : fitColor,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${playlist.trackCount} tracks • ${playlist.durationMinutes} min',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryRecentCard extends StatelessWidget {
  const _LibraryRecentCard({
    required this.playlist,
    required this.fitLabel,
  });

  final _LibraryPlaylist playlist;
  final String fitLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LibraryCoverArt(
            playlist: playlist,
            size: 72,
            borderRadius: 20,
            icon: Icons.play_arrow_rounded,
          ),
          const Spacer(),
          Text(
            playlist.title,
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
            fitLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryCoverArt extends StatelessWidget {
  const _LibraryCoverArt({
    required this.playlist,
    required this.size,
    required this.borderRadius,
    required this.icon,
  });

  final _LibraryPlaylist playlist;
  final double size;
  final double borderRadius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: playlist.colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -6,
            child: Icon(
              icon,
              size: size * 0.62,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Text(
              '${playlist.bpm}',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: size * 0.20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryPill extends StatelessWidget {
  const _LibraryPill({
    required this.label,
    this.background,
    this.textColor,
  });

  final String label;
  final Color? background;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LibrarySectionLabel extends StatelessWidget {
  const _LibrarySectionLabel({
    required this.title,
    required this.trailing,
  });

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
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

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.library_music_rounded,
            color: AppColors.textSecondary,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryPlaylist {
  const _LibraryPlaylist({
    required this.title,
    required this.subtitle,
    required this.bpm,
    required this.trackCount,
    required this.durationMinutes,
    required this.category,
    required this.mood,
    required this.colors,
    this.isPinned = false,
    this.wasRecentlyPlayed = false,
  });

  final String title;
  final String subtitle;
  final int bpm;
  final int trackCount;
  final int durationMinutes;
  final String category;
  final String mood;
  final List<Color> colors;
  final bool isPinned;
  final bool wasRecentlyPlayed;
}
