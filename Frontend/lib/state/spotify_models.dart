import 'package:flutter/material.dart';

import 'playlist_models.dart';
import '../ui/theme/colors.dart';

class SpotifyUserProfile {
  const SpotifyUserProfile({
    required this.id,
    required this.displayName,
    this.email,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? email;
  final String? avatarUrl;
}

class SpotifyTrack {
  const SpotifyTrack({
    required this.id,
    required this.title,
    required this.artistLine,
    required this.imageUrl,
    required this.spotifyUri,
    required this.durationMs,
    required this.bpm,
    this.playlistPosition = -1,
  });

  final String id;
  final String title;
  final String artistLine;
  final String imageUrl;
  final String spotifyUri;
  final int durationMs;
  final int bpm;
  final int playlistPosition;
}

class SpotifySearchEntry {
  const SpotifySearchEntry({
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

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final SpotifySearchEntryType type;
  final int? bpm;
  final String useCase;
  final String mood;
  final int durationMinutes;
  final List<String> keywords;
}

enum SpotifySearchEntryType { playlist, track, artist }

TempoPlaylist spotifyPlaylistToTempoPlaylist({
  required String id,
  required String title,
  required String subtitle,
  required String imageUrl,
  required int trackCount,
  required bool isPinned,
  required bool wasRecentlyPlayed,
}) {
  final bpm = _deriveBpm(id, title);
  final category = bpm >= 110 ? 'Running' : 'Walking';
  final mood = _deriveMood(title);
  return TempoPlaylist(
    id: id,
    title: title,
    subtitle: subtitle,
    imageAsset: imageUrl,
    spotifyUri: 'spotify:playlist:$id',
    bpm: bpm,
    trackCount: trackCount,
    durationMinutes: (trackCount * 3.4).round().clamp(12, 140),
    category: category,
    mood: mood,
    colors: _deriveColors(id, title),
    isPinned: isPinned,
    wasRecentlyPlayed: wasRecentlyPlayed,
  );
}

SpotifyTrack spotifyTrackFromJson(
  Map<String, dynamic> trackJson, {
  int playlistPosition = -1,
}) {
  final album = trackJson['album'] as Map<String, dynamic>? ?? const {};
  final images = album['images'] as List<dynamic>? ?? const [];
  final firstImage = images.isNotEmpty ? images.first as Map<String, dynamic>? : null;
  final artists = (trackJson['artists'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map((artist) => artist['name'] as String? ?? '')
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  final id = trackJson['id'] as String? ?? trackJson['uri'] as String? ?? 'track';
  final title = trackJson['name'] as String? ?? 'Track';

  return SpotifyTrack(
    id: id,
    title: title,
    artistLine: artists.isEmpty ? 'Spotify' : artists.join(', '),
    imageUrl: firstImage?['url'] as String? ?? '',
    spotifyUri: trackJson['uri'] as String? ?? '',
    durationMs: (trackJson['duration_ms'] as num?)?.toInt() ?? 0,
    bpm: _deriveBpm(id, title),
    playlistPosition: playlistPosition,
  );
}

SpotifySearchEntry spotifyPlaylistToSearchEntry(TempoPlaylist playlist) {
  return SpotifySearchEntry(
    id: playlist.id,
    title: playlist.title,
    subtitle: playlist.subtitle,
    imageUrl: playlist.imageAsset,
    type: SpotifySearchEntryType.playlist,
    bpm: playlist.bpm,
    useCase: _deriveUseCase(playlist.title, playlist.category),
    mood: playlist.mood,
    durationMinutes: playlist.durationMinutes,
    keywords: [
      playlist.title.toLowerCase(),
      playlist.subtitle.toLowerCase(),
      playlist.category.toLowerCase(),
      playlist.mood.toLowerCase(),
    ],
  );
}

int _deriveBpm(String id, String title) {
  final seed = id.codeUnits.fold<int>(0, (sum, unit) => sum + unit) +
      title.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return 96 + (seed % 26);
}

String _deriveMood(String title) {
  final value = title.toLowerCase();
  if (value.contains('night') || value.contains('dark')) return 'Dark';
  if (value.contains('run') || value.contains('tempo')) return 'Driven';
  if (value.contains('focus') || value.contains('study')) return 'Focused';
  if (value.contains('calm') || value.contains('sleep')) return 'Calm';
  return 'Euphoric';
}

String _deriveUseCase(String title, String category) {
  final value = title.toLowerCase();
  if (value.contains('night')) return 'Night walk';
  if (value.contains('focus') || value.contains('study')) return 'Focus';
  if (value.contains('warm')) return 'Warm up';
  if (value.contains('recover') || value.contains('chill')) return 'Recovery';
  return category == 'Running' ? 'Steady run' : 'Night walk';
}

List<Color> _deriveColors(String id, String title) {
  final seed = id.codeUnits.fold<int>(0, (sum, unit) => sum + unit) +
      title.length * 17;
  final palette = [
    [const Color(0xFF17363A), AppColors.primaryBright],
    [const Color(0xFF1B2331), const Color(0xFF6FE7F2)],
    [const Color(0xFF2A1A26), AppColors.cinemaRed],
    [const Color(0xFF243126), const Color(0xFF8ACB88)],
    [const Color(0xFF261836), const Color(0xFF6B8DFF)],
  ];
  return palette[seed % palette.length];
}
