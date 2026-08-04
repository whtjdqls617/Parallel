import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/forest_palette.dart';

/// Small moss hideout — room-scale forms you can read, not color washes.
/// Ceiling, walls, trunks, moss floor. Soft light on real shapes.
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
    final wind = math.sin(t * 0.12) * 0.45 + math.sin(t * 0.05) * 0.55;
    final sway = math.sin(t * 0.07) * 0.005;
    final pocket = Offset(size.width * 0.5, size.height * 0.40);

    _paintRoomAir(canvas, size, breath: breath);

    // Back hedge wall — lobed silhouette a few meters away.
    _paintBackHedge(canvas, size, wind: wind, sway: sway);

    // Soft pocket light between walls (glow only — forms stay sharp).
    _paintPocketGlow(canvas, size, pocket: pocket, breath: breath);

    // Leaf ceiling clusters — hanging shapes with readable bottoms.
    _paintCanopyClusters(canvas, size, wind: wind, sway: sway, breath: breath);

    // Side thickets — close walls of the room.
    _paintSideThicket(canvas, size, left: true, wind: wind, sway: sway);
    _paintSideThicket(canvas, size, left: false, wind: wind, sway: sway);

    // Trunks — solid pillars.
    _paintTrunk(
      canvas,
      size,
      base: Offset(
        size.width * 0.11 + sway * size.width * 0.3,
        size.height * 0.78,
      ),
      height: size.height * 0.72,
      widthBase: size.width * 0.07,
      lean: 0.018,
      litSide: 1,
      wind: wind,
    );
    _paintTrunk(
      canvas,
      size,
      base: Offset(
        size.width * 0.89 - sway * size.width * 0.3,
        size.height * 0.80,
      ),
      height: size.height * 0.74,
      widthBase: size.width * 0.075,
      lean: -0.016,
      litSide: -1,
      wind: wind,
    );

    // Near leaf tufts at trunk bases / wall edge.
    _paintNearLeafTufts(canvas, size, wind: wind, sway: sway);

    final mossPath = _paintMossFloor(
      canvas,
      size,
      startY: size.height * 0.54,
      wind: wind,
    );
    _paintMossGrain(
      canvas,
      size,
      mossPath: mossPath,
      startY: size.height * 0.54,
    );
    _paintMossContours(canvas, size, startY: size.height * 0.56, wind: wind);
    _paintNearGrass(canvas, size, startY: size.height * 0.58, wind: wind);
    _paintDapples(canvas, size, breath: breath);

    _paintMotes(canvas, size, breath: breath, pocket: pocket);
    _paintPresenceInMoss(canvas, size, breath: breath);
    _paintPresenceSpirits(canvas, size, breath: breath);
    _paintComfortGlow(canvas, size, breath);
    _paintRoomVignette(canvas, size, breath);
  }

  void _paintRoomAir(Canvas canvas, Size size, {required double breath}) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, size.height),
          [
            ForestPalette.shadeDeep,
            ForestPalette.shade,
            ForestPalette.airDeep,
            ForestPalette.airMid,
          ],
          const [0.0, 0.25, 0.55, 1.0],
        ),
    );
    // Warm center — still a fill, forms will sit on top.
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.42),
      size.width * 0.28,
      Paint()
        ..color = ForestPalette.sunGlow.withValues(alpha: 0.12 + breath * 0.05),
    );
  }

  /// Back wall as a lobed hedge — silhouette first, then soft fill on it.
  void _paintBackHedge(
    Canvas canvas,
    Size size, {
    required double wind,
    required double sway,
  }) {
    final swayX = sway * size.width * 0.12;
    final baseY = size.height * 0.52;
    final topY = size.height * 0.14;

    // Lobed crest across the back — readable bush tops, not a mountain ridge.
    final lobes = <({double u, double h, double w})>[
      (u: 0.06, h: 0.72, w: 0.11),
      (u: 0.18, h: 0.95, w: 0.13),
      (u: 0.32, h: 0.78, w: 0.12),
      (u: 0.46, h: 0.62, w: 0.14),
      (u: 0.58, h: 0.68, w: 0.12),
      (u: 0.72, h: 0.88, w: 0.13),
      (u: 0.86, h: 0.96, w: 0.12),
      (u: 0.96, h: 0.74, w: 0.10),
    ];

    final path = Path()..moveTo(-20, size.height * 0.7);
    path.lineTo(-20, baseY);

    // Build lobed top edge left → right.
    for (final lobe in lobes) {
      final cx = size.width * lobe.u + swayX;
      final cy = ui.lerpDouble(baseY, topY, lobe.h)!;
      final rx = size.width * lobe.w;
      final ry = size.height * 0.08 * lobe.h;
      // Approximate lobe with a soft arc bump.
      path.quadraticBezierTo(
        cx - rx * 0.35,
        cy + ry * 0.2,
        cx,
        cy - ry * 0.15 + math.sin(t * 0.1 + lobe.u * 4) * wind * 2,
      );
      path.quadraticBezierTo(
        cx + rx * 0.35,
        cy + ry * 0.2,
        cx + rx * 0.55,
        ui.lerpDouble(baseY, topY, lobe.h * 0.7)!,
      );
    }
    path.lineTo(size.width + 20, baseY);
    path.lineTo(size.width + 20, size.height * 0.7);
    path.close();

    // Solid body — no blur. Value does the softness.
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, topY),
          Offset(0, baseY + size.height * 0.08),
          [
            ForestPalette.shadeDeep,
            ForestPalette.canopyNear,
            ForestPalette.canopyMid,
            ForestPalette.canopyLit,
          ],
          const [0.0, 0.35, 0.7, 1.0],
        ),
    );

    // Lit rims on lobe tops — makes bushes read.
    for (final lobe in lobes) {
      final cx = size.width * lobe.u + swayX;
      final cy =
          ui.lerpDouble(baseY, topY, lobe.h)! -
          size.height * 0.02 +
          math.sin(t * 0.1 + lobe.u * 4) * wind * 2;
      final rx = size.width * lobe.w * 0.85;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: rx * 1.6,
          height: size.height * 0.035,
        ),
        Paint()..color = ForestPalette.canopySun.withValues(alpha: 0.22),
      );
      // Dark under-lobe.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy + size.height * 0.04),
          width: rx * 1.4,
          height: size.height * 0.05,
        ),
        Paint()..color = ForestPalette.shadeDeep.withValues(alpha: 0.28),
      );
    }

    // A few mid trunks peeking through the hedge — thin, quiet.
    final rng = math.Random(11);
    for (var i = 0; i < 5; i++) {
      final u = 0.2 + i * 0.15 + (rng.nextDouble() - 0.5) * 0.04;
      if ((u - 0.5).abs() < 0.08) continue;
      final x = size.width * u;
      final top = size.height * (0.28 + rng.nextDouble() * 0.08);
      final bot = baseY + size.height * 0.02;
      final w = size.width * (0.01 + rng.nextDouble() * 0.006);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - w * 0.4, top, x + w * 0.4, bot),
          Radius.circular(w),
        ),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x, top),
            Offset(x, bot),
            [
              const Color(0xFF2A2420).withValues(alpha: 0.0),
              const Color(0xFF2A2420).withValues(alpha: 0.45),
              const Color(0xFF2A2420).withValues(alpha: 0.25),
            ],
            const [0.0, 0.25, 1.0],
          ),
      );
    }
  }

  void _paintPocketGlow(
    Canvas canvas,
    Size size, {
    required Offset pocket,
    required double breath,
  }) {
    canvas.drawOval(
      Rect.fromCenter(
        center: pocket,
        width: size.width * 0.5,
        height: size.height * 0.36,
      ),
      Paint()
        ..shader = ui.Gradient.radial(pocket, size.width * 0.28, [
          ForestPalette.mossSun.withValues(alpha: 0.16 + breath * 0.06),
          ForestPalette.mossSun.withValues(alpha: 0.0),
        ]),
    );
  }

  /// Hanging leaf masses — each cluster is a lobed shape with a clear bottom.
  void _paintCanopyClusters(
    Canvas canvas,
    Size size, {
    required double wind,
    required double sway,
    required double breath,
  }) {
    final swayX = sway * size.width * 0.25;
    final clusters = <({double u, double y, double s, int seed})>[
      (u: 0.08, y: 0.02, s: 1.15, seed: 2),
      (u: 0.22, y: 0.0, s: 1.0, seed: 5),
      (u: 0.38, y: 0.04, s: 0.85, seed: 8),
      (u: 0.52, y: 0.06, s: 0.75, seed: 11),
      (u: 0.66, y: 0.03, s: 0.9, seed: 14),
      (u: 0.80, y: 0.0, s: 1.05, seed: 17),
      (u: 0.94, y: 0.02, s: 1.1, seed: 20),
      (u: 0.30, y: -0.02, s: 0.7, seed: 23),
      (u: 0.70, y: -0.03, s: 0.72, seed: 26),
    ];

    for (final c in clusters) {
      final cx = size.width * c.u + swayX;
      final cy = size.height * c.y + math.sin(t * 0.12 + c.u * 5) * wind * 2.5;
      final path = _lobedCluster(
        center: Offset(cx, cy),
        rx: size.width * 0.14 * c.s,
        ry: size.height * 0.1 * c.s,
        seed: c.seed,
        hang: true,
      );

      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx, cy - size.height * 0.08 * c.s),
            Offset(cx, cy + size.height * 0.12 * c.s),
            [
              ForestPalette.shadeDeep,
              ForestPalette.canopyNear,
              ForestPalette.canopyLit.withValues(alpha: 0.85 + breath * 0.05),
            ],
            const [0.0, 0.45, 1.0],
          ),
      );

      // Bright underside flecks — leaf catching light from the pocket.
      final rng = math.Random(c.seed + 3);
      for (var i = 0; i < 4; i++) {
        final lx = cx + (rng.nextDouble() - 0.5) * size.width * 0.1 * c.s;
        final ly = cy + size.height * (0.02 + rng.nextDouble() * 0.05) * c.s;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(lx, ly),
            width: size.width * 0.04 * c.s,
            height: size.height * 0.018 * c.s,
          ),
          Paint()..color = ForestPalette.canopySun.withValues(alpha: 0.28),
        );
      }
    }
  }

  /// Side thicket wall — lobed bushes stacked at the edge.
  void _paintSideThicket(
    Canvas canvas,
    Size size, {
    required bool left,
    required double wind,
    required double sway,
  }) {
    final dir = left ? 1.0 : -1.0;
    final swayX = sway * size.width * 0.18 * dir;
    final bushes = <({double y, double reach, double s, int seed})>[
      (y: 0.12, reach: 0.28, s: 1.1, seed: left ? 31 : 41),
      (y: 0.28, reach: 0.38, s: 1.25, seed: left ? 33 : 43),
      (y: 0.44, reach: 0.34, s: 1.05, seed: left ? 35 : 45),
      (y: 0.58, reach: 0.30, s: 0.95, seed: left ? 37 : 47),
      (y: 0.20, reach: 0.18, s: 0.7, seed: left ? 39 : 49),
    ];

    for (final b in bushes) {
      final cx =
          (left ? 0.0 : size.width) +
          dir * size.width * b.reach +
          swayX +
          math.sin(t * 0.1 + b.y * 3) * wind * 2 * dir;
      final cy = size.height * b.y;
      final path = _lobedCluster(
        center: Offset(cx, cy),
        rx: size.width * 0.16 * b.s,
        ry: size.height * 0.11 * b.s,
        seed: b.seed,
        hang: false,
      );

      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(left ? 0 : size.width, cy),
            Offset(size.width * (left ? 0.4 : 0.6), cy),
            [
              ForestPalette.shadeDeep,
              ForestPalette.canopyNear,
              ForestPalette.canopyLit,
              ForestPalette.canopySun.withValues(alpha: 0.5),
            ],
            const [0.0, 0.35, 0.75, 1.0],
          ),
      );

      // Rim light on the room-facing edge.
      final rimX = cx + dir * size.width * 0.05 * b.s;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rimX, cy),
          width: size.width * 0.05 * b.s,
          height: size.height * 0.08 * b.s,
        ),
        Paint()..color = ForestPalette.canopySun.withValues(alpha: 0.2),
      );
    }
  }

  /// Organic foliage cluster — scalloped oval silhouette.
  Path _lobedCluster({
    required Offset center,
    required double rx,
    required double ry,
    required int seed,
    required bool hang,
  }) {
    final rng = math.Random(seed);
    final path = Path();
    const n = 14;
    for (var i = 0; i <= n; i++) {
      final a = (i / n) * math.pi * 2 - math.pi / 2;
      // Hang: flatter top, heavier bottom lobes. Wall: even scallops.
      final lobe =
          0.78 +
          0.22 * math.sin(a * (hang ? 3.5 : 4) + seed) +
          0.08 * rng.nextDouble();
      final stretchY = hang && math.sin(a) > 0 ? 1.25 : 1.0;
      final x = center.dx + math.cos(a) * rx * lobe;
      final y = center.dy + math.sin(a) * ry * lobe * stretchY;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _paintTrunk(
    Canvas canvas,
    Size size, {
    required Offset base,
    required double height,
    required double widthBase,
    required double lean,
    required int litSide,
    required double wind,
  }) {
    final sway = math.sin(t * 0.15) * wind * 1.2;
    const samples = 24;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= samples; i++) {
      final u = i / samples;
      final y = base.dy - height * u;
      final curve =
          lean * height * u * u +
          math.sin(u * math.pi) * widthBase * 0.06 +
          sway * u;
      final x = base.dx + curve;
      final half = widthBase * 0.5 * (1.0 - u * 0.52);
      left.add(Offset(x - half, y));
      right.add(Offset(x + half, y));
    }

    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in right.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    final midX = base.dx + lean * height * 0.3;
    // Solid trunk — sharp silhouette.
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(midX - litSide * widthBase * 0.4, base.dy),
          Offset(midX + litSide * widthBase * 0.4, base.dy),
          const [Color(0xFF1A1612), Color(0xFF3A322A), Color(0xFF5A4E40)],
          const [0.0, 0.4, 1.0],
        ),
    );

    // Bark strokes — readable wood.
    final bark = math.Random(base.dx.round() + 9);
    for (var i = 0; i < 10; i++) {
      final u = 0.1 + bark.nextDouble() * 0.75;
      final y0 = base.dy - height * u;
      final half = widthBase * 0.5 * (1.0 - u * 0.52) * 0.7;
      final x0 = midX + lean * height * u * u;
      canvas.drawLine(
        Offset(x0 - half * litSide * 0.2, y0),
        Offset(x0 + half * 0.6 * litSide, y0 + height * 0.04),
        Paint()
          ..color = const Color(0xFF1A1612).withValues(alpha: 0.35)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
    }

    // Moss collar.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(base.dx, base.dy - size.height * 0.008),
        width: widthBase * 2.4,
        height: size.height * 0.04,
      ),
      Paint()
        ..shader =
            ui.Gradient.radial(Offset(base.dx, base.dy), widthBase * 1.2, [
              ForestPalette.canopyLit.withValues(alpha: 0.7),
              ForestPalette.moss.withValues(alpha: 0.45),
              ForestPalette.moss.withValues(alpha: 0.0),
            ]),
    );

    // Dissolve only the very top into canopy (short fade, still a form).
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(midX, base.dy - height),
          Offset(midX, base.dy - height * 0.72),
          [
            ForestPalette.canopyNear.withValues(alpha: 0.85),
            ForestPalette.canopyNear.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  void _paintNearLeafTufts(
    Canvas canvas,
    Size size, {
    required double wind,
    required double sway,
  }) {
    final tufts = <({double u, double y, double s, int seed})>[
      (u: 0.18, y: 0.58, s: 0.55, seed: 61),
      (u: 0.28, y: 0.62, s: 0.4, seed: 63),
      (u: 0.72, y: 0.60, s: 0.45, seed: 65),
      (u: 0.82, y: 0.56, s: 0.58, seed: 67),
    ];
    for (final tuft in tufts) {
      final cx = size.width * tuft.u + sway * size.width * 0.1;
      final cy =
          size.height * tuft.y + math.sin(t * 0.14 + tuft.u * 4) * wind * 1.5;
      final path = _lobedCluster(
        center: Offset(cx, cy),
        rx: size.width * 0.1 * tuft.s,
        ry: size.height * 0.06 * tuft.s,
        seed: tuft.seed,
        hang: false,
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx, cy - size.height * 0.04),
            Offset(cx, cy + size.height * 0.04),
            [
              ForestPalette.canopyLit,
              ForestPalette.canopySun,
              ForestPalette.mossLit,
            ],
            const [0.0, 0.5, 1.0],
          ),
      );
    }
  }

  Path _paintMossFloor(
    Canvas canvas,
    Size size, {
    required double startY,
    required double wind,
  }) {
    final path = Path()..moveTo(-30, size.height + 10);
    const samples = 48;
    for (var i = 0; i <= samples; i++) {
      final u = i / samples;
      final x = -30 + (size.width + 60) * u;
      final y =
          startY +
          size.height * 0.025 * math.sin(u * math.pi * 1.3) +
          size.height * 0.012 * math.sin(u * math.pi * 3.2 + t * 0.05) * wind +
          size.height * 0.035 * math.sin(u * math.pi);
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width + 30, size.height + 10)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, startY),
          Offset(0, size.height),
          [
            ForestPalette.mossLit,
            ForestPalette.moss,
            Color.lerp(ForestPalette.moss, ForestPalette.mossDeep, 0.55)!,
          ],
          const [0.0, 0.35, 1.0],
        ),
    );

    // Soft crest highlight on the moss lip — reads as a ground edge.
    final rim = Path();
    for (var i = 0; i <= samples; i++) {
      final u = i / samples;
      final x = -30 + (size.width + 60) * u;
      final y =
          startY +
          size.height * 0.025 * math.sin(u * math.pi * 1.3) +
          size.height * 0.012 * math.sin(u * math.pi * 3.2 + t * 0.05) * wind +
          size.height * 0.035 * math.sin(u * math.pi);
      if (i == 0) {
        rim.moveTo(x, y);
      } else {
        rim.lineTo(x, y);
      }
    }
    canvas.drawPath(
      rim,
      Paint()
        ..color = ForestPalette.mossSun.withValues(alpha: 0.35)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    return path;
  }

  void _paintMossGrain(
    Canvas canvas,
    Size size, {
    required Path mossPath,
    required double startY,
  }) {
    canvas.save();
    canvas.clipPath(mossPath);
    final grain = math.Random(21);
    for (var i = 0; i < 240; i++) {
      final x = grain.nextDouble() * size.width;
      final y = startY + grain.nextDouble() * (size.height - startY);
      final depth = ((y - startY) / (size.height - startY)).clamp(0.0, 1.0);
      final r = 0.4 + grain.nextDouble() * 1.15;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = grain.nextBool()
              ? ForestPalette.canopySun.withValues(alpha: 0.1 + depth * 0.12)
              : ForestPalette.mossDeep.withValues(alpha: 0.08 + depth * 0.12),
      );
    }
    canvas.restore();
  }

  void _paintMossContours(
    Canvas canvas,
    Size size, {
    required double startY,
    required double wind,
  }) {
    final bottom = size.height * 0.98;
    const rows = 12;
    for (var row = 0; row < rows; row++) {
      final depth = row / (rows - 1);
      final y0 = ui.lerpDouble(startY, bottom, depth)!;
      final amp = ui.lerpDouble(1.2, 4.5, depth)! * (0.75 + wind.abs() * 0.3);
      final freq = ui.lerpDouble(7, 4.5, depth)!;
      final alpha = ui.lerpDouble(0.07, 0.2, depth)!;
      final drift = t * (0.08 + depth * 0.05);

      final path = Path();
      const cols = 42;
      for (var c = 0; c <= cols; c++) {
        final u = c / cols;
        final x = size.width * u;
        final y =
            y0 +
            math.sin(u * math.pi * freq + drift + row * 0.4) * amp +
            math.sin(u * math.pi * (freq * 0.35) + row) * amp * 0.35;
        if (c == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = ForestPalette.canopySun.withValues(alpha: alpha)
          ..strokeWidth = ui.lerpDouble(0.8, 1.7, depth)!
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path.shift(Offset(0, 1.3 + depth * 0.5)),
        Paint()
          ..color = ForestPalette.mossDeep.withValues(alpha: alpha * 0.55)
          ..strokeWidth = ui.lerpDouble(0.6, 1.2, depth)!
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _paintNearGrass(
    Canvas canvas,
    Size size, {
    required double startY,
    required double wind,
  }) {
    final rng = math.Random(37);
    for (var i = 0; i < 90; i++) {
      final x = size.width * (0.04 + rng.nextDouble() * 0.92);
      final y = startY + rng.nextDouble() * (size.height - startY) * 0.9;
      final depth = ((y - startY) / (size.height - startY)).clamp(0.0, 1.0);
      final h = ui.lerpDouble(7, 22, depth)! * (0.85 + rng.nextDouble() * 0.3);
      final lean =
          (rng.nextDouble() - 0.5) * 0.45 +
          math.sin(t * 0.5 + i * 0.2) * wind * 0.15;
      final blade = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(
          x + lean * h * 0.5,
          y - h * 0.55,
          x + lean * h,
          y - h,
        );
      canvas.drawPath(
        blade,
        Paint()
          ..color =
              (rng.nextDouble() > 0.4
                      ? ForestPalette.canopySun
                      : ForestPalette.canopyLit)
                  .withValues(alpha: ui.lerpDouble(0.28, 0.65, depth)!)
          ..strokeWidth = ui.lerpDouble(1.0, 2.0, depth)!
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Sun through leaves — readable light spots on moss.
  void _paintDapples(Canvas canvas, Size size, {required double breath}) {
    final spots = <({double u, double v, double s})>[
      (u: 0.38, v: 0.62, s: 1.0),
      (u: 0.52, v: 0.66, s: 1.25),
      (u: 0.62, v: 0.60, s: 0.8),
      (u: 0.44, v: 0.72, s: 0.7),
      (u: 0.58, v: 0.74, s: 0.9),
    ];
    for (final s in spots) {
      final c = Offset(size.width * s.u, size.height * s.v);
      final pulse = 0.85 + 0.15 * math.sin(t * 0.35 + s.u * 6);
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: size.width * 0.14 * s.s * pulse,
          height: size.height * 0.045 * s.s * pulse,
        ),
        Paint()
          ..shader = ui.Gradient.radial(c, size.width * 0.08 * s.s, [
            ForestPalette.mossSun.withValues(alpha: 0.55 + breath * 0.1),
            ForestPalette.mossSun.withValues(alpha: 0.0),
          ]),
      );
    }
  }

  void _paintMotes(
    Canvas canvas,
    Size size, {
    required double breath,
    required Offset pocket,
  }) {
    final rng = math.Random(71);
    for (var i = 0; i < 28; i++) {
      final baseX = pocket.dx + (rng.nextDouble() - 0.5) * size.width * 0.5;
      final baseY = pocket.dy + (rng.nextDouble() - 0.25) * size.height * 0.32;
      final x =
          (baseX +
                  t * (0.4 + rng.nextDouble()) * 0.18 +
                  math.sin(t * 0.28 + i) * 3) %
              (size.width + 8) -
          4;
      final y = baseY + math.sin(t * 0.36 + i * 0.5) * 3.5;
      final r = 0.45 + rng.nextDouble() * 1.0;
      final twinkle =
          0.4 +
          0.6 *
              math
                  .pow(
                    (0.5 + 0.5 * math.sin(t * (0.5 + rng.nextDouble()) + i))
                        .clamp(0.0, 1.0),
                    1.5,
                  )
                  .toDouble();
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = ForestPalette.mote.withValues(
            alpha: (0.16 + twinkle * 0.4) * (0.8 + breath * 0.2),
          ),
      );
    }
  }

  void _paintComfortGlow(Canvas canvas, Size size, double breath) {
    final seat = Offset(size.width * 0.5, size.height * 0.86);
    final radius = size.shortestSide * (0.45 + breath * 0.03);
    canvas.drawCircle(
      seat,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          seat,
          radius,
          [
            ForestPalette.comfort.withValues(alpha: 0.14 + breath * 0.07),
            ForestPalette.comfort.withValues(alpha: 0.0),
          ],
          const [0.0, 1.0],
        ),
    );
  }

  void _paintRoomVignette(Canvas canvas, Size size, double breath) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.48),
          size.longestSide * 0.7,
          [
            const Color(0x00000000),
            ForestPalette.shadeDeep.withValues(alpha: 0.05 + breath * 0.02),
            ForestPalette.shadeDeep.withValues(alpha: 0.22),
          ],
          const [0.4, 0.78, 1.0],
        ),
    );
  }

  void _paintPresenceInMoss(
    Canvas canvas,
    Size size, {
    required double breath,
  }) {
    if (mossCount <= 0) return;
    if (mossReveal < 0.01 && mossErase > 0.99) return;

    final label = _formatPresence(mossCount);
    final opacity = 0.30 + breath * 0.09;
    final fontSize = size.shortestSide * 0.078;
    final hand = math.Random(mossCount * 31 + 7);
    final anchor = Offset(size.width * 0.72, size.height * 0.90);

    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.rotate(0.16);
    final tip = Matrix4.identity()
      ..setEntry(3, 1, 0.0016)
      ..scaleByDouble(1.08, 0.62, 1.0, 1.0);
    canvas.transform(tip.storage);

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

    final n = marks.length;
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

      final fill = glyph(ForestPalette.earth.withValues(alpha: opacity * 0.9));
      painters.add((
        shadow: glyph(ForestPalette.earthDeep.withValues(alpha: opacity)),
        fill: fill,
        rim: glyph(ForestPalette.canopySun.withValues(alpha: opacity * 0.3)),
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

      final smear = gone * (1.0 - gone) * 4.0;
      final smearX = gone * fontSize * 0.35;
      final blur = gone * fontSize * 0.08;

      canvas.save();
      canvas.translate(
        x + g.fill.width * 0.5 + smearX,
        m.wobbleY + (1.0 - appear) * fontSize * 0.08,
      );
      canvas.rotate(m.wobbleRot + gone * 0.06);
      canvas.scale(1.0 + (1.0 - appear) * 0.04, appear * 0.85 + 0.15);

      final o = Offset(-g.fill.width * 0.5, -g.fill.height * 0.35);
      canvas.saveLayer(
        Rect.fromLTWH(
          o.dx - fontSize,
          o.dy - fontSize,
          g.fill.width + fontSize * 2,
          g.fill.height + fontSize * 2,
        ),
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, life)
          ..imageFilter = blur > 0.4
              ? ui.ImageFilter.blur(sigmaX: blur + smear, sigmaY: blur * 0.4)
              : null,
      );
      g.shadow.paint(canvas, o.translate(1.0, 1.4));
      g.fill.paint(canvas, o);
      g.rim.paint(canvas, o.translate(-0.5, -0.6));
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
    if (presenceCount <= 0) return;
    final n = _presenceSparkCount(presenceCount);
    final rng = math.Random(53);
    final seat = Offset(size.width * 0.5, size.height * 0.72);
    final rx = size.width * 0.28;
    final ry = size.height * 0.1;

    for (var i = 0; i < n; i++) {
      final lane = 0.4 + rng.nextDouble() * 0.6;
      final slot = (i + 0.5) / n;
      final homeAngle =
          slot * math.pi * 2 + math.sin(slot * math.pi * 2) * 0.35;
      final homeX = seat.dx + math.cos(homeAngle) * rx * lane;
      final homeY = seat.dy + math.sin(homeAngle) * ry * lane * 0.75;

      final p1 = rng.nextDouble() * math.pi * 2;
      final p2 = rng.nextDouble() * math.pi * 2;
      final amp = size.shortestSide * (0.01 + rng.nextDouble() * 0.014);
      final pos = Offset(
        homeX +
            math.sin(t * (0.28 + rng.nextDouble() * 0.4) + p1) * amp +
            math.sin(t * (0.7 + rng.nextDouble()) + p2) * amp * 0.45,
        homeY + math.cos(t * (0.22 + rng.nextDouble() * 0.3) + p2) * amp * 0.55,
      );

      final twinkle =
          0.4 +
          0.6 *
              math
                  .pow(
                    (0.5 + 0.5 * math.sin(t * (0.45 + rng.nextDouble()) + p1))
                        .clamp(0.0, 1.0),
                    1.5,
                  )
                  .toDouble();
      final r = (1.8 + rng.nextDouble() * 1.6) * (0.85 + twinkle * 0.35);
      final alpha = (0.55 + twinkle * 0.4) * (0.82 + breath * 0.18);

      canvas.drawCircle(
        pos,
        r * 2.4,
        Paint()
          ..color = ForestPalette.presence.withValues(alpha: alpha * 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.1),
      );
      canvas.drawCircle(
        pos,
        r,
        Paint()..color = ForestPalette.presenceGlow.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        pos,
        r * 0.38,
        Paint()..color = ForestPalette.presenceCore.withValues(alpha: alpha),
      );
    }
  }

  int _presenceSparkCount(int people) {
    if (people <= 0) return 0;
    if (people <= 3) return people;
    if (people < 20) {
      return (3 + ((people - 3) / 4).round()).clamp(3, 7);
    }
    if (people < 60) {
      return (7 + ((people - 20) / 20).round()).clamp(7, presenceSparkMax);
    }
    return presenceSparkMax;
  }

  @override
  bool shouldRepaint(covariant ForestPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.presenceCount != presenceCount ||
      oldDelegate.mossCount != mossCount ||
      oldDelegate.mossReveal != mossReveal ||
      oldDelegate.mossErase != mossErase;
}
