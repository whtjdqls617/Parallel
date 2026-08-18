import 'dart:math' as math;
import 'dart:ui';

import 'memo.dart';

/// Quiet sticky placement — clear of body / ♪ text; always leave visible seats.
class MemoStickyPlacer {
  MemoStickyPlacer._();

  /// Resolve pixel top-left for each reply (anchors first, auto for the rest).
  static List<Offset> layoutReplies({
    required Size bounds,
    required double size,
    required List<MemoReply> replies,
    required int seed,
    List<Rect> avoid = const [
      Rect.fromLTRB(0.06, 0.08, 0.62, 0.56),
    ],
    bool lowerBand = true,
  }) {
    if (replies.isEmpty) return const [];

    final sticky = size;
    final inset = sticky * 0.08;
    final maxLeft = math.max(inset, bounds.width - sticky - inset);
    final maxTop = math.max(inset, bounds.height - sticky - inset);

    Offset clampPos(Offset o) => Offset(
          o.dx.clamp(inset, maxLeft),
          o.dy.clamp(inset, maxTop),
        );

    final result = List<Offset?>.filled(replies.length, null);
    final occupied = <Offset>[];

    for (var i = 0; i < replies.length; i++) {
      final r = replies[i];
      if (!r.hasAnchor) continue;
      final o = clampPos(
        Offset(r.x! * bounds.width, r.y! * bounds.height),
      );
      result[i] = o;
      occupied.add(o);
    }

    final need = <int>[];
    for (var i = 0; i < replies.length; i++) {
      if (result[i] == null) need.add(i);
    }

    final auto = place(
      bounds: bounds,
      size: size,
      count: need.length,
      seed: seed,
      avoid: avoid,
      lowerBand: lowerBand,
      occupied: occupied,
    );
    for (var j = 0; j < need.length; j++) {
      final o = j < auto.length
          ? auto[j]
          : Offset(maxLeft * 0.9, maxTop * 0.9);
      result[need[j]] = o;
    }

    return [
      for (final o in result) o ?? Offset(maxLeft * 0.5, maxTop * 0.7),
    ];
  }

  /// Top-left positions for [count] stickies of edge [size].
  static List<Offset> place({
    required Size bounds,
    required double size,
    required int count,
    required int seed,
    List<Rect> avoid = const [
      Rect.fromLTRB(0.06, 0.08, 0.62, 0.56),
    ],
    bool lowerBand = true,
    List<Offset> occupied = const [],
  }) {
    if (count <= 0) return const [];

    final sticky = size;
    final inset = sticky * 0.10;
    final maxLeft = math.max(inset, bounds.width - sticky - inset);
    final maxTop = math.max(inset, bounds.height - sticky - inset);

    final blocked = [
      for (final r in avoid)
        Rect.fromLTRB(
          r.left * bounds.width,
          r.top * bounds.height,
          r.right * bounds.width,
          r.bottom * bounds.height,
        ),
    ];

    bool coversBlocked(Offset topLeft) {
      final box = Rect.fromLTWH(topLeft.dx, topLeft.dy, sticky, sticky);
      for (final b in blocked) {
        if (box.overlaps(b.deflate(2))) return true;
      }
      return false;
    }

    double centerDist(Offset a, Offset b) {
      final ca = a.translate(sticky / 2, sticky / 2);
      final cb = b.translate(sticky / 2, sticky / 2);
      return (ca - cb).distance;
    }

    final preferGap = sticky * 0.92;
    final minGap = sticky * 0.72;
    final placed = [...occupied];

    final seats = <Offset>[];
    void addSeat(double xf, double yf) {
      final o = Offset(
        (bounds.width * xf - sticky * 0.5).clamp(inset, maxLeft),
        (bounds.height * yf - sticky * 0.5).clamp(inset, maxTop),
      );
      if (!coversBlocked(o)) seats.add(o);
    }

    if (lowerBand) {
      for (var x = 0.22; x <= 0.70; x += 0.14) {
        addSeat(x, 0.68);
        addSeat(x, 0.76);
      }
      addSeat(0.78, 0.70);
    } else {
      for (var y = 0.46; y <= 0.78; y += 0.10) {
        addSeat(0.82, y);
        addSeat(0.88, y);
      }
      addSeat(0.78, 0.80);
      addSeat(0.86, 0.58);
    }

    if (seats.isEmpty) {
      seats.add(Offset(maxLeft, maxTop));
    }

    final rng = math.Random(seed);
    final order = List<int>.generate(seats.length, (i) => i)..shuffle(rng);
    final out = <Offset>[];

    for (var i = 0; i < count; i++) {
      final local = math.Random(seed + i * 31);

      Offset? pick;
      for (final idx in order) {
        final base = seats[idx];
        final trial = Offset(
          (base.dx + (local.nextDouble() - 0.5) * sticky * 0.05)
              .clamp(inset, maxLeft),
          (base.dy + (local.nextDouble() - 0.5) * sticky * 0.05)
              .clamp(inset, maxTop),
        );
        if (coversBlocked(trial) && seats.length > 1) continue;
        if (placed.every((p) => centerDist(trial, p) >= preferGap)) {
          pick = trial;
          break;
        }
      }

      if (pick == null) {
        var bestScore = -1.0;
        Offset? best;
        for (final idx in order) {
          final base = seats[idx];
          if (coversBlocked(base) && placed.isNotEmpty) continue;
          final nearest = placed.isEmpty
              ? preferGap
              : placed.map((p) => centerDist(base, p)).reduce(math.min);
          if (nearest < minGap) continue;
          if (nearest > bestScore) {
            bestScore = nearest;
            best = base;
          }
        }
        pick = best ?? seats[i % seats.length];
      }

      placed.add(pick);
      out.add(pick);
    }

    return out;
  }

  static double sized(double base, int count) => base;
}
