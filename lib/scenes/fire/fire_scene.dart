import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../memo/memo.dart';
import '../../memo/memo_board.dart';
import '../../theme/fire_palette.dart';
import 'fire_painter.dart';

/// European brick fireplace. Shared only by the quiet count.
class FireScene extends StatefulWidget {
  const FireScene({
    super.key,
    this.presenceCount = 0,
    this.useDemoDrift = false,
  });

  /// People currently resting in this same moment, worldwide.
  final int presenceCount;

  /// Local ±1 drift for polish demos. Off when a live feed is wired.
  final bool useDemoDrift;

  @override
  State<FireScene> createState() => _FireSceneState();
}

class _FireSceneState extends State<FireScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  late int _emberSettled;
  int? _emberFrom;
  int? _emberTo;
  double? _emberChangeAt;

  late int _liveCount;
  double _nextDemoAt = 9;

  @override
  void initState() {
    super.initState();
    _liveCount = widget.presenceCount;
    _emberSettled = widget.presenceCount;
    _ticker = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1e6;
      if (widget.useDemoDrift) _maybeDemoDrift(t);
      _maybeSettleEmber(t);
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
  void didUpdateWidget(covariant FireScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presenceCount == widget.presenceCount) return;
    _liveCount = widget.presenceCount;
    _beginEmberChange(widget.presenceCount);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _beginEmberChange(int next) {
    final t = _elapsed.inMicroseconds / 1e6;
    final showing = _currentEmberCount(t);
    if (next == showing && _emberChangeAt == null) return;
    _emberFrom = showing;
    _emberTo = next;
    _emberChangeAt = t;
  }

  void _maybeDemoDrift(double t) {
    if (t < _nextDemoAt) return;
    if (_emberChangeAt != null) {
      _nextDemoAt = t + 2;
      return;
    }
    final delta = (t * 11).floor() % 3 == 0 ? 1 : -1;
    final next = (_liveCount + delta).clamp(1, 9999);
    if (next == _liveCount) return;
    _liveCount = next;
    _beginEmberChange(next);
    _nextDemoAt = t + 7 + (t * 3).floor() % 5;
  }

  void _maybeSettleEmber(double t) {
    final changeAt = _emberChangeAt;
    final to = _emberTo;
    if (changeAt == null || to == null) return;

    final total =
        FirePainter.emberEraseSeconds +
        FirePainter.emberPauseSeconds +
        FirePainter.emberWriteSeconds;
    if (t - changeAt < total) return;

    _emberSettled = to;
    _emberFrom = null;
    _emberTo = null;
    _emberChangeAt = null;
  }

  int _currentEmberCount(double t) {
    final changeAt = _emberChangeAt;
    final from = _emberFrom;
    final to = _emberTo;
    if (changeAt == null || from == null || to == null) return _emberSettled;

    final u = t - changeAt;
    if (u < FirePainter.emberEraseSeconds) return from;
    return to;
  }

  ({int emberCount, double reveal, double erase}) _emberInscription(double t) {
    final changeAt = _emberChangeAt;
    final from = _emberFrom;
    final to = _emberTo;
    if (changeAt == null || from == null || to == null) {
      return (emberCount: _emberSettled, reveal: 1, erase: 0);
    }

    final u = t - changeAt;
    const eraseDur = FirePainter.emberEraseSeconds;
    const pauseDur = FirePainter.emberPauseSeconds;
    const writeDur = FirePainter.emberWriteSeconds;

    if (u < eraseDur) {
      return (
        emberCount: from,
        reveal: 1,
        erase: (u / eraseDur).clamp(0.0, 1.0),
      );
    }
    if (u < eraseDur + pauseDur) {
      return (emberCount: to, reveal: 0, erase: 1);
    }
    if (u < eraseDur + pauseDur + writeDur) {
      final w = ((u - eraseDur - pauseDur) / writeDur).clamp(0.0, 1.0);
      return (emberCount: to, reveal: w, erase: 0);
    }
    return (emberCount: to, reveal: 1, erase: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = _elapsed.inMicroseconds / 1e6;
    final ember = _emberInscription(t);

    return ColoredBox(
      color: FirePalette.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: FirePainter(
              t: t,
              presenceCount: _liveCount,
              emberCount: ember.emberCount,
              emberReveal: ember.reveal,
              emberErase: ember.erase,
            ),
            size: Size.infinite,
          ),
          const MemoBoardLayer(theme: MemoTheme.fire),
        ],
      ),
    );
  }
}
