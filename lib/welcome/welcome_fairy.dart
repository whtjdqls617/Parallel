import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/desert_palette.dart';

/// Desert presence spark — the little guide that speaks in the welcome.
class WelcomeFairy extends StatelessWidget {
  const WelcomeFairy({
    super.key,
    required this.t,
    this.size = 28,
  });

  /// 0…1 pulse / twinkle phase.
  final double t;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 2.4,
      height: size * 2.4,
      child: CustomPaint(
        painter: _WelcomeFairyPainter(t: t, radius: size * 0.38),
      ),
    );
  }
}

class _WelcomeFairyPainter extends CustomPainter {
  _WelcomeFairyPainter({required this.t, required this.radius});

  final double t;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final twinkle = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(t * math.pi * 2));
    final breath = 0.85 + 0.15 * (0.5 + 0.5 * math.sin(t * math.pi * 2 + 1.2));
    final alpha = (0.72 + twinkle * 0.28) * breath;
    final r = radius * (0.92 + twinkle * 0.12);

    // Soft halo.
    canvas.drawCircle(
      center,
      r * 2.8,
      Paint()
        ..color = DesertPalette.comfort.withValues(alpha: alpha * 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.35),
    );

    // Outer glow ring.
    canvas.drawCircle(
      center,
      r * 1.55,
      Paint()
        ..color = const Color(0xFFFFE8C0).withValues(alpha: alpha * 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
    );

    // Body.
    canvas.drawCircle(
      center,
      r,
      Paint()..color = const Color(0xFFFFF4E0).withValues(alpha: alpha),
    );

    // Core.
    canvas.drawCircle(
      center,
      r * 0.42,
      Paint()..color = const Color(0xFFFFFFF8).withValues(alpha: alpha),
    );

    // Cross glint — same language as desert companions.
    final glint = Paint()
      ..color = const Color(0xFFFFFFF8).withValues(alpha: alpha * 0.9)
      ..strokeWidth = math.max(1.0, r * 0.18)
      ..strokeCap = StrokeCap.round;
    final arm = r * 1.4;
    canvas.drawLine(center.translate(-arm, 0), center.translate(arm, 0), glint);
    canvas.drawLine(center.translate(0, -arm), center.translate(0, arm), glint);
  }

  @override
  bool shouldRepaint(covariant _WelcomeFairyPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.radius != radius;
}
