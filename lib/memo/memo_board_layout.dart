import 'package:flutter/painting.dart';

import 'memo.dart';

/// Shared geometry for the planted theme notice board.
abstract final class MemoBoardLayout {
  /// Right side — easier for right-handed reach.
  /// Desert: planted on the near sitting-sand lip (first ridge).
  static Rect frameFor(MemoTheme theme) => switch (theme) {
    // Mid of the near sitting-sand lip (first ridge), a touch farther than feet.
    MemoTheme.desert => const Rect.fromLTWH(0.66, 0.70, 0.18, 0.12),
    MemoTheme.forest => const Rect.fromLTWH(0.72, 0.60, 0.12, 0.085),
    // Driftwood board on the right of your sitting sand.
    MemoTheme.ocean => const Rect.fromLTWH(0.70, 0.70, 0.16, 0.11),
    // Small board on the near grass — left side.
    MemoTheme.space => const Rect.fromLTWH(0.14, 0.76, 0.14, 0.09),
    // Long cabin tray + small desk calendar sitting on it.
    MemoTheme.rain => const Rect.fromLTWH(0.06, 0.78, 0.88, 0.18),
    // Fire diary — size from width; true 3:4 computed in [frameRect].
    MemoTheme.fire => const Rect.fromLTWH(0.64, 0.78, 0.16, 0),
  };

  /// Plank face; lower band of frame is posts in the ground.
  /// Rain: upright calendar face on the right of the tray.
  /// Fire: nearly full frame — notebook body.
  static Rect faceInFrameFor(MemoTheme theme) => switch (theme) {
    MemoTheme.rain => const Rect.fromLTRB(0.64, 0.04, 0.92, 0.58),
    MemoTheme.fire => const Rect.fromLTRB(0.08, 0.1, 0.92, 0.88),
    _ => const Rect.fromLTRB(0.06, 0.04, 0.94, 0.58),
  };

  /// Casual floor tilt for the fire diary (radians). Positive = leans right.
  static double tiltFor(MemoTheme theme) => switch (theme) {
    MemoTheme.fire => 0.12,
    _ => 0,
  };

  static Rect frameRect(Size sceneSize, MemoTheme theme) {
    final frame = frameFor(theme);
    if (theme == MemoTheme.fire) {
      // Pixel-true 3:4 portrait (가로3 : 세로4).
      final w = sceneSize.width * frame.width;
      final h = w * 4 / 3;
      return Rect.fromLTWH(
        frame.left * sceneSize.width,
        frame.top * sceneSize.height,
        w,
        h,
      );
    }
    return Rect.fromLTWH(
      frame.left * sceneSize.width,
      frame.top * sceneSize.height,
      frame.width * sceneSize.width,
      frame.height * sceneSize.height,
    );
  }

  static Rect faceRect(Size sceneSize, MemoTheme theme) {
    final framePx = frameRect(sceneSize, theme);
    final f = faceInFrameFor(theme);
    return Rect.fromLTRB(
      framePx.left + f.left * framePx.width,
      framePx.top + f.top * framePx.height,
      framePx.left + f.right * framePx.width,
      framePx.top + f.bottom * framePx.height,
    );
  }
}
