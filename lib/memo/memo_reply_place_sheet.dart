import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'memo.dart';

/// Drag the sticky onto the memo — returns normalized top-left (0..1).
Future<Offset?> showMemoReplyPlaceSheet(
  BuildContext context, {
  required Memo memo,
  required MemoDraft draft,
  required MemoTheme theme,
  Offset? initial,
  String? hideUid,
}) {
  return showGeneralDialog<Offset>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close place reply',
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondary) {
      return SafeArea(
        child: _ReplyPlaceBody(
          memo: memo,
          draft: draft,
          theme: theme,
          initial: initial,
          hideUid: hideUid,
        ),
      );
    },
    transitionBuilder: (context, animation, secondary, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(opacity: fade, child: child);
    },
  );
}

class _ReplyPlaceBody extends StatefulWidget {
  const _ReplyPlaceBody({
    required this.memo,
    required this.draft,
    required this.theme,
    this.initial,
    this.hideUid,
  });

  final Memo memo;
  final MemoDraft draft;
  final MemoTheme theme;
  final Offset? initial;
  final String? hideUid;

  @override
  State<_ReplyPlaceBody> createState() => _ReplyPlaceBodyState();
}

class _ReplyPlaceBodyState extends State<_ReplyPlaceBody> {
  /// Normalized top-left of the new sticky.
  late Offset _norm;

  @override
  void initState() {
    super.initState();
    _norm = widget.initial ?? const Offset(0.52, 0.62);
  }

  int get _paperColor {
    final seed =
        (widget.draft.text.hashCode ^ widget.draft.song.hashCode).abs();
    return (seed & 1) == 0 ? 0xFFFFF59D : 0xFFF8BBD0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final cool = theme.isCool;
    final size = MediaQuery.sizeOf(context);
    final paperW = math.min(size.width * 0.88, 420.0);
    final paperH = paperW / 0.68;
    final ink = cool
        ? (theme == MemoTheme.space
            ? const Color(0xFFD8DCE8)
            : theme == MemoTheme.ocean || theme == MemoTheme.rain
                ? const Color(0xFFD8E4E8)
                : const Color(0xFFE8DCC8))
        : const Color(0xFF4A3018);
    final board = cool
        ? (theme == MemoTheme.space
            ? const Color(0xFF12182A)
            : theme == MemoTheme.ocean || theme == MemoTheme.rain
                ? const Color(0xFF1A2830)
                : const Color(0xFF1A2820))
        : const Color(0xFFE8C898);
    final letter = cool
        ? (theme == MemoTheme.space
            ? const Color(0xFFDCE0EC)
            : theme == MemoTheme.ocean || theme == MemoTheme.rain
                ? const Color(0xFFE4ECF0)
                : const Color(0xFFE4E8D8))
        : const Color(0xFFF8EBD4);
    final nestInk = cool
        ? (theme == MemoTheme.space
            ? const Color(0xFF1C2438)
            : const Color(0xFF1C3038))
        : const Color(0xFF5A3A20);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: paperW + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '포스트잇을 끌어 붙일 자리를 정해요',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 14,
                  letterSpacing: 0.6,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: paperW,
                height: paperH,
                decoration: BoxDecoration(
                  color: board,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    final sticky = math.min(w, h) * 0.26;
                    final maxLeft = math.max(0.0, w - sticky);
                    final maxTop = math.max(0.0, h - sticky);

                    Offset clampNorm(Offset n) => Offset(
                          n.dx.clamp(0.0, maxLeft / w),
                          n.dy.clamp(0.0, maxTop / h),
                        );

                    final left = _norm.dx * w;
                    final top = _norm.dy * h;

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              color: letter,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 14, 14, 14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '누군가의 마음',
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 11,
                                        letterSpacing: 1.6,
                                        color: nestInk.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Text(
                                        widget.memo.text,
                                        maxLines: 8,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Georgia',
                                          fontSize: 15,
                                          height: 1.45,
                                          color: nestInk,
                                        ),
                                      ),
                                    ),
                                    if (widget.memo.hasSong) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '♪  ${widget.memo.songLabel}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Georgia',
                                          fontSize: 13,
                                          color:
                                              nestInk.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Existing replies (dimmed).
                          for (final r in widget.memo.replies)
                            if (r.hasAnchor && r.uid != widget.hideUid)
                              Positioned(
                                left: (r.x! * w).clamp(0.0, maxLeft),
                                top: (r.y! * h).clamp(0.0, maxTop),
                                width: sticky * 0.85,
                                height: sticky * 0.85,
                                child: Opacity(
                                  opacity: 0.55,
                                  child: _MiniSticky(
                                    paper: Color(r.stickyColorValue),
                                    text: r.text,
                                    song: r.hasSong ? r.songLabel : null,
                                  ),
                                ),
                              ),
                          // Draggable new sticky.
                          Positioned(
                            left: left.clamp(0.0, maxLeft),
                            top: top.clamp(0.0, maxTop),
                            width: sticky,
                            height: sticky,
                            child: GestureDetector(
                              onPanUpdate: (d) {
                                setState(() {
                                  _norm = clampNorm(
                                    Offset(
                                      _norm.dx + d.delta.dx / w,
                                      _norm.dy + d.delta.dy / h,
                                    ),
                                  );
                                });
                              },
                              child: _MiniSticky(
                                paper: Color(_paperColor),
                                text: widget.draft.text,
                                song: () {
                                  final a = widget.draft.artist.trim();
                                  final s = widget.draft.song.trim();
                                  if (s.isEmpty && a.isEmpty) return null;
                                  if (s.isNotEmpty && a.isNotEmpty) {
                                    return '$s / $a';
                                  }
                                  return s.isNotEmpty ? s : a;
                                }(),
                                elevating: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(foregroundColor: ink),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_norm),
                    style: FilledButton.styleFrom(
                      backgroundColor: cool
                          ? const Color(0xFF3A5460)
                          : const Color(0xFF8A5A30),
                      foregroundColor: cool
                          ? const Color(0xFFE0ECF0)
                          : const Color(0xFFF3E6C8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      '여기 붙이기',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSticky extends StatelessWidget {
  const _MiniSticky({
    required this.paper,
    required this.text,
    this.song,
    this.elevating = false,
  });

  final Color paper;
  final String text;
  final String? song;
  final bool elevating;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: elevating ? 6 : 1,
      shadowColor: Colors.black54,
      child: CustomPaint(
        painter: _PlaceStickyPainter(paper: paper),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: song != null ? 3 : 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 11,
                    height: 1.3,
                    color: Color(0xFF3A3428),
                  ),
                ),
              ),
              if (song != null)
                Text(
                  '♪ $song',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 9,
                    color: const Color(0xFF3A3428).withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceStickyPainter extends CustomPainter {
  _PlaceStickyPainter({required this.paper});

  final Color paper;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 3, size.height - 3),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(
      r.shift(const Offset(1.5, 2)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRRect(r, Paint()..color = paper);
  }

  @override
  bool shouldRepaint(covariant _PlaceStickyPainter oldDelegate) =>
      oldDelegate.paper != paper;
}
