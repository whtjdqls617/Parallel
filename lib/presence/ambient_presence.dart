import '../memo/memo.dart';

/// Softens the live presence number so an empty room doesn't feel abandoned.
///
/// Real heartbeats still drive the count; this only adds a small, stable
/// companion buffer that fades as more people arrive.
class AmbientPresence {
  AmbientPresence._();

  /// 20-minute buckets so the number doesn't jitter every rebuild.
  static const _bucketMs = 20 * 60 * 1000;

  /// Display count for the scene number / sparks.
  static int display({
    required int live,
    required MemoTheme theme,
    DateTime? now,
  }) {
    final real = live < 1 ? 1 : live;
    final extra = softExtra(live: real, theme: theme, now: now ?? DateTime.now());
    return real + extra;
  }

  /// Extra companions (0–3). Shrinks as real presence grows.
  static int softExtra({
    required int live,
    required MemoTheme theme,
    required DateTime now,
  }) {
    if (live >= 6) return 0;

    final bucket = now.toUtc().millisecondsSinceEpoch ~/ _bucketMs;
    final seed = Object.hash(theme.key, bucket);
    // 1..3 stable within the bucket; theme shifts the feel a little.
    final soft = 1 + (seed.abs() % 3);

    if (live <= 1) return soft; // alone → 2..4
    if (live == 2) return soft >= 2 ? soft - 1 : 1; // → 3..4
    if (live <= 4) return 1; // → 4..5
    return 0;
  }
}
