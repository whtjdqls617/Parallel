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
  };

  /// Plank face; lower band of frame is posts in the ground.
  static const faceInFrame = Rect.fromLTRB(0.06, 0.04, 0.94, 0.58);

  static Rect frameRect(Size sceneSize, MemoTheme theme) {
    final frame = frameFor(theme);
    return Rect.fromLTWH(
      frame.left * sceneSize.width,
      frame.top * sceneSize.height,
      frame.width * sceneSize.width,
      frame.height * sceneSize.height,
    );
  }

  static Rect faceRect(Size sceneSize, MemoTheme theme) {
    final framePx = frameRect(sceneSize, theme);
    final f = faceInFrame;
    return Rect.fromLTRB(
      framePx.left + f.left * framePx.width,
      framePx.top + f.top * framePx.height,
      framePx.left + f.right * framePx.width,
      framePx.top + f.bottom * framePx.height,
    );
  }
}
