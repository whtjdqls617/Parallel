import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'memo.dart';
import 'memo_reader.dart';

/// Large centered memo board — weathered theme frame; tap a scrap to zoom in.
Future<void> showMemoPanel(
  BuildContext context, {
  required MemoTheme theme,
  required List<Memo> memos,
  required Future<void> Function() onCompose,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close memos',
    barrierColor: Colors.black.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondary) {
      return SafeArea(
        child: Center(
          child: _MemoPanelBody(
            theme: theme,
            memos: memos,
            onCompose: onCompose,
          ),
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
          scale: Tween<double>(begin: 0.97, end: 1).animate(scale),
          child: child,
        ),
      );
    },
  );
}

class _MemoPanelBody extends StatelessWidget {
  const _MemoPanelBody({
    required this.theme,
    required this.memos,
    required this.onCompose,
  });

  final MemoTheme theme;
  final List<Memo> memos;
  final Future<void> Function() onCompose;

  @override
  Widget build(BuildContext context) {
    final isForest = theme == MemoTheme.forest;
    final iconColor = isForest
        ? const Color(0xFFD0C4A8)
        : const Color(0xFF4A3018);
    final size = MediaQuery.sizeOf(context);

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.9,
          maxHeight: size.height * 0.74,
          minWidth: 280,
        ),
        child: CustomPaint(
          painter: _WeatheredBoardPainter(theme: theme),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close, color: iconColor, size: 22),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: memos.isEmpty
                      ? const SizedBox.expand()
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 1.05,
                          ),
                          itemCount: memos.length,
                          itemBuilder: (context, index) {
                            final memo = memos[index];
                            return _MemoScrap(
                              memo: memo,
                              theme: theme,
                              index: index,
                              onTap: () => showMemoReader(
                                context,
                                memo: memo,
                                theme: theme,
                              ),
                            );
                          },
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () async {
                      Navigator.of(context).maybePop();
                      await onCompose();
                    },
                    icon: Icon(
                      Icons.edit_note_rounded,
                      color: iconColor,
                      size: 28,
                    ),
                    tooltip: '흔적 남기기',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sun-bleached / moss-dark board with worn grain — no decorative corner blobs.
class _WeatheredBoardPainter extends CustomPainter {
  _WeatheredBoardPainter({required this.theme});

  final MemoTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final isForest = theme == MemoTheme.forest;
    final rect = Offset.zero & size;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(3, 5),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0x88000000),
    );

    final board = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    final colors = isForest
        ? const [Color(0xFF2A3224), Color(0xFF1A2218), Color(0xFF12180E)]
        : const [Color(0xFFD2A878), Color(0xFFB88858), Color(0xFF9A6A38)];

    canvas.drawRRect(
      board,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    final face = rect.deflate(8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, const Radius.circular(3)),
      Paint()
        ..color = isForest
            ? const Color(0xFF243028)
            : const Color(0xFFC89860),
    );

    final grain = Paint()
      ..color = isForest ? const Color(0xFF3A4434) : const Color(0xFFA87840)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    final rng = math.Random(isForest ? 9 : 3);
    for (var i = 0; i < 7; i++) {
      final y = face.top + face.height * (0.12 + i * 0.12);
      final path = Path()
        ..moveTo(face.left + 6, y)
        ..cubicTo(
          face.left + face.width * 0.35,
          y + (rng.nextDouble() - 0.5) * 3,
          face.left + face.width * 0.7,
          y + (rng.nextDouble() - 0.5) * 3,
          face.right - 6,
          y,
        );
      canvas.drawPath(path, grain);
    }

    canvas.drawRRect(
      board,
      Paint()
        ..color = isForest ? const Color(0xFF4A5A40) : const Color(0xFF6A4018)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant _WeatheredBoardPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

class _MemoScrap extends StatelessWidget {
  const _MemoScrap({
    required this.memo,
    required this.theme,
    required this.index,
    required this.onTap,
  });

  final Memo memo;
  final MemoTheme theme;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isForest = theme == MemoTheme.forest;
    final paper = isForest
        ? (index.isEven ? const Color(0xFFE6D8B8) : const Color(0xFFDCCEAE))
        : (index.isEven ? const Color(0xFFF0E0B8) : const Color(0xFFE6D4A8));
    final ink = isForest ? const Color(0xFF2A3424) : const Color(0xFF4A2E14);
    final mute = ink.withValues(alpha: 0.45);
    final rot = ((index % 5) - 2) * 0.035;

    final lead = memo.hasSong ? memo.songLabel : memo.text.trim();
    final preview = lead.isEmpty
        ? '…'
        : (lead.length > 40 ? '${lead.substring(0, 40)}…' : lead);

    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: rot,
        child: CustomPaint(
          painter: _ScrapPainter(paper: paper, seed: index * 17 + 3),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memo.hasSong ? '♪' : '·',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 12,
                    color: mute,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    preview,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 15,
                      height: 1.32,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrapPainter extends CustomPainter {
  _ScrapPainter({required this.paper, required this.seed});

  final Color paper;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);

    final path = Path()
      ..moveTo(2 + rng.nextDouble() * 2, 3)
      ..lineTo(size.width - 2 - rng.nextDouble() * 2, 1 + rng.nextDouble() * 2)
      ..lineTo(size.width - 1, size.height - 3 - rng.nextDouble() * 2)
      ..lineTo(2 + rng.nextDouble() * 2, size.height - 1)
      ..close();

    canvas.drawPath(
      path.shift(const Offset(1.5, 2)),
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawPath(path, Paint()..color = paper);

    final spot = Paint()..color = const Color(0x22A07040);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        2 + rng.nextDouble() * 4,
        spot,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8A6A40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrapPainter oldDelegate) =>
      oldDelegate.paper != paper || oldDelegate.seed != seed;
}
