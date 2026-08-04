import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../theme/forest_palette.dart';
import 'forest_painter.dart';

/// Moonlit lakeside. Soft water. Shared only by the quiet count.
class ForestScene extends StatefulWidget {
  const ForestScene({super.key, this.presenceCount = 127});

  /// People currently resting in this same moment, worldwide.
  final int presenceCount;

  @override
  State<ForestScene> createState() => _ForestSceneState();
}

class _ForestSceneState extends State<ForestScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  late int _mossSettled;
  int? _mossFrom;
  int? _mossTo;
  double? _mossChangeAt;

  late int _liveCount;
  double _nextDemoAt = 9;

  @override
  void initState() {
    super.initState();
    _liveCount = widget.presenceCount;
    _mossSettled = widget.presenceCount;
    _ticker = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1e6;
      _maybeDemoDrift(t);
      _maybeSettleMoss(t);
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
  void didUpdateWidget(covariant ForestScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presenceCount == widget.presenceCount) return;
    _liveCount = widget.presenceCount;
    _beginMossChange(widget.presenceCount);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _beginMossChange(int next) {
    final t = _elapsed.inMicroseconds / 1e6;
    final showing = _currentMossCount(t);
    if (next == showing && _mossChangeAt == null) return;
    _mossFrom = showing;
    _mossTo = next;
    _mossChangeAt = t;
  }

  void _maybeDemoDrift(double t) {
    if (t < _nextDemoAt) return;
    if (_mossChangeAt != null) {
      _nextDemoAt = t + 2;
      return;
    }
    final delta = (t * 17).floor().isEven ? 1 : -1;
    final next = (_liveCount + delta).clamp(3, 999);
    if (next == _liveCount) return;
    _liveCount = next;
    _beginMossChange(next);
    _nextDemoAt = t + 8 + (next % 5);
  }

  void _maybeSettleMoss(double t) {
    final changeAt = _mossChangeAt;
    final to = _mossTo;
    if (changeAt == null || to == null) return;

    final total =
        ForestPainter.mossEraseSeconds +
        ForestPainter.mossPauseSeconds +
        ForestPainter.mossWriteSeconds;
    if (t - changeAt < total) return;

    _mossSettled = to;
    _mossFrom = null;
    _mossTo = null;
    _mossChangeAt = null;
  }

  int _currentMossCount(double t) {
    final changeAt = _mossChangeAt;
    final from = _mossFrom;
    final to = _mossTo;
    if (changeAt == null || from == null || to == null) return _mossSettled;

    final u = t - changeAt;
    if (u < ForestPainter.mossEraseSeconds) return from;
    return to;
  }

  ({int mossCount, double reveal, double erase}) _mossInscription(double t) {
    final changeAt = _mossChangeAt;
    final from = _mossFrom;
    final to = _mossTo;
    if (changeAt == null || from == null || to == null) {
      return (mossCount: _mossSettled, reveal: 1, erase: 0);
    }

    final u = t - changeAt;
    const eraseDur = ForestPainter.mossEraseSeconds;
    const pauseDur = ForestPainter.mossPauseSeconds;
    const writeDur = ForestPainter.mossWriteSeconds;

    if (u < eraseDur) {
      return (
        mossCount: from,
        reveal: 1,
        erase: (u / eraseDur).clamp(0.0, 1.0),
      );
    }
    if (u < eraseDur + pauseDur) {
      return (mossCount: to, reveal: 0, erase: 1);
    }
    if (u < eraseDur + pauseDur + writeDur) {
      final w = ((u - eraseDur - pauseDur) / writeDur).clamp(0.0, 1.0);
      return (mossCount: to, reveal: w, erase: 0);
    }
    return (mossCount: to, reveal: 1, erase: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = _elapsed.inMicroseconds / 1e6;
    final moss = _mossInscription(t);

    return ColoredBox(
      color: ForestPalette.canvas,
      child: CustomPaint(
        painter: ForestPainter(
          t: t,
          presenceCount: _liveCount,
          mossCount: moss.mossCount,
          mossReveal: moss.reveal,
          mossErase: moss.erase,
        ),
        size: Size.infinite,
      ),
    );
  }
}
