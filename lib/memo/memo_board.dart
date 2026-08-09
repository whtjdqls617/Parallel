import 'dart:async';

import 'package:flutter/material.dart';

import 'memo.dart';
import 'memo_board_layout.dart';
import 'memo_board_paint.dart';
import 'memo_compose_sheet.dart';
import 'memo_panel.dart';
import 'memo_reveal_controller.dart';
import 'memo_service.dart';

/// Overlay: planted board + one cryptic teaser note. Tap opens center list.
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
    // Board teaser only — one quiet scrap.
    _reveal = MemoRevealController(maxVisible: 1);
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
      onCompose: _compose,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sceneSize = Size(constraints.maxWidth, constraints.maxHeight);
        final frame = MemoBoardLayout.frameRect(sceneSize, widget.theme);
        final face = MemoBoardLayout.faceRect(sceneSize, widget.theme);
        final teaser = _reveal.visibleMemos.isEmpty
            ? null
            : _reveal.visibleMemos.first;

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
            if (teaser != null)
              Positioned(
                left: face.left,
                top: face.top,
                width: face.width,
                height: face.height,
                child: _TeaserNote(
                  key: ValueKey(teaser.id),
                  theme: widget.theme,
                  faceSize: face.size,
                  onTap: _openPanel,
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
    required this.onTap,
  });

  final MemoTheme theme;
  final Size faceSize;
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
      duration: const Duration(milliseconds: 1100),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
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
    final isForest = widget.theme == MemoTheme.forest;
    final paper = isForest
        ? const Color(0xFFD2C6A8)
        : const Color(0xFFE2D0A8);

    final noteW = widget.faceSize.width * 0.36;
    final noteH = widget.faceSize.height * 0.62;
    final left = widget.faceSize.width * 0.32;
    final top = widget.faceSize.height * 0.16;

    return Stack(
      children: [
        Positioned(
          left: left.clamp(2.0, widget.faceSize.width - noteW - 2),
          top: top.clamp(2.0, widget.faceSize.height - noteH - 2),
          width: noteW,
          height: noteH,
          child: FadeTransition(
            opacity: _opacity,
            child: SlideTransition(
              position: _slide,
              child: Transform.rotate(
                angle: -0.04,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: ColoredBox(color: paper),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
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
