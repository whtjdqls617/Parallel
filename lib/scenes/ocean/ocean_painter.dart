import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/ocean_palette.dart';

/// Sitting on the beach under a clear afternoon sky.
class OceanPainter extends CustomPainter {
  OceanPainter({
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

  static const breathPeriod = 6.8;
  static const sandEraseSeconds = 1.15;
  static const sandPauseSeconds = 0.28;
  static const sandWriteSeconds = 1.35;
  static const presenceSparkMax = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final breath = 0.5 + 0.5 * math.sin(t * (math.pi * 2 / breathPeriod));
    // Clear afternoon — sun high in a blue sky.
    final sun = Offset(size.width * 0.72, size.height * 0.14);
    final horizon = size.height * 0.40;
    final breakY = size.height * 0.61;
    final shoreY = size.height * 0.66;

    // Wave cycle: rush in, pause, slide back (not a smooth sine).
    // Phase offset matches nature_ocean.wav (loop joins mid-rest).
    final waveClock = t + waveAudioPhaseOffset - waveAudioLeadSeconds;
    final wave = _waveCycle(waveClock);
    final foam = _foamEnvelope(waveClock);

    _paintSky(canvas, size, horizon: horizon, sun: sun, breath: breath);
    _paintSunBloom(canvas, size, sun: sun, breath: breath);
    _paintSunRays(canvas, size, sun: sun, horizon: horizon, breath: breath);
    _paintSun(canvas, size, sun: sun, breath: breath);
    _paintClouds(canvas, size, horizon: horizon, breath: breath);
    _paintSea(
      canvas,
      size,
      horizon: horizon,
      shoreY: shoreY,
      breath: breath,
    );
    _paintDistantYachts(canvas, size, horizon: horizon, breath: breath);
    _paintWaves(
      canvas,
      size,
      horizon: horizon,
      breakY: breakY,
      shoreY: shoreY,
      breath: breath,
      wave: wave,
    );
    _paintSeaSparkles(
      canvas,
      size,
      horizon: horizon,
      breakY: breakY,
      breath: breath,
    );
    // Sand first, then transparent wash on top so the beach shows through.
    _paintShore(canvas, size, shoreY: shoreY, breath: breath);
    _paintWashOverSand(
      canvas,
      size,
      breakY: breakY,
      shoreY: shoreY,
      breath: breath,
      wave: wave,
      foam: foam,
    );
    _paintBeachShells(canvas, size, shoreY: shoreY, breath: breath);
    _paintSandcastle(canvas, size, shoreY: shoreY, breath: breath);
    _paintPresenceInSand(canvas, size, breath: breath);
    _paintPresenceSpirits(canvas, size, breath: breath);
    _paintComfortGlow(canvas, size, breath);
    _paintVignette(canvas, size, breath);
  }

  /// 0 = pulled back, 1 = farthest up the sand.
  /// Soft easeInOut rush + long natural slide back — synced with nature_ocean.wav.
  /// Shared envelope: rush 0–0.18, hold →0.22, drain →0.66, rest →1.0 (16s period).
  /// File starts mid-rest (`waveAudioPhaseOffset`) so native loop joins on quiet bed.
  static const wavePeriodSeconds = 16.0;
  static const waveAudioLeadSeconds = 0.3;
  static const waveAudioPhaseOffset = 0.78 * wavePeriodSeconds;

  double _waveCycle(double time) {
    const period = wavePeriodSeconds;
    final u = ((time % period) + period) % period / period;
    if (u < 0.18) {
      return Curves.easeInOutCubic.transform(u / 0.18);
    }
    if (u < 0.22) {
      return 1;
    }
    if (u < 0.66) {
      // A touch slower than the rush, but not a long linger.
      return 1 - Curves.easeInOut.transform((u - 0.22) / 0.44);
    }
    return 0;
  }

  double _foamEnvelope(double time) {
    const period = wavePeriodSeconds;
    final u = ((time % period) + period) % period / period;
    if (u < 0.18) {
      return Curves.easeOutCubic.transform(u / 0.18);
    }
    if (u < 0.28) {
      return 1;
    }
    final x = ((u - 0.28) / 0.42).clamp(0.0, 1.0);
    return math.pow(1 - Curves.easeInOut.transform(x), 1.6).toDouble();
  }

  void _paintSky(
    Canvas canvas,
    Size size, {
    required double horizon,
    required Offset sun,
    required double breath,
  }) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, horizon),
          [
            OceanPalette.skyTop,
            OceanPalette.skyMid,
            OceanPalette.skyLow,
            OceanPalette.skyHorizon,
          ],
          const [0.0, 0.35, 0.7, 1.0],
        ),
    );

    // Soft daylight brightening near the sun — still blue, hint of yellow.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, horizon),
      Paint()
        ..shader = ui.Gradient.radial(
          sun,
          size.width * 0.55,
          [
            OceanPalette.skyGlow.withValues(alpha: 0.35 + breath * 0.06),
            OceanPalette.skyLow.withValues(alpha: 0.12),
            OceanPalette.skyLow.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  void _paintSunBloom(
    Canvas canvas,
    Size size, {
    required Offset sun,
    required double breath,
  }) {
    canvas.drawCircle(
      sun,
      size.shortestSide * 0.28,
      Paint()
        ..shader = ui.Gradient.radial(
          sun,
          size.shortestSide * 0.28,
          [
            OceanPalette.sunBloom.withValues(alpha: 0.38 + breath * 0.06),
            OceanPalette.sunHalo.withValues(alpha: 0.14),
            OceanPalette.sunHalo.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  /// Soft summer rays fanning from the sun — light, not harsh.
  void _paintSunRays(
    Canvas canvas,
    Size size, {
    required Offset sun,
    required double horizon,
    required double breath,
  }) {
    // Angles fan downward / outward across the sky.
    const rays = <(double angle, double width, double peak)>[
      (-0.55, 0.028, 0.07),
      (-0.32, 0.036, 0.09),
      (-0.12, 0.042, 0.10),
      (0.08, 0.034, 0.08),
      (0.28, 0.04, 0.09),
      (0.48, 0.03, 0.07),
      (0.68, 0.024, 0.055),
    ];

    final length = (horizon - sun.dy) * 1.55;
    for (var i = 0; i < rays.length; i++) {
      final (angle, width, peak) = rays[i];
      // Slow shimmer so rays gently breathe
      final pulse = 0.7 +
          0.3 * math.sin(t * (0.35 + i * 0.07) + i * 1.1) *
              (0.5 + 0.5 * breath);
      final alpha = peak * pulse;
      final half = size.width * width;
      final dir = Offset(math.sin(angle), math.cos(angle));
      final perp = Offset(-dir.dy, dir.dx);
      final tip = sun + dir * length;

      final path = Path()
        ..moveTo(
          sun.dx + perp.dx * half * 0.12,
          sun.dy + perp.dy * half * 0.12,
        )
        ..lineTo(tip.dx + perp.dx * half, tip.dy + perp.dy * half)
        ..lineTo(tip.dx - perp.dx * half, tip.dy - perp.dy * half)
        ..lineTo(
          sun.dx - perp.dx * half * 0.12,
          sun.dy - perp.dy * half * 0.12,
        )
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            sun,
            tip,
            [
              const Color(0xFFFFF2C8).withValues(alpha: alpha * 0.9),
              const Color(0xFFFFE090).withValues(alpha: alpha * 0.35),
              const Color(0xFFFFD878).withValues(alpha: 0),
            ],
            const [0.0, 0.4, 1.0],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }

  void _paintSun(
    Canvas canvas,
    Size size, {
    required Offset sun,
    required double breath,
  }) {
    final r = size.shortestSide * (0.04 + breath * 0.003);
    canvas.drawCircle(
      sun,
      r * 2.6,
      Paint()
        ..color = OceanPalette.sunGlow.withValues(alpha: 0.38 + breath * 0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.9),
    );
    canvas.drawCircle(
      sun,
      r * 1.35,
      Paint()
        ..shader = ui.Gradient.radial(
          sun,
          r * 1.35,
          [
            OceanPalette.sunCore,
            OceanPalette.sunGlow,
            OceanPalette.sunGlow.withValues(alpha: 0),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    canvas.drawCircle(
      sun,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          sun,
          r,
          const [
            Color(0xFFFFFCE8),
            Color(0xFFFFEE88),
            Color(0xFFFFD040),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  void _paintClouds(
    Canvas canvas,
    Size size, {
    required double horizon,
    required double breath,
  }) {
    final rng = math.Random(5);
    for (var i = 0; i < 6; i++) {
      final x = size.width * (0.05 + rng.nextDouble() * 0.9);
      final y = horizon * (0.18 + rng.nextDouble() * 0.55);
      final w = size.width * (0.12 + rng.nextDouble() * 0.22);
      final h = size.height * (0.014 + rng.nextDouble() * 0.02);
      final drift = math.sin(t * 0.03 + i) * size.width * 0.008;
      final lit = y > horizon * 0.45;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + drift, y),
          width: w,
          height: h,
        ),
        Paint()
          ..color = (lit ? OceanPalette.cloudLit : OceanPalette.cloud)
              .withValues(alpha: 0.18 + breath * 0.05 + rng.nextDouble() * 0.1),
      );
    }
  }

  /// Soft natural shoreline — gentle curve, not a ruler-straight cut.
  double _shoreEdgeY(double x, Size size, double shoreY) {
    final n = size.width;
    return shoreY +
        math.sin(x / n * math.pi * 1.8) * size.height * 0.006 +
        math.sin(x / n * math.pi * 4.2 + 0.7) * size.height * 0.0028 +
        math.sin(x / n * math.pi * 7.5 + 1.4) * size.height * 0.0014;
  }

  /// Sample the shore edge left→right, always pinning both screen edges
  /// so the sand never leaves a diagonal gap on the right.
  void _traceShoreEdge(
    Path path,
    Size size,
    double shoreY, {
    double yPad = 0,
  }) {
    path.lineTo(0, _shoreEdgeY(0, size, shoreY) + yPad);
    for (var x = 8.0; x < size.width; x += 8) {
      path.lineTo(x, _shoreEdgeY(x, size, shoreY) + yPad);
    }
    path.lineTo(size.width, _shoreEdgeY(size.width, size, shoreY) + yPad);
  }

  void _paintSea(
    Canvas canvas,
    Size size, {
    required double horizon,
    required double shoreY,
    required double breath,
  }) {
    // Far → near: steadily deeper blue out, steadily paler toward shore.
    final sea = Path()
      ..moveTo(0, horizon)
      ..lineTo(size.width, horizon)
      ..lineTo(size.width, _shoreEdgeY(size.width, size, shoreY) + 2);
    for (var x = size.width - 8; x > 0; x -= 8) {
      sea.lineTo(x, _shoreEdgeY(x, size, shoreY) + 2);
    }
    sea
      ..lineTo(0, _shoreEdgeY(0, size, shoreY) + 2)
      ..close();

    canvas.drawPath(
      sea,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, horizon),
          Offset(size.width * 0.5, shoreY),
          [
            Color.lerp(OceanPalette.waterDeep, OceanPalette.skyHorizon, 0.22)!,
            OceanPalette.waterDeep,
            OceanPalette.water,
            OceanPalette.waterLit,
            OceanPalette.waterWarm,
            OceanPalette.waterShallow,
          ],
          const [0.0, 0.12, 0.32, 0.55, 0.78, 1.0],
        ),
    );
  }

  /// Sail yachts on the far water — soft silhouettes, slow bob.
  void _paintDistantYachts(
    Canvas canvas,
    Size size, {
    required double horizon,
    required double breath,
  }) {
    final yachts = <(double x, double yOff, double scale, double phase)>[
      (0.18, 0.016, 1.55, 0.0),
      (0.42, 0.011, 1.2, 1.7),
      (0.78, 0.022, 1.85, 3.1),
    ];

    for (final (nx, yOff, scale, phase) in yachts) {
      final bob = math.sin(t * 0.28 + phase) * size.height * 0.0009;
      final x = size.width * nx;
      final y = horizon + size.height * yOff + bob;
      _paintYacht(canvas, Offset(x, y), scale: scale, breath: breath);
    }
  }

  void _paintYacht(
    Canvas canvas,
    Offset waterline, {
    required double scale,
    required double breath,
  }) {
    final s = scale;
    final hullW = 28.0 * s;
    final hullH = 5.0 * s;
    final mastH = 22.0 * s;

    final hull = Path()
      ..moveTo(waterline.dx - hullW * 0.48, waterline.dy)
      ..quadraticBezierTo(
        waterline.dx - hullW * 0.1,
        waterline.dy - hullH,
        waterline.dx + hullW * 0.35,
        waterline.dy - hullH * 0.55,
      )
      ..lineTo(waterline.dx + hullW * 0.52, waterline.dy)
      ..close();

    // Soft far haze — almost white, slightly cooled.
    final body = Color.lerp(
      const Color(0xFFE8F4F8),
      OceanPalette.waterWarm,
      0.12,
    )!
        .withValues(alpha: 0.55 + breath * 0.08);
    final sail = const Color(0xFFF8FCFF).withValues(alpha: 0.5 + breath * 0.06);

    canvas.drawPath(hull, Paint()..color = body);

    // Mast
    canvas.drawLine(
      Offset(waterline.dx - hullW * 0.05, waterline.dy - hullH * 0.2),
      Offset(waterline.dx - hullW * 0.05, waterline.dy - mastH),
      Paint()
        ..color = body.withValues(alpha: 0.65)
        ..strokeWidth = 1.35 * s
        ..strokeCap = StrokeCap.round,
    );

    // Main triangle sail
    final main = Path()
      ..moveTo(waterline.dx - hullW * 0.05, waterline.dy - mastH)
      ..lineTo(waterline.dx + hullW * 0.38, waterline.dy - hullH * 1.1)
      ..lineTo(waterline.dx - hullW * 0.05, waterline.dy - hullH * 0.85)
      ..close();
    canvas.drawPath(main, Paint()..color = sail);

    // Small jib
    final jib = Path()
      ..moveTo(waterline.dx - hullW * 0.05, waterline.dy - mastH * 0.85)
      ..lineTo(waterline.dx - hullW * 0.42, waterline.dy - hullH * 0.4)
      ..lineTo(waterline.dx - hullW * 0.05, waterline.dy - hullH * 0.7)
      ..close();
    canvas.drawPath(
      jib,
      Paint()..color = sail.withValues(alpha: sail.a * 0.85),
    );
  }

  /// Soft water lines — far stays calm; only a quiet shimmer.
  void _paintWaves(
    Canvas canvas,
    Size size, {
    required double horizon,
    required double breakY,
    required double shoreY,
    required double breath,
    required double wave,
  }) {
    final span = breakY - horizon;
    for (var i = 0; i < 6; i++) {
      final depth = i / 5;
      final farness = 1.0 - depth; // 1 = horizon, 0 = near shore
      final phase = (t * (0.12 + farness * 0.06) + i * 0.9) % 1.0;
      var y = horizon + span * (0.1 + depth * 0.85) +
          math.sin(phase * math.pi * 2) *
              size.height *
              (0.0008 + farness * 0.0012);
      if (depth > 0.6) {
        y += (breakY - y) * wave * 0.06;
      }

      // Far: almost still. Mid/near: gentle only.
      final amp = 0.6 + farness * 1.1 + depth * 1.4;
      final alpha = 0.025 + farness * 0.035 + depth * 0.03 + breath * 0.008;
      final stroke = 0.55 + farness * 0.35 + depth * 0.5;

      final path = Path()..moveTo(-10, y);
      final drift = t * (0.28 + farness * 0.12);
      for (var x = 0.0; x <= size.width + 10; x += 14) {
        final n = math.sin(x * (0.007 + farness * 0.003) + drift + i) * amp +
            math.sin(x * 0.022 - t * 0.22 + i * 0.4) * amp * 0.22;
        path.lineTo(x, y + n);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = OceanPalette.waterFoam.withValues(alpha: alpha)
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Soft sun glints — calm on the far water, a bit livelier mid-sea.
  void _paintSeaSparkles(
    Canvas canvas,
    Size size, {
    required double horizon,
    required double breakY,
    required double breath,
  }) {
    final rng = math.Random(19);
    final span = breakY - horizon;
    for (var i = 0; i < 14; i++) {
      final u = rng.nextDouble();
      final x = size.width * (0.08 + rng.nextDouble() * 0.84);
      final y = horizon +
          span * (0.14 + u * 0.65) +
          math.sin(t * 0.4 + i * 0.7) * (0.35 + u * 0.8);
      final twinkle =
          0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * (1.0 + rng.nextDouble() * 0.5) + i));
      final a = (0.04 + u * 0.12) * twinkle * (0.6 + breath * 0.2);
      if (a < 0.03) continue;
      final s = 0.45 + rng.nextDouble() * (0.7 + u * 0.6);
      canvas.drawCircle(
        Offset(x, y),
        s,
        Paint()..color = OceanPalette.waterGlint.withValues(alpha: a),
      );
    }
  }

  /// Transparent sheet of water sliding over the sand — beach shows through.
  /// White foam builds on the leading lip as the wave rushes in.
  void _paintWashOverSand(
    Canvas canvas,
    Size size, {
    required double breakY,
    required double shoreY,
    required double breath,
    required double wave,
    required double foam,
  }) {
    if (wave < 0.02 && foam < 0.03) return;

    final farLip = shoreY - size.height * 0.01;
    // Stronger crest reach so the push matches the swash peak.
    final nearLip = shoreY + size.height * 0.105;
    final lip = ui.lerpDouble(farLip, nearLip, wave)!;
    final foamStrength = foam.clamp(0.0, 1.0);

    final edgeYs = <double>[];
    final edgeXs = <double>[];
    // Edge stays crisp as water pulls back — less wobble at the end.
    final edgeWobble = (1.2 + wave * 4.0) * (0.25 + 0.75 * wave);
    for (var x = 0.0; ; ) {
      final shore = _shoreEdgeY(x, size, shoreY);
      final localLip = lip + (shore - shoreY);
      final n = math.sin(x * 0.028 + t * 0.7) * edgeWobble +
          math.sin(x * 0.07 - t * 0.4) * edgeWobble * 0.35;
      edgeXs.add(x);
      edgeYs.add(localLip + n);
      if (x >= size.width) break;
      x = math.min(x + 8, size.width);
    }

    if (wave >= 0.02) {
      final sheet = Path()..moveTo(0, _shoreEdgeY(0, size, shoreY) - 4);
      _traceShoreEdge(sheet, size, shoreY, yPad: -2);
      for (var i = edgeYs.length - 1; i >= 0; i--) {
        sheet.lineTo(edgeXs[i], edgeYs[i]);
      }
      sheet.close();

      canvas.drawPath(
        sheet,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(size.width * 0.5, shoreY - 4),
            Offset(size.width * 0.5, lip + size.height * 0.04),
            [
              OceanPalette.waterShallow.withValues(alpha: 0.28 + wave * 0.28),
              OceanPalette.waterWarm.withValues(alpha: 0.2 + wave * 0.22),
              OceanPalette.waterFoam.withValues(alpha: 0.18 + wave * 0.22),
              const Color(0xFFE8F8FC).withValues(alpha: 0.08 + wave * 0.1),
              OceanPalette.waterWarm.withValues(alpha: 0),
            ],
            const [0.0, 0.28, 0.55, 0.78, 1.0],
          ),
      );
    }

    // Leading white foam — like a real swash breaking on the sand.
    final lipFoam = foamStrength * (0.45 + 0.55 * wave.clamp(0.0, 1.0));
    if (wave >= 0.08 && lipFoam > 0.05) {
      final foamBand = Path();
      for (var i = 0; i < edgeYs.length; i++) {
        final x = edgeXs[i];
        final yFront = edgeYs[i];
        final yBack = yFront -
            size.height * (0.012 + lipFoam * 0.028) *
                (0.8 + 0.2 * math.sin(i * 0.45 + t));
        if (i == 0) {
          foamBand.moveTo(x, yBack);
        } else {
          foamBand.lineTo(x, yBack);
        }
      }
      for (var i = edgeYs.length - 1; i >= 0; i--) {
        foamBand.lineTo(edgeXs[i], edgeYs[i]);
      }
      foamBand.close();

      canvas.drawPath(
        foamBand,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, lip - size.height * 0.028),
            Offset(0, lip + size.height * 0.008),
            [
              OceanPalette.waterFoam.withValues(alpha: 0.12 * lipFoam),
              const Color(0xFFF4FCFF).withValues(alpha: 0.55 * lipFoam),
              const Color(0xFFFFFFF8).withValues(alpha: 0.82 * lipFoam),
            ],
            const [0.0, 0.45, 1.0],
          ),
      );

      final crest = Path()..moveTo(edgeXs.first, edgeYs.first);
      for (var i = 0; i < edgeYs.length; i++) {
        crest.lineTo(edgeXs[i], edgeYs[i]);
      }
      canvas.drawPath(
        crest,
        Paint()
          ..color = OceanPalette.waterFoam.withValues(alpha: 0.2 * lipFoam)
          ..strokeWidth = 5 + lipFoam * 10
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
      );
      canvas.drawPath(
        crest,
        Paint()
          ..color = const Color(0xFFFFFFF8).withValues(
            alpha: (0.42 + breath * 0.06) * lipFoam,
          )
          ..strokeWidth = 2.0 + lipFoam * 2.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        crest,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35 * lipFoam)
          ..strokeWidth = 1.0 + lipFoam * 1.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // Foam bubbles clustered near the leading edge
    if (foamStrength > 0.18 && wave > 0.2) {
      final rng = math.Random(27);
      final count = (28 + foamStrength * wave * 55).round();
      for (var i = 0; i < count; i++) {
        final u = rng.nextDouble();
        final x = size.width * rng.nextDouble();
        final along = math.pow(u, 0.55).toDouble();
        final y = ui.lerpDouble(shoreY, lip, 0.35 + along * 0.65)! +
            (rng.nextDouble() - 0.5) * 5;
        final a = (0.16 + rng.nextDouble() * 0.4) *
            foamStrength *
            wave *
            (0.4 + along);
        canvas.drawCircle(
          Offset(x, y),
          0.7 + rng.nextDouble() * (1.4 + foamStrength * wave * 2.2),
          Paint()..color = const Color(0xFFFFFFF8).withValues(alpha: a),
        );
      }
    }

    // Thin lace while draining — follows the water, settles quickly, no blur wobble.
    if (foamStrength > 0.18 && wave > 0.18 && wave < 0.92) {
      for (var i = 0; i < 3; i++) {
        final y = ui.lerpDouble(shoreY, lip, 0.22 + i * 0.2)!;
        final lace = Path()..moveTo(0, y);
        for (var x = 0.0; x <= size.width; x += 14) {
          lace.lineTo(
            x,
            y + math.sin(x * 0.04 + i * 1.2) * (0.6 + wave * 0.8),
          );
        }
        canvas.drawPath(
          lace,
          Paint()
            ..color = OceanPalette.waterFoam.withValues(
              alpha: (0.14 - i * 0.025) * foamStrength * wave,
            )
            ..strokeWidth = 0.8 + (1 - i * 0.15) * wave * 0.7
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  void _paintShore(
    Canvas canvas,
    Size size, {
    required double shoreY,
    required double breath,
  }) {
    final path = Path()..moveTo(0, _shoreEdgeY(0, size, shoreY));
    _traceShoreEdge(path, size, shoreY);
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, shoreY),
          Offset(size.width * 0.5, size.height),
          [
            OceanPalette.sandWet,
            OceanPalette.sand,
            Color.lerp(OceanPalette.sandLit, OceanPalette.sandWarm, 0.4 + breath * 0.15)!,
            Color.lerp(OceanPalette.sand, OceanPalette.sandDeep, 0.25)!,
          ],
          const [0.0, 0.2, 0.55, 1.0],
        ),
    );

    // Soft daylight on near sand.
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, shoreY),
          Offset(size.width * 0.5, size.height),
          [
            OceanPalette.sunGlow.withValues(alpha: 0.06 + breath * 0.03),
            OceanPalette.sunGlow.withValues(alpha: 0.02),
            OceanPalette.sunGlow.withValues(alpha: 0),
          ],
          const [0.0, 0.4, 1.0],
        ),
    );

    // Wet rim along the waterline
    final wet = Path()..moveTo(0, _shoreEdgeY(0, size, shoreY));
    _traceShoreEdge(wet, size, shoreY);
    canvas.drawPath(
      wet,
      Paint()
        ..color = OceanPalette.sandWet.withValues(alpha: 0.45)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Soft sand grain — fine grit + a few quiet ripples.
    canvas.save();
    canvas.clipPath(path);
    final rng = math.Random(11);
    final sandH = size.height - shoreY;
    for (var i = 0; i < 90; i++) {
      final x = rng.nextDouble() * size.width;
      final y = shoreY + size.height * (0.04 + rng.nextDouble() * 0.32);
      final lit = i.isEven;
      canvas.drawCircle(
        Offset(x, y),
        0.35 + rng.nextDouble() * 0.7,
        Paint()
          ..color = (lit ? OceanPalette.sandLit : OceanPalette.sandDeep)
              .withValues(alpha: lit ? 0.14 : 0.09),
      );
    }
    for (var i = 0; i < 14; i++) {
      final y = shoreY + sandH * (0.08 + rng.nextDouble() * 0.55);
      final x0 = size.width * rng.nextDouble() * 0.2;
      final x1 = x0 + size.width * (0.25 + rng.nextDouble() * 0.5);
      canvas.drawLine(
        Offset(x0, y),
        Offset(x1, y + (rng.nextDouble() - 0.5) * 2.5),
        Paint()
          ..color = OceanPalette.sandDeep.withValues(alpha: 0.055 + rng.nextDouble() * 0.04)
          ..strokeWidth = 0.7 + rng.nextDouble() * 0.6
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i < 28; i++) {
      final x = size.width * (0.05 + rng.nextDouble() * 0.9);
      final y = shoreY + size.height * (0.12 + rng.nextDouble() * 0.28);
      canvas.drawCircle(
        Offset(x, y),
        0.4 + rng.nextDouble() * 0.5,
        Paint()..color = OceanPalette.sandWarm.withValues(alpha: 0.12 + breath * 0.04),
      );
    }
    canvas.restore();

    _paintShells(canvas, size, shoreY: shoreY, breath: breath);
  }

  void _paintShells(
    Canvas canvas,
    Size size, {
    required double shoreY,
    required double breath,
  }) {
    final rng = math.Random(61);
    // Scattered on dry-ish sand, clear of the memo board on the right.
    for (var i = 0; i < 6; i++) {
      final x = size.width * (0.08 + rng.nextDouble() * 0.58);
      final y = shoreY + size.height * (0.06 + rng.nextDouble() * 0.22);
      final s = size.shortestSide * (0.008 + rng.nextDouble() * 0.012);
      final rot = (rng.nextDouble() - 0.5) * 1.2;
      final kind = i % 3;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);

      if (kind == 0) {
        // Fan clam
        final shell = Path()
          ..moveTo(0, s * 0.2)
          ..quadraticBezierTo(-s, -s * 0.1, -s * 0.15, -s * 0.95)
          ..quadraticBezierTo(0, -s * 1.05, s * 0.15, -s * 0.95)
          ..quadraticBezierTo(s, -s * 0.1, 0, s * 0.2)
          ..close();
        canvas.drawPath(
          shell,
          Paint()..color = Color.lerp(
            const Color(0xFFE8D0B8),
            const Color(0xFFD0A888),
            rng.nextDouble(),
          )!,
        );
        canvas.drawPath(
          shell,
          Paint()
            ..color = const Color(0xFFB88868).withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7,
        );
        for (var r = 0; r < 4; r++) {
          canvas.drawLine(
            Offset(0, s * 0.05),
            Offset((r - 1.5) * s * 0.28, -s * 0.75),
            Paint()
              ..color = const Color(0xFFC89878).withValues(alpha: 0.35)
              ..strokeWidth = 0.6,
          );
        }
      } else if (kind == 1) {
        // Spiral / snail
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: s * 1.4, height: s * 1.1),
          Paint()..color = const Color(0xFFD8C0A0),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(s * 0.1, -s * 0.05),
            width: s * 0.7,
            height: s * 0.55,
          ),
          Paint()..color = const Color(0xFFC8A888),
        );
        canvas.drawCircle(
          Offset(s * 0.15, -s * 0.08),
          s * 0.12,
          Paint()..color = const Color(0xFFA88868).withValues(alpha: 0.5),
        );
      } else {
        // Tiny oval fragment
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: s * 1.1, height: s * 0.7),
          Paint()
            ..color = Color.lerp(
              const Color(0xFFF0E0D0),
              const Color(0xFFC8B098),
              rng.nextDouble(),
            )!,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(-s * 0.05, 0),
            width: s * 0.45,
            height: s * 0.28,
          ),
          Paint()..color = const Color(0xFFE8D8C8).withValues(alpha: 0.7),
        );
      }

      // Soft contact shadow
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, s * 0.35),
          width: s * 1.1,
          height: s * 0.25,
        ),
        Paint()..color = OceanPalette.sandDeep.withValues(alpha: 0.12),
      );
      canvas.restore();
    }
  }

  /// Small sandcastle on the left sand — planted, not floating.
  void _paintSandcastle(
    Canvas canvas,
    Size size, {
    required double shoreY,
    required double breath,
  }) {
    final s = size.shortestSide * 0.08;
    final base = Offset(
      size.width * 0.22,
      shoreY + size.height * 0.145,
    );

    // Soft contact under the keep — light, not a dark puddle.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(base.dx, base.dy + s * 0.06),
        width: s * 2.3,
        height: s * 0.4,
      ),
      Paint()..color = OceanPalette.sandDeep.withValues(alpha: 0.18),
    );

    final lit = OceanPalette.sandLit;
    final mid = OceanPalette.sand;
    final deep = OceanPalette.sandDeep;
    final wet = OceanPalette.sandWet;

    void drawKeep(Offset origin, double w, double h, {required bool tall}) {
      final top = origin.dy - h;
      final rect = Rect.fromLTWH(origin.dx - w * 0.5, top, w, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topLeft,
            rect.bottomRight,
            [Color.lerp(lit, mid, 0.25)!, mid, deep],
            const [0.0, 0.45, 1.0],
          ),
      );
      // Soft sun kiss on the left face.
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, w * 0.28, h),
        Paint()..color = lit.withValues(alpha: 0.28 + breath * 0.05),
      );
      // Crenellations.
      final merlon = w / 5;
      for (var i = 0; i < 5; i++) {
        if (i.isOdd) continue;
        final mx = rect.left + i * merlon;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(mx, top - h * 0.12, merlon * 0.92, h * 0.14),
            const Radius.circular(1),
          ),
          Paint()..color = Color.lerp(mid, lit, 0.2)!,
        );
      }
      if (tall) {
        // Tiny arched door.
        final door = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(origin.dx, origin.dy - h * 0.18),
            width: w * 0.22,
            height: h * 0.32,
          ),
          const Radius.circular(6),
        );
        canvas.drawRRect(door, Paint()..color = wet.withValues(alpha: 0.75));
      } else {
        // Window slit.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(origin.dx, top + h * 0.42),
              width: w * 0.14,
              height: h * 0.22,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = wet.withValues(alpha: 0.7),
        );
      }
    }

    // Side towers + curtain wall, then main keep in front.
    drawKeep(Offset(base.dx - s * 0.72, base.dy), s * 0.55, s * 0.95, tall: false);
    drawKeep(Offset(base.dx + s * 0.72, base.dy), s * 0.52, s * 0.88, tall: false);

    final wall = Rect.fromLTRB(
      base.dx - s * 0.72,
      base.dy - s * 0.55,
      base.dx + s * 0.72,
      base.dy - s * 0.08,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(wall, const Radius.circular(2)),
      Paint()
        ..shader = ui.Gradient.linear(
          wall.topCenter,
          wall.bottomCenter,
          [mid, deep],
          const [0.0, 1.0],
        ),
    );

    drawKeep(Offset(base.dx, base.dy), s * 0.95, s * 1.25, tall: true);

    // Little flag pole on the keep — upright.
    final tip = Offset(base.dx, base.dy - s * 1.42);
    canvas.drawLine(
      Offset(base.dx, base.dy - s * 1.25),
      tip,
      Paint()
        ..color = deep
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    final flag = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + s * 0.28, tip.dy + s * 0.06)
      ..lineTo(tip.dx, tip.dy + s * 0.14)
      ..close();
    canvas.drawPath(
      flag,
      Paint()..color = const Color(0xFFE87860).withValues(alpha: 0.9),
    );
  }

  /// Beach shells on the wet sand (replaces rocks).
  void _paintBeachShells(
    Canvas canvas,
    Size size, {
    required double shoreY,
    required double breath,
  }) {
    final shells = <(double nx, double ny, double scale, double rot, int kind)>[
      (0.08, 0.10, 1.1, -0.35, 0),
      (0.90, 0.09, 1.2, 0.28, 1),
    ];

    for (final (nx, ny, scale, rot, kind) in shells) {
      final c = Offset(size.width * nx, shoreY + size.height * ny);
      final s = size.shortestSide * 0.022 * scale;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(rot);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, s * 0.4),
          width: s * 1.2,
          height: s * 0.3,
        ),
        Paint()..color = OceanPalette.sandDeep.withValues(alpha: 0.16),
      );

      if (kind == 0) {
        final shell = Path()
          ..moveTo(0, s * 0.25)
          ..quadraticBezierTo(-s, -s * 0.05, -s * 0.12, -s * 1.05)
          ..quadraticBezierTo(0, -s * 1.15, s * 0.12, -s * 1.05)
          ..quadraticBezierTo(s, -s * 0.05, 0, s * 0.25)
          ..close();
        canvas.drawPath(
          shell,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, -s),
              Offset(0, s * 0.2),
              [
                Color.lerp(
                  const Color(0xFFF0E0D0),
                  OceanPalette.sunGlow,
                  0.12 + breath * 0.05,
                )!,
                const Color(0xFFD8B898),
              ],
            ),
        );
        canvas.drawPath(
          shell,
          Paint()
            ..color = const Color(0xFFB88868).withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9,
        );
        for (var r = 0; r < 5; r++) {
          canvas.drawLine(
            Offset(0, s * 0.08),
            Offset((r - 2) * s * 0.22, -s * 0.85),
            Paint()
              ..color = const Color(0xFFC89878).withValues(alpha: 0.4)
              ..strokeWidth = 0.7,
          );
        }
      } else if (kind == 1) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: s * 1.55,
            height: s * 1.2,
          ),
          Paint()..color = const Color(0xFFE0C8A8),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(s * 0.12, -s * 0.06),
            width: s * 0.8,
            height: s * 0.6,
          ),
          Paint()..color = const Color(0xFFD0B090),
        );
        canvas.drawCircle(
          Offset(s * 0.18, -s * 0.1),
          s * 0.14,
          Paint()..color = const Color(0xFFA88868).withValues(alpha: 0.45),
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: s * 1.25,
            height: s * 0.75,
          ),
          Paint()..color = const Color(0xFFF2E4D4),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(-s * 0.06, 0),
            width: s * 0.5,
            height: s * 0.3,
          ),
          Paint()..color = const Color(0xFFE8D8C8).withValues(alpha: 0.75),
        );
      }

      canvas.restore();
    }
  }

  void _paintPresenceSpirits(
    Canvas canvas,
    Size size, {
    required double breath,
  }) {
    // Same companion field as desert/forest — white sun-glint fairies.
    final n = presenceSparkMax;
    final rng = math.Random(41);

    for (var i = 0; i < n; i++) {
      // Spread across the whole scene — sky, water, and sand.
      final col = (i + 0.5) / n;
      final homeX =
          size.width * (0.04 + col * 0.92 + (rng.nextDouble() - 0.5) * 0.06);
      final homeY = size.height * (0.16 + rng.nextDouble() * 0.68);

      final p1 = rng.nextDouble() * math.pi * 2;
      final p2 = rng.nextDouble() * math.pi * 2;
      final p3 = rng.nextDouble() * math.pi * 2;
      final ampX = size.width * (0.06 + rng.nextDouble() * 0.08);
      final ampY = size.height * (0.05 + rng.nextDouble() * 0.07);
      final sx1 = 0.2 + rng.nextDouble() * 0.35;
      final sx2 = 0.5 + rng.nextDouble() * 0.5;
      final sy1 = 0.18 + rng.nextDouble() * 0.3;
      final sy2 = 0.45 + rng.nextDouble() * 0.45;

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
      final dartAmp = size.shortestSide * (0.03 + rng.nextDouble() * 0.04);

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
          0.3 +
          0.7 *
              math
                  .pow(
                    (0.5 +
                            0.5 *
                                math.sin(
                                  t * (0.75 + rng.nextDouble() * 1.1) + p1,
                                ))
                        .clamp(0.0, 1.0),
                    2.0,
                  )
                  .toDouble();
      final flash = math
          .pow(
            (0.5 + 0.5 * math.sin(t * (1.5 + rng.nextDouble()) + p2))
                .clamp(0.0, 1.0),
            3.8,
          )
          .toDouble();
      final spark = (twinkle * 0.7 + flash * 0.4).clamp(0.0, 1.0);
      final r = (2.5 + rng.nextDouble() * 2.3) * (0.8 + spark * 0.55);
      final alpha = (0.52 + spark * 0.48) * (0.9 + breath * 0.12);

      // Soft round glow — no hard star points.
      canvas.drawCircle(
        pos,
        r * (3.4 + spark * 0.6),
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.2)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.8),
      );
      canvas.drawCircle(
        pos,
        r * 1.35,
        Paint()
          ..color = const Color(0xFFFFFFF8).withValues(alpha: alpha * 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.55),
      );
      canvas.drawCircle(
        pos,
        r,
        Paint()..color = const Color(0xFFFFFFF8).withValues(alpha: alpha * 0.88),
      );
      canvas.drawCircle(
        pos,
        r * 0.38,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
      );
    }
  }

  void _paintPresenceInSand(
    Canvas canvas,
    Size size, {
    required double breath,
  }) {
    if (sandCount <= 0) return;
    if (sandReveal < 0.01 && sandErase > 0.99) return;

    final label = _formatPresence(sandCount);
    final baseOpacity = 0.3 + breath * 0.08;
    final fontSize = size.shortestSide * 0.074;
    final hand = math.Random(sandCount * 31 + 7);
    final anchor = Offset(size.width * 0.28, size.height * 0.8);

    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.rotate(-0.08);

    final marks =
        <({String ch, double gap, double sizeMul, double wobbleY, double wobbleRot})>[];
    for (var i = 0; i < label.length; i++) {
      marks.add((
        ch: label[i],
        gap: i == 0 ? 0.0 : fontSize * (0.06 + hand.nextDouble() * 0.10),
        sizeMul: 0.94 + hand.nextDouble() * 0.12,
        wobbleY: (hand.nextDouble() - 0.5) * fontSize * 0.12,
        wobbleRot: (hand.nextDouble() - 0.5) * 0.12,
      ));
    }

    final painters = <({TextPainter shadow, TextPainter fill})>[];
    var runWidth = 0.0;
    for (final m in marks) {
      TextPainter glyph(Color c) => TextPainter(
        text: TextSpan(
          text: m.ch,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: fontSize * m.sizeMul,
            color: c,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final fill = glyph(
        OceanPalette.presenceInk.withValues(
          alpha: baseOpacity * sandReveal * (1 - sandErase * 0.85),
        ),
      );
      final shadow = glyph(
        OceanPalette.sandDeep.withValues(alpha: baseOpacity * 0.35 * sandReveal),
      );
      painters.add((shadow: shadow, fill: fill));
      runWidth += fill.width + m.gap;
    }

    var x = -runWidth * 0.5;
    for (var i = 0; i < marks.length; i++) {
      final m = marks[i];
      final p = painters[i];
      x += m.gap;
      canvas.save();
      canvas.translate(x, m.wobbleY);
      canvas.rotate(m.wobbleRot);
      p.shadow.paint(canvas, const Offset(0.8, 1.0));
      p.fill.paint(canvas, Offset.zero);
      canvas.restore();
      x += p.fill.width;
    }
    canvas.restore();
  }

  void _paintComfortGlow(Canvas canvas, Size size, double breath) {
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.78),
      size.shortestSide * 0.45,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.78),
          size.shortestSide * 0.45,
          [
            OceanPalette.comfort.withValues(alpha: 0.08 + breath * 0.03),
            OceanPalette.comfort.withValues(alpha: 0),
          ],
        ),
    );
  }

  void _paintVignette(Canvas canvas, Size size, double breath) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.52),
          size.longestSide * 0.82,
          [
            const Color(0x00000000),
            Color.fromRGBO(24, 10, 20, 0.05 + breath * 0.02),
            Color.fromRGBO(12, 6, 14, 0.16),
          ],
          const [0.4, 0.78, 1.0],
        ),
    );
  }

  String _formatPresence(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}k';
    }
    return '$count';
  }

  @override
  bool shouldRepaint(covariant OceanPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.presenceCount != presenceCount ||
      oldDelegate.sandCount != sandCount ||
      oldDelegate.sandReveal != sandReveal ||
      oldDelegate.sandErase != sandErase;
}
