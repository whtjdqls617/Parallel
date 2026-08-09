import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'memo.dart';

/// Center overlay — torn scrap of letter paper, stuck on (theme-flavored).
Future<void> showMemoReader(
  BuildContext context, {
  required Memo memo,
  required MemoTheme theme,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close memo',
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondary) {
      return SafeArea(
        child: Center(
          child: _MemoReaderLetter(memo: memo, theme: theme),
        ),
      );
    },
    transitionBuilder: (context, animation, secondary, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      final scale = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(scale),
          child: child,
        ),
      );
    },
  );
}

class _MemoReaderLetter extends StatelessWidget {
  const _MemoReaderLetter({required this.memo, required this.theme});

  final Memo memo;
  final MemoTheme theme;

  @override
  Widget build(BuildContext context) {
    final isForest = theme == MemoTheme.forest;
    // Desert: sun-bleached parchment. Forest: cool damp leaf-letter.
    final paper = isForest
        ? const Color(0xFFE4E8D8)
        : const Color(0xFFF8EBD4);
    final nest = isForest
        ? const Color(0xFFEEF2E4)
        : const Color(0xFFFFF6E6);
    final songNest = isForest
        ? const Color(0xFFDCE4D0)
        : const Color(0xFFF2E0C0);
    final ink = isForest
        ? const Color(0xFF243428)
        : const Color(0xFF5A3A20);
    final tilt = isForest ? 0.014 : -0.022;
    final size = MediaQuery.sizeOf(context);

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.86,
          maxHeight: size.height * 0.72,
        ),
        child: AspectRatio(
          aspectRatio: 0.72,
          child: Transform.rotate(
            angle: tilt,
            child: _TornPaper(
              theme: theme,
              paper: paper,
              seed: isForest ? 19 : 11,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '누군가의 흔적',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 12,
                                letterSpacing: 2.2,
                                color: ink.withValues(alpha: 0.42),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: Icon(
                              Icons.close,
                              color: ink.withValues(alpha: 0.5),
                              size: 22,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      flex: memo.hasSong ? 3 : 5,
                      child: _TornNest(
                        theme: theme,
                        color: nest,
                        seed: isForest ? 29 : 21,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                          child: SingleChildScrollView(
                            child: Text(
                              memo.text,
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 20,
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                                color: ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (memo.hasSong) ...[
                      const SizedBox(height: 10),
                      _TornNest(
                        theme: theme,
                        color: songNest,
                        seed: isForest ? 41 : 37,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                          child: Text(
                            '♪  ${memo.songLabel}',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 16,
                              height: 1.4,
                              color: ink.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TornNest extends StatelessWidget {
  const _TornNest({
    required this.theme,
    required this.color,
    required this.seed,
    required this.child,
  });

  final MemoTheme theme;
  final Color color;
  final int seed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _TornPaper(
      theme: theme,
      paper: color,
      seed: seed,
      recessed: true,
      child: child,
    );
  }
}

class _TornPaper extends StatelessWidget {
  const _TornPaper({
    required this.theme,
    required this.paper,
    required this.seed,
    required this.child,
    this.recessed = false,
  });

  final MemoTheme theme;
  final Color paper;
  final int seed;
  final Widget child;
  final bool recessed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TornSheetPainter(
        theme: theme,
        paper: paper,
        seed: seed,
        recessed: recessed,
      ),
      child: ClipPath(
        clipper: _TornClipper(
          theme: theme,
          seed: seed,
          recessed: recessed,
        ),
        child: child,
      ),
    );
  }
}

Path _buildTornPath(
  Size size, {
  required MemoTheme theme,
  required int seed,
  required bool recessed,
}) {
  final isForest = theme == MemoTheme.forest;
  final rng = math.Random(seed);
  final w = size.width;
  final h = size.height;
  final path = Path();

  final inset = recessed ? 2.0 : 4.0;
  final tl = Offset(inset + rng.nextDouble() * 3, inset + rng.nextDouble() * 3);
  final tr = Offset(w - inset - rng.nextDouble() * 4, inset + rng.nextDouble() * 2);
  final br = Offset(w - inset - rng.nextDouble() * 3, h - inset - rng.nextDouble() * 4);
  final bl = Offset(inset + rng.nextDouble() * 2, h - inset - rng.nextDouble() * 3);

  // Desert: dry sharper bites. Forest: soft rounded lobes, no bumpy teeth.
  void desertEdge(
    Offset from,
    Offset to, {
    required int steps,
    required Offset normal,
    required double amp,
  }) {
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final base = Offset.lerp(from, to, t)!;
      final n = (rng.nextDouble() - 0.28) * amp * 1.15;
      final side =
          Offset(-normal.dy, normal.dx) *
          (rng.nextDouble() - 0.5) *
          amp *
          0.3;
      path.lineTo(
        base.dx + normal.dx * n + side.dx,
        base.dy + normal.dy * n + side.dy,
      );
    }
  }

  void forestEdge(
    Offset from,
    Offset to, {
    required int lobes,
    required Offset normal,
    required double amp,
  }) {
    for (var i = 1; i <= lobes; i++) {
      final t0 = (i - 1) / lobes;
      final t1 = i / lobes;
      final midT = (t0 + t1) * 0.5;
      final end = Offset.lerp(from, to, t1)!;
      final mid = Offset.lerp(from, to, midT)!;
      // Gentle outward/inward bulge — smooth quadratic, not jagged.
      final bulge = (rng.nextDouble() * 0.7 + 0.35) *
          amp *
          (rng.nextBool() ? 1.0 : -0.55);
      final ctrl = Offset(
        mid.dx + normal.dx * bulge,
        mid.dy + normal.dy * bulge,
      );
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    }
  }

  final baseAmp = recessed
      ? (isForest ? 3.2 : 2.3)
      : (isForest ? 5.0 : 3.9);
  path.moveTo(tl.dx, tl.dy);
  if (isForest) {
    forestEdge(tl, tr, lobes: 5, normal: const Offset(0, 1), amp: baseAmp);
    forestEdge(tr, br, lobes: 6, normal: const Offset(-1, 0), amp: baseAmp + 0.4);
    forestEdge(br, bl, lobes: 5, normal: const Offset(0, -1), amp: baseAmp);
    forestEdge(bl, tl, lobes: 6, normal: const Offset(1, 0), amp: baseAmp + 0.5);
  } else {
    desertEdge(tl, tr, steps: 18, normal: const Offset(0, 1), amp: baseAmp);
    desertEdge(tr, br, steps: 22, normal: const Offset(-1, 0), amp: baseAmp + 0.4);
    desertEdge(br, bl, steps: 18, normal: const Offset(0, -1), amp: baseAmp);
    desertEdge(bl, tl, steps: 22, normal: const Offset(1, 0), amp: baseAmp + 0.5);
  }
  path.close();
  return path;
}

class _TornClipper extends CustomClipper<Path> {
  _TornClipper({
    required this.theme,
    required this.seed,
    required this.recessed,
  });

  final MemoTheme theme;
  final int seed;
  final bool recessed;

  @override
  Path getClip(Size size) =>
      _buildTornPath(size, theme: theme, seed: seed, recessed: recessed);

  @override
  bool shouldReclip(covariant _TornClipper oldClipper) =>
      oldClipper.theme != theme ||
      oldClipper.seed != seed ||
      oldClipper.recessed != recessed;
}

class _TornSheetPainter extends CustomPainter {
  _TornSheetPainter({
    required this.theme,
    required this.paper,
    required this.seed,
    this.recessed = false,
  });

  final MemoTheme theme;
  final Color paper;
  final int seed;
  final bool recessed;

  @override
  void paint(Canvas canvas, Size size) {
    final isForest = theme == MemoTheme.forest;
    final path = _buildTornPath(
      size,
      theme: theme,
      seed: seed,
      recessed: recessed,
    );

    canvas.drawPath(
      path.shift(Offset(
        recessed ? 1.2 : (isForest ? 2.0 : 2.8),
        recessed ? 1.6 : (isForest ? 2.8 : 3.6),
      )),
      Paint()
        ..color = Color(
          recessed
              ? 0x22000000
              : (isForest ? 0x55000000 : 0x6A000000),
        ),
    );

    canvas.drawPath(path, Paint()..color = paper);

    // Rim: desert warm dry fiber, forest cool moss edge
    canvas.drawPath(
      path,
      Paint()
        ..color = isForest
            ? const Color(0x665A6A50)
            : const Color(0x668A6030)
        ..style = PaintingStyle.stroke
        ..strokeWidth = recessed
            ? 1.0
            : (isForest ? 1.2 : 1.5),
    );
  }

  @override
  bool shouldRepaint(covariant _TornSheetPainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.paper != paper ||
      oldDelegate.seed != seed ||
      oldDelegate.recessed != recessed;
}
