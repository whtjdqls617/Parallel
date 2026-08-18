import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'memo.dart';
import 'memo_board_layout.dart';
import 'memo_board_paint.dart';
import 'memo_compose_sheet.dart';
import 'memo_panel.dart';
import 'memo_reveal_controller.dart';
import 'memo_service.dart';
import '../subscription/subscription_gate.dart';
import '../subscription/subscription_service.dart';

/// Overlay: planted board + up to three teaser notes. Tap opens center list.
class MemoBoardLayer extends StatefulWidget {
  const MemoBoardLayer({
    super.key,
    required this.theme,
    MemoService? service,
  }) : _service = service;

  final MemoTheme theme;
  final MemoService? _service;

  @override
  State<MemoBoardLayer> createState() => _MemoBoardLayerState();
}

class _MemoBoardLayerState extends State<MemoBoardLayer> {
  late final MemoService _service;
  late final MemoRevealController _reveal;
  StreamSubscription<List<Memo>>? _sub;
  String? _pendingPreferId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _service = widget._service ?? MemoService();
    // Board teasers — up to three, revealed one by one from the front.
    _reveal = MemoRevealController(maxVisible: 3);
    _reveal.addListener(_onReveal);
    _listen();
  }

  @override
  void didUpdateWidget(covariant MemoBoardLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme) _listen();
  }

  void _onReveal() {
    if (mounted) setState(() {});
  }

  void _listen() {
    _sub?.cancel();
    _pendingPreferId = null;
    _reveal.reset();
    _sub = _service.watchPool(widget.theme).listen(
      (pool) {
        _reveal.setPool(pool, preferId: _pendingPreferId);
        _pendingPreferId = null;
      },
      onError: (e, st) => debugPrint('Memo watch failed: $e\n$st'),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reveal.removeListener(_onReveal);
    _reveal.dispose();
    super.dispose();
  }

  Future<void> _compose() async {
    if (_submitting) return;
    if (!SubscriptionService.instance.isSubscribed) {
      await showSubscriptionGate(
        context,
        reason: '흔적을 남기려면 Parallel Plus가 필요해요. 읽기는 누구나 할 수 있어요.',
      );
      return;
    }

    final draft = await showMemoComposeSheet(
      context,
      theme: widget.theme,
    );
    if (draft == null || draft.text.trim().isEmpty || !mounted) return;

    setState(() => _submitting = true);
    try {
      final created = await _service.create(
        theme: widget.theme,
        text: draft.text,
        artist: draft.artist,
        song: draft.song,
      );
      _pendingPreferId = created.id;
    } catch (e, st) {
      debugPrint('Memo create failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('흔적 저장 실패: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openPanel() async {
    await showMemoPanel(
      context,
      theme: widget.theme,
      memos: _reveal.pool,
      canCompose: SubscriptionService.instance.isSubscribed,
      onCompose: _compose,
      service: _service,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sceneSize = Size(constraints.maxWidth, constraints.maxHeight);
        final frame = MemoBoardLayout.frameRect(sceneSize, widget.theme);
        final face = MemoBoardLayout.faceRect(sceneSize, widget.theme);
        final teasers = _reveal.visibleMemos;

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _MemoPropPainter(theme: widget.theme),
              size: Size.infinite,
            ),
            Positioned(
              left: frame.left,
              top: frame.top,
              width: frame.width,
              height: frame.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openPanel,
              ),
            ),
            if (teasers.isNotEmpty)
              Positioned(
                left: face.left,
                top: face.top,
                width: face.width,
                height: face.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < teasers.length; i++)
                      _TeaserNote(
                        key: ValueKey(teasers[i].id),
                        theme: widget.theme,
                        faceSize: face.size,
                        index: i,
                        mine: teasers[i].isOwnedBy(_service.currentUid),
                        onTap: _openPanel,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Blank scrap on the board — no text; tap opens the list.
class _TeaserNote extends StatefulWidget {
  const _TeaserNote({
    super.key,
    required this.theme,
    required this.faceSize,
    required this.index,
    required this.mine,
    required this.onTap,
  });

  final MemoTheme theme;
  final Size faceSize;
  final int index;
  final bool mine;
  final VoidCallback onTap;

  @override
  State<_TeaserNote> createState() => _TeaserNoteState();
}

class _TeaserNoteState extends State<_TeaserNote>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Small theme scraps in a loose row — front → back left-to-right.
    const pad = 2.0;
    final maxW = math.max(0.0, widget.faceSize.width - pad * 2);
    final maxH = math.max(0.0, widget.faceSize.height - pad * 2);
    final noteW = (widget.faceSize.width * 0.30).clamp(0.0, maxW);
    final noteH = (widget.faceSize.height * 0.42).clamp(0.0, maxH);
    final slot = widget.index.clamp(0, 2);
    final left = (pad +
            (widget.faceSize.width - noteW - pad * 2) *
                (slot == 0
                    ? 0.08
                    : slot == 1
                        ? 0.36
                        : 0.62))
        .clamp(pad, math.max(pad, widget.faceSize.width - noteW - pad))
        .toDouble();
    final top = (pad +
            widget.faceSize.height *
                (slot == 0
                    ? 0.22
                    : slot == 1
                        ? 0.14
                        : 0.28))
        .clamp(pad, math.max(pad, widget.faceSize.height - noteH - pad))
        .toDouble();
    final paper = widget.mine
        ? switch (widget.theme) {
            MemoTheme.forest => const Color(0xFFF3E8C4),
            MemoTheme.ocean => const Color(0xFFF0E6D4),
            MemoTheme.desert => const Color(0xFFFFF0C8),
          }
        : switch (widget.theme) {
            MemoTheme.forest =>
              slot.isEven ? const Color(0xFFD2C6A8) : const Color(0xFFC8B898),
            MemoTheme.ocean =>
              slot.isEven ? const Color(0xFFD0DCE0) : const Color(0xFFC4D0D6),
            MemoTheme.desert =>
              slot.isEven ? const Color(0xFFE2D0A8) : const Color(0xFFD8C498),
          };
    final angle = slot == 0 ? -0.06 : slot == 1 ? 0.05 : -0.03;

    return Positioned(
      left: left,
      top: top,
      width: noteW,
      height: noteH,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Transform.rotate(
            angle: angle,
            child: GestureDetector(
              onTap: widget.onTap,
              child: CustomPaint(
                size: Size(noteW, noteH),
                painter: _TeaserScrapPainter(paper: paper, seed: slot * 17 + 5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeaserScrapPainter extends CustomPainter {
  _TeaserScrapPainter({required this.paper, required this.seed});

  final Color paper;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final path = Path()
      ..moveTo(1.2 + rng.nextDouble(), 1.5 + rng.nextDouble())
      ..lineTo(size.width - 1.5 - rng.nextDouble(), 1 + rng.nextDouble())
      ..lineTo(size.width - 1, size.height - 1.5 - rng.nextDouble())
      ..lineTo(1.5 + rng.nextDouble(), size.height - 1)
      ..close();
    canvas.drawPath(
      path.shift(const Offset(0.9, 1.2)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawPath(path, Paint()..color = paper);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x668A6A40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _TeaserScrapPainter oldDelegate) =>
      oldDelegate.paper != paper || oldDelegate.seed != seed;
}

class _MemoPropPainter extends CustomPainter {
  _MemoPropPainter({required this.theme});

  final MemoTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    MemoBoardPaint.paint(canvas, size, theme);
  }

  @override
  bool shouldRepaint(covariant _MemoPropPainter oldDelegate) =>
      oldDelegate.theme != theme;

  @override
  bool hitTest(Offset position) => false;
}
