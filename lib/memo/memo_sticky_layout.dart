import 'dart:math' as math;
import 'dart:ui';

import 'memo.dart';

/// Quiet sticky placement — clear of body / ♪ text; spread across free paper.
class MemoStickyPlacer {
  MemoStickyPlacer._();

  /// Resolve pixel top-left for each reply (anchors first, then auto seats).
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
    final inset = sticky * 0.06;
    final maxLeft = math.max(inset, bounds.width - sticky - inset);
    final maxTop = math.max(inset, bounds.height - sticky - inset);

    Offset clampPos(Offset o) => Offset(
          o.dx.clamp(inset, maxLeft),
          o.dy.clamp(inset, maxTop),
        );

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

    final preferGap = sticky * 1.05;
    final minGap = sticky * 0.78;
    final result = List<Offset?>.filled(replies.length, null);
    final occupied = <Offset>[];
    final rng = math.Random(seed);

    Offset? findFreeNear(Offset preferred, int salt) {
      final local = math.Random(seed + salt * 17);
      // Try preferred, then spiral jitter, then random free spots.
      final trials = <Offset>[preferred];
      for (var k = 0; k < 28; k++) {
        final ang = local.nextDouble() * math.pi * 2;
        final rad = sticky * (0.35 + local.nextDouble() * 1.8);
        trials.add(
          clampPos(
            Offset(
              preferred.dx + math.cos(ang) * rad,
              preferred.dy + math.sin(ang) * rad,
            ),
          ),
        );
      }
      for (var k = 0; k < 24; k++) {
        trials.add(
          clampPos(
            Offset(
              inset + local.nextDouble() * (maxLeft - inset),
              inset + local.nextDouble() * (maxTop - inset),
            ),
          ),
        );
      }

      Offset? best;
      var bestScore = -1.0;
      for (final trial in trials) {
        if (coversBlocked(trial)) continue;
        final nearest = occupied.isEmpty
            ? preferGap * 2
            : occupied.map((p) => centerDist(trial, p)).reduce(math.min);
        if (nearest >= preferGap) return trial;
        if (nearest >= minGap && nearest > bestScore) {
          bestScore = nearest;
          best = trial;
        }
      }
      return best;
    }

    // 1) Honored anchors, but nudge if they collide or sit on body text.
    for (var i = 0; i < replies.length; i++) {
      final r = replies[i];
      if (!r.hasAnchor) continue;
      final preferred = clampPos(
        Offset(r.x! * bounds.width, r.y! * bounds.height),
      );
      final placed = findFreeNear(preferred, i) ?? preferred;
      result[i] = placed;
      occupied.add(placed);
    }

    final need = <int>[];
    for (var i = 0; i < replies.length; i++) {
      if (result[i] == null) need.add(i);
    }

    final auto = place(
      bounds: bounds,
      size: size,
      count: need.length,
      seed: seed ^ 0x9e3779b9,
      avoid: avoid,
      lowerBand: lowerBand,
      occupied: occupied,
    );
    for (var j = 0; j < need.length; j++) {
      final o = j < auto.length
          ? auto[j]
          : findFreeNear(
                Offset(maxLeft * (0.2 + rng.nextDouble() * 0.6),
                    maxTop * (0.55 + rng.nextDouble() * 0.35)),
                100 + j,
              ) ??
              Offset(maxLeft * 0.85, maxTop * 0.85);
      result[need[j]] = o;
      occupied.add(o);
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
    final inset = sticky * 0.08;
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

    final preferGap = sticky * 1.05;
    final minGap = sticky * 0.78;
    final placed = [...occupied];

    final seats = <Offset>[];
    void addSeat(double xf, double yf) {
      final o = Offset(
        (bounds.width * xf - sticky * 0.5).clamp(inset, maxLeft),
        (bounds.height * yf - sticky * 0.5).clamp(inset, maxTop),
      );
      if (!coversBlocked(o)) seats.add(o);
    }

    // Scatter across free margins — not one tight strip.
    if (lowerBand) {
      for (var x = 0.14; x <= 0.88; x += 0.12) {
        addSeat(x, 0.62);
        addSeat(x, 0.72);
        addSeat(x, 0.82);
      }
      for (var y = 0.42; y <= 0.88; y += 0.12) {
        addSeat(0.78, y);
        addSeat(0.88, y);
      }
      addSeat(0.10, 0.70);
      addSeat(0.10, 0.82);
    } else {
      for (var y = 0.40; y <= 0.88; y += 0.09) {
        addSeat(0.78, y);
        addSeat(0.88, y);
      }
      for (var x = 0.55; x <= 0.92; x += 0.10) {
        addSeat(x, 0.78);
        addSeat(x, 0.88);
      }
      addSeat(0.70, 0.48);
      addSeat(0.82, 0.52);
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
          (base.dx + (local.nextDouble() - 0.5) * sticky * 0.35)
              .clamp(inset, maxLeft),
          (base.dy + (local.nextDouble() - 0.5) * sticky * 0.35)
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
        pick = best ??
            Offset(
              inset + local.nextDouble() * (maxLeft - inset),
              inset + local.nextDouble() * (maxTop - inset),
            );
      }

      placed.add(pick);
      out.add(pick);
    }

    return out;
  }

  static double sized(double base, int count) => base;
}
