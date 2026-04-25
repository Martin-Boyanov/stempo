class BpmMatchWindow {
  const BpmMatchWindow({required this.min, required this.max});

  final int min;
  final int max;
}

bool bpmMatchesWindow(int bpm, {required int minBpm, required int maxBpm}) {
  for (final window in harmonicBpmWindows(minBpm: minBpm, maxBpm: maxBpm)) {
    if (bpm >= window.min && bpm <= window.max) {
      return true;
    }
  }
  return false;
}

int bpmFitDelta(
  int bpm, {
  required int minBpm,
  required int maxBpm,
  required int targetBpm,
}) {
  final windows = harmonicBpmWindows(minBpm: minBpm, maxBpm: maxBpm);
  var best = 1 << 30;
  for (final window in windows) {
    final clamped = bpm.clamp(window.min, window.max);
    final delta = (bpm - clamped).abs();
    if (delta < best) {
      best = delta;
    }
  }

  final targetDeltas = <int>[
    (bpm - targetBpm).abs(),
    (bpm - (targetBpm ~/ 2)).abs(),
    (bpm - (targetBpm * 2)).abs(),
  ];
  final bestTargetDelta = targetDeltas.reduce((a, b) => a < b ? a : b);
  return best < bestTargetDelta ? best : bestTargetDelta;
}

List<BpmMatchWindow> harmonicBpmWindows({
  required int minBpm,
  required int maxBpm,
}) {
  final normalizedMin = minBpm < maxBpm ? minBpm : maxBpm;
  final normalizedMax = maxBpm > minBpm ? maxBpm : minBpm;
  final windows = <BpmMatchWindow>[
    BpmMatchWindow(min: normalizedMin, max: normalizedMax),
  ];

  final halfMin = normalizedMin ~/ 2;
  final halfMax = normalizedMax ~/ 2;
  if (halfMin > 0 && halfMax >= halfMin) {
    windows.add(BpmMatchWindow(min: halfMin, max: halfMax));
  }

  final doubleMin = normalizedMin * 2;
  final doubleMax = normalizedMax * 2;
  windows.add(BpmMatchWindow(min: doubleMin, max: doubleMax));

  return windows;
}
