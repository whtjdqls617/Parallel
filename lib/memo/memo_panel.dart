import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'memo.dart';
import 'memo_reader.dart';
import 'memo_service.dart';
import 'memo_sticky_layout.dart';

/// Large centered memo board — weathered theme frame; tap a scrap to zoom in.
Future<void> showMemoPanel(
  BuildContext context, {
  required MemoTheme theme,
  required List<Memo> memos,
  required Future<void> Function() onCompose,
  bool canCompose = true,
  MemoService? service,
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
            canCompose: canCompose,
            service: service ?? MemoService(),
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

class _MemoPanelBody extends StatefulWidget {
  const _MemoPanelBody({
    required this.theme,
    required this.memos,
    required this.onCompose,
    required this.canCompose,
    required this.service,
  });

  final MemoTheme theme;
  final List<Memo> memos;
  final Future<void> Function() onCompose;
  final bool canCompose;
  final MemoService service;

  @override
  State<_MemoPanelBody> createState() => _MemoPanelBodyState();
}

class _MemoPanelBodyState extends State<_MemoPanelBody> {
  late List<Memo> _memos;
  StreamSubscription<List<Memo>>? _sub;

  @override
  void initState() {
    super.initState();
    _memos = List<Memo>.from(widget.memos);
    _sub = widget.service.watchPool(widget.theme).listen((pool) {
      if (!mounted) return;
      setState(() => _memos = pool);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _openReader(Memo memo) async {
    final updated = await showMemoReader(
      context,
      memo: memo,
      theme: widget.theme,
      service: widget.service,
    );
    if (updated == null || !mounted) return;
    setState(() {
      final i = _memos.indexWhere((m) => m.id == updated.id);
      if (i >= 0) _memos[i] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final iconColor = switch (theme) {
      MemoTheme.forest => const Color(0xFFD0C4A8),
      MemoTheme.ocean => const Color(0xFFC8D8E0),
      MemoTheme.desert => const Color(0xFF4A3018),
    };
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
                  child: _memos.isEmpty
                      ? const SizedBox.expand()
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: _memos.length,
                          itemBuilder: (context, index) {
                            final memo = _memos[index];
                            return _MemoScrap(
                              memo: memo,
                              theme: theme,
                              index: index,
                              mine: memo.isOwnedBy(widget.service.currentUid),
                              onTap: () => _openReader(memo),
                            );
                          },
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () async {
                      Navigator.of(context).maybePop();
                      await widget.onCompose();
                    },
                    icon: Icon(
                      widget.canCompose
                          ? Icons.edit_note_rounded
                          : Icons.lock_outline_rounded,
                      color: iconColor.withValues(
                        alpha: widget.canCompose ? 1 : 0.55,
                      ),
                      size: 28,
                    ),
                    tooltip: widget.canCompose
                        ? '흔적 남기기'
                        : '구독하면 남길 수 있어요',
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
    final rect = Offset.zero & size;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(3, 5),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0x88000000),
    );

    final board = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    final colors = switch (theme) {
      MemoTheme.forest => const [
        Color(0xFF2A3224),
        Color(0xFF1A2218),
        Color(0xFF12180E),
      ],
      MemoTheme.ocean => const [
        Color(0xFF8A1E1E),
        Color(0xFF6A1414),
        Color(0xFF4A0E0E),
      ],
      MemoTheme.desert => const [
        Color(0xFFD2A878),
        Color(0xFFB88858),
        Color(0xFF9A6A38),
      ],
    };

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
        ..color = switch (theme) {
          MemoTheme.forest => const Color(0xFF243028),
          MemoTheme.ocean => const Color(0xFF5A1010),
          MemoTheme.desert => const Color(0xFFC89860),
        },
    );

    final grain = Paint()
      ..color = switch (theme) {
        MemoTheme.forest => const Color(0xFF3A4434),
        MemoTheme.ocean => const Color(0xFFA03030),
        MemoTheme.desert => const Color(0xFFA87840),
      }
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    final rng = math.Random(switch (theme) {
      MemoTheme.forest => 9,
      MemoTheme.ocean => 13,
      MemoTheme.desert => 3,
    });
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
        ..color = switch (theme) {
          MemoTheme.forest => const Color(0xFF4A5A40),
          MemoTheme.ocean => const Color(0xFFB84848),
          MemoTheme.desert => const Color(0xFF6A4018),
        }
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
    required this.mine,
    required this.onTap,
  });

  final Memo memo;
  final MemoTheme theme;
  final int index;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Own traces: warmer cream so they stand out when a reply lands.
    final paper = mine
        ? switch (theme) {
            MemoTheme.forest => const Color(0xFFF3E8C4),
            MemoTheme.ocean => const Color(0xFFF0E6D4),
            MemoTheme.desert => const Color(0xFFFFF0C8),
          }
        : switch (theme) {
            MemoTheme.forest =>
              index.isEven ? const Color(0xFFE6D8B8) : const Color(0xFFDCCEAE),
            MemoTheme.ocean =>
              index.isEven ? const Color(0xFFE0E8EC) : const Color(0xFFD4DEE4),
            MemoTheme.desert =>
              index.isEven ? const Color(0xFFF0E0B8) : const Color(0xFFE6D4A8),
          };
    final ink = switch (theme) {
      MemoTheme.forest => const Color(0xFF2A3424),
      MemoTheme.ocean => const Color(0xFF1C3038),
      MemoTheme.desert => const Color(0xFF4A2E14),
    };
    final mute = ink.withValues(alpha: 0.45);
    final rot = ((index % 5) - 2) * 0.035;

    final lead = memo.hasSong ? memo.songLabel : memo.text.trim();
    final preview = lead.isEmpty
        ? '…'
        : (lead.length > 48 ? '${lead.substring(0, 48)}…' : lead);

    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: rot,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              painter: _ScrapPainter(paper: paper, seed: index * 17 + 3),
              child: SizedBox.expand(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.72,
                      heightFactor: 0.55,
                      alignment: Alignment.topLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memo.hasSong ? '♪' : '·',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 13,
                              color: mute,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 16,
                                height: 1.35,
                                color: ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (memo.hasReply)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const maxTilt = 0.10;
                    final replies = memo.replies;
                    final shown = replies.length > 3
                        ? replies.sublist(replies.length - 3)
                        : replies;
                    const base = 26.0;
                    final sticky =
                        MemoStickyPlacer.sized(base, shown.length);
                    final positions = MemoStickyPlacer.layoutReplies(
                      bounds: Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      ),
                      size: base,
                      replies: shown,
                      seed: memo.id.hashCode ^ index,
                      lowerBand: !memo.hasSong,
                      avoid: [
                        const Rect.fromLTRB(0.04, 0.04, 0.62, 0.50),
                        if (memo.hasSong)
                          const Rect.fromLTRB(0.04, 0.48, 0.58, 0.76),
                      ],
                    );
                    final badges = <Widget>[];
                    for (var i = 0; i < shown.length; i++) {
                      final reply = shown[i];
                      final seed =
                          (reply.text.hashCode ^ reply.uid.hashCode ^ index)
                              .abs();
                      final rng = math.Random(seed);
                      final pos = positions[i];
                      badges.add(
                        Positioned(
                          left: pos.dx,
                          top: pos.dy,
                          child: Transform.rotate(
                            angle: -maxTilt + rng.nextDouble() * maxTilt * 2,
                            child: CustomPaint(
                              size: Size(sticky, sticky),
                              painter: _PostItPainter(
                                paper: Color(reply.stickyColorValue),
                                seed: seed,
                                adhesive: false,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return Stack(children: badges);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Theme scrap paper for memo previews — not a sticky note.
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

/// Reply sticky only — yellow / pink post-it.
class _PostItPainter extends CustomPainter {
  _PostItPainter({
    required this.paper,
    required this.seed,
    this.adhesive = true,
  });

  final Color paper;
  final int seed;
  final bool adhesive;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 3, size.height - 3),
      const Radius.circular(2.5),
    );

    canvas.drawRRect(
      r.shift(Offset(1.4 + rng.nextDouble() * 0.4, 2.0 + rng.nextDouble() * 0.5)),
      Paint()..color = const Color(0x55000000),
    );

    canvas.drawRRect(r, Paint()..color = paper);

    if (adhesive) {
      final bandH = size.height * 0.12;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(1, 1, size.width - 3, bandH),
          topLeft: const Radius.circular(2.5),
          topRight: const Radius.circular(2.5),
        ),
        Paint()..color = Color.lerp(paper, Colors.white, 0.28)!,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PostItPainter oldDelegate) =>
      oldDelegate.paper != paper ||
      oldDelegate.seed != seed ||
      oldDelegate.adhesive != adhesive;
}
