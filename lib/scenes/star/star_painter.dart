import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/space_palette.dart';

/// Sitting in open grassland. Looking far into the night sky.
class StarPainter extends CustomPainter {
  StarPainter({
    required this.t,
    this.presenceCount = 0,
    this.sandCount = 0,
    this.sandReveal = 1,
    this.sandErase = 0,
  });

  final double t;
  final int presenceCount;
  final int sandCount;
  final double sandReveal;
  final double sandErase;

  static const breathPeriod = 6.2;
  static const sandEraseSeconds = 1.15;
  static const sandPauseSeconds = 0.28;
  static const sandWriteSeconds = 1.35;

  /// Low horizon — sky dominates like the reference, land is a quiet band.
  static const _landTopFrac = 0.68;
  static const _nearGrassFrac = 0.82;

  @override
  void paint(Canvas canvas, Size size) {
    final breath = 0.5 + 0.5 * math.sin(t * (math.pi * 2 / breathPeriod));

    _paintSky(canvas, size);
    _paintMilkyWay(canvas, size, breath);
    _paintHorizonHaze(canvas, size, breath);
    _paintStars(canvas, size, breath);
    _paintShootingStars(canvas, size);
    _paintSteppe(canvas, size, breath);
    _paintPresenceOnGrass(canvas, size, breath: breath);
    _paintPresenceSpirits(canvas, size, breath: breath);
  }

  void _paintSky(Canvas canvas, Size size) {
    // Full-height soft sky — navy → violet → rose → amber, no hard stops.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, size.height * _landTopFrac),
          const [
            SpacePalette.skyZenith,
            SpacePalette.skyTop,
            SpacePalette.skyMid,
            SpacePalette.skyViolet,
            SpacePalette.skyRose,
            SpacePalette.skyLow,
            SpacePalette.skyHorizon,
          ],
          const [0.0, 0.16, 0.34, 0.52, 0.68, 0.84, 1.0],
        ),
    );
    // Continue below horizon into dark ground softly.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * _landTopFrac, size.width, size.height * (1 - _landTopFrac)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * _landTopFrac),
          Offset(0, size.height),
          const [
            SpacePalette.skyHorizon,
            SpacePalette.earth,
          ],
          const [0.0, 0.35],
        ),
    );
  }

  void _paintMilkyWay(Canvas canvas, Size size, double breath) {
    // Soft diagonal river of light — like a real Milky Way, no hard edges.
    final a = 0.55 + breath * 0.04;

    // Wide veil across the whole sky (full rect → no cut-off seam).
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * -0.05, size.height * 0.42),
          Offset(size.width * 1.05, size.height * 0.04),
          [
            const Color(0x00000000),
            SpacePalette.milkyViolet.withValues(alpha: 0.04 * a),
            SpacePalette.milkyBlue.withValues(alpha: 0.08 * a),
            SpacePalette.milkyCore.withValues(alpha: 0.13 * a),
            SpacePalette.milkyBlue.withValues(alpha: 0.08 * a),
            SpacePalette.milkyViolet.withValues(alpha: 0.04 * a),
            const Color(0x00000000),
          ],
          const [0.0, 0.18, 0.34, 0.5, 0.66, 0.82, 1.0],
        ),
    );

    // Second, slightly tilted core — denser center of the band.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.1, size.height * 0.34),
          Offset(size.width * 0.9, size.height * 0.10),
          [
            const Color(0x00000000),
            SpacePalette.milkySoft.withValues(alpha: 0.05 * a),
            SpacePalette.milkyCore.withValues(alpha: 0.11 * a),
            SpacePalette.milkyWarm.withValues(alpha: 0.07 * a),
            SpacePalette.milkySoft.withValues(alpha: 0.05 * a),
            const Color(0x00000000),
          ],
          const [0.0, 0.25, 0.45, 0.55, 0.75, 1.0],
        ),
    );

    // Soft blooms along the arc — thicken the river naturally.
    final blooms = <(double, double, double, double, Color, double)>[
      (0.20, 0.30, 0.48, 0.20, SpacePalette.milkyViolet, 0.10),
      (0.35, 0.18, 0.42, 0.22, SpacePalette.milkyBlue, 0.11),
      (0.50, 0.16, 0.46, 0.24, SpacePalette.milkyCore, 0.13),
      (0.65, 0.22, 0.40, 0.20, SpacePalette.milkySoft, 0.10),
      (0.78, 0.14, 0.36, 0.18, SpacePalette.milkyBlue, 0.09),
      (0.45, 0.20, 0.28, 0.14, SpacePalette.milkyWarm, 0.08),
      (0.58, 0.18, 0.24, 0.12, SpacePalette.milkyRose, 0.06),
    ];
    for (final b in blooms) {
      final c = Offset(size.width * b.$1, size.height * b.$2);
      final rw = size.width * b.$3;
      final rh = size.height * b.$4;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: rw, height: rh),
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            math.max(rw, rh) * 0.5,
            [
              b.$5.withValues(alpha: b.$6 * a),
              b.$5.withValues(alpha: b.$6 * 0.35 * a),
              b.$5.withValues(alpha: 0),
            ],
            const [0.0, 0.42, 1.0],
          ),
      );
    }

    // Merge pass — blur so blooms don't read as separate ovals.
    for (final p in [
      (0.42, 0.19, 0.7, 0.28),
      (0.68, 0.17, 0.55, 0.24),
    ]) {
      final c = Offset(size.width * p.$1, size.height * p.$2);
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: size.width * p.$3,
          height: size.height * p.$4,
        ),
        Paint()
          ..color = SpacePalette.milkySoft.withValues(alpha: 0.045 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32),
      );
    }

    // Fine dust along the band — milky texture, not a stroke.
    final rng = math.Random(41);
    for (var i = 0; i < 120; i++) {
      final u = rng.nextDouble();
      final x = size.width * (0.05 + u * 0.9);
      final y = size.height * (0.34 - u * 0.22) +
          (rng.nextDouble() - 0.5) * size.height * 0.07;
      if (y > size.height * _landTopFrac * 0.9) continue;
      final tw = 0.5 + 0.5 * math.sin(t * 0.9 + i);
      canvas.drawCircle(
        Offset(x, y),
        0.4 + rng.nextDouble() * 1.1,
        Paint()
          ..color = SpacePalette.milkyCore.withValues(alpha: (0.06 + tw * 0.1) * a),
      );
    }
  }

  void _paintHorizonHaze(Canvas canvas, Size size, double breath) {
    // Soft center bloom — rose then orange, blur only (no rings).
    final cx = size.width * 0.5;
    final cy = size.height * (_landTopFrac - 0.01);
    final a = 0.9 + breath * 0.08;

    void glow(double w, double h, Color color, double alpha, double blur) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * w,
          height: size.height * h,
        ),
        Paint()
          ..color = color.withValues(alpha: alpha * a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }

    glow(1.15, 0.16, SpacePalette.hazeRose, 0.05, 48);
    glow(0.9, 0.13, SpacePalette.hazeWarm, 0.07, 36);
    glow(0.58, 0.09, SpacePalette.hazeGold, 0.09, 26);
    glow(0.34, 0.06, SpacePalette.hazeGlow, 0.1, 18);
  }

  void _paintStars(Canvas canvas, Size size, double breath) {
    final rng = math.Random(77);
    final landTop = size.height * _landTopFrac;
    for (var i = 0; i < 280; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * landTop * 0.98;
      final depth = rng.nextDouble();
      // Only the brightest horizon strip has no stars — rest of sky is filled.
      final skyU = (1.0 - (y / landTop).clamp(0.0, 1.0));
      if (skyU < 0.1) continue;
      // Very slight thin-out at the lowest star band only.
      if (skyU < 0.28 && rng.nextDouble() > 0.72) continue;
      final r = 0.4 + depth * 1.15;
      final personality = rng.nextDouble();
      final restless = personality < 0.7
          ? 0.08 + personality * 0.12
          : 0.2 + personality * 0.18;
      final live = _starLive(t, seed: i, restless: restless);
      final color = switch (i % 5) {
        0 => SpacePalette.starWarm,
        1 => SpacePalette.starBlue,
        _ => SpacePalette.star,
      };

      // Soft night points — readable, not piercing; lower sky even softer.
      final lowSoft = ((skyU - 0.1) / 0.55).clamp(0.0, 1.0);
      final alpha = (0.22 + live * 0.16) + (0.12 + live * 0.08) * lowSoft;
      final glow = (0.35 + live * 0.25) + (0.12 + live * 0.1) * lowSoft;

      canvas.drawCircle(
        Offset(x, y),
        r * (1.7 + glow * 0.5),
        Paint()
          ..color = color.withValues(alpha: (0.03 + 0.04 * glow) * (0.55 + 0.45 * lowSoft))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.8 + glow * 0.8 + (1 - lowSoft) * 0.6),
      );
      canvas.drawCircle(
        Offset(x, y),
        r * (0.85 + 0.1 * lowSoft),
        Paint()..color = color.withValues(alpha: alpha),
      );
    }

    final guides = [
      Offset(size.width * 0.18, size.height * 0.12),
      Offset(size.width * 0.42, size.height * 0.08),
      Offset(size.width * 0.68, size.height * 0.14),
      Offset(size.width * 0.88, size.height * 0.10),
      Offset(size.width * 0.30, size.height * 0.22),
      Offset(size.width * 0.55, size.height * 0.18),
    ];
    for (var i = 0; i < guides.length; i++) {
      final p = guides[i];
      final skyU = (1.0 - (p.dy / landTop).clamp(0.0, 1.0));
      if (skyU < 0.1) continue;
      final live = _starLive(t, seed: 800 + i, restless: 0.25);
      canvas.drawCircle(
        p,
        2.2 + live * 0.8,
        Paint()
          ..color = SpacePalette.starGlow.withValues(alpha: 0.04 + 0.05 * live)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.4 + live * 0.6),
      );
      canvas.drawCircle(
        p,
        1.25,
        Paint()
          ..color = SpacePalette.star.withValues(alpha: 0.42 + live * 0.18),
      );
    }
  }

  /// Soft brightness pulse — stays clearly visible.
  double _starLive(double t, {required int seed, double restless = 1.0}) {
    final a = 0.5 + 0.5 * math.sin(t * (0.11 + (seed % 6) * 0.018) + seed * 0.61);
    final b = 0.5 + 0.5 * math.sin(t * (0.19 + (seed % 4) * 0.012) + seed * 1.17);
    final mixed = 0.62 * a + 0.38 * b;
    final mid = 0.72;
    return (mid + (mixed - mid) * restless).clamp(0.5, 1.0);
  }

  void _paintShootingStars(Canvas canvas, Size size) {
    // Soft but readable trails — between piercing and invisible.
    final landTop = size.height * _landTopFrac * 0.92;
    for (var i = 0; i < 6; i++) {
      final period = 8.2 + i * 3.0 + (i % 3) * 1.1;
      final offset = i * 3.17 + 0.8;
      final local = t + offset;
      final cycle = (local / period).floor();
      final phase = local % period;

      final rng = math.Random(10007 + i * 97 + cycle * 131);
      final fly = 1.5 + rng.nextDouble() * 1.4;
      if (phase > fly) continue;

      final u = (phase / fly).clamp(0.0, 1.0);
      final fade = math.sin(u * math.pi);
      if (fade < 0.05) continue;

      final startX = size.width * (0.02 + rng.nextDouble() * 0.96);
      final startY = size.height * (0.03 + rng.nextDouble() * 0.42);
      final len = size.shortestSide * (0.16 + rng.nextDouble() * 0.26);
      final jitter = (rng.nextDouble() - 0.5) * 0.28;
      final angle = math.pi / 4 + jitter;
      final dx = math.cos(angle) * len;
      final dy = math.sin(angle) * len;

      final head = Offset(startX + dx * u, startY + dy * u);
      if (head.dy > landTop || head.dx < -20 || head.dx > size.width + 20) {
        continue;
      }

      final tailScale = 0.42 + rng.nextDouble() * 0.32;
      final tail = Offset(head.dx - dx * tailScale, head.dy - dy * tailScale);
      final thick = 1.0 + rng.nextDouble() * 1.2;

      final paint = Paint()
        ..shader = ui.Gradient.linear(
          tail,
          head,
          [
            SpacePalette.star.withValues(alpha: 0),
            SpacePalette.starWarm.withValues(alpha: 0.22 * fade),
            SpacePalette.star.withValues(alpha: 0.62 * fade),
          ],
          const [0.0, 0.52, 1.0],
        )
        ..strokeWidth = thick + fade * 0.75
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);

      canvas.drawLine(tail, head, paint);
      canvas.drawCircle(
        head,
        1.4 + fade * (1.0 + thick * 0.3),
        Paint()
          ..color = SpacePalette.star.withValues(alpha: 0.48 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
      );
    }
  }

  void _paintSteppe(Canvas canvas, Size size, double breath) {
    final horizon = size.height * _landTopFrac;
    final near = size.height * _nearGrassFrac;
    final left = -2.0;
    final right = size.width + 2.0;

    final farPts = _ridgePoints(
      size,
      baseY: horizon,
      amp: size.height * 0.028,
      seed: 3,
      left: left,
      right: right,
      hillBias: true,
    );
    final nearPts = _ridgePoints(
      size,
      baseY: near,
      amp: size.height * 0.012,
      seed: 23,
      left: left,
      right: right,
    );
    final farPath = _pathFromPoints(farPts);
    final nearPath = _pathFromPoints(nearPts);

    // Far band — pin to left/right so no side gap.
    final farFill = Path()..moveTo(left, farPts.first.dy);
    for (final p in farPts) {
      farFill.lineTo(p.dx, p.dy);
    }
    farFill.lineTo(right, farPts.last.dy);
    farFill.lineTo(right, nearPts.last.dy);
    for (final p in nearPts.reversed) {
      farFill.lineTo(p.dx, p.dy);
    }
    farFill.lineTo(left, nearPts.first.dy);
    farFill.close();

    final farBounds = farFill.getBounds();
    // Solid dark hill silhouette (reference feel), soft gradient only near the join.
    canvas.drawPath(
      farFill,
      Paint()..color = const Color(0xFF050608),
    );
    canvas.drawPath(
      farFill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, farBounds.top),
          Offset(0, farBounds.bottom),
          [
            const Color(0xFF0A0B0E),
            const Color(0xFF060708),
            const Color(0xFF030405),
          ],
          const [0.0, 0.4, 1.0],
        ),
    );
    // Soft dissolve into sky — no hard ridge cut.
    canvas.drawPath(
      farPath,
      Paint()
        ..color = SpacePalette.hazeRose.withValues(alpha: 0.04 + breath * 0.015)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(
      farPath,
      Paint()
        ..color = SpacePalette.hazeGold.withValues(alpha: 0.05 + breath * 0.02)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Near ochre — edge to edge.
    final nearFill = Path()
      ..moveTo(left, nearPts.first.dy);
    for (final p in nearPts) {
      nearFill.lineTo(p.dx, p.dy);
    }
    nearFill
      ..lineTo(right, nearPts.last.dy)
      ..lineTo(right, size.height + 2)
      ..lineTo(left, size.height + 2)
      ..close();
    canvas.drawPath(
      nearFill,
      Paint()
        ..color = SpacePalette.grassNear.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(
      nearFill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, near - size.height * 0.02),
          Offset(0, size.height),
          const [
            SpacePalette.grassLit,
            SpacePalette.grassNear,
            SpacePalette.earth,
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Sparse blades across the near ground — not just the crest edge.
    final allowed = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTRB(left, 0, right, size.height + 2)),
      farFill,
    );
    canvas.save();
    canvas.clipPath(allowed);
    final rng = math.Random(9);
    final tipPaint = Paint()
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 48; i++) {
      final x = size.width * (0.02 + rng.nextDouble() * 0.96);
      // Spread from just below the near crest down into the lower field.
      final depth = math.pow(rng.nextDouble(), 0.65).toDouble();
      final y = near +
          size.height * 0.02 +
          depth * (size.height - near - size.height * 0.04) +
          math.sin(x * 0.008 + i) * 3;
      final h = 2.2 + rng.nextDouble() * 4.5 + depth * 1.5;
      final lean =
          (rng.nextDouble() - 0.5) * 2.0 + math.sin(t * 0.25 + i) * 0.35;
      final alpha = (0.28 + (1 - depth) * 0.22 + breath * 0.04)
          .clamp(0.2, 0.55);
      tipPaint
        ..color = SpacePalette.grassTip.withValues(alpha: alpha)
        ..strokeWidth = 0.9 + rng.nextDouble() * 0.55;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + lean, y - h),
        tipPaint,
      );
    }
    canvas.restore();
  }

  List<Offset> _ridgePoints(
    Size size, {
    required double baseY,
    required double amp,
    required int seed,
    required double left,
    required double right,
    bool hillBias = false,
  }) {
    final rng = math.Random(seed);
    final pts = <Offset>[];
    pts.add(Offset(left, baseY + math.sin(seed.toDouble()) * amp * 0.2));
    var x = left + size.width * 0.05;
    while (x < right - size.width * 0.04) {
      final u = ((x - left) / (right - left)).clamp(0.0, 1.0);
      // Optional soft hill mound (higher toward left-center, like the reference).
      final hill = hillBias
          ? math.exp(-math.pow((u - 0.32) / 0.22, 2)) * amp * 1.8
          : 0.0;
      final y = baseY -
          hill +
          math.sin(x * 0.006 + seed) * amp * 0.55 +
          math.sin(x * 0.015 + seed * 0.7) * amp * 0.35 +
          (rng.nextDouble() - 0.5) * amp * 0.2;
      pts.add(Offset(x, y));
      x += size.width * (0.055 + rng.nextDouble() * 0.05);
    }
    pts.add(Offset(right, baseY + math.sin(seed + 2.0) * amp * 0.2));
    return pts;
  }

  Path _pathFromPoints(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  void _paintPresenceOnGrass(
    Canvas canvas,
    Size size, {
    required double breath,
  }) {
    if (sandReveal < 0.01 && sandErase > 0.99) return;
    final count = sandCount.clamp(0, 999);
    if (count <= 0 && sandErase < 0.01) return;

    final text = '$count';
    // Right side of the dark hill silhouette — chalk on black mountain.
    final center = Offset(size.width * 0.76, size.height * 0.735);
    final style = TextStyle(
      fontFamily: 'Georgia',
      fontSize: size.shortestSide * 0.052,
      fontWeight: FontWeight.w400,
      letterSpacing: 1.2,
      color: const Color(0xFFD8D0C0).withValues(alpha: 0.38 + breath * 0.1),
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final reveal = sandReveal.clamp(0.0, 1.0);
    final erase = sandErase.clamp(0.0, 1.0);
    canvas.save();
    if (reveal < 0.999) {
      canvas.clipRect(
        Rect.fromLTWH(
          center.dx - tp.width * 0.5,
          center.dy - tp.height * 0.5,
          tp.width * reveal,
          tp.height,
        ),
      );
    }
    if (erase > 0.01) {
      canvas.clipRect(
        Rect.fromLTWH(
          center.dx - tp.width * 0.5 + tp.width * erase,
          center.dy - tp.height * 0.5,
          tp.width * (1 - erase),
          tp.height,
        ),
      );
    }
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    canvas.restore();
  }

  void _paintPresenceSpirits(
    Canvas canvas,
    Size size, {
    required double breath,
  }) {
    final n = presenceCount.clamp(0, 12);
    if (n <= 0) return;
    final rng = math.Random(51);
    for (var i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2 + t * 0.07;
      final radius = size.shortestSide * (0.14 + (i % 3) * 0.03);
      final cx = size.width * 0.55 + math.cos(a) * radius * 0.45;
      final cy = size.height * 0.86 + math.sin(a * 0.6) * radius * 0.12;
      final tw = 0.5 + 0.5 * math.sin(t * 1.1 + i + breath);
      final r = 1.2 + rng.nextDouble() * 1.3;
      canvas.drawCircle(
        Offset(cx, cy),
        r * 3,
        Paint()
          ..color = SpacePalette.presenceGlow.withValues(alpha: 0.07 * tw)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = SpacePalette.presence.withValues(alpha: 0.28 + tw * 0.32),
      );
    }
  }

  @override
  bool shouldRepaint(covariant StarPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.presenceCount != presenceCount ||
      oldDelegate.sandCount != sandCount ||
      oldDelegate.sandReveal != sandReveal ||
      oldDelegate.sandErase != sandErase;
}
