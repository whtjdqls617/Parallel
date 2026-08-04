import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/desert_palette.dart';

/// Seated alone in a remote hollow — and gently held by it.
/// Comfort is the light that breathes around you; the number outside
/// this painter is the quiet proof that others rest in the same moment.
class DesertPainter extends CustomPainter {
  DesertPainter({required this.t, this.presenceCount = 0});

  /// Continuous elapsed time in seconds.
  final double t;

  /// People resting in this same moment — soft sparks around your seat.
  final int presenceCount;

  /// Shared lullaby period — scene and count breathe together.
  static const breathPeriod = 5.5;

  @override
  void paint(Canvas canvas, Size size) {
    // Slow as consolation — not scenery, a rhythm you can lean on.
    final breath = 0.5 + 0.5 * math.sin(t * (math.pi * 2 / breathPeriod));
    final sway = math.sin(t * 0.07) * 0.006;
    final wind = math.sin(t * 0.12) * 0.45 + math.sin(t * 0.05) * 0.55;
    // Horizon a bit higher — sitting, looking out across sand.
    final vanish = Offset(size.width * 0.5, size.height * 0.38);

    _paintSky(canvas, size);
    _paintSun(canvas, size, sway, breath);
    _paintWarmAir(canvas, size, breath);
    _paintLightShafts(canvas, size, sway, breath);

    // Distant layered ridges — out there, not at your feet.
    _paintDistantRidge(
      canvas,
      size,
      baseY: size.height * 0.36,
      amplitude: size.height * 0.04,
      parallax: t * 0.25 + sway * size.width,
      color: DesertPalette.mountainFar.withValues(alpha: 0.32),
      seed: 11,
    );
    _paintDistantRidge(
      canvas,
      size,
      baseY: size.height * 0.40,
      amplitude: size.height * 0.05,
      parallax: t * 0.4 + sway * size.width * 1.2,
      color: DesertPalette.mountainMid.withValues(alpha: 0.45),
      seed: 19,
    );

    _paintDepthVeil(canvas, size, y: size.height * 0.42, strength: 0.16);

    // Far sweeping ridge — mid-distance.
    _paintWithPerspective(
      canvas,
      vanish: vanish,
      scale: 0.94,
      child: () => _paintDuneLayer(
        canvas,
        size,
        crestY: size.height * 0.44,
        rise: size.height * 0.18,
        color: DesertPalette.duneFar,
        shadow: DesertPalette.duneDeepShadow.withValues(alpha: 0.32),
        wind: wind * 0.15,
        sway: sway,
        seed: 3,
        depthFade: 0.20,
        style: DuneStyle.ridge,
      ),
    );

    _paintDepthVeil(canvas, size, y: size.height * 0.52, strength: 0.08);

    // Mid — low open sand, a soft pass to look through. No wall.
    _paintWithPerspective(
      canvas,
      vanish: vanish,
      scale: 0.99,
      child: () => _paintDuneLayer(
        canvas,
        size,
        crestY: size.height * 0.58,
        rise: size.height * 0.09,
        color: DesertPalette.duneMid,
        shadow: DesertPalette.duneDeepShadow.withValues(alpha: 0.22),
        wind: wind * 0.15,
        sway: sway * 0.4,
        seed: 7,
        depthFade: 0.12,
        style: DuneStyle.mid,
      ),
    );

    // At your feet — soft sand lap, gentle slope, not a ridge wall.
    _paintSittingSand(canvas, size, startY: size.height * 0.68, wind: wind);

    _paintWindRipples(canvas, size, wind: wind);
    _paintGroundPerspectiveWash(canvas, size, vanish: vanish);
    _paintFootprints(canvas, size, vanish: vanish);
    _paintPresenceInSand(canvas, size, breath: breath);
    _paintDust(canvas, size, wind, vanish: vanish);

    // Close companions — soft sparks wrapping your seat.
    _paintPresenceSpirits(canvas, size, breath: breath);

    _paintComfortGlow(canvas, size, breath);
    _paintVignette(canvas, size, breath);
  }

  void _paintWithPerspective(
    Canvas canvas, {
    required Offset vanish,
    required double scale,
    required VoidCallback child,
  }) {
    canvas.save();
    canvas.translate(vanish.dx, vanish.dy);
    canvas.scale(scale);
    canvas.translate(-vanish.dx, -vanish.dy);
    child();
    canvas.restore();
  }

  void _paintSky(Canvas canvas, Size size) {
    // Warm desert vault — same hour as the sand.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, size.height * 0.55),
          const [
            DesertPalette.skyTop,
            DesertPalette.skyMid,
            DesertPalette.skyHorizon,
          ],
          const [0.0, 0.4, 1.0],
        ),
    );
  }

  void _paintSun(Canvas canvas, Size size, double sway, double breath) {
    // Side sun — directional light that carves the lee faces.
    final cx = size.width * (0.28 + sway * 2);
    final cy = size.height * 0.14;
    final coreR = size.shortestSide * (0.052 + breath * 0.005);

    canvas.drawCircle(
      Offset(cx, cy),
      coreR * (8.5 + breath * 0.5),
      Paint()
        ..shader = ui.Gradient.radial(Offset(cx, cy), coreR * 8.5, [
          DesertPalette.sunHalo.withValues(alpha: 0.38 + breath * 0.12),
          DesertPalette.sunHalo.withValues(alpha: 0.0),
        ]),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      coreR * 3.0,
      Paint()
        ..shader = ui.Gradient.radial(Offset(cx, cy), coreR * 3.0, [
          DesertPalette.sunGlow.withValues(alpha: 0.62 + breath * 0.1),
          DesertPalette.sunGlow.withValues(alpha: 0.0),
        ]),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      coreR,
      Paint()
        ..shader = ui.Gradient.radial(Offset(cx, cy), coreR, const [
          DesertPalette.sunCore,
          DesertPalette.sunGlow,
        ]),
    );
  }

  void _paintWarmAir(Canvas canvas, Size size, double breath) {
    // Soft warm haze where blue meets sand.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.28, size.width, size.height * 0.28),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.28),
          Offset(0, size.height * 0.56),
          [
            DesertPalette.haze.withValues(alpha: 0.0),
            DesertPalette.haze.withValues(alpha: 0.35 + breath * 0.1),
            DesertPalette.haze.withValues(alpha: 0.0),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    _paintHeatShimmer(canvas, size, breath);
  }

  void _paintHeatShimmer(Canvas canvas, Size size, double breath) {
    final y0 = size.height * 0.30;
    for (var band = 0; band < 4; band++) {
      final y = y0 + band * size.height * 0.022;
      final path = Path();
      for (var i = 0; i <= 32; i++) {
        final u = i / 32;
        final x = size.width * u;
        final wave =
            math.sin(u * math.pi * 4 + t * 1.1 + band * 0.8) * 3.5 +
            math.sin(u * math.pi * 7 + t * 0.7) * 1.5;
        if (i == 0) {
          path.moveTo(x, y + wave);
        } else {
          path.lineTo(x, y + wave);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.fromRGBO(255, 240, 200, 0.04 + breath * 0.03)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  /// Occasional soft shafts — appear, linger, fade. Never constant.
  void _paintLightShafts(Canvas canvas, Size size, double sway, double breath) {
    final sun = Offset(size.width * (0.28 + sway * 2), size.height * 0.14);

    const shafts =
        <
          (double angle, double width, double period, double phase, double peak)
        >[
          (-0.22, 0.045, 18.0, 0.0, 0.15),
          (-0.06, 0.032, 23.0, 0.35, 0.12),
          (0.10, 0.038, 27.0, 0.62, 0.14),
          (0.28, 0.028, 21.0, 0.18, 0.11),
          (-0.38, 0.022, 31.0, 0.78, 0.09),
        ];

    for (final shaft in shafts) {
      final (angle, width, period, phase, peak) = shaft;
      final visibility = _intermittent(t, period: period, phase: phase);
      if (visibility < 0.02) continue;

      final alpha = peak * visibility * (0.75 + breath * 0.25);
      final length = size.height * 0.72;
      final half = size.width * width;

      final dir = Offset(math.sin(angle), math.cos(angle));
      final perp = Offset(-dir.dy, dir.dx);
      final tip = sun + dir * length;

      final path = Path()
        ..moveTo(sun.dx + perp.dx * half * 0.15, sun.dy + perp.dy * half * 0.15)
        ..lineTo(tip.dx + perp.dx * half, tip.dy + perp.dy * half)
        ..lineTo(tip.dx - perp.dx * half, tip.dy - perp.dy * half)
        ..lineTo(sun.dx - perp.dx * half * 0.15, sun.dy - perp.dy * half * 0.15)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            sun,
            tip,
            [
              Color.fromRGBO(255, 236, 200, alpha * 0.85),
              Color.fromRGBO(255, 220, 170, alpha * 0.35),
              Color.fromRGBO(255, 210, 160, 0.0),
            ],
            const [0.0, 0.35, 1.0],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  /// Soft on/off envelope — visible for part of each cycle only.
  double _intermittent(
    double time, {
    required double period,
    required double phase,
    double attack = 0.12,
    double hold = 0.22,
    double release = 0.18,
  }) {
    final u = ((time / period) + phase) % 1.0;
    final endAttack = attack;
    final endHold = attack + hold;
    final endRelease = attack + hold + release;

    if (u < endAttack) {
      final x = u / attack;
      return x * x * (3 - 2 * x);
    }
    if (u < endHold) return 1.0;
    if (u < endRelease) {
      final x = (u - endHold) / release;
      final s = x * x * (3 - 2 * x);
      return 1.0 - s;
    }
    return 0.0;
  }

  void _paintDistantRidge(
    Canvas canvas,
    Size size, {
    required double baseY,
    required double amplitude,
    required double parallax,
    required Color color,
    required int seed,
  }) {
    final rng = math.Random(seed);
    const peaks = 8;
    final heights = List<double>.generate(
      peaks + 1,
      (_) => 0.4 + rng.nextDouble() * 0.6,
    );

    final period = size.width * 1.4;
    final shift = parallax % period;
    final path = Path()..moveTo(-period, size.height);

    for (var pass = 0; pass < 2; pass++) {
      final origin = pass * period - shift;
      for (var i = 0; i < peaks; i++) {
        final x0 = origin + (period / peaks) * i;
        final x1 = origin + (period / peaks) * (i + 1);
        final y0 = baseY - amplitude * heights[i];
        final y1 = baseY - amplitude * heights[(i + 1) % heights.length];
        final midX = (x0 + x1) / 2;
        final midY = (y0 + y1) / 2 - amplitude * 0.08;

        if (pass == 0 && i == 0) path.lineTo(x0, y0);
        path.quadraticBezierTo(x0, y0, midX, midY);
        if (i == peaks - 1) path.lineTo(x1, y1);
      }
    }

    path
      ..lineTo(period * 2, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  /// Soft atmospheric veil between layers — far air eats detail.
  void _paintDepthVeil(
    Canvas canvas,
    Size size, {
    required double y,
    required double strength,
  }) {
    final band = size.height * 0.12;
    canvas.drawRect(
      Rect.fromLTWH(0, y - band * 0.4, size.width, band),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y - band * 0.4),
          Offset(0, y + band * 0.6),
          [
            DesertPalette.haze.withValues(alpha: 0.0),
            DesertPalette.skyHorizon.withValues(alpha: strength),
            DesertPalette.haze.withValues(alpha: 0.0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  /// Sweeping dune faces — smooth crests, bright lit side, deep lee.
  void _paintDuneLayer(
    Canvas canvas,
    Size size, {
    required double crestY,
    required double rise,
    required Color color,
    required Color shadow,
    required double wind,
    required double sway,
    required int seed,
    required double depthFade,
    required DuneStyle style,
  }) {
    final rng = math.Random(seed);
    final points = <Offset>[];
    if (style == DuneStyle.ridge) {
      final a = 0.50 + rng.nextDouble() * 0.15;
      final b = 0.78 + rng.nextDouble() * 0.15;
      final c = 0.45 + rng.nextDouble() * 0.12;
      final d = 0.68 + rng.nextDouble() * 0.14;
      points.addAll([
        Offset(0.00, a),
        Offset(0.22, b),
        Offset(0.48, c),
        Offset(0.72, d),
        Offset(1.00, 0.52 + rng.nextDouble() * 0.12),
      ]);
    } else if (style == DuneStyle.mid) {
      // Soft open pass — low shoulders, open center. Easy on the eyes.
      // Looks toward the far ridges instead of blocking them.
      points.addAll([
        Offset(0.00, 0.42),
        Offset(0.16, 0.52),
        Offset(0.32, 0.38),
        Offset(0.50, 0.28), // open middle — gaze slips through
        Offset(0.68, 0.40),
        Offset(0.84, 0.55),
        Offset(1.00, 0.44),
      ]);
    } else {
      points.addAll([
        Offset(0.00, 0.35 + rng.nextDouble() * 0.08),
        Offset(0.28, 0.48 + rng.nextDouble() * 0.08),
        Offset(0.55, 0.88 + rng.nextDouble() * 0.08),
        Offset(0.78, 0.55 + rng.nextDouble() * 0.08),
        Offset(1.00, 0.42 + rng.nextDouble() * 0.08),
      ]);
    }

    final windLift = wind * rise * 0.006;
    final swayX = sway * size.width * 0.2;

    double crestAt(double u) {
      for (var i = 0; i < points.length - 1; i++) {
        final a = points[i];
        final b = points[i + 1];
        if (u >= a.dx && u <= b.dx) {
          final tt = ((u - a.dx) / (b.dx - a.dx)).clamp(0.0, 1.0);
          final s = tt * tt * (3 - 2 * tt);
          return a.dy * (1 - s) + b.dy * s;
        }
      }
      return points.last.dy;
    }

    final path = Path()..moveTo(-20, size.height);
    const samples = 64;
    final crestSamples = <Offset>[];
    for (var i = 0; i <= samples; i++) {
      final u = i / samples;
      final x = -20 + (size.width + 40) * u + swayX;
      final h = crestAt(u);
      final y = crestY + rise * (1 - h) - windLift * math.sin(u * math.pi);
      crestSamples.add(Offset(x, y));
      if (i == 0) {
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path
      ..lineTo(size.width + 20, size.height)
      ..close();

    final washed = Color.lerp(color, DesertPalette.skyHorizon, depthFade)!;
    final lit = Color.lerp(DesertPalette.duneLit, washed, depthFade * 0.5)!;

    canvas.drawPath(
      path,
      Paint()
        ..shader =
            ui.Gradient.linear(Offset(0, crestY), Offset(0, size.height), [
              lit.withValues(alpha: 0.96),
              Color.lerp(washed, DesertPalette.duneShadow, 0.45)!,
            ]),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.05, crestY - rise * 0.2),
          Offset(size.width * 0.55, crestY + rise * 0.4),
          [
            lit.withValues(alpha: 0.55 * (1 - depthFade)),
            lit.withValues(alpha: 0.0),
          ],
        ),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.35, crestY),
          Offset(size.width * 0.95, crestY + rise * 0.7),
          [
            shadow.withValues(alpha: 0.0),
            shadow,
            DesertPalette.duneDeepShadow.withValues(alpha: shadow.a * 0.85),
          ],
          const [0.0, 0.4, 1.0],
        )
        ..blendMode = BlendMode.multiply,
    );

    final rim = Path()..moveTo(crestSamples.first.dx, crestSamples.first.dy);
    for (final p in crestSamples.skip(1)) {
      rim.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      rim,
      Paint()
        ..color = Color.fromRGBO(
          255,
          236,
          200,
          (style == DuneStyle.near
                  ? 0.35
                  : style == DuneStyle.mid
                  ? 0.22
                  : 0.18) *
              (1 - depthFade),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = style == DuneStyle.near
            ? 2.4
            : style == DuneStyle.mid
            ? 1.8
            : 1.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  /// Sand at your feet — a gentle lap, looking out, not a wall of ridges.
  void _paintSittingSand(
    Canvas canvas,
    Size size, {
    required double startY,
    required double wind,
  }) {
    final path = Path()..moveTo(-30, size.height);
    const samples = 40;
    for (var i = 0; i <= samples; i++) {
      final u = i / samples;
      final x = -30 + (size.width + 60) * u;
      final y =
          startY +
          size.height * 0.02 * math.sin(u * math.pi * 1.2) +
          size.height * 0.008 * math.sin(u * math.pi * 3 + t * 0.05) * wind;
      if (i == 0) {
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path
      ..lineTo(size.width + 30, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, startY),
          Offset(0, size.height),
          [
            DesertPalette.duneLit,
            DesertPalette.duneNear,
            Color.lerp(DesertPalette.duneNear, DesertPalette.duneShadow, 0.35)!,
          ],
          const [0.0, 0.4, 1.0],
        ),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.1, startY),
          Offset(size.width * 0.7, size.height),
          [
            DesertPalette.duneLit.withValues(alpha: 0.35),
            DesertPalette.duneLit.withValues(alpha: 0.0),
          ],
        ),
    );

    // Coarse grain — readable even when you're not staring.
    canvas.save();
    canvas.clipPath(path);
    final grain = math.Random(21);
    for (var i = 0; i < 220; i++) {
      final x = grain.nextDouble() * size.width;
      final y = startY + grain.nextDouble() * (size.height - startY);
      final depth = ((y - startY) / (size.height - startY)).clamp(0.0, 1.0);
      final r = 0.4 + grain.nextDouble() * 1.1;
      final lit = grain.nextBool();
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = lit
              ? Color.fromRGBO(255, 230, 180, 0.10 + depth * 0.10)
              : Color.fromRGBO(120, 60, 28, 0.08 + depth * 0.10),
      );
    }
    canvas.restore();
  }

  /// Wind ripples — bold enough to read from across the room.
  void _paintWindRipples(Canvas canvas, Size size, {required double wind}) {
    final top = size.height * 0.70;
    final bottom = size.height * 0.98;
    const rows = 18;

    for (var row = 0; row < rows; row++) {
      final depth = row / (rows - 1);
      final y0 = ui.lerpDouble(top, bottom, depth)!;
      final amp = ui.lerpDouble(1.8, 6.5, depth)! * (0.75 + wind.abs() * 0.35);
      final freq = ui.lerpDouble(9, 5.5, depth)!;
      final alpha = ui.lerpDouble(0.08, 0.26, depth)!;
      final drift = t * (0.12 + depth * 0.08);

      final path = Path();
      const cols = 52;
      for (var c = 0; c <= cols; c++) {
        final u = c / cols;
        final x = size.width * u;
        final y =
            y0 +
            math.sin(u * math.pi * freq + drift + row * 0.35) * amp +
            math.sin(u * math.pi * (freq * 0.4) + row) * amp * 0.4;
        if (c == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = Color.fromRGBO(255, 220, 170, alpha)
          ..strokeWidth = ui.lerpDouble(1.0, 2.0, depth)!
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      canvas.drawPath(
        path.shift(Offset(0, 1.6 + depth * 0.8)),
        Paint()
          ..color = Color.fromRGBO(100, 48, 22, alpha * 0.55)
          ..strokeWidth = ui.lerpDouble(0.8, 1.5, depth)!
          ..style = PaintingStyle.stroke,
      );
    }
  }

  /// Darker underfoot, lighter toward the opening — depth on the floor.
  void _paintGroundPerspectiveWash(
    Canvas canvas,
    Size size, {
    required Offset vanish,
  }) {
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.70, size.width, size.height * 0.30),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, size.height),
          Offset(vanish.dx, size.height * 0.68),
          [const Color(0x14000000), const Color(0x00FFFFFF)],
          const [0.0, 1.0],
        )
        ..blendMode = BlendMode.multiply,
    );
  }

  /// Soft prints in the sand — a quiet walk that appears, lingers, and clears.
  void _paintFootprints(Canvas canvas, Size size, {required Offset vanish}) {
    const steps = 7;
    const stepInterval = 1.4; // seconds between stamps
    const stampIn = 0.4;
    const pauseAfter = 2.2;
    const fadeOut = 3.5;
    final cycle = steps * stepInterval + pauseAfter + fadeOut;
    final u = t % cycle;

    final near = Offset(size.width * 0.44, size.height * 0.92);
    // Trail across the lap toward the mid dunes.
    final far = Offset(vanish.dx + size.width * 0.03, size.height * 0.72);

    final fadeStart = steps * stepInterval + pauseAfter;
    final globalFade = u > fadeStart
        ? (1.0 - ((u - fadeStart) / fadeOut).clamp(0.0, 1.0))
        : 1.0;
    if (globalFade < 0.02) return;

    for (var i = 0; i < steps; i++) {
      final born = i * stepInterval;
      if (u < born) continue;

      final age = u - born;
      final stamp = age < stampIn
          ? _smooth01((age / stampIn).clamp(0.0, 1.0))
          : 1.0;
      final life = stamp * globalFade;
      if (life < 0.02) continue;

      final depth = i / (steps - 1); // 0 near → 1 far
      final eased = math.pow(depth, 1.15).toDouble();
      final along = Offset.lerp(near, far, eased)!;

      // Gentle wander so it feels walked, not plotted.
      final wander = math.sin(i * 1.7) * size.width * 0.012 * (1 - eased * 0.5);
      final center = along.translate(wander, 0);

      // Facing along the trail.
      final nextT = ((i + 1) / (steps - 1)).clamp(0.0, 1.0);
      final next = Offset.lerp(near, far, math.pow(nextT, 1.15).toDouble())!;
      final dir = next - along;
      final angle = math.atan2(dir.dy, dir.dx) + math.pi / 2;

      final scale = ui.lerpDouble(1.15, 0.28, eased)!;
      // Fresh print is darker, then settles.
      final freshness = age < 2.0 ? (1.0 - age / 2.0) * 0.35 : 0.0;
      final opacity =
          ui.lerpDouble(0.48, 0.14, eased)! * life * (1.0 + freshness);
      final isLeft = i.isEven;
      final side = isLeft ? -1.0 : 1.0;
      final stride = size.shortestSide * 0.022 * scale;

      final footCenter = Offset(
        center.dx + math.cos(angle) * side * stride,
        center.dy + math.sin(angle) * side * stride,
      );

      // Soft settle — print sinks a hair as it appears.
      final settle = (1.0 - stamp) * scale * size.shortestSide * 0.004;

      _paintOnePrint(
        canvas,
        center: footCenter.translate(0, settle),
        angle: angle + side * 0.08,
        scale: scale * size.shortestSide * (0.95 + stamp * 0.08),
        opacity: opacity,
      );
    }
  }

  double _smooth01(double x) => x * x * (3 - 2 * x);

  void _paintOnePrint(
    Canvas canvas, {
    required Offset center,
    required double angle,
    required double scale,
    required double opacity,
  }) {
    final length = scale * 0.065;
    final width = scale * 0.030;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Soft depression in warm sand.
    final sole = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: length,
    );
    canvas.drawOval(
      sole,
      Paint()
        ..color = DesertPalette.duneDeepShadow.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.004),
    );

    // Slightly darker heel.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, length * 0.22),
        width: width * 0.85,
        height: length * 0.35,
      ),
      Paint()
        ..color = DesertPalette.duneDeepShadow.withValues(alpha: opacity * 1.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.003),
    );

    // Soft rim catch-light — sand pushed up at the edge.
    canvas.drawOval(
      sole.inflate(scale * 0.005),
      Paint()
        ..color = Color.fromRGBO(255, 232, 200, opacity * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.004
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.003),
    );

    canvas.restore();
  }

  void _paintDust(
    Canvas canvas,
    Size size,
    double wind, {
    required Offset vanish,
  }) {
    // Occasional soft gust — air lifts, then settles.
    final gust = math
        .pow((0.5 + 0.5 * math.sin(t * 0.23)).clamp(0.0, 1.0), 3)
        .toDouble();

    // Fine grit — dry dust flecks.
    final fine = math.Random(99);
    for (var i = 0; i < 56; i++) {
      _paintDustSpeck(
        canvas,
        size,
        vanish: vanish,
        wind: wind,
        gust: gust,
        seed: fine,
        index: i,
        lifeMin: 8,
        lifeSpan: 10,
        baseAlpha: 0.42,
        radiusMin: 0.7,
        radiusSpan: 1.6,
        blur: 0.4,
        softCloud: false,
      );
    }

    // Soft dust clouds — tiny haze puffs, not sparkles.
    final soft = math.Random(41);
    for (var i = 0; i < 22; i++) {
      _paintDustSpeck(
        canvas,
        size,
        vanish: vanish,
        wind: wind,
        gust: gust,
        seed: soft,
        index: i,
        lifeMin: 10,
        lifeSpan: 12,
        baseAlpha: 0.22,
        radiusMin: 3.0,
        radiusSpan: 6.0,
        blur: 3.2,
        softCloud: true,
      );
    }
  }

  /// Desert dust — muted sand color, soft edges, floats then settles.
  void _paintDustSpeck(
    Canvas canvas,
    Size size, {
    required Offset vanish,
    required double wind,
    required double gust,
    required math.Random seed,
    required int index,
    required double lifeMin,
    required double lifeSpan,
    required double baseAlpha,
    required double radiusMin,
    required double radiusSpan,
    required double blur,
    required bool softCloud,
  }) {
    final life = lifeMin + seed.nextDouble() * lifeSpan;
    final phase = seed.nextDouble() * life;
    final originX = seed.nextDouble() * size.width;
    final originY = size.height * (0.20 + seed.nextDouble() * 0.52);
    final carryScale = 14 + seed.nextDouble() * 28;
    final liftScale = 5 + seed.nextDouble() * 12;
    final settleScale = 8 + seed.nextDouble() * 18;
    final radius = radiusMin + seed.nextDouble() * radiusSpan;

    final local = (t + phase) % life;
    final u = local / life;

    final envelope = u < 0.2
        ? _smooth01(u / 0.2)
        : u > 0.7
        ? _smooth01((1.0 - u) / 0.3)
        : 1.0;
    if (envelope < 0.03) return;

    final carryX = carryScale * (0.45 + wind.abs() * 0.45 + gust * 0.55);
    final lift = liftScale * (0.35 + gust * 0.8);
    final arc = math.sin(u * math.pi);
    final fall = u * u;

    final px = index * 1.7;
    final turbX =
        math.sin(t * 0.45 + px) * 5 + math.sin(t * 0.95 + px * 2.1) * 2.4;
    final turbY =
        math.cos(t * 0.38 + px * 1.3) * 3.5 +
        math.sin(t * 0.8 + px * 0.9) * 1.8;

    final x = originX + carryX * u + turbX;
    final y = originY - lift * arc + settleScale * fall + turbY;

    if (x < -30 || x > size.width + 30 || y < 0 || y > size.height) return;

    final depth = ((y - vanish.dy) / (size.height - vanish.dy)).clamp(0.0, 1.0);
    final r = radius * (0.6 + depth * 0.85);
    final alpha =
        baseAlpha * envelope * (0.65 + depth * 0.5) * (0.9 + gust * 0.2);

    final color = softCloud
        ? DesertPalette.dustLight.withValues(alpha: alpha)
        : DesertPalette.dust.withValues(alpha: alpha);

    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()
        ..color = color
        ..maskFilter = blur > 0.05
            ? MaskFilter.blur(BlurStyle.normal, blur)
            : null,
    );
  }

  /// The heart of comfort — warm light gathering where you sit.
  void _paintComfortGlow(Canvas canvas, Size size, double breath) {
    final seat = Offset(size.width * 0.5, size.height * 0.90);
    final radius = size.shortestSide * (0.55 + breath * 0.04);

    canvas.drawCircle(
      seat,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          seat,
          radius,
          [
            DesertPalette.comfort.withValues(alpha: 0.22 + breath * 0.12),
            DesertPalette.comfort.withValues(alpha: 0.09 + breath * 0.05),
            DesertPalette.comfort.withValues(alpha: 0.0),
          ],
          const [0.0, 0.4, 1.0],
        ),
    );

    // A quieter second wrap — like a blanket settling.
    canvas.drawCircle(
      seat.translate(0, size.height * 0.02),
      radius * 0.55,
      Paint()
        ..shader = ui.Gradient.radial(seat, radius * 0.55, [
          const Color(0x33FFF0DC),
          const Color(0x00FFF0DC),
        ]),
    );
  }

  void _paintVignette(Canvas canvas, Size size, double breath) {
    // Warm enclosure — held, not darkened.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.58),
          size.longestSide * 0.78,
          [
            const Color(0x00000000),
            Color.fromRGBO(140, 70, 30, 0.03 + breath * 0.015),
            Color.fromRGBO(100, 48, 20, 0.07),
          ],
          const [0.45, 0.82, 1.0],
        ),
    );
  }

  /// Quiet count pressed into the sand at your right —
  /// where a right hand would idly mark, facing you.
  void _paintPresenceInSand(
    Canvas canvas,
    Size size, {
    required double breath,
  }) {
    if (presenceCount <= 0) return;

    final label = _formatPresence(presenceCount);
    final opacity = 0.30 + breath * 0.09;
    final fontSize = size.shortestSide * 0.078;
    final hand = math.Random(presenceCount * 31 + 7);

    // Right lap, close — number only, no sand cover.
    final anchor = Offset(size.width * 0.74, size.height * 0.88);

    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    // Opposite slant — like writing toward yourself with the right hand.
    canvas.rotate(0.18);
    final tip = Matrix4.identity()
      ..setEntry(3, 1, 0.0016)
      ..scaleByDouble(1.08, 0.62, 1.0, 1.0);
    canvas.transform(tip.storage);

    // Finger-written: uneven size, spacing, and tilt per mark.
    final marks =
        <
          ({
            String ch,
            double gap,
            double sizeMul,
            double wobbleY,
            double wobbleRot,
          })
        >[];
    for (var i = 0; i < label.length; i++) {
      marks.add((
        ch: label[i],
        gap: i == 0 ? 0.0 : fontSize * (0.06 + hand.nextDouble() * 0.10),
        sizeMul: 0.94 + hand.nextDouble() * 0.12,
        wobbleY: (hand.nextDouble() - 0.5) * fontSize * 0.12,
        wobbleRot: (hand.nextDouble() - 0.5) * 0.12,
      ));
    }

    var runWidth = 0.0;
    final painters =
        <({TextPainter shadow, TextPainter fill, TextPainter rim})>[];
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
        DesertPalette.duneShadow.withValues(alpha: opacity * 0.9),
      );
      painters.add((
        shadow: glyph(DesertPalette.duneDeepShadow.withValues(alpha: opacity)),
        fill: fill,
        rim: glyph(DesertPalette.duneLit.withValues(alpha: opacity * 0.36)),
      ));
      runWidth += m.gap + fill.width;
    }

    var x = -runWidth * 0.5;
    for (var i = 0; i < painters.length; i++) {
      final m = marks[i];
      final g = painters[i];
      x += m.gap;

      canvas.save();
      canvas.translate(x + g.fill.width * 0.5, m.wobbleY);
      canvas.rotate(m.wobbleRot);
      final o = Offset(-g.fill.width * 0.5, -g.fill.height * 0.35);
      g.shadow.paint(canvas, o.translate(1.0, 1.4));
      g.fill.paint(canvas, o);
      g.rim.paint(canvas, o.translate(-0.5, -0.6));
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

  /// Soft constellation sparks — company wrapping your seat.
  void _paintPresenceSpirits(
    Canvas canvas,
    Size size, {
    required double breath,
  }) {
    if (presenceCount <= 0) return;

    final n = presenceCount <= 3
        ? presenceCount
        : presenceCount < 20
        ? 3 + ((presenceCount - 3) / 4).round().clamp(0, 6)
        : presenceCount < 100
        ? 9 + ((presenceCount - 20) / 16).round().clamp(0, 5)
        : 14;
    final rng = math.Random(53);

    // Home ring around the seat — periphery, not the horizon.
    final seat = Offset(size.width * 0.5, size.height * 0.58);
    final rx = size.width * 0.46;
    final ry = size.height * 0.28;

    for (var i = 0; i < n; i++) {
      final lane = 0.55 + rng.nextDouble() * 0.45;
      final slot = (i + 0.5) / n;
      final sideBias = math.sin(slot * math.pi * 2) * 0.35;
      final homeAngle = slot * math.pi * 2 + sideBias + rng.nextDouble() * 0.5;

      var homeX = seat.dx + math.cos(homeAngle) * rx * lane;
      var homeY = seat.dy + math.sin(homeAngle) * ry * lane * 0.85;

      // Keep a soft clear cone ahead.
      final ahead = (homeX - seat.dx).abs() / (size.width * 0.5);
      final lift = (seat.dy - homeY) / (size.height * 0.35);
      if (ahead < 0.22 && lift > 0.15 && lift < 0.85) {
        final dir = homeX >= seat.dx ? 1.0 : -1.0;
        homeX += dir * (0.22 - ahead) * size.width * 0.55;
      }

      // Irregular wander — layered drifts + rare darts, not a smooth orbit.
      final p1 = rng.nextDouble() * math.pi * 2;
      final p2 = rng.nextDouble() * math.pi * 2;
      final p3 = rng.nextDouble() * math.pi * 2;
      final sx1 = 0.31 + rng.nextDouble() * 0.55;
      final sx2 = 0.73 + rng.nextDouble() * 0.9;
      final sx3 = 1.4 + rng.nextDouble() * 1.6;
      final sy1 = 0.27 + rng.nextDouble() * 0.5;
      final sy2 = 0.61 + rng.nextDouble() * 0.85;
      final sy3 = 1.2 + rng.nextDouble() * 1.4;
      final amp = size.shortestSide * (0.018 + rng.nextDouble() * 0.028);

      final wanderX =
          math.sin(t * sx1 + p1) * amp +
          math.sin(t * sx2 + p2) * amp * 0.55 +
          math.sin(t * sx3 + p3) * amp * 0.28;
      final wanderY =
          math.cos(t * sy1 + p2) * amp * 0.75 +
          math.sin(t * sy2 + p3) * amp * 0.45 +
          math.cos(t * sy3 + p1) * amp * 0.22;

      // Occasional dart — sharp envelope, different phase per spark.
      final dartPhase = rng.nextDouble() * math.pi * 2;
      final dart = math
          .pow(
            (0.5 +
                    0.5 *
                        math.sin(
                          t * (0.17 + rng.nextDouble() * 0.22) + dartPhase,
                        ))
                .clamp(0.0, 1.0),
            10,
          )
          .toDouble();
      final dartDir = rng.nextDouble() * math.pi * 2;
      final dartAmp = amp * (0.8 + rng.nextDouble() * 1.4);

      final pos = Offset(
        homeX + wanderX + math.cos(dartDir) * dartAmp * dart,
        homeY + wanderY + math.sin(dartDir) * dartAmp * dart * 0.7,
      );

      // Twinkle — irregular brightness, not a shared pulse.
      final twinkle =
          0.35 +
          0.65 *
              math
                  .pow(
                    (0.5 +
                            0.5 *
                                math.sin(
                                  t * (0.55 + rng.nextDouble() * 1.4) + p1,
                                ))
                        .clamp(0.0, 1.0),
                    1.6 + rng.nextDouble(),
                  )
                  .toDouble();

      final nearness = (1.1 - lane).clamp(0.4, 1.0);
      final rimFade = (0.45 + ahead.clamp(0.0, 1.0) * 0.55).clamp(0.5, 1.0);
      final r =
          (2.2 + rng.nextDouble() * 2.8) *
          (0.9 + nearness * 0.4) *
          (0.8 + twinkle * 0.4);
      final alpha =
          (0.48 + twinkle * 0.5) * (0.78 + breath * 0.22) * nearness * rimFade;

      _paintPresenceSpark(canvas, center: pos, radius: r, alpha: alpha);
    }
  }

  void _paintPresenceSpark(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double alpha,
  }) {
    canvas.drawCircle(
      center,
      radius * 3.0,
      Paint()
        ..color = DesertPalette.comfort.withValues(alpha: alpha * 0.48)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.6),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFFFFF2DC).withValues(alpha: alpha),
    );
    canvas.drawCircle(
      center,
      radius * 0.4,
      Paint()..color = const Color(0xFFFFFCF8).withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant DesertPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.presenceCount != presenceCount;
}

enum DuneStyle { ridge, mid, near }
