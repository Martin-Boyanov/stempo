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
