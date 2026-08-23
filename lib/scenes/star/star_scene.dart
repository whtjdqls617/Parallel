import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../memo/memo.dart';
import '../../memo/memo_board.dart';
import '../../theme/space_palette.dart';
import 'star_painter.dart';

/// Open grassland under a deep blue Milky Way sky.
class StarScene extends StatefulWidget {
  const StarScene({
    super.key,
    this.presenceCount = 0,
    this.useDemoDrift = false,
  });

  final int presenceCount;
  final bool useDemoDrift;

  @override
  State<StarScene> createState() => _SpaceSceneState();
}

class _SpaceSceneState extends State<StarScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  late int _sandSettled;
  int? _sandFrom;
  int? _sandTo;
  double? _sandChangeAt;

  late int _liveCount;
  double _nextDemoAt = 9;

  @override
  void initState() {
    super.initState();
    _liveCount = widget.presenceCount;
    _sandSettled = widget.presenceCount;
    _ticker = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1e6;
      if (widget.useDemoDrift) _maybeDemoDrift(t);
      _maybeSettleSand(t);
      setState(() => _elapsed = elapsed);
    })..start();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant StarScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presenceCount == widget.presenceCount) return;
    _liveCount = widget.presenceCount;
    _beginSandChange(widget.presenceCount);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _beginSandChange(int next) {
    final t = _elapsed.inMicroseconds / 1e6;
    final showing = _currentSandCount(t);
    if (next == showing && _sandChangeAt == null) return;
    _sandFrom = showing;
    _sandTo = next;
    _sandChangeAt = t;
  }

  void _maybeDemoDrift(double t) {
    if (t < _nextDemoAt) return;
    if (_sandChangeAt != null) {
      _nextDemoAt = t + 2;
      return;
    }
    final delta = (t * 17).floor().isEven ? 1 : -1;
    final next = (_liveCount + delta).clamp(3, 999);
    if (next == _liveCount) return;
    _liveCount = next;
    _beginSandChange(next);
    _nextDemoAt = t + 8 + (next % 5);
  }

  void _maybeSettleSand(double t) {
    final changeAt = _sandChangeAt;
    final to = _sandTo;
    if (changeAt == null || to == null) return;

    final total = StarPainter.sandEraseSeconds +
        StarPainter.sandPauseSeconds +
        StarPainter.sandWriteSeconds;
    if (t - changeAt < total) return;

    _sandSettled = to;
    _sandFrom = null;
    _sandTo = null;
    _sandChangeAt = null;
  }

  int _currentSandCount(double t) {
    final changeAt = _sandChangeAt;
    final from = _sandFrom;
    final to = _sandTo;
    if (changeAt == null || from == null || to == null) return _sandSettled;

    final u = t - changeAt;
    if (u < StarPainter.sandEraseSeconds) return from;
    return to;
  }

  ({int sandCount, double reveal, double erase}) _sandInscription(double t) {
    final changeAt = _sandChangeAt;
    final from = _sandFrom;
    final to = _sandTo;
    if (changeAt == null || from == null || to == null) {
      return (sandCount: _sandSettled, reveal: 1, erase: 0);
    }

    final u = t - changeAt;
    const eraseDur = StarPainter.sandEraseSeconds;
    const pauseDur = StarPainter.sandPauseSeconds;
    const writeDur = StarPainter.sandWriteSeconds;

    if (u < eraseDur) {
      return (
        sandCount: from,
        reveal: 1,
        erase: (u / eraseDur).clamp(0.0, 1.0),
      );
    }
    if (u < eraseDur + pauseDur) {
      return (sandCount: to, reveal: 0, erase: 1);
    }
    if (u < eraseDur + pauseDur + writeDur) {
      final w = ((u - eraseDur - pauseDur) / writeDur).clamp(0.0, 1.0);
      return (sandCount: to, reveal: w, erase: 0);
    }
    return (sandCount: to, reveal: 1, erase: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = _elapsed.inMicroseconds / 1e6;
    final sand = _sandInscription(t);

    return ColoredBox(
      color: SpacePalette.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: StarPainter(
              t: t,
              presenceCount: _liveCount,
              sandCount: sand.sandCount,
              sandReveal: sand.reveal,
              sandErase: sand.erase,
            ),
            size: Size.infinite,
          ),
          const MemoBoardLayer(theme: MemoTheme.space),
        ],
      ),
    );
  }
}
