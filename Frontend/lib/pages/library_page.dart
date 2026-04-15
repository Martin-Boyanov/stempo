import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/mock_playlists.dart';
import '../state/playlist_models.dart';
import '../ui/theme/app_fx.dart';
import '../ui/theme/colors.dart';
import '../ui/widgets/media_cover.dart';
import 'playlist_page.dart';

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
    this.playlists,
    this.profileName,
  });

  final int userCadence;
  final List<TempoPlaylist>? playlists;
  final String? profileName;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  LibraryFilter _selectedFilter = LibraryFilter.all;
  String _searchQuery = '';
  bool _isSearching = false;

  List<TempoPlaylist> get _playlists => widget.playlists ?? const [];

  bool _isBpmSpecificPlaylist(TempoPlaylist playlist) {
    return playlist.title.toLowerCase().contains('bpm');
  }

  List<TempoPlaylist> get _filteredPlaylists {
    final items = _playlists
        .where((playlist) {
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final matches = playlist.title.toLowerCase().contains(query) ||
                playlist.subtitle.toLowerCase().contains(query);
            if (!matches) return false;
          }

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
        })
        .toList(growable: false);

    items.sort((a, b) {
      final fitCompare = _fitRating(a).compareTo(_fitRating(b));
      if (fitCompare != 0) return fitCompare;
      return (a.bpm - widget.userCadence).abs().compareTo(
        (b.bpm - widget.userCadence).abs(),
      );
    });
    return items;
  }

  List<TempoPlaylist> get _curatedPlaylists => _filteredPlaylists
      .where((playlist) => !_isBpmSpecificPlaylist(playlist))
      .toList(growable: false);

  List<TempoPlaylist> get _bpmPlaylists => _filteredPlaylists
      .where(_isBpmSpecificPlaylist)
      .toList(growable: false);

  TempoPlaylist? get _heroPlaylist {
    if (_curatedPlaylists.isEmpty) return null;
    return _curatedPlaylists.cast<TempoPlaylist?>().firstWhere(
      (playlist) => playlist!.isPinned,
      orElse: () => _curatedPlaylists.first,
    );
  }

  List<TempoPlaylist> get _mainPlaylists {
    final hero = _heroPlaylist;
    if (hero == null) return const [];
    return _curatedPlaylists
        .where((playlist) => playlist.id != hero.id)
        .toList(growable: false);
  }

  List<TempoPlaylist> get _recentlyPlayed {
    return _curatedPlaylists
        .where((playlist) => playlist.wasRecentlyPlayed)
        .toList(growable: false);
  }

  Widget _buildPlaylistCollection(List<TempoPlaylist> playlists) {
    if (playlists.isEmpty) {
      return const _LibraryEmptyState(
        title: 'No playlists in this view yet',
        message: 'Connect Spotify playlists to build your tempo library.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        if (!isWide) {
          return Column(
            children: [
              for (var i = 0; i < playlists.length; i++) ...[
                _LibraryPlaylistCard(
                  playlist: playlists[i],
                  fitLabel: _fitLabel(playlists[i]),
                  fitColor: _fitColor(playlists[i]),
                  onTap: () => _openPlaylist(playlists[i]),
                ),
                if (i != playlists.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final playlist in playlists)
              SizedBox(
                width: (constraints.maxWidth - 12) / 2,
                child: _LibraryPlaylistCard(
                  playlist: playlist,
                  fitLabel: _fitLabel(playlist),
                  fitColor: _fitColor(playlist),
                  onTap: () => _openPlaylist(playlist),
                ),
              ),
          ],
        );
      },
    );
  }

  int _fitRating(TempoPlaylist playlist) {
    final difference = (playlist.bpm - widget.userCadence).abs();
    if (difference <= 3) return 0;
    if (difference <= 8) return 1;
    return 2;
  }

  String _fitLabel(TempoPlaylist playlist) {
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

  Color _fitColor(TempoPlaylist playlist) {
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

  void _openPlaylist(TempoPlaylist playlist) {
    context.push(
      '/playlist/${playlist.id}?cadence=${widget.userCadence}',
      extra: PlaylistPageArgs(
        playlist: playlist,
        userCadence: widget.userCadence,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hero = _heroPlaylist;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 172),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LibraryHeader(
                  userCadence: widget.userCadence,
                  profileName: widget.profileName,
                  isSearching: _isSearching,
                  onSearchToggle: () => setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) _searchQuery = '';
                  }),
                  onSearchChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 22),
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
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (_filteredPlaylists.isNotEmpty) ...[
            if (hero != null) ...[
              _LibraryHeroCard(
                playlist: hero,
                fitLabel: _fitLabel(hero),
                fitColor: _fitColor(hero),
                onTap: () => _openPlaylist(hero),
              ),
              const SizedBox(height: 22),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LibrarySectionLabel(
                    title: 'Playlists',
                    trailing: 'Tempo-ready',
                  ),
                  const SizedBox(height: 12),
                  _buildPlaylistCollection(_mainPlaylists),
                  if (_bpmPlaylists.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _LibrarySectionLabel(
                      title: 'BPM playlists',
                      trailing: '${_bpmPlaylists.length} generated',
                    ),
                    const SizedBox(height: 12),
                    _buildPlaylistCollection(_bpmPlaylists),
                  ],
                  const SizedBox(height: 22),
                  const _LibrarySectionLabel(
                    title: 'Recently played',
                    trailing: 'Jump back in',
                  ),
                  const SizedBox(height: 12),
                  if (_recentlyPlayed.isEmpty)
                    const _LibraryEmptyState(
                      title: 'Nothing played recently',
                      message:
                          'Start a session from a playlist and it will show up here.',
                    )
                  else
                    SizedBox(
                      height: 182,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentlyPlayed.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final playlist = _recentlyPlayed[index];
                          return _LibraryRecentCard(
                            playlist: playlist,
                            fitLabel: _fitLabel(playlist),
                            onTap: () => _openPlaylist(playlist),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _LibraryEmptyState(
                title: 'Your library is waiting',
                message: 'Connect Spotify playlists to build your tempo library.',
              ),
            ),
        ],
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.userCadence,
    this.profileName,
    required this.isSearching,
    required this.onSearchToggle,
    required this.onSearchChanged,
  });

  final int userCadence;
  final String? profileName;
  final bool isSearching;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: isSearching
              ? TextField(
                  autofocus: true,
                  onChanged: onSearchChanged,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search library...',
                    hintStyle: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.5),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                  ),
                )
              : Column(
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
                      profileName == null
                          ? 'Tempo-ready playlists around $userCadence steps/min'
                          : '$profileName\'s playlists around $userCadence steps/min',
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
        _LibraryIconButton(
          icon: isSearching ? Icons.close_rounded : Icons.search_rounded,
          onTap: onSearchToggle,
        ),
      ],
    );
  }
}

class _LibraryIconButton extends StatelessWidget {
  const _LibraryIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: AppFx.glassDecoration(
          radius: 18,
          glowColor: AppColors.cinemaRed,
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 22),
      ),
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
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryBright, AppColors.primary],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x661B2420), Color(0x33201F21)],
                ),
          boxShadow: isSelected
              ? AppFx.softGlow(AppColors.primary, strength: 0.18)
              : null,
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
    required this.onTap,
  });

  final TempoPlaylist playlist;
  final String fitLabel;
  final Color fitColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 380;
        final cover = _LibraryCoverArt(
          playlist: playlist,
          size: isCompact ? 96 : 112,
          borderRadius: isCompact ? 24 : 26,
          icon: Icons.queue_music_rounded,
        );

        final content = Column(
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
              maxLines: isCompact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: isCompact ? 24 : 28,
                height: 0.98,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LibraryPill(
                  label: fitLabel,
                  background: fitColor.withValues(alpha: 0.22),
                  textColor: fitColor == AppColors.textMuted
                      ? AppColors.textPrimary
                      : fitColor,
                ),
                _LibraryPill(label: playlist.category),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                    'Open playlist',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: FrostedPanel(
            radius: 32,
            padding: const EdgeInsets.all(20),
            elevated: true,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                playlist.colors.first.withValues(alpha: 0.92),
                playlist.colors.last.withValues(alpha: 0.84),
                AppColors.cinemaRed.withValues(alpha: 0.18),
              ],
            ),
            glowColor: playlist.colors.last,
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cover,
                      const SizedBox(height: 16),
                      content,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cover,
                      const SizedBox(width: 18),
                      Expanded(child: content),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _LibraryPlaylistCard extends StatelessWidget {
  const _LibraryPlaylistCard({
    required this.playlist,
    required this.fitLabel,
    required this.fitColor,
    required this.onTap,
  });

  final TempoPlaylist playlist;
  final String fitLabel;
  final Color fitColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: FrostedPanel(
        radius: 26,
        padding: const EdgeInsets.all(14),
        glowColor: playlist.colors.last,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryRecentCard extends StatelessWidget {
  const _LibraryRecentCard({
    required this.playlist,
    required this.fitLabel,
    required this.onTap,
  });

  final TempoPlaylist playlist;
  final String fitLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: FrostedPanel(
        radius: 24,
        padding: const EdgeInsets.all(12),
        glowColor: playlist.colors.last,
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

  final TempoPlaylist playlist;
  final double size;
  final double borderRadius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return MediaCover(
      imageAsset: playlist.imageAsset,
      size: size,
      borderRadius: borderRadius,
    );
  }
}

class _LibraryPill extends StatelessWidget {
  const _LibraryPill({required this.label, this.background, this.textColor});

  final String label;
  final Color? background;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        boxShadow: background != null
            ? AppFx.softGlow(textColor ?? AppColors.primary, strength: 0.08)
            : null,
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
  const _LibrarySectionLabel({required this.title, required this.trailing});

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
  const _LibraryEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 28,
      padding: const EdgeInsets.all(24),
      glowColor: AppColors.cinemaRed,
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
