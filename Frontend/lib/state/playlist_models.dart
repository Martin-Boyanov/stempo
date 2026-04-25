import 'package:flutter/material.dart';

class TempoPlaylist {
  const TempoPlaylist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    this.spotifyUri,
    required this.bpm,
    required this.trackCount,
    required this.durationMinutes,
    required this.category,
    required this.mood,
    required this.colors,
    this.isPinned = false,
    this.wasRecentlyPlayed = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageAsset;
  final String? spotifyUri;
  final int bpm;
  final int trackCount;
  final int durationMinutes;
  final String category;
  final String mood;
  final List<Color> colors;
  final bool isPinned;
  final bool wasRecentlyPlayed;
}

bool isGeneratedBpmPlaylistTitle(String title) {
  final normalized = title.trim();
  return RegExp(
    r'\d{2,3}\s*-\s*\d{2,3}\s*bpm$',
    caseSensitive: false,
  ).hasMatch(normalized);
}

int? generatedBpmPlaylistMidpoint(String title) {
  final match = RegExp(
    r'(\d{2,3})\s*-\s*(\d{2,3})\s*bpm$',
    caseSensitive: false,
  ).firstMatch(title.trim());
  final minBpm = int.tryParse(match?.group(1) ?? '');
  final maxBpm = int.tryParse(match?.group(2) ?? '');
  if (minBpm == null || maxBpm == null || minBpm > maxBpm) return null;
  return (minBpm + maxBpm) ~/ 2;
}
