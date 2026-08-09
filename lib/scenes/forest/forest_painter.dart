import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/forest_palette.dart';

/// Moonlit lakeside — dark pines, cool water, a path of moonlight.
/// Soft breath. Green fireflies for shared presence.
class ForestPainter extends CustomPainter {
  ForestPainter({
    required this.t,
    this.presenceCount = 0,
    this.mossCount = 0,
    this.mossReveal = 1,
    this.mossErase = 0,
  });

  final double t;
  final int presenceCount;
  final int mossCount;
  final double mossReveal;
  final double mossErase;

  static const breathPeriod = 5.5;
  static const mossEraseSeconds = 1.15;
  static const mossPauseSeconds = 0.28;
  static const mossWriteSeconds = 1.35;
  static const presenceSparkMax = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final breath = 0.5 + 0.5 * math.sin(t * (math.pi * 2 / breathPeriod));
    final wind = math.sin(t * 0.1) * 0.4 + math.sin(t * 0.04) * 0.5;
    final moon = Offset(size.width * 0.5, size.height * 0.16);
    final waterTop = size.height * 0.48;
    final shoreY = size.height * 0.58;
    // Slight underlap so the join stays seamless — no raised bank.
    final waterBottom = shoreY + size.height * 0.02;

    _paintNightSky(canvas, size, breath: breath);
    _paintStars(canvas, size, breath: breath);
    _paintMoon(canvas, size, moon: moon, breath: breath);
    _paintNightClouds(canvas, size, moon: moon);

    // Soft mass behind pines — fills gaps without a black wall.
    _paintForestBackfill(canvas, size);

    _paintPineBand(
      canvas,
      size,
      baseY: size.height * 0.36,
      height: size.height * 0.14,
      color: ForestPalette.pineFar,
      seed: 3,
      density: 20,
      wind: wind * 0.12,
      fade: 0.2,
    );
    _paintPineBand(
      canvas,
      size,
      baseY: size.height * 0.40,
      height: size.height * 0.16,
      color: ForestPalette.pineMid,
      seed: 7,
      density: 19,
      wind: wind * 0.2,
      fade: 0.08,
    );
    // Far bank under the pines — soil, not cool gray mist.
    _paintBankStrip(canvas, size, y: size.height * 0.43, h: size.height * 0.07);
    _paintPineBand(
      canvas,
      size,
      baseY: size.height * 0.45,
      height: size.height * 0.12,
      color: ForestPalette.pineNear,
      seed: 11,
      density: 17,
      wind: wind * 0.28,
      fade: 0.0,
    );

    _paintLake(
      canvas,
      size,
      waterTop: waterTop,
      waterBottom: waterBottom,
      shoreY: shoreY,
      moon: moon,
      breath: breath,
      wind: wind,
    );
    _paintPresenceOnWater(
      canvas,
      size,
      waterTop: waterTop,
      waterBottom: shoreY,
      breath: breath,
      wind: wind,
    );
    _paintMist(canvas, size, y: waterTop + 8, strength: 0.22, breath: breath);

    _paintNearShore(canvas, size, startY: shoreY, wind: wind);
    _paintShorePlants(canvas, size, wind: wind);
    _paintRocks(canvas, size, breath: breath);

    _paintPresenceSpirits(canvas, size, breath: breath);
    _paintComfortGlow(canvas, size, breath);
    _paintVignette(canvas, size, breath);
  }

  void _paintNightSky(Canvas canvas, Size size, {required double breath}) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, size.height * 0.55),
          [
            ForestPalette.skyTop,
            ForestPalette.skyMid,
            Color.lerp(
              ForestPalette.skyHorizon,
              ForestPalette.moonGlow,
              0.08 + breath * 0.04,
            )!,
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
  }

  void _paintStars(Canvas canvas, Size size, {required double breath}) {
    final rng = math.Random(91);
    for (var i = 0; i < 20; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.42;
      final twinkle =
          0.45 +
          0.55 *
              math
                  .pow(
                    (0.5 + 0.5 * math.sin(t * (0.4 + rng.nextDouble()) + i))
                        .clamp(0.0, 1.0),
                    1.5,
                  )
                  .toDouble();
      final r = 0.4 + rng.nextDouble() * 1.1;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = ForestPalette.star.withValues(
            alpha: (0.25 + twinkle * 0.55) * (0.85 + breath * 0.15),
          ),
      );
    }
  }

  void _paintMoon(
    Canvas canvas,
    Size size, {
    required Offset moon,
    required double breath,
  }) {
    final r = size.shortestSide * (0.055 + breath * 0.004);

    canvas.drawCircle(
      moon,
      r * 7.5,
      Paint()
        ..shader = ui.Gradient.radial(moon, r * 7.5, [
          ForestPalette.moonHalo.withValues(alpha: 0.45 + breath * 0.1),
          ForestPalette.moonHalo.withValues(alpha: 0.0),
        ]),
    );
    canvas.drawCircle(
      moon,
      r * 2.6,
      Paint()
        ..shader = ui.Gradient.radial(moon, r * 2.6, [
          ForestPalette.moonGlow.withValues(alpha: 0.7),
          ForestPalette.moonGlow.withValues(alpha: 0.0),
        ]),
    );
    canvas.drawCircle(
      moon,
      r,
      Paint()
        ..shader = ui.Gradient.radial(moon, r, const [
          ForestPalette.moonCore,
          ForestPalette.moonGlow,
        ]),
    );
  }

  void _paintNightClouds(Canvas canvas, Size size, {required Offset moon}) {
    final clouds = <({double u, double v, double s})>[
      (u: 0.28, v: 0.14, s: 1.1),
      (u: 0.62, v: 0.12, s: 0.9),
      (u: 0.78, v: 0.18, s: 0.75),
    ];
    for (final c in clouds) {
      final cx = size.width * c.u + math.sin(t * 0.025 + c.u) * 3;
      final cy = size.height * c.v;
      final rx = size.width * 0.1 * c.s;
      final ry = size.height * 0.025 * c.s;
      // Backlit edge near moon.
      final nearMoon = (Offset(cx, cy) - moon).distance / size.shortestSide;
      final glow = (1.0 - nearMoon.clamp(0.0, 1.0)) * 0.35;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: rx * 2.2,
          height: ry * 2,
        ),
        Paint()
          ..color = ForestPalette.cloud
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      if (glow > 0.05) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy - ry * 0.3),
            width: rx * 1.4,
            height: ry,
          ),
          Paint()
            ..color = ForestPalette.moonGlow.withValues(alpha: glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }
  }

  void _paintMist(
    Canvas canvas,
    Size size, {
    required double y,
    required double strength,
    required double breath,
  }) {
    canvas.drawRect(
      Rect.fromLTWH(0, y - size.height * 0.04, size.width, size.height * 0.12),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y - size.height * 0.04),
          Offset(0, y + size.height * 0.08),
          [
            ForestPalette.mist.withValues(alpha: 0.0),
            ForestPalette.mist.withValues(
              alpha: strength * (0.7 + breath * 0.2),
            ),
            ForestPalette.mist.withValues(alpha: 0.0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  /// Soft fill behind pines — closes gaps without crushing the night.
  void _paintForestBackfill(Canvas canvas, Size size) {
    final path = Path()..moveTo(-20, size.height * 0.5);
    const n = 28;
    for (var i = 0; i <= n; i++) {
      final u = i / n;
      final x = -20 + (size.width + 40) * u;
      final y =
          size.height *
          (0.30 +
              0.05 * math.sin(u * math.pi * 3.2) +
              0.02 * math.sin(u * math.pi * 7));
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width + 20, size.height * 0.5)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.28),
          Offset(0, size.height * 0.48),
          [
            ForestPalette.pineFar.withValues(alpha: 0.62),
            ForestPalette.pineMid.withValues(alpha: 0.8),
            ForestPalette.pineNear.withValues(alpha: 0.88),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
  }

  void _paintBankStrip(
    Canvas canvas,
    Size size, {
    required double y,
    required double h,
  }) {
    final path = Path()..moveTo(-10, y + h);
    const n = 28;
    for (var i = 0; i <= n; i++) {
      final u = i / n;
      path.lineTo(
        -10 + (size.width + 20) * u,
        y + math.sin(u * math.pi * 3) * h * 0.12,
      );
    }
    path
      ..lineTo(size.width + 10, y + h)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y),
          Offset(0, y + h),
          [
            Color.lerp(ForestPalette.bankLit, ForestPalette.bankMoon, 0.2)!,
            ForestPalette.bank,
            ForestPalette.bankDeep,
          ],
          const [0.0, 0.4, 1.0],
        ),
    );
  }

  void _paintPineBand(
    Canvas canvas,
    Size size, {
    required double baseY,
    required double height,
    required Color color,
    required int seed,
    required int density,
    required double wind,
    required double fade,
  }) {
    final rng = math.Random(seed);
    final washed = Color.lerp(color, ForestPalette.skyHorizon, fade * 0.45)!;
    final lit = Color.lerp(washed, ForestPalette.pineLit, 0.32)!;

    for (var i = 0; i < density; i++) {
      final u = (i + rng.nextDouble() * 0.28) / density;
      final x = size.width * (u * 1.1 - 0.03);
      final h = height * (0.75 + rng.nextDouble() * 0.35);
      final w = size.width * (0.028 + rng.nextDouble() * 0.02) * (h / height);
      final sway = math.sin(t * 0.07 + i * 0.4) * wind * 2.5;
      _pineTree(
        canvas,
        tip: Offset(x + sway, baseY - h),
        base: Offset(x, baseY + height * 0.06),
        halfW: w,
        color: washed,
        lit: lit,
        seed: seed + i,
      );
    }
  }

  void _pineTree(
    Canvas canvas, {
    required Offset tip,
    required Offset base,
    required double halfW,
    required Color color,
    required Color lit,
    required int seed,
  }) {
    final rng = math.Random(seed);
    final h = base.dy - tip.dy;
    final tiers = 3 + rng.nextInt(2);
    for (var ti = 0; ti < tiers; ti++) {
      final u0 = ti / tiers;
      final u1 = (ti + 1) / tiers;
      final top = Offset(tip.dx, tip.dy + h * u0 * 0.92);
      final botY = tip.dy + h * (u1 * 0.85 + 0.12);
      final hw = halfW * (0.45 + u1 * 0.7);
      final path = Path()..moveTo(top.dx, top.dy);
      const steps = 5;
      for (var s = 1; s <= steps; s++) {
        final v = s / steps;
        final jagged = (s.isEven ? 0.72 : 1.0) * hw;
        path.lineTo(tip.dx - jagged, ui.lerpDouble(top.dy, botY, v)!);
      }
      for (var s = steps; s >= 1; s--) {
        final v = s / steps;
        final jagged = (s.isEven ? 0.72 : 1.0) * hw;
        path.lineTo(tip.dx + jagged, ui.lerpDouble(top.dy, botY, v)!);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(tip.dx - hw, top.dy),
            Offset(tip.dx + hw, botY),
            [lit, color, Color.lerp(color, ForestPalette.pineDeep, 0.4)!],
            const [0.0, 0.45, 1.0],
          ),
      );
    }
  }

  void _paintLake(
    Canvas canvas,
    Size size, {
    required double waterTop,
    required double waterBottom,
    required double shoreY,
    required Offset moon,
    required double breath,
    required double wind,
  }) {
    // Flat water plane into the shore — no wavy “hill” lip.
    canvas.drawRect(
      Rect.fromLTRB(-2, waterTop, size.width + 2, waterBottom),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, waterTop),
          Offset(0, shoreY),
          [
            ForestPalette.waterLit,
            ForestPalette.water,
            ForestPalette.waterDeep,
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Soft pine reflections across the water.
    final rng = math.Random(29);
    final waterMidH = shoreY - waterTop;
    for (var i = 0; i < 8; i++) {
      final x = size.width * (0.1 + rng.nextDouble() * 0.8);
      final h = waterMidH * (0.3 + rng.nextDouble() * 0.3);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, waterTop + h * 0.4),
          width: size.width * 0.04,
          height: h,
        ),
        Paint()
          ..color = ForestPalette.pineDeep.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Moon path — denser shimmering column of light on the water.
    final pathTop = Offset(moon.dx, waterTop + 2);
    final pathBot = Offset(size.width * 0.5, shoreY - 4);
    final path = Path()
      ..moveTo(pathTop.dx - size.width * 0.035, pathTop.dy)
      ..lineTo(pathTop.dx + size.width * 0.035, pathTop.dy)
      ..lineTo(pathBot.dx + size.width * 0.11, pathBot.dy)
      ..lineTo(pathBot.dx - size.width * 0.11, pathBot.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          pathTop,
          pathBot,
          [
            ForestPalette.waterMoon.withValues(alpha: 0.7 + breath * 0.12),
            ForestPalette.waterMoon.withValues(alpha: 0.4),
            ForestPalette.waterMoon.withValues(alpha: 0.08),
          ],
          const [0.0, 0.4, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // Second softer wrap — fills gaps so the path doesn't look sparse.
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          pathTop,
          pathBot,
          [
            ForestPalette.moonCore.withValues(alpha: 0.22 + breath * 0.06),
            ForestPalette.moonGlow.withValues(alpha: 0.1),
            ForestPalette.moonGlow.withValues(alpha: 0.0),
          ],
          const [0.0, 0.5, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Shimmer flecks along the moon path — denser.
    for (var i = 0; i < 32; i++) {
      final u = i / 31;
      final x =
          ui.lerpDouble(pathTop.dx, pathBot.dx, u)! +
          math.sin(t * 0.9 + i * 1.1) * (3 + u * 12) * (0.4 + wind.abs());
      final y = ui.lerpDouble(pathTop.dy, pathBot.dy, u)!;
      final twinkle =
          0.35 +
          0.65 *
              math
                  .pow(
                    (0.5 + 0.5 * math.sin(t * 1.4 + i * 0.7)).clamp(0.0, 1.0),
                    1.8,
                  )
                  .toDouble();
      canvas.drawCircle(
        Offset(x, y),
        1.0 + u * 1.6,
        Paint()
          ..color = ForestPalette.moonCore.withValues(
            alpha: (0.22 + twinkle * 0.5) * (1 - u * 0.25),
          ),
      );
    }

    // Soft horizontal ripples.
    for (var row = 0; row < 7; row++) {
      final u = row / 6;
      final y = ui.lerpDouble(waterTop + 10, shoreY - 10, u)!;
      final amp = 0.8 + u * 1.8;
      final rip = Path();
      const cols = 36;
      for (var c = 0; c <= cols; c++) {
        final x = size.width * c / cols;
        final yy =
            y +
            math.sin(c / cols * math.pi * 4 + t * 0.25 + row) *
                amp *
                (0.5 + wind.abs());
        if (c == 0) {
          rip.moveTo(x, yy);
        } else {
          rip.lineTo(x, yy);
        }
      }
      canvas.drawPath(
        rip,
        Paint()
          ..color = ForestPalette.waterFoam.withValues(alpha: 0.06 + u * 0.08)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _paintNearShore(
    Canvas canvas,
    Size size, {
    required double startY,
    required double wind,
  }) {
    // Soft edge that sits on the water — tiny undulation, no ridge.
    final path = Path()..moveTo(-20, size.height + 10);
    const n = 40;
    for (var i = 0; i <= n; i++) {
      final u = i / n;
      final x = -20 + (size.width + 40) * u;
      final y =
          startY -
          size.height * 0.006 +
          size.height * 0.008 * math.sin(u * math.pi * 1.6) +
          size.height * 0.003 * math.sin(u * math.pi * 3.4 + t * 0.05) * wind;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width + 20, size.height + 10)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, startY - size.height * 0.01),
          Offset(0, size.height),
          [
            Color.lerp(ForestPalette.waterDeep, ForestPalette.bank, 0.55)!,
            ForestPalette.bank,
            ForestPalette.bankDeep,
            ForestPalette.shadeDeep,
          ],
          const [0.0, 0.12, 0.48, 1.0],
        ),
    );

    // Soft seam blend — kills any leftover gap without building a bank.
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        startY - size.height * 0.02,
        size.width,
        size.height * 0.04,
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, startY - size.height * 0.02),
          Offset(0, startY + size.height * 0.02),
          [
            ForestPalette.waterDeep.withValues(alpha: 0.0),
            ForestPalette.waterDeep.withValues(alpha: 0.35),
            ForestPalette.bank.withValues(alpha: 0.0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  /// Soft rounded shore stones — irregular, not mirrored.
  void _paintRocks(Canvas canvas, Size size, {required double breath}) {
    // Left: heavier cluster, varied sizes.
    _boulder(
      canvas,
      center: Offset(size.width * 0.08, size.height * 0.84),
      rx: size.width * 0.14,
      ry: size.height * 0.09,
      litSide: 1,
    );
    _boulder(
      canvas,
      center: Offset(size.width * 0.2, size.height * 0.9),
      rx: size.width * 0.08,
      ry: size.height * 0.05,
      litSide: 1,
    );
    _boulder(
      canvas,
      center: Offset(size.width * 0.05, size.height * 0.94),
      rx: size.width * 0.055,
      ry: size.height * 0.032,
      litSide: 1,
    );

    // Right: fewer, differently placed — no mirror of the left.
    _boulder(
      canvas,
      center: Offset(size.width * 0.91, size.height * 0.86),
      rx: size.width * 0.11,
      ry: size.height * 0.07,
      litSide: -1,
    );
    _boulder(
      canvas,
      center: Offset(size.width * 0.8, size.height * 0.93),
      rx: size.width * 0.065,
      ry: size.height * 0.038,
      litSide: -1,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.12, size.height * 0.8),
        width: size.width * 0.07,
        height: size.height * 0.03,
      ),
      Paint()
        ..color = ForestPalette.moonGlow.withValues(alpha: 0.07 + breath * 0.03)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  void _boulder(
    Canvas canvas, {
    required Offset center,
    required double rx,
    required double ry,
    required int litSide,
  }) {
    final path = Path();
    const n = 20;
    for (var i = 0; i <= n; i++) {
      final a = (i / n) * math.pi * 2 - math.pi / 2;
      final bump = 1.0 + 0.06 * math.sin(a * 3 + center.dx * 0.01);
      final x = center.dx + math.cos(a) * rx * bump;
      final y = center.dy + math.sin(a) * ry * bump;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx - litSide * rx * 0.5, center.dy - ry * 0.4),
          Offset(center.dx + litSide * rx * 0.5, center.dy + ry * 0.5),
          [ForestPalette.rockLit, ForestPalette.rock, ForestPalette.rockDeep],
          const [0.0, 0.4, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + ry * 0.55),
        width: rx * 1.5,
        height: ry * 0.35,
      ),
      Paint()
        ..color = ForestPalette.shadeDeep.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  /// Quiet grass — irregular pockets, including the far edges.
  void _paintShorePlants(Canvas canvas, Size size, {required double wind}) {
    // kind: 0 short tuft, 1 tall reed, 2 thin sparse, 3 low carpet.
    final clumps = <({double u, double v, double s, int kind, int seed})>[
      // Far left edge.
      (u: 0.12, v: 0.70, s: 0.48, kind: 1, seed: 41),
      (u: 0.16, v: 0.66, s: 0.4, kind: 2, seed: 43),
      (u: 0.18, v: 0.74, s: 0.38, kind: 0, seed: 47),

      // Sparse mid scatter.
      (u: 0.30, v: 0.64, s: 0.48, kind: 1, seed: 49),
      (u: 0.40, v: 0.72, s: 0.36, kind: 2, seed: 51),
      (u: 0.48, v: 0.68, s: 0.32, kind: 0, seed: 53),
      (u: 0.36, v: 0.84, s: 0.34, kind: 3, seed: 57),
      (u: 0.56, v: 0.76, s: 0.38, kind: 0, seed: 65),
      (u: 0.62, v: 0.66, s: 0.42, kind: 2, seed: 67),
      (u: 0.68, v: 0.80, s: 0.36, kind: 1, seed: 71),

      // Far right edge.
      (u: 0.84, v: 0.68, s: 0.42, kind: 2, seed: 79),
      (u: 0.88, v: 0.72, s: 0.46, kind: 1, seed: 77),
      (u: 0.82, v: 0.78, s: 0.36, kind: 0, seed: 83),
    ];

    for (final clump in clumps) {
      if (_grassHitsRock(clump.u, clump.v)) continue;

      final rng = math.Random(clump.seed);
      final cx = size.width * clump.u;
      final cy = size.height * clump.v;
      final lean =
          math.sin(t * 0.28 + clump.u * 3 + clump.seed * 0.1) *
          wind *
          (clump.kind == 1 ? 0.12 : 0.07);
      final moonCatch = (1.0 - (clump.u - 0.5).abs() * 1.4).clamp(0.35, 1.0);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy + 2),
          width: size.width * (clump.kind == 3 ? 0.04 : 0.028) * clump.s,
          height: size.height * (clump.kind == 3 ? 0.008 : 0.006) * clump.s,
        ),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, cy),
            size.width * 0.022 * clump.s,
            [
              ForestPalette.grassLit.withValues(alpha: 0.16 * moonCatch),
              ForestPalette.grass.withValues(alpha: 0.1),
              ForestPalette.grass.withValues(alpha: 0.0),
            ],
            const [0.0, 0.55, 1.0],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
      );

      final blades = switch (clump.kind) {
        1 => 3 + rng.nextInt(2),
        2 => 2 + rng.nextInt(2),
        3 => 5 + rng.nextInt(4),
        _ => 4 + rng.nextInt(3),
      };
      final spreadMul = switch (clump.kind) {
        1 => 0.4,
        2 => 0.85,
        3 => 1.0,
        _ => 0.65,
      };
      final lenMul = switch (clump.kind) {
        1 => 1.25,
        2 => 0.95,
        3 => 0.5,
        _ => 0.85,
      };
      final strokeMul = switch (clump.kind) {
        1 => 0.7,
        2 => 0.45,
        3 => 0.55,
        _ => 0.6,
      };

      for (var i = 0; i < blades; i++) {
        final spread =
            (i / math.max(blades - 1, 1) - 0.5) * spreadMul +
            (rng.nextDouble() - 0.5) * 0.06;
        final a = spread + (rng.nextDouble() - 0.5) * 0.08;
        final len =
            size.height * (0.016 + rng.nextDouble() * 0.012) * clump.s * lenMul;
        final base = Offset(cx + spread * size.width * 0.012, cy);
        final tip = Offset(
          cx + math.sin(a + lean) * len * (clump.kind == 1 ? 0.35 : 0.5),
          cy - len * (0.85 + rng.nextDouble() * 0.15),
        );
        final mid = Offset(
          cx + math.sin(a + lean * 0.5) * len * 0.22,
          cy - len * 0.45,
        );
        canvas.drawPath(
          Path()
            ..moveTo(base.dx, base.dy)
            ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy),
          Paint()
            ..shader = ui.Gradient.linear(
              base,
              tip,
              [
                ForestPalette.grass.withValues(alpha: 0.5),
                ForestPalette.grassLit.withValues(
                  alpha: 0.4 + moonCatch * 0.18,
                ),
                ForestPalette.grassMoon.withValues(
                  alpha: 0.12 + moonCatch * 0.16,
                ),
              ],
              const [0.0, 0.55, 1.0],
            )
            ..strokeWidth = (0.55 + rng.nextDouble() * 0.35) * strokeMul
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  /// True when a grass clump would sit on a shore boulder.
  bool _grassHitsRock(double u, double v) {
    const rocks = <(double u, double v, double ru, double rv)>[
      (0.08, 0.84, 0.15, 0.10),
      (0.20, 0.90, 0.09, 0.06),
      (0.05, 0.94, 0.07, 0.04),
      (0.91, 0.86, 0.12, 0.08),
      (0.80, 0.93, 0.08, 0.05),
    ];
    for (final r in rocks) {
      final du = (u - r.$1) / r.$3;
      final dv = (v - r.$2) / r.$4;
      if (du * du + dv * dv < 1.0) return true;
    }
    return false;
  }

  void _paintComfortGlow(Canvas canvas, Size size, double breath) {
    final seat = Offset(size.width * 0.5, size.height * 0.9);
    final radius = size.shortestSide * (0.45 + breath * 0.03);
    canvas.drawCircle(
      seat,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(seat, radius, [
          ForestPalette.comfort.withValues(alpha: 0.12 + breath * 0.05),
          ForestPalette.comfort.withValues(alpha: 0.0),
        ]),
    );
  }

  void _paintVignette(Canvas canvas, Size size, double breath) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.45),
          size.longestSide * 0.78,
          [
            const Color(0x00000000),
            ForestPalette.shadeDeep.withValues(alpha: 0.08 + breath * 0.03),
            ForestPalette.shadeDeep.withValues(alpha: 0.35),
          ],
          const [0.4, 0.78, 1.0],
        ),
    );
  }

  /// Quiet count floating on the moonlit water —
  /// noticed when you look, not when you rest.
  void _paintPresenceOnWater(
    Canvas canvas,
    Size size, {
    required double waterTop,
    required double waterBottom,
    required double breath,
    required double wind,
  }) {
    if (mossCount <= 0) return;
    if (mossReveal < 0.01 && mossErase > 0.99) return;

    final label = _formatPresence(mossCount);
    final baseOpacity = 0.22 + breath * 0.05;
    final fontSize = size.shortestSide * 0.062;
    final hand = math.Random(mossCount * 31 + 7);
    // Right half of the lake, centered in that half.
    final anchor = Offset(
      size.width * 0.75,
      ui.lerpDouble(waterTop, waterBottom, 0.5)! +
          math.sin(t * 0.12) * wind * 0.6,
    );

    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    // Softly angled on the water — part of the surface, not a label.
    canvas.rotate(-0.14);
    canvas.skew(-0.16, 0.04);
    canvas.scale(1.04, 0.6);

    final marks =
        <
          ({
            String ch,
            double gap,
            double sizeMul,
            double wobbleY,
            double wobbleRot,
            double phase,
          })
        >[];
    for (var i = 0; i < label.length; i++) {
      marks.add((
        ch: label[i],
        gap: i == 0 ? 0.0 : fontSize * (0.08 + hand.nextDouble() * 0.08),
        sizeMul: 0.96 + hand.nextDouble() * 0.08,
        wobbleY: (hand.nextDouble() - 0.5) * fontSize * 0.05,
        wobbleRot: (hand.nextDouble() - 0.5) * 0.045,
        phase: hand.nextDouble() * math.pi * 2,
      ));
    }

    final n = marks.length;
    var runWidth = 0.0;
    final painters =
        <({TextPainter glow, TextPainter fill, TextPainter rim})>[];
    for (final m in marks) {
      TextPainter glyph(Color c) => TextPainter(
        text: TextSpan(
          text: m.ch,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: fontSize * m.sizeMul,
            fontWeight: FontWeight.w400,
            height: 1,
            color: c,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final fill = glyph(
        ForestPalette.waterMoon.withValues(alpha: baseOpacity * 0.85),
      );
      painters.add((
        glow: glyph(
          ForestPalette.moonGlow.withValues(alpha: baseOpacity * 0.28),
        ),
        fill: fill,
        rim: glyph(
          ForestPalette.waterLit.withValues(alpha: baseOpacity * 0.35),
        ),
      ));
      runWidth += m.gap + fill.width;
    }

    var x = -runWidth * 0.5;
    for (var i = 0; i < painters.length; i++) {
      final m = marks[i];
      final g = painters[i];
      x += m.gap;

      final writeLocal = (mossReveal * (n + 0.35) - i).clamp(0.0, 1.0);
      final eraseLocal = (mossErase * (n + 0.35) - (n - 1 - i)).clamp(0.0, 1.0);
      final appear = _smooth01(writeLocal);
      final gone = _smooth01(eraseLocal);
      final life = (appear * (1.0 - gone)).clamp(0.0, 1.0);
      if (life < 0.02) {
        x += g.fill.width;
        continue;
      }

      // Wipe becomes a soft ripple smear across the water.
      final smear = gone * (1.0 - gone) * 2.2;
      final smearX = gone * fontSize * 0.3;
      final blur = gone * fontSize * 0.08 + 0.35;

      // Barely there sway — water, not a bouncing badge.
      final rippleY = math.sin(t * 0.55 + m.phase + i * 0.7) * fontSize * 0.016;
      final rippleX = math.sin(t * 0.4 + m.phase) * fontSize * 0.008;
      final rippleRot = math.sin(t * 0.45 + m.phase) * 0.01;

      canvas.save();
      canvas.translate(
        x + g.fill.width * 0.5 + smearX + rippleX,
        m.wobbleY + rippleY + (1.0 - appear) * fontSize * 0.05,
      );
      canvas.rotate(m.wobbleRot + gone * 0.03 + rippleRot);
      canvas.scale(1.0 + (1.0 - appear) * 0.03, appear * 0.92 + 0.08);

      final o = Offset(-g.fill.width * 0.5, -g.fill.height * 0.4);

      canvas.saveLayer(
        Rect.fromLTWH(
          o.dx - fontSize,
          o.dy - fontSize,
          g.fill.width + fontSize * 2,
          g.fill.height + fontSize * 2,
        ),
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, life)
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: blur + smear * 0.5,
            sigmaY: blur * 0.7 + smear * 0.3,
          ),
      );

      if (smear > 0.15) {
        for (var s = 1; s <= 2; s++) {
          final trail = (1.0 - s / 3) * gone * 0.28;
          canvas.saveLayer(
            null,
            Paint()..color = Color.fromRGBO(255, 255, 255, trail),
          );
          final trailO = o.translate(s * fontSize * 0.1, s * 0.2);
          g.fill.paint(canvas, trailO);
          canvas.restore();
        }
      }

      g.glow.paint(canvas, o.translate(0, 0.8));
      g.fill.paint(canvas, o);
      g.rim.paint(canvas, o.translate(-0.25, -0.3));
      canvas.restore();
      canvas.restore();

      x += g.fill.width;
    }

    canvas.restore();
  }

  String _formatPresence(int n) {
    if (n < 1000) return '$n';
    if (n < 10000) {
      final k = n / 1000;
      return k == k.truncateToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return '${(n / 1000).round()}k';
  }

  double _smooth01(double x) => x * x * (3 - 2 * x);

  void _paintPresenceSpirits(
    Canvas canvas,
    Size size, {
    required double breath,
  }) {
    // Always paint the full field for now — count can be sparse early on.
    final n = presenceSparkMax;
    final rng = math.Random(53);

    // Drift freely in mid-air over the lake — not grounded on the shore.
    for (var i = 0; i < n; i++) {
      // Drift mid-air and near the shore — fill the lower night too.
      final homeX = size.width * (0.1 + rng.nextDouble() * 0.8);
      final homeY = size.height * (0.26 + rng.nextDouble() * 0.55);

      final p1 = rng.nextDouble() * math.pi * 2;
      final p2 = rng.nextDouble() * math.pi * 2;
      final p3 = rng.nextDouble() * math.pi * 2;
      final ampX = size.width * (0.04 + rng.nextDouble() * 0.06);
      final ampY = size.height * (0.03 + rng.nextDouble() * 0.05);
      final sx1 = 0.22 + rng.nextDouble() * 0.35;
      final sx2 = 0.55 + rng.nextDouble() * 0.5;
      final sy1 = 0.18 + rng.nextDouble() * 0.3;
      final sy2 = 0.48 + rng.nextDouble() * 0.45;

      // Occasional soft dart — still free, not orbital.
      final dartPhase = rng.nextDouble() * math.pi * 2;
      final dart = math
          .pow(
            (0.5 +
                    0.5 *
                        math.sin(
                          t * (0.15 + rng.nextDouble() * 0.2) + dartPhase,
                        ))
                .clamp(0.0, 1.0),
            9,
          )
          .toDouble();
      final dartDir = rng.nextDouble() * math.pi * 2;
      final dartAmp = size.shortestSide * (0.02 + rng.nextDouble() * 0.03);

      final pos = Offset(
        homeX +
            math.sin(t * sx1 + p1) * ampX +
            math.sin(t * sx2 + p2) * ampX * 0.45 +
            math.cos(dartDir) * dartAmp * dart,
        homeY +
            math.cos(t * sy1 + p2) * ampY +
            math.sin(t * sy2 + p3) * ampY * 0.5 +
            math.sin(dartDir) * dartAmp * dart * 0.7,
      );

      final twinkle =
          0.35 +
          0.65 *
              math
                  .pow(
                    (0.5 +
                            0.5 *
                                math.sin(
                                  t * (0.65 + rng.nextDouble() * 1.0) + p1,
                                ))
                        .clamp(0.0, 1.0),
                    1.8,
                  )
                  .toDouble();
      // Fireflies: readable across the room, soft green halo, clear blink.
      final r = (2.4 + rng.nextDouble() * 2.2) * (0.8 + twinkle * 0.5);
      final alpha = (0.55 + twinkle * 0.45) * (0.88 + breath * 0.12);

      canvas.drawCircle(
        pos,
        r * 3.6,
        Paint()
          ..color = ForestPalette.presence.withValues(alpha: alpha * 0.38)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.8),
      );
      canvas.drawCircle(
        pos,
        r * 1.35,
        Paint()
          ..color = ForestPalette.presenceGlow.withValues(alpha: alpha * 0.95)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.55),
      );
      canvas.drawCircle(
        pos,
        r * 0.48,
        Paint()..color = ForestPalette.presenceCore.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ForestPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.presenceCount != presenceCount ||
      oldDelegate.mossCount != mossCount ||
      oldDelegate.mossReveal != mossReveal ||
      oldDelegate.mossErase != mossErase;
}
