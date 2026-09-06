import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/rain_palette.dart';

/// Looking out an airplane window — dark cabin, drifting sky and cloud sea.
class RainPainter extends CustomPainter {
  RainPainter({
    required this.t,
    required this.presenceCount,
    required this.sandCount,
    required this.sandReveal,
    required this.sandErase,
    this.showPresence = true,
  });

  final double t;
  final int presenceCount;
  final int sandCount;
  final double sandReveal;
  final double sandErase;

  /// When false, skip presence mark in the sky (theme grid thumbs).
  final bool showPresence;

  static const sandEraseSeconds = 0.85;
  static const sandPauseSeconds = 0.2;
  static const sandWriteSeconds = 1.1;

  @override
  void paint(Canvas canvas, Size size) {
    final breath = 0.5 + 0.5 * math.sin(t * 0.22);
    final win = _windowRect(size);

    _paintCabin(canvas, size, win: win);
    canvas.save();
    canvas.clipPath(_windowPath(win));
    _paintSky(canvas, size, win: win, breath: breath);
    // Far → near: parallax scroll (right → left) so the plane feels in motion.
    _paintFarStreaks(canvas, win: win, breath: breath);
    _paintMidCumulus(canvas, win: win, breath: breath);
    _paintSun(canvas, size, win: win, breath: breath);
    _paintCloudDeck(canvas, win: win, breath: breath);
    _paintWing(canvas, size, win: win);
    canvas.restore();

    _paintWindowFrame(canvas, size, win: win);
    if (showPresence) {
      _paintPresence(canvas, size, win: win, breath: breath);
    }
  }

  /// Stadium window — wide, a bit shorter so cabin rim reads clearly.
  Rect _windowRect(Size size) {
    final w = size.width * 0.78;
    final h = size.height * 0.62;
    return Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.46),
      width: w,
      height: h,
    );
  }

  Path _windowPath(Rect win) {
    // Fully rounded ends → classic airplane porthole silhouette.
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(win, Radius.circular(win.width * 0.5)),
      );
  }

  void _paintCabin(Canvas canvas, Size size, {required Rect win}) {
    // Soft grey cabin — dimmer than the sky, not a black filter.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          win.center,
          size.shortestSide * 0.95,
          const [
            Color(0xFF7A8898),
            Color(0xFF5A6878),
            Color(0xFF3A4450),
            Color(0xFF2A323C),
          ],
          const [0.0, 0.35, 0.7, 1.0],
        ),
    );

    // Daylight spill — soft, not crushing the pane
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        win.inflate(size.shortestSide * 0.1),
        Radius.circular(win.width * 0.55),
      ),
      Paint()
        ..color = const Color(0x38C8DCF0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
    );

    final rng = math.Random(3);
    final paint = Paint()..color = const Color(0xFF4A5460).withValues(alpha: 0.28);
    for (var i = 0; i < 220; i++) {
      final x = size.width * rng.nextDouble();
      final y = size.height * rng.nextDouble();
      if (win.inflate(16).contains(Offset(x, y))) continue;
      canvas.drawCircle(Offset(x, y), 0.55, paint);
    }
  }

  void _paintSky(
    Canvas canvas,
    Size size, {
    required Rect win,
    required double breath,
  }) {
    // Clear open azure — crisp vault, light near the horizon.
    canvas.drawRect(
      win.inflate(8),
      Paint()
        ..shader = ui.Gradient.linear(
          win.topCenter,
          win.bottomCenter,
          [
            const Color(0xFF0E7ADB),
            RainPalette.skyTop,
            RainPalette.skyMid,
            Color.lerp(RainPalette.skyHorizon, Colors.white, 0.22)!,
          ],
          const [0.0, 0.22, 0.55, 1.0],
        ),
    );
    // Soft sun wash — keep subtle so the blue stays clear.
    canvas.drawRect(
      win.inflate(4),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(win.left + win.width * 0.22, win.top + win.height * 0.18),
          win.width * 0.55,
          [
            Colors.white.withValues(alpha: 0.1 + breath * 0.03),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  void _paintSun(
    Canvas canvas,
    Size size, {
    required Rect win,
    required double breath,
  }) {
    final sun = Offset(
      win.left + win.width * 0.2,
      win.top + win.height * 0.14,
    );
    final r = win.height * 0.07;
    // Soft bloom — bright, not muddy
    canvas.drawCircle(
      sun,
      r * 2.4,
      Paint()
        ..color = const Color(0xFFFFF0C8).withValues(alpha: 0.22 + breath * 0.05)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.6),
    );
    canvas.drawCircle(
      sun,
      r * 1.1,
      Paint()
        ..color = const Color(0xFFFFF8E8).withValues(alpha: 0.55 + breath * 0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
    );
    canvas.drawCircle(
      sun,
      r * 0.38,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
    );
  }

  /// Continuous leftward scroll with stable absolute slot indices
  /// (so clouds don't morph/jump when one leaves the frame).
  void _forScrollSlots({
    required double scroll,
    required double spacing,
    required double left,
    required double right,
    double phase = 0,
    required void Function(double x, int slot) paint,
  }) {
    final margin = spacing * 1.2;
    final start = left - margin;
    final end = right + margin;
    final first = ((start - phase + scroll) / spacing).floor();
    for (var slot = first; ; slot++) {
      final x = phase + slot * spacing - scroll;
      if (x > end) break;
      if (x >= start) paint(x, slot);
    }
  }

  /// Thin high streaks — sparse, keep the vault open.
  void _paintFarStreaks(
    Canvas canvas, {
    required Rect win,
    required double breath,
  }) {
    final scroll = t * win.width * 0.012;
    _forScrollSlots(
      scroll: scroll,
      spacing: win.width * 0.7,
      left: win.left,
      right: win.right,
      phase: 0,
      paint: (x, slot) {
        final yf = 0.22 + (slot.abs() % 3) * 0.04;
        final wf = 0.22 + (slot.abs() % 2) * 0.08;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, win.top + win.height * yf),
            width: win.width * wf,
            height: win.height * 0.008,
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.06 + breath * 0.02)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
        );
      },
    );
  }

  /// A few distant islands — don't crowd the open blue.
  void _paintMidCumulus(
    Canvas canvas, {
    required Rect win,
    required double breath,
  }) {
    final scroll = t * win.width * 0.022;
    final yfs = [0.5, 0.56, 0.52];
    final scales = [0.12, 0.16, 0.1];
    _forScrollSlots(
      scroll: scroll,
      spacing: win.width * 1.05,
      left: win.left,
      right: win.right,
      phase: win.width * 0.2,
      paint: (x, slot) {
        final k = slot.abs() % yfs.length;
        _drawCumulus(
          canvas,
          center: Offset(x, win.top + win.height * yfs[k]),
          scale: win.width * scales[k],
          alpha: 0.38 + breath * 0.04,
        );
      },
    );
  }

  /// Sea of clouds — layered cotton carpet under the wing.
  void _paintCloudDeck(
    Canvas canvas, {
    required Rect win,
    required double breath,
  }) {
    final scroll = t * win.width * 0.036;
    final baseY = win.bottom - win.height * 0.04;

    // Soft horizon haze where sky meets the cloud sea
    canvas.drawRect(
      Rect.fromLTWH(
        win.left,
        baseY - win.height * 0.16,
        win.width,
        win.height * 0.14,
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, baseY - win.height * 0.16),
          Offset(0, baseY),
          [
            RainPalette.skyMid.withValues(alpha: 0.0),
            const Color(0x33C8E8FF),
          ],
        ),
    );

    // Far band — small, muted, blue-tinted
    _paintCloudBand(
      canvas,
      win: win,
      y: baseY - win.height * 0.07,
      scroll: scroll * 0.7,
      spacing: win.width * 0.14,
      phase: 0.02,
      scale: win.width * 0.11,
      alpha: 0.55,
      shade: const Color(0xFFA8BCCE),
    );

    // Mid band
    _paintCloudBand(
      canvas,
      win: win,
      y: baseY - win.height * 0.04,
      scroll: scroll * 0.9,
      spacing: win.width * 0.16,
      phase: win.width * 0.05,
      scale: win.width * 0.15,
      alpha: 0.72,
      shade: RainPalette.cloudShade,
    );

    // Near band — brightest tops, deeper shade
    _paintCloudBand(
      canvas,
      win: win,
      y: baseY,
      scroll: scroll,
      spacing: win.width * 0.15,
      phase: win.width * 0.09,
      scale: win.width * 0.19,
      alpha: 0.9 + breath * 0.04,
      shade: const Color(0xFF8A9AAC),
    );
  }

  void _paintCloudBand(
    Canvas canvas, {
    required Rect win,
    required double y,
    required double scroll,
    required double spacing,
    required double phase,
    required double scale,
    required double alpha,
    required Color shade,
  }) {
    _forScrollSlots(
      scroll: scroll,
      spacing: spacing,
      left: win.left,
      right: win.right,
      phase: phase,
      paint: (x, slot) {
        final bump =
            math.sin(slot * 1.9 + y * 0.01) * win.height * 0.006 +
            math.cos(slot * 0.7) * win.height * 0.003;
        final s = scale * (0.85 + (slot.abs() % 5) * 0.04);
        _drawSeaCloud(
          canvas,
          center: Offset(x, y + bump),
          scale: s,
          alpha: alpha,
          shade: shade,
          seed: slot,
        );
      },
    );
  }

  /// One mound in the cloud sea — shade, body lobes, bright sunlit crown.
  void _drawSeaCloud(
    Canvas canvas, {
    required Offset center,
    required double scale,
    required double alpha,
    required Color shade,
    required int seed,
  }) {
    final w = scale;
    final h = scale * 0.42;
    final a = alpha.clamp(0.0, 1.0);

    // Deep shade under the mound
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, h * 0.28),
        width: w * 1.15,
        height: h * 0.75,
      ),
      Paint()
        ..color = shade.withValues(alpha: a * 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.07),
    );

    // Varied lobe layout from seed
    final lobes = <(double, double, double)>[
      (-0.32, 0.1, 0.4 + (seed % 3) * 0.02),
      (-0.08, -0.12, 0.52),
      (0.18, -0.04, 0.44),
      (0.34, 0.12, 0.36),
      (0.02, 0.16, 0.34),
    ];
    for (final (dx, dy, s) in lobes) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(w * dx, h * dy),
          width: w * s,
          height: h * s * 0.9,
        ),
        Paint()
          ..color = RainPalette.cloud.withValues(alpha: a * 0.92)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.03),
      );
    }

    // Sunlit crown
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-w * 0.04, -h * 0.22),
        width: w * 0.38,
        height: h * 0.28,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: a * 0.7)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.045),
    );

    // Tiny secondary highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(w * 0.18, -h * 0.1),
        width: w * 0.2,
        height: h * 0.16,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: a * 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.03),
    );
  }

  /// Soft multi-lobe cloud puff (mid / far streaks use this).
  void _drawCumulus(
    Canvas canvas, {
    required Offset center,
    required double scale,
    required double alpha,
    bool flat = false,
  }) {
    final w = scale;
    final h = flat ? scale * 0.38 : scale * 0.48;

    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, h * 0.18),
        width: w * 1.05,
        height: h * 0.7,
      ),
      Paint()
        ..color = RainPalette.cloudShade.withValues(alpha: alpha * 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.06),
    );

    final lobes = flat
        ? <(double, double, double)>[
            (-0.28, 0.05, 0.42),
            (0.0, -0.08, 0.5),
            (0.30, 0.02, 0.4),
          ]
        : <(double, double, double)>[
            (-0.28, 0.08, 0.46),
            (-0.05, -0.18, 0.52),
            (0.22, -0.06, 0.44),
            (0.08, 0.14, 0.38),
          ];

    for (final (dx, dy, s) in lobes) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(w * dx, h * dy),
          width: w * s,
          height: h * s * (flat ? 0.85 : 0.95),
        ),
        Paint()
          ..color = RainPalette.cloud.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.035),
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, -h * (flat ? 0.12 : 0.22)),
        width: w * 0.35,
        height: h * 0.22,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.04),
    );
  }

  void _paintWing(
    Canvas canvas,
    Size size, {
    required Rect win,
  }) {
    final bob = math.sin(t * 0.16) * win.width * 0.0015;
    final w = win.width;
    final h = win.height;

    // Shorter wing — root flush bottom-right, tip near center.
    final rootLead = Offset(win.right + w * 0.02, win.bottom - h * 0.14 + bob);
    final rootTrail = Offset(win.right + w * 0.02, win.bottom + h * 0.02 + bob);
    final tipLead = Offset(win.center.dx - w * 0.02, win.bottom - h * 0.16 + bob);
    final tipTrail = Offset(win.center.dx + w * 0.03, win.bottom - h * 0.12 + bob);

    Offset mix(Offset a, Offset b, double u) =>
        Offset(a.dx + (b.dx - a.dx) * u, a.dy + (b.dy - a.dy) * u);

    final body = Path()
      ..moveTo(rootTrail.dx, rootTrail.dy)
      ..lineTo(rootLead.dx, rootLead.dy)
      ..lineTo(tipLead.dx, tipLead.dy)
      ..lineTo(tipTrail.dx, tipTrail.dy)
      ..close();

    // Soft contact shadow into clouds
    canvas.drawPath(
      body.shift(Offset(-w * 0.008, h * 0.014)),
      Paint()
        ..color = const Color(0x33202838)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.028),
    );

    // Soft silhouette — kills sticker edge
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0x66AEB8C4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.006)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012,
    );

    // Body lit from upper-left sun
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          rootLead.translate(-w * 0.1, -h * 0.05),
          tipTrail,
          const [
            Color(0xFFF2F4F7),
            Color(0xFFD8DEE4),
            Color(0xFFA8B4C0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Sky bleed on far tip
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          mix(rootLead, tipLead, 0.4),
          tipLead,
          const [
            Color(0x00B0C8E0),
            Color(0x55B0C8E0),
          ],
        ),
    );

    // Soft sun wash near root
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.radial(
          rootLead.translate(-w * 0.05, -h * 0.02),
          w * 0.55,
          [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );

    // Quiet trailing shade
    final under = Path()
      ..moveTo(mix(rootLead, rootTrail, 0.48).dx, mix(rootLead, rootTrail, 0.48).dy)
      ..lineTo(rootTrail.dx, rootTrail.dy)
      ..lineTo(tipTrail.dx, tipTrail.dy)
      ..lineTo(mix(tipLead, tipTrail, 0.48).dx, mix(tipLead, tipTrail, 0.48).dy)
      ..close();
    canvas.drawPath(
      under,
      Paint()
        ..shader = ui.Gradient.linear(
          rootTrail,
          tipTrail,
          const [
            Color(0x3A6A7684),
            Color(0x146A7684),
          ],
        ),
    );

    // Leading-edge rim (thin lit strip)
    canvas.drawLine(
      rootLead,
      tipLead,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5),
    );

    // Flap hinge + secondary panel line
    for (final chord in [0.38, 0.58]) {
      canvas.drawLine(
        mix(rootLead, rootTrail, chord),
        mix(tipLead, tipTrail, chord),
        Paint()
          ..color = const Color(0xFF7A8490).withValues(alpha: 0.28)
          ..strokeWidth = chord < 0.5 ? 1.15 : 0.9
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4),
      );
    }

    // Span-wise seams (perspective: denser toward tip)
    for (final u in [0.18, 0.36, 0.55, 0.72]) {
      final p = math.pow(u, 1.35).toDouble();
      canvas.drawLine(
        mix(rootLead, tipLead, p),
        mix(rootTrail, tipTrail, p),
        Paint()
          ..color = const Color(0xFF8A949E).withValues(alpha: 0.26 * (1 - p * 0.4))
          ..strokeWidth = (1.5 * (1 - p * 0.55)).clamp(0.6, 1.5),
      );
    }

    // Tiny rivets along the near flap hinge
    final rivetPaint = Paint()..color = const Color(0xFF6A7480).withValues(alpha: 0.35);
    for (var i = 0; i < 7; i++) {
      final u = 0.08 + i * 0.07;
      final p = mix(
        mix(rootLead, rootTrail, 0.55),
        mix(tipLead, tipTrail, 0.55),
        u,
      );
      canvas.drawCircle(p, 0.7, rivetPaint);
    }

    // Soft fairings — teardrop pods along trailing edge
    for (final entry in <(double, double)>[
      (0.16, 1.05),
      (0.34, 0.82),
      (0.52, 0.6),
      (0.68, 0.42),
      (0.82, 0.28),
    ]) {
      final (u, s) = entry;
      final base = mix(rootTrail, tipTrail, u);
      final span = Offset(tipTrail.dx - rootTrail.dx, tipTrail.dy - rootTrail.dy);
      final len = span.distance;
      if (len < 1) continue;
      final out = Offset(-span.dy / len, span.dx / len);
      final back = Offset(-span.dx / len, -span.dy / len);
      final tipF = base + out * (h * 0.035 * s) + back * (w * 0.012 * s);
      final side = Offset(-out.dy, out.dx) * (h * 0.006 * s);
      final fairing = Path()
        ..moveTo(base.dx + side.dx * 0.3, base.dy + side.dy * 0.3)
        ..lineTo(base.dx - side.dx, base.dy - side.dy)
        ..quadraticBezierTo(
          mix(base, tipF, 0.55).dx - out.dx * h * 0.008 * s,
          mix(base, tipF, 0.55).dy - out.dy * h * 0.008 * s,
          tipF.dx,
          tipF.dy,
        )
        ..close();
      canvas.drawPath(
        fairing,
        Paint()
          ..shader = ui.Gradient.linear(
            base,
            tipF,
            [
              const Color(0xE6D0D6DC),
              const Color(0xB09AA3AC),
            ],
          ),
      );
      // Soft shade under each pod
      canvas.drawPath(
        fairing.shift(Offset(out.dx * 1.2, out.dy * 1.2)),
        Paint()
          ..color = const Color(0x22081820)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }

    // Winglet — soft navy, follows tip direction
    final wl = tipLead;
    final tipDir = Offset(tipLead.dx - rootLead.dx, tipLead.dy - rootLead.dy);
    final tipLen = tipDir.distance;
    final alongTip = Offset(tipDir.dx / tipLen, tipDir.dy / tipLen);
    final up = Offset(-alongTip.dy, alongTip.dx);
    final winglet = Path()
      ..moveTo(
        wl.dx - alongTip.dx * w * 0.01,
        wl.dy - alongTip.dy * w * 0.01,
      )
      ..lineTo(
        wl.dx + alongTip.dx * w * 0.012 + up.dx * h * 0.005,
        wl.dy + alongTip.dy * w * 0.012 + up.dy * h * 0.005,
      )
      ..lineTo(
        wl.dx + up.dx * h * 0.038 + alongTip.dx * w * 0.004,
        wl.dy + up.dy * h * 0.038 + alongTip.dy * w * 0.004,
      )
      ..lineTo(
        wl.dx + up.dx * h * 0.03 - alongTip.dx * w * 0.008,
        wl.dy + up.dy * h * 0.03 - alongTip.dy * w * 0.008,
      )
      ..close();
    canvas.drawPath(
      winglet,
      Paint()
        ..shader = ui.Gradient.linear(
          wl,
          wl + up * h * 0.038,
          const [
            Color(0xFF1A2A44),
            Color(0xFF2A4870),
            Color(0x553A68A0),
          ],
          const [0.0, 0.55, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );
  }

  void _paintWindowFrame(Canvas canvas, Size size, {required Rect win}) {
    final rim = size.shortestSide;
    final r = win.width * 0.5;
    final outerPad = rim * 0.022;
    final facePad = rim * 0.009;

    final outer = win.inflate(outerPad);
    final face = win.inflate(facePad);
    final outerR = RRect.fromRectAndRadius(outer, Radius.circular(r + outerPad));
    final faceR = RRect.fromRectAndRadius(face, Radius.circular(r + facePad));
    final glassR = RRect.fromRectAndRadius(win, Radius.circular(r));

    // Contact into cabin
    canvas.drawRRect(
      outerR,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rim * 0.01),
    );

    // Bright plastic frame against dark wall
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRRect(outerR)
        ..addRRect(glassR),
      Paint()..color = const Color(0xFFD4D9DE),
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRRect(faceR)
        ..addRRect(glassR),
      Paint()
        ..shader = ui.Gradient.linear(
          face.topLeft,
          face.bottomRight,
          const [
            Color(0xFFF2F4F6),
            Color(0xFFE4E8EC),
            Color(0xFFD0D6DC),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    canvas.drawRRect(
      glassR,
      Paint()
        ..color = const Color(0xFF9AA3AC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim * 0.004,
    );

    // Soft catch light on the full inner rim
    canvas.drawRRect(
      glassR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim * 0.007
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rim * 0.002),
    );
  }

  void _paintPresence(
    Canvas canvas,
    Size size, {
    required Rect win,
    required double breath,
  }) {
    if (sandCount <= 0) return;
    if (sandReveal < 0.01 && sandErase > 0.99) return;

    final label = '$sandCount';
    final fontSize = size.shortestSide * 0.055;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: fontSize,
          color: RainPalette.presenceInk.withValues(
            alpha: (0.32 + breath * 0.1) * sandReveal * (1 - sandErase * 0.9),
          ),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final origin = Offset(
      win.center.dx - tp.width * 0.5,
      win.top + win.height * 0.36 - tp.height * 0.5,
    );

    canvas.save();
    canvas.clipPath(_windowPath(win));
    if (sandReveal < 0.999) {
      canvas.clipRect(
        Rect.fromLTWH(origin.dx, origin.dy, tp.width * sandReveal, tp.height),
      );
    }
    if (sandErase > 0.01) {
      canvas.clipRect(
        Rect.fromLTWH(
          origin.dx + tp.width * sandErase,
          origin.dy,
          tp.width * (1 - sandErase),
          tp.height,
        ),
      );
    }
    canvas.drawCircle(
      origin + Offset(tp.width * 0.5, tp.height * 0.5),
      tp.width * 0.85,
      Paint()
        ..color = RainPalette.presenceGlow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    tp.paint(canvas, origin);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RainPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.presenceCount != presenceCount ||
      oldDelegate.sandCount != sandCount ||
      oldDelegate.sandReveal != sandReveal ||
      oldDelegate.sandErase != sandErase ||
      oldDelegate.showPresence != showPresence;
}
