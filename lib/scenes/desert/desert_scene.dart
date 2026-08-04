import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../theme/desert_palette.dart';
import 'desert_painter.dart';

/// Full-bleed desert. Empty place. Shared only by the quiet count.
class DesertScene extends StatefulWidget {
  const DesertScene({
    super.key,
    this.presenceCount = 127,
  });

  /// People currently resting in this same moment, worldwide.
  final int presenceCount;

  @override
  State<DesertScene> createState() => _DesertSceneState();
}

class _DesertSceneState extends State<DesertScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _elapsed = elapsed);
    })..start();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _elapsed.inMicroseconds / 1e6;
    return ColoredBox(
      color: DesertPalette.canvas,
      child: CustomPaint(
        painter: DesertPainter(
          t: t,
          presenceCount: widget.presenceCount,
        ),
        size: Size.infinite,
      ),
    );
  }
}
