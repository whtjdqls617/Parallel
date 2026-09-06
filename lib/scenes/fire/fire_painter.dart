import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/fire_palette.dart';

/// European brick fireplace — looking into a warm hearth.
class FirePainter extends CustomPainter {
  FirePainter({
    required this.t,
    this.presenceCount = 0,
    this.emberCount = 0,
    this.emberReveal = 1,
    this.emberErase = 0,
    this.showPresence = true,
  });

  final double t;
  final int presenceCount;
  final int emberCount;
  final double emberReveal;
  final double emberErase;
  final bool showPresence;

  static const breathPeriod = 4.2;
  static const emberEraseSeconds = 1.0;
  static const emberPauseSeconds = 0.25;
  static const emberWriteSeconds = 1.2;
  static const presenceSparkMax = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final breath = 0.5 + 0.5 * math.sin(t * (math.pi * 2 / breathPeriod));
    final flicker =
        0.55 +
        0.25 * math.sin(t * 7.3) +
        0.12 * math.sin(t * 13.1) +
        0.08 * math.sin(t * 23.7);

    _paintRoom(canvas, size);
    _paintSurround(canvas, size, flicker);
    _paintFirebox(canvas, size, flicker);
    // Count sits on the brick — painted before flames so fire sits in front.
    if (showPresence) {
      _paintEmberCount(canvas, size, breath: breath, flicker: flicker);
    }
    _paintHearthFloor(canvas, size);
    _paintLogs(canvas, size, flicker, front: false);
    _paintFlames(canvas, size, flicker, breath);
    _paintLogs(canvas, size, flicker, front: true);
    _paintRoomVignette(canvas, size);

    if (showPresence) {
      _paintPresenceEmbers(canvas, size, breath: breath);
    }
  }

  /// Opening of the firebox in scene coords.
  Rect _mouth(Size size) {
    return Rect.fromLTRB(
      size.width * 0.12,
      size.height * 0.18,
      size.width * 0.88,
      size.height * 0.82,
    );
  }

  void _paintRoom(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.55),
          size.shortestSide * 0.85,
          const [
            FirePalette.roomMid,
            FirePalette.roomDeep,
            FirePalette.canvas,
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  /// Dark stone surround + mantel — European hearth frame.
  void _paintSurround(Canvas canvas, Size size, double flicker) {
    final mouth = _mouth(size);

    // Outer stone mass
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        size.width * 0.04,
        size.height * 0.08,
        size.width * 0.96,
        size.height * 0.9,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, size.height * 0.08),
          Offset(size.width * 0.5, size.height * 0.9),
          [
            FirePalette.surroundLit.withValues(alpha: 0.55 + flicker * 0.15),
            FirePalette.surround,
            FirePalette.mantelEdge,
          ],
          const [0.0, 0.4, 1.0],
        ),
    );

    // Mantel shelf
    final shelf = Rect.fromLTRB(
      size.width * 0.02,
      size.height * 0.07,
      size.width * 0.98,
      size.height * 0.155,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shelf, const Radius.circular(3)),
      Paint()
        ..shader = ui.Gradient.linear(
          shelf.topCenter,
          shelf.bottomCenter,
          const [
            Color(0xFF4A4038),
            FirePalette.mantel,
            FirePalette.mantelEdge,
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    // Shelf lip highlight
    canvas.drawLine(
      Offset(shelf.left + 4, shelf.bottom - 2),
      Offset(shelf.right - 4, shelf.bottom - 2),
      Paint()
        ..color = const Color(0x33C8B8A0)
        ..strokeWidth = 1.2,
    );

    // Inner reveal around mouth
    canvas.drawRect(
      mouth.inflate(size.shortestSide * 0.018),
      Paint()..color = FirePalette.mantelEdge,
    );

    // Soft fire spill on surround
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(mouth.center.dx, mouth.bottom - size.height * 0.08),
        width: mouth.width * 1.05,
        height: size.height * 0.35,
      ),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(mouth.center.dx, mouth.bottom - size.height * 0.12),
          mouth.width * 0.55,
          [
            FirePalette.flameMid.withValues(alpha: 0.14 * flicker),
            Colors.transparent,
          ],
        ),
    );
  }

  void _paintFirebox(Canvas canvas, Size size, double flicker) {
    final mouth = _mouth(size);

    // Deep black recess
    canvas.drawRect(mouth, Paint()..color = const Color(0xFF080604));

    // Brick back wall — perspective-ish vertical plane
    final wall = Rect.fromLTRB(
      mouth.left + mouth.width * 0.04,
      mouth.top + mouth.height * 0.02,
      mouth.right - mouth.width * 0.04,
      mouth.bottom - mouth.height * 0.22,
    );

    canvas.drawRect(
      wall,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(wall.center.dx, wall.bottom - wall.height * 0.15),
          wall.height * 0.9,
          [
            FirePalette.brickLit.withValues(alpha: 0.55 + flicker * 0.25),
            FirePalette.brickMid,
            FirePalette.brickDark,
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    _paintBrickGrid(canvas, wall, flicker);

    // Left / right returns (side bricks, darker)
    final leftSide = Path()
      ..moveTo(mouth.left, mouth.top)
      ..lineTo(wall.left, wall.top)
      ..lineTo(wall.left, wall.bottom)
      ..lineTo(mouth.left, mouth.bottom - mouth.height * 0.18)
      ..close();
    canvas.drawPath(
      leftSide,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(mouth.left, mouth.center.dy),
          Offset(wall.left, mouth.center.dy),
          [
            FirePalette.brickDark,
            FirePalette.brickMid.withValues(alpha: 0.7),
          ],
        ),
    );

    final rightSide = Path()
      ..moveTo(mouth.right, mouth.top)
      ..lineTo(wall.right, wall.top)
      ..lineTo(wall.right, wall.bottom)
      ..lineTo(mouth.right, mouth.bottom - mouth.height * 0.18)
      ..close();
    canvas.drawPath(
      rightSide,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(mouth.right, mouth.center.dy),
          Offset(wall.right, mouth.center.dy),
          [
            FirePalette.brickDark,
            FirePalette.brickMid.withValues(alpha: 0.75),
          ],
        ),
    );

    // Side brick hints
    _paintBrickGrid(
      canvas,
      Rect.fromLTRB(mouth.left, wall.top, wall.left, wall.bottom),
      flicker * 0.6,
      cols: 2,
      rows: 8,
    );
    _paintBrickGrid(
      canvas,
      Rect.fromLTRB(wall.right, wall.top, mouth.right, wall.bottom),
      flicker * 0.6,
      cols: 2,
      rows: 8,
    );
  }

  void _paintBrickGrid(
    Canvas canvas,
    Rect area,
    double flicker, {
    int cols = 7,
    int rows = 9,
  }) {
    if (area.width < 4 || area.height < 4) return;
    final mortar = Paint()
      ..color = FirePalette.mortar.withValues(alpha: 0.55)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final brickH = area.height / rows;
    final brickW = area.width / cols;

    for (var r = 0; r <= rows; r++) {
      final y = area.top + r * brickH;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), mortar);
    }

    for (var r = 0; r < rows; r++) {
      final y0 = area.top + r * brickH;
      final offset = (r.isOdd ? brickW * 0.5 : 0.0);
      final startCol = offset > 0 ? -1 : 0;
      for (var c = startCol; c <= cols; c++) {
        final x = area.left + c * brickW + offset;
        if (x < area.left - 1 || x > area.right + 1) continue;
        canvas.drawLine(
          Offset(x.clamp(area.left, area.right), y0),
          Offset(x.clamp(area.left, area.right), y0 + brickH),
          mortar,
        );
      }
    }

    // Warm speckles on lit bricks
    final rng = math.Random(33);
    final speck = Paint();
    for (var i = 0; i < 40; i++) {
      final x = area.left + area.width * rng.nextDouble();
      final y = area.top + area.height * (0.35 + rng.nextDouble() * 0.6);
      final warm = (1.0 - (area.bottom - y) / area.height).clamp(0.0, 1.0);
      speck.color = FirePalette.flameMid.withValues(
        alpha: warm * 0.08 * flicker * rng.nextDouble(),
      );
      canvas.drawCircle(Offset(x, y), 1.5 + rng.nextDouble() * 3, speck);
    }
  }

  void _paintHearthFloor(Canvas canvas, Size size) {
    final mouth = _mouth(size);
    final floor = Path()
      ..moveTo(mouth.left, mouth.bottom - mouth.height * 0.18)
      ..lineTo(mouth.left + mouth.width * 0.04, mouth.bottom - mouth.height * 0.22)
      ..lineTo(mouth.right - mouth.width * 0.04, mouth.bottom - mouth.height * 0.22)
      ..lineTo(mouth.right, mouth.bottom - mouth.height * 0.18)
      ..lineTo(mouth.right, mouth.bottom)
      ..lineTo(mouth.left, mouth.bottom)
      ..close();

    canvas.drawPath(
      floor,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(mouth.center.dx, mouth.bottom - mouth.height * 0.22),
          Offset(mouth.center.dx, mouth.bottom),
          const [
            FirePalette.hearthAsh,
            FirePalette.hearthFloor,
            Color(0xFF040302),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Soft ash bed under logs
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(mouth.center.dx, mouth.bottom - mouth.height * 0.14),
        width: mouth.width * 0.55,
        height: mouth.height * 0.08,
      ),
      Paint()..color = const Color(0xFF1A100C),
    );
  }

  void _paintLogs(
    Canvas canvas,
    Size size,
    double flicker, {
    required bool front,
  }) {
    final mouth = _mouth(size);
    final cx = mouth.center.dx;
    final baseY = mouth.bottom - mouth.height * 0.16;
    final span = mouth.width * 0.52;
    final h = size.height;

    // Journey-like: soft silhouette sticks — almost no surface noise.
    void log({
      required Offset a,
      required Offset b,
      required double thickA,
      required double thickB,
      double bow = 0,
      double glow = 0,
    }) {
      final dir = b - a;
      final len = dir.distance;
      if (len < 1) return;
      final n = Offset(-dir.dy / len, dir.dx / len);
      final mid = Offset.lerp(a, b, 0.5)! + n * bow;
      final thick = math.max(thickA, thickB);

      canvas.drawOval(
        Rect.fromCenter(
          center: mid + Offset(0, thick * 0.25),
          width: len * 0.75,
          height: thick * 0.4,
        ),
        Paint()
          ..color = const Color(0x44000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      final path = Path()
        ..moveTo((a + n * thickA * 0.5).dx, (a + n * thickA * 0.5).dy)
        ..quadraticBezierTo(
          (mid + n * ((thickA + thickB) * 0.28)).dx,
          (mid + n * ((thickA + thickB) * 0.28)).dy,
          (b + n * thickB * 0.42).dx,
          (b + n * thickB * 0.42).dy,
        )
        ..lineTo((b - n * thickB * 0.5).dx, (b - n * thickB * 0.5).dy)
        ..quadraticBezierTo(
          (mid - n * ((thickA + thickB) * 0.26)).dx,
          (mid - n * ((thickA + thickB) * 0.26)).dy,
          (a - n * thickA * 0.48).dx,
          (a - n * thickA * 0.48).dy,
        )
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF0A0806)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            a - n * thick * 0.05,
            a + n * thick * 0.9,
            [
              Color.lerp(
                const Color(0xFF3A2A20),
                FirePalette.flameMid,
                glow * 0.22 * flicker,
              )!,
              const Color(0xFF1C140E),
              const Color(0xFF0C0A08),
            ],
            const [0.0, 0.4, 1.0],
          ),
      );

      if (glow > 0.08) {
        canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(
              mid - n * thick * 0.1,
              mid + n * thick * 0.5,
              [
                FirePalette.flameCore.withValues(alpha: 0.22 * glow * flicker),
                FirePalette.flameMid.withValues(alpha: 0.1 * glow * flicker),
                const Color(0x00000000),
              ],
              const [0.0, 0.4, 1.0],
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    if (!front) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, baseY - h * 0.018),
          width: span * 0.38,
          height: h * 0.024,
        ),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, baseY - h * 0.02),
            span * 0.2,
            [
              FirePalette.flameCore.withValues(alpha: 0.55 * flicker),
              FirePalette.flameMid.withValues(alpha: 0.25 * flicker),
              const Color(0x00000000),
            ],
            const [0.0, 0.45, 1.0],
          ),
      );

      // Simple crossed / layered pile
      log(
        a: Offset(cx - span * 0.46, baseY + h * 0.006),
        b: Offset(cx + span * 0.36, baseY),
        thickA: h * 0.034,
        thickB: h * 0.028,
        bow: h * 0.004,
        glow: 0.55,
      );
      log(
        a: Offset(cx - span * 0.3, baseY - h * 0.01),
        b: Offset(cx + span * 0.4, baseY - h * 0.03),
        thickA: h * 0.03,
        thickB: h * 0.024,
        bow: h * 0.003,
        glow: 0.45,
      );
      log(
        a: Offset(cx - span * 0.22, baseY - h * 0.032),
        b: Offset(cx + span * 0.26, baseY - h * 0.046),
        thickA: h * 0.024,
        thickB: h * 0.02,
        bow: -h * 0.003,
        glow: 0.35,
      );
      return;
    }

    log(
      a: Offset(cx - span * 0.4, baseY + h * 0.02),
      b: Offset(cx + span * 0.44, baseY + h * 0.014),
      thickA: h * 0.036,
      thickB: h * 0.03,
      bow: -h * 0.002,
      glow: 0.75,
    );
    log(
      a: Offset(cx - span * 0.42, baseY + h * 0.004),
      b: Offset(cx - span * 0.16, baseY - h * 0.034),
      thickA: h * 0.026,
      thickB: h * 0.016,
      bow: h * 0.003,
      glow: 0.4,
    );
    log(
      a: Offset(cx + span * 0.14, baseY + h * 0.01),
      b: Offset(cx + span * 0.44, baseY - h * 0.026),
      thickA: h * 0.024,
      thickB: h * 0.015,
      bow: -h * 0.004,
      glow: 0.4,
    );
    log(
      a: Offset(cx - span * 0.1, baseY - h * 0.008),
      b: Offset(cx + span * 0.18, baseY - h * 0.018),
      thickA: h * 0.014,
      thickB: h * 0.011,
      bow: h * 0.002,
      glow: 0.5,
    );
  }

  /// Flame silhouette — morph varies the character (blob / curl / split / lick…).
  Path _flameTonguePath({
    required Offset base,
    required double rise,
    required double halfW,
    required double sway,
    required double lean,
    required double belly,
    required double tipJitter,
    required double phase,
    required double roundness,
    int morph = 0,
    bool fork = false,
    int steps = 20,
  }) {
    final r = roundness.clamp(0.0, 1.0);
    final m = morph % 6;
    final left = <Offset>[];
    final right = <Offset>[];

    // Live morphing — fire never holds one silhouette
    final morphPulse = 0.5 + 0.5 * math.sin(t * (2.1 + phase * 0.15) + phase);

    for (var i = 0; i <= steps; i++) {
      final u = i / steps;

      // Width profile by morph family
      late double bellyU;
      late double taperPow;
      late double tipFloor;
      late double midBulge;
      switch (m) {
        case 1: // bulb / mushroom — fat upper belly
          bellyU = 0.38 + r * 0.12;
          taperPow = 0.55 + r * 0.25;
          tipFloor = 0.2 + r * 0.25;
          midBulge = 0.35 + morphPulse * 0.2;
        case 2: // curling ribbon — narrower, S-lean
          bellyU = 0.14 + r * 0.08;
          taperPow = 0.85 + r * 0.2;
          tipFloor = 0.1 + r * 0.15;
          midBulge = 0.05;
        case 3: // split-ready — mid waist then flare
          bellyU = 0.22 + r * 0.1;
          taperPow = 0.65 + r * 0.3;
          tipFloor = 0.18 + r * 0.2;
          midBulge = 0.15 + (1 - morphPulse) * 0.15;
        case 4: // short fat lick
          bellyU = 0.28 + r * 0.15;
          taperPow = 0.5 + r * 0.4;
          tipFloor = 0.28 + r * 0.3;
          midBulge = 0.4;
        case 5: // tall plume — slow taper
          bellyU = 0.12 + r * 0.06;
          taperPow = 0.95 + r * 0.15;
          tipFloor = 0.08 + r * 0.12;
          midBulge = 0.08;
        default: // classic tongue
          bellyU = 0.16 + r * 0.1;
          taperPow = 0.72 + r * 0.35;
          tipFloor = 0.12 + r * 0.2;
          midBulge = 0.12 + morphPulse * 0.1;
      }

      final width01 = u < bellyU
          ? (0.55 + 0.45 * (u / bellyU))
          : math
              .pow(1.0 - ((u - bellyU) / (1.0 - bellyU)), taperPow)
              .toDouble();
      final bulge =
          midBulge * math.sin(math.pi * u.clamp(0.0, 1.0)) * (0.7 + morphPulse * 0.4);
      final rootBoost = (1.0 - u).clamp(0.0, 1.0);
      var width = halfW *
          (math.max(width01 + bulge, tipFloor * u) *
                  (0.85 + belly * 0.18) *
                  (1.0 + r * 0.25) +
              rootBoost * 0.16);

      // Asymmetry — left/right never mirror perfectly
      final asym =
          0.12 * math.sin(phase * 1.7 + m) + 0.08 * math.sin(t * 1.8 + phase);
      final leftScale = 1.0 + asym + (m == 2 ? 0.15 : 0.0);
      final rightScale = 1.0 - asym * 0.8 + (m == 1 ? 0.12 : 0.0);

      // Centerline: morph 2 curls harder; others sway normally
      final curl = m == 2
          ? math.sin(u * math.pi * 1.4 + t * 3.2 + phase) * halfW * 0.55
          : math.sin(u * math.pi + t * 2.4 + phase) * halfW * (0.08 + m * 0.03);
      final swayAmt = sway * (0.08 + 0.92 * u * u) + curl * u;
      final leanAmt = lean * rise * u * u * (m == 5 ? 0.4 : 0.55);
      final turb =
          math.sin(t * (4.6 + phase * 0.35 + m * 0.4) + phase + u * 5.5) *
              halfW *
              0.05 *
              u +
          math.sin(t * (11.0 + phase) + phase * 1.5 + u * 8.5 + m) *
              halfW *
              0.03 *
              u *
              u +
          tipJitter * halfW * 0.02 * u * u;
      final cx = base.dx + swayAmt + leanAmt + turb;
      // Morph 4 stays shorter in Y; morph 5 stretches
      final yScale = m == 4 ? 0.78 : (m == 5 ? 1.08 : 1.0);
      final cy = base.dy - rise * u * yScale * (1.0 - r * 0.06 * u);

      final flutterL = math.sin(t * (7.2 + phase * 0.4 + m) + phase + u * 10) *
              width *
              (0.04 + 0.12 * u) +
          math.sin(t * 14.5 + phase * 2 + u * 12) * width * 0.025 * u;
      final flutterR = math.sin(t * (8.0 + phase * 0.4) + phase + 2 + u * 9) *
              width *
              (0.035 + 0.11 * u) +
          math.cos(t * 13.5 + phase * 1.6 + u * 11) * width * 0.022 * u;

      left.add(Offset(cx - width * leftScale - flutterL, cy));
      right.add(Offset(cx + width * rightScale + flutterR, cy));
    }

    final tipL = left.last;
    final tipR = right.last;
    final tipX = (tipL.dx + tipR.dx) * 0.5 + tipJitter * halfW * 0.03;
    final tipSoft = halfW * (0.2 + r * 0.5 + (m == 1 || m == 4 ? 0.25 : 0.0));
    final tipY = math.min(tipL.dy, tipR.dy) -
        rise * (0.01 + r * 0.025 + (m == 5 ? 0.02 : 0.0));

    final path = Path()
      ..moveTo(base.dx - halfW * 0.55, base.dy + rise * 0.02);
    for (var i = 0; i < left.length; i++) {
      path.lineTo(left[i].dx, left[i].dy);
    }

    final doFork = fork || m == 3;
    if (doFork && r < 0.7) {
      final forkH = rise * (0.07 + 0.05 * math.sin(t * 8.5 + phase) + (m == 3 ? 0.06 : 0));
      final forkX = tipX -
          tipSoft * (0.7 + 0.35 * math.sin(t * 6.0 + phase)) *
              (m == 3 ? 1.3 : 1.0);
      // Second soft lobe on the other side sometimes
      final twin = m == 3 || (fork && morphPulse > 0.55);
      path
        ..quadraticBezierTo(
          tipX - tipSoft * 0.55,
          tipY + rise * 0.02,
          forkX,
          tipY - forkH,
        )
        ..quadraticBezierTo(
          tipX - tipSoft * 0.1,
          tipY - rise * 0.005,
          tipX,
          tipY,
        );
      if (twin) {
        final fork2X = tipX + tipSoft * (0.65 + 0.2 * math.cos(t * 5.5 + phase));
        final fork2H = rise * (0.05 + 0.03 * math.cos(t * 7.2 + phase));
        path.quadraticBezierTo(
          tipX + tipSoft * 0.25,
          tipY - rise * 0.01,
          fork2X,
          tipY - fork2H,
        );
      }
      path.quadraticBezierTo(
        tipX + tipSoft * 0.5,
        tipY + rise * 0.03,
        tipR.dx,
        tipR.dy,
      );
    } else if (m == 1) {
      // Domed / mushroom cap tip
      path
        ..quadraticBezierTo(
          tipX - tipSoft * 0.9,
          tipY + rise * 0.04,
          tipX - tipSoft * 0.35,
          tipY - rise * 0.01,
        )
        ..quadraticBezierTo(tipX, tipY - rise * 0.02, tipX, tipY)
        ..quadraticBezierTo(
          tipX + tipSoft * 0.35,
          tipY - rise * 0.01,
          tipX + tipSoft * 0.9,
          tipY + rise * 0.04,
        )
        ..quadraticBezierTo(
          tipX + tipSoft * 0.4,
          tipY + rise * 0.02,
          tipR.dx,
          tipR.dy,
        );
    } else {
      // Soft rounded tip
      path
        ..quadraticBezierTo(
          tipX - tipSoft * (0.45 + r * 0.2),
          tipY + rise * 0.012,
          tipX,
          tipY,
        )
        ..quadraticBezierTo(
          tipX + tipSoft * (0.45 + r * 0.2),
          tipY + rise * 0.015,
          tipR.dx,
          tipR.dy,
        );
    }

    for (var i = right.length - 1; i >= 0; i--) {
      path.lineTo(right[i].dx, right[i].dy);
    }
    path.lineTo(base.dx + halfW * 0.55, base.dy + rise * 0.02);
    path.close();
    return path;
  }

  void _paintFlames(
    Canvas canvas,
    Size size,
    double flicker,
    double breath,
  ) {
    final mouth = _mouth(size);
    final base = Offset(
      mouth.center.dx,
      mouth.bottom - mouth.height * 0.16 - size.height * 0.04,
    );
    final h = size.height * (0.36 + 0.05 * flicker);
    final w = mouth.width * 0.48;

    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, -h * 0.4),
        width: w * 1.7,
        height: h * 1.25,
      ),
      Paint()
        ..color = const Color(0xFFFF4A10).withValues(alpha: 0.14 * flicker)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, size.shortestSide * 0.05)
        ..blendMode = BlendMode.plus,
    );

    void tongue({
      required double ox,
      required double phase,
      required double heightScale,
      required double widthScale,
      required double lean,
      required double belly,
      required int layer,
      required double roundness,
      int morph = 0,
      double baseDy = 0,
      bool fork = false,
    }) {
      final sway =
          math.sin(t * (3.4 + phase * 0.45 + morph * 0.2) + phase) * w * 0.1 +
          math.sin(t * (9.5 + phase * 0.3) + phase * 1.5) * w * 0.045 +
          math.sin(t * (17.5 + phase) + phase * 2.2) * w * 0.02;
      final rise = h *
          heightScale *
          (0.78 +
              0.13 * math.sin(t * (5.2 + phase * 0.3) + phase) +
              0.08 * math.sin(t * 12.5 + phase * 2.0) +
              0.04 * math.sin(t * 20.5 + phase + morph) +
              breath * 0.05);
      final halfW = w * 0.14 * widthScale * (1.0 + roundness * 0.22);
      final tipJitter = math.sin(t * 14.0 + phase) +
          0.4 * math.sin(t * 22.5 + phase * 1.2);
      final root = base.translate(ox, baseDy * size.height);
      final path = _flameTonguePath(
        base: root,
        rise: rise,
        halfW: halfW,
        sway: sway,
        lean: lean,
        belly: belly,
        tipJitter: tipJitter,
        phase: phase,
        roundness: roundness,
        morph: morph,
        fork: fork,
        steps: 18 + morph,
      );

      final tip = root.translate(sway * 0.65, -rise);

      if (layer == 0) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFF2808).withValues(alpha: 0.22 * flicker)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + roundness * 5)
            ..blendMode = BlendMode.plus,
        );
        canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(
              root,
              tip,
              [
                const Color(0xFFFF5518).withValues(alpha: 0.95),
                const Color(0xFFFF7A22).withValues(alpha: 0.85),
                const Color(0xFFFF9A28).withValues(alpha: 0.4),
                const Color(0xFFFF6A18).withValues(alpha: 0.0),
              ],
              const [0.0, 0.22, 0.58, 1.0],
            )
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              1.2 + roundness * 2.5,
            ),
        );
      } else if (layer == 1) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFA028).withValues(alpha: 0.16 * flicker)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
            ..blendMode = BlendMode.plus,
        );
        canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(
              root,
              tip,
              [
                const Color(0xFFFFD050).withValues(alpha: 0.98),
                const Color(0xFFFFE878).withValues(alpha: 0.9),
                const Color(0xFFFFB038).withValues(alpha: 0.35),
                const Color(0xFFFF8A20).withValues(alpha: 0.0),
              ],
              const [0.0, 0.28, 0.65, 1.0],
            )
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              0.8 + roundness * 1.8,
            ),
        );
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(
              root,
              tip,
              [
                const Color(0xFFFFFFF8).withValues(alpha: 1.0),
                const Color(0xFFFFF4C8).withValues(alpha: 0.92),
                const Color(0xFFFFD060).withValues(alpha: 0.3),
                const Color(0xFFFFB040).withValues(alpha: 0.0),
              ],
              const [0.0, 0.3, 0.68, 1.0],
            )
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.6 + roundness)
            ..blendMode = BlendMode.plus,
        );
      }
    }

    // Diverse outer cast — classic / bulb / curl / split / fat / plume
    const outers = <({
      double ox,
      double ph,
      double hs,
      double ws,
      double lean,
      double belly,
      double rnd,
      double by,
      int morph,
      bool fork,
    })>[
      (ox: -0.32, ph: 0.1, hs: 0.45, ws: 1.25, lean: -0.45, belly: 1.4, rnd: 0.85, by: 0.015, morph: 4, fork: false),
      (ox: -0.22, ph: 0.6, hs: 0.72, ws: 1.0, lean: -0.3, belly: 1.2, rnd: 0.55, by: 0.011, morph: 2, fork: false),
      (ox: -0.1, ph: 1.1, hs: 1.05, ws: 1.05, lean: -0.12, belly: 1.3, rnd: 0.4, by: 0.008, morph: 0, fork: true),
      (ox: 0.02, ph: 1.7, hs: 1.28, ws: 1.1, lean: 0.05, belly: 1.35, rnd: 0.35, by: 0.006, morph: 5, fork: true),
      (ox: 0.14, ph: 2.4, hs: 0.9, ws: 1.15, lean: 0.22, belly: 1.4, rnd: 0.7, by: 0.01, morph: 1, fork: false),
      (ox: 0.26, ph: 3.1, hs: 0.7, ws: 0.95, lean: 0.38, belly: 1.15, rnd: 0.4, by: 0.012, morph: 3, fork: true),
      (ox: 0.34, ph: 3.8, hs: 0.42, ws: 1.2, lean: 0.5, belly: 1.35, rnd: 0.8, by: 0.016, morph: 4, fork: false),
      (ox: -0.28, ph: 4.5, hs: 0.55, ws: 0.9, lean: -0.52, belly: 1.1, rnd: 0.5, by: 0.014, morph: 2, fork: true),
      (ox: 0.08, ph: 5.2, hs: 0.65, ws: 0.85, lean: 0.15, belly: 1.2, rnd: 0.6, by: 0.009, morph: 1, fork: false),
      (ox: -0.04, ph: 5.9, hs: 0.85, ws: 0.75, lean: -0.08, belly: 1.05, rnd: 0.3, by: 0.007, morph: 3, fork: true),
    ];
    for (final f in outers) {
      tongue(
        ox: w * f.ox,
        phase: f.ph,
        heightScale: f.hs,
        widthScale: f.ws,
        lean: f.lean,
        belly: f.belly,
        layer: 0,
        roundness: f.rnd,
        morph: f.morph,
        baseDy: f.by,
        fork: f.fork,
      );
    }

    const mids = <({
      double ox,
      double ph,
      double hs,
      double ws,
      double lean,
      double belly,
      double rnd,
      double by,
      int morph,
      bool fork,
    })>[
      (ox: -0.16, ph: 0.4, hs: 0.75, ws: 0.85, lean: -0.2, belly: 1.25, rnd: 0.65, by: 0.01, morph: 1, fork: false),
      (ox: -0.05, ph: 1.2, hs: 1.0, ws: 0.7, lean: -0.05, belly: 1.1, rnd: 0.35, by: 0.006, morph: 0, fork: true),
      (ox: 0.08, ph: 2.0, hs: 1.18, ws: 0.68, lean: 0.08, belly: 1.15, rnd: 0.3, by: 0.005, morph: 5, fork: true),
      (ox: 0.18, ph: 2.9, hs: 0.8, ws: 0.9, lean: 0.25, belly: 1.3, rnd: 0.7, by: 0.01, morph: 4, fork: false),
      (ox: 0.0, ph: 3.7, hs: 0.58, ws: 0.5, lean: -0.12, belly: 1.0, rnd: 0.4, by: 0.007, morph: 3, fork: true),
      (ox: -0.12, ph: 4.6, hs: 0.52, ws: 0.7, lean: -0.28, belly: 1.15, rnd: 0.55, by: 0.012, morph: 2, fork: false),
      (ox: 0.12, ph: 5.4, hs: 0.68, ws: 0.6, lean: 0.18, belly: 1.05, rnd: 0.45, by: 0.008, morph: 0, fork: true),
      (ox: 0.24, ph: 6.1, hs: 0.48, ws: 0.95, lean: 0.35, belly: 1.35, rnd: 0.8, by: 0.014, morph: 1, fork: false),
    ];
    for (final f in mids) {
      tongue(
        ox: w * f.ox,
        phase: f.ph,
        heightScale: f.hs,
        widthScale: f.ws,
        lean: f.lean,
        belly: f.belly,
        layer: 1,
        roundness: f.rnd,
        morph: f.morph,
        baseDy: f.by,
        fork: f.fork,
      );
    }

    const cores = <({
      double ox,
      double ph,
      double hs,
      double ws,
      double lean,
      double belly,
      double rnd,
      double by,
      int morph,
    })>[
      (ox: -0.06, ph: 0.9, hs: 0.58, ws: 0.38, lean: -0.08, belly: 1.0, rnd: 0.5, by: 0.006, morph: 1),
      (ox: 0.03, ph: 1.9, hs: 0.8, ws: 0.3, lean: 0.03, belly: 0.9, rnd: 0.25, by: 0.004, morph: 5),
      (ox: 0.12, ph: 2.9, hs: 0.5, ws: 0.42, lean: 0.14, belly: 1.1, rnd: 0.6, by: 0.007, morph: 4),
      (ox: -0.02, ph: 4.0, hs: 0.45, ws: 0.28, lean: -0.04, belly: 0.95, rnd: 0.35, by: 0.005, morph: 0),
      (ox: 0.08, ph: 5.0, hs: 0.62, ws: 0.34, lean: 0.1, belly: 1.0, rnd: 0.45, by: 0.006, morph: 2),
    ];
    for (final f in cores) {
      tongue(
        ox: w * f.ox,
        phase: f.ph,
        heightScale: f.hs,
        widthScale: f.ws,
        lean: f.lean,
        belly: f.belly,
        layer: 2,
        roundness: f.rnd,
        morph: f.morph,
        baseDy: f.by,
      );
    }

    // Extra roaming flickers — morph cycles so the cast keeps changing
    for (var i = 0; i < 5; i++) {
      final ph = i * 1.33 + 0.5;
      final morph = (i + (t * 0.35).floor()) % 6;
      final ox = w *
          (-0.2 +
              i * 0.1 +
              0.04 * math.sin(t * 1.7 + ph) +
              0.03 * math.sin(t * 0.6 + i));
      tongue(
        ox: ox,
        phase: ph + 7,
        heightScale: 0.55 + 0.35 * math.sin(t * 3.8 + ph).abs(),
        widthScale: 0.45 + 0.35 * ((i * 37) % 5) / 5,
        lean: -0.35 + i * 0.15 + 0.1 * math.sin(t * 2.2 + ph),
        belly: 0.9 + 0.4 * math.sin(t * 1.5 + ph).abs(),
        layer: i.isEven ? 1 : 0,
        roundness: 0.35 + 0.4 * ((i * 17) % 4) / 4,
        morph: morph,
        baseDy: 0.005 + 0.004 * (i % 3),
        fork: morph == 3 || i % 3 == 0,
      );
    }
  }

  void _paintRoomVignette(Canvas canvas, Size size) {
    final mouth = _mouth(size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          mouth.center,
          size.shortestSide * 0.72,
          [
            Colors.transparent,
            FirePalette.canvas.withValues(alpha: 0.35),
            FirePalette.canvas.withValues(alpha: 0.85),
          ],
          const [0.0, 0.62, 1.0],
        ),
    );
  }

  void _paintPresenceEmbers(
    Canvas canvas,
    Size size, {
    required double breath,
  }) {
    final n = presenceSparkMax;
    final rng = math.Random(61);
    final mouth = _mouth(size);
    final seat = Offset(mouth.center.dx, mouth.bottom - mouth.height * 0.25);

    for (var i = 0; i < n; i++) {
      final homeX = mouth.left +
          mouth.width * (0.15 + (i + 0.5) / n * 0.7) +
          (rng.nextDouble() - 0.5) * mouth.width * 0.04;
      final homeY = mouth.top + mouth.height * (0.2 + rng.nextDouble() * 0.45);
      final amp = size.shortestSide * (0.01 + rng.nextDouble() * 0.018);
      final p1 = rng.nextDouble() * math.pi * 2;
      final p2 = rng.nextDouble() * math.pi * 2;
      final wanderX = math.sin(t * (0.4 + rng.nextDouble()) + p1) * amp;
      final wanderY = math.cos(t * (0.35 + rng.nextDouble()) + p2) * amp * 0.8;
      final c = Offset(homeX + wanderX, homeY + wanderY) +
          Offset((seat.dx - homeX) * 0.04, (seat.dy - homeY) * 0.03);
      final pulse = 0.45 +
          0.35 * math.sin(t * (1.2 + rng.nextDouble()) + p1) +
          breath * 0.1;
      final r = size.shortestSide * (0.0035 + rng.nextDouble() * 0.0035);
      canvas.drawCircle(
        c,
        r * 2.4,
        Paint()
          ..color = FirePalette.comfort.withValues(alpha: pulse * 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()..color = FirePalette.flameCore.withValues(alpha: pulse * 0.9),
      );
    }
  }

  void _paintEmberCount(
    Canvas canvas,
    Size size, {
    required double breath,
    required double flicker,
  }) {
    if (emberCount <= 0) return;
    if (emberReveal < 0.01 && emberErase > 0.99) return;

    final label = emberCount > 9999 ? '9999+' : '$emberCount';
    final fireLit = (0.45 + flicker * 0.55).clamp(0.0, 1.0);
    final opacity = (0.55 + breath * 0.12 + flicker * 0.22) *
        emberReveal *
        (1.0 - emberErase * 0.85);
    if (opacity < 0.02) return;

    final mouth = _mouth(size);
    final fontSize = size.shortestSide * 0.062;
    // Brick wall, upper-left (a bit toward center) — before flames.
    final anchor = Offset(
      mouth.left + mouth.width * 0.18,
      mouth.top + mouth.height * 0.13,
    );

    final ink = Color.lerp(
      const Color(0xFF8A5038),
      const Color(0xFFFFE8C0),
      fireLit,
    )!;
    final glow = FirePalette.flameMid.withValues(
      alpha: opacity * (0.5 + flicker * 0.5),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: ink.withValues(alpha: opacity.clamp(0.35, 0.95)),
          fontSize: fontSize,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.4,
          shadows: [
            Shadow(color: glow, blurRadius: 12 + flicker * 14),
            Shadow(
              color: FirePalette.flameOuter.withValues(alpha: opacity * 0.4),
              blurRadius: 22,
              offset: const Offset(3, 5),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Slight lean on the brick — not straight UI chrome.
    const tilt = -0.12; // ~7°
    final revealW = tp.width * emberReveal.clamp(0.0, 1.0) + 2;

    canvas.save();
    canvas.translate(anchor.dx + tp.width * 0.5, anchor.dy);
    canvas.rotate(tilt);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: tp.width + 14,
          height: tp.height + 10,
        ),
        const Radius.circular(4),
      ),
      Paint()
        ..color = FirePalette.brickLit.withValues(alpha: 0.12 + flicker * 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.clipRect(
      Rect.fromLTWH(-tp.width * 0.5, -tp.height * 0.5, revealW, tp.height + 4),
    );
    tp.paint(canvas, Offset(-tp.width * 0.5, -tp.height * 0.5));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FirePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.presenceCount != presenceCount ||
      oldDelegate.emberCount != emberCount ||
      oldDelegate.emberReveal != emberReveal ||
      oldDelegate.emberErase != emberErase ||
      oldDelegate.showPresence != showPresence;
}
