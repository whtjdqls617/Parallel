import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'memo.dart';
import 'memo_board_layout.dart';

/// Small distant notice boards — fully opaque, planted, theme-specific.
abstract final class MemoBoardPaint {
  static void paint(Canvas canvas, Size size, MemoTheme theme) {
    final frame = MemoBoardLayout.frameRect(size, theme);
    canvas.save();
    switch (theme) {
      case MemoTheme.desert:
        _paintDesertBoard(canvas, frame);
      case MemoTheme.forest:
        _paintForestBoard(canvas, frame);
      case MemoTheme.ocean:
        _paintOceanBoard(canvas, frame);
      case MemoTheme.space:
        _paintSpaceBoard(canvas, frame);
    }
    canvas.restore();
  }

  static Rect _face(Rect frame) {
    final w = frame.width;
    final h = frame.height;
    final f = MemoBoardLayout.faceInFrame;
    return Rect.fromLTRB(
      frame.left + f.left * w,
      frame.top + f.top * h,
      frame.left + f.right * w,
      frame.top + f.bottom * h,
    );
  }

  static void _paintDesertBoard(Canvas canvas, Rect frame) {
    final w = frame.width;
    final h = frame.height;
    final face = _face(frame);

    // Opaque sand pile where posts enter
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(frame.center.dx, frame.bottom - h * 0.05),
        width: w * 0.9,
        height: h * 0.22,
      ),
      Paint()..color = const Color(0xFFB88858),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(frame.center.dx, frame.bottom - h * 0.02),
        width: w * 0.62,
        height: h * 0.10,
      ),
      Paint()..color = const Color(0xFF8A6038),
    );

    final postW = w * 0.06;
    final postTop = face.top + face.height * 0.12;
    final postBottom = frame.bottom - h * 0.02;
    for (final x in [frame.left + w * 0.17, frame.right - w * 0.17 - postW]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x, postTop, x + postW, postBottom),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFF6A4018),
      );
    }

    final board = RRect.fromRectAndRadius(face, const Radius.circular(2));
    canvas.drawRRect(board, Paint()..color = const Color(0xFF5A3818));
    canvas.drawRRect(
      board,
      Paint()
        ..shader = ui.Gradient.linear(
          face.topLeft,
          face.bottomRight,
          const [
            Color(0xFFC8A068),
            Color(0xFFB08850),
            Color(0xFF987040),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );

    final grain = Paint()
      ..color = const Color(0xFF8A5828)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final y = face.top + face.height * (0.35 + i * 0.25);
      canvas.drawLine(
        Offset(face.left + face.width * 0.08, y),
        Offset(face.right - face.width * 0.08, y + (i.isEven ? 0.8 : -0.8)),
        grain,
      );
    }

    final nail = Paint()..color = const Color(0xFF5A3010);
    for (final nx in [0.14, 0.86]) {
      canvas.drawCircle(
        Offset(face.left + face.width * nx, face.top + face.height * 0.2),
        math.max(1.0, w * 0.02),
        nail,
      );
    }
  }

  static void _paintForestBoard(Canvas canvas, Rect frame) {
    final w = frame.width;
    final h = frame.height;
    final face = _face(frame);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(frame.center.dx, frame.bottom - h * 0.04),
        width: w * 0.88,
        height: h * 0.2,
      ),
      Paint()..color = const Color(0xFF1A2418),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(frame.center.dx, frame.bottom - h * 0.02),
        width: w * 0.55,
        height: h * 0.09,
      ),
      Paint()..color = const Color(0xFF2A3828),
    );

    final postW = w * 0.065;
    final postTop = face.top + face.height * 0.1;
    final postBottom = frame.bottom - h * 0.015;
    for (final x in [frame.left + w * 0.16, frame.right - w * 0.16 - postW]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x, postTop, x + postW, postBottom),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFF14100C),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - 0.5, postBottom - h * 0.14, x + postW + 0.5, postBottom),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFF3A4A30),
      );
    }

    final board = RRect.fromRectAndRadius(face, const Radius.circular(2));
    canvas.drawRRect(board, Paint()..color = const Color(0xFF0C100C));
    canvas.drawRRect(
      board,
      Paint()
        ..shader = ui.Gradient.linear(
          face.topLeft,
          face.bottomRight,
          const [
            Color(0xFF2E2A20),
            Color(0xFF221E16),
            Color(0xFF16120C),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );

    canvas.drawLine(
      Offset(face.left + 2, face.top + 1),
      Offset(face.right - 2, face.top + 1),
      Paint()
        ..color = const Color(0xFF4A5A48)
        ..strokeWidth = 1.0,
    );

    final grain = Paint()
      ..color = const Color(0xFF3A3020)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 2; i++) {
      final y = face.top + face.height * (0.38 + i * 0.22);
      canvas.drawLine(
        Offset(face.left + face.width * 0.1, y),
        Offset(face.right - face.width * 0.1, y),
        grain,
      );
    }

    final nail = Paint()..color = const Color(0xFF5A6048);
    for (final nx in [0.14, 0.86]) {
      canvas.drawCircle(
        Offset(face.left + face.width * nx, face.top + face.height * 0.22),
        math.max(1.0, w * 0.018),
        nail,
      );
    }
  }

  static void _paintOceanBoard(Canvas canvas, Rect frame) {
    final w = frame.width;
    final h = frame.height;
    final face = _face(frame);

    // Wet sand mound.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(frame.center.dx, frame.bottom - h * 0.04),
        width: w * 0.9,
        height: h * 0.2,
      ),
      Paint()..color = const Color(0xFF9A8060),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(frame.center.dx, frame.bottom - h * 0.015),
        width: w * 0.58,
        height: h * 0.09,
      ),
      Paint()..color = const Color(0xFF7A6448),
    );

    final postW = w * 0.06;
    final postTop = face.top + face.height * 0.1;
    final postBottom = frame.bottom - h * 0.012;
    for (final x in [frame.left + w * 0.16, frame.right - w * 0.16 - postW]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x, postTop, x + postW, postBottom),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFF3A1814),
      );
    }

    final board = RRect.fromRectAndRadius(face, const Radius.circular(2));
    canvas.drawRRect(board, Paint()..color = const Color(0xFF2A0C0C));
    canvas.drawRRect(
      board,
      Paint()
        ..shader = ui.Gradient.linear(
          face.topLeft,
          face.bottomRight,
          const [
            Color(0xFF8A1E1E),
            Color(0xFF6A1414),
            Color(0xFF4A0E0E),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );

    final grain = Paint()
      ..color = const Color(0xFFA83838)
      ..strokeWidth = 0.85
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 2; i++) {
      final y = face.top + face.height * (0.36 + i * 0.24);
      canvas.drawLine(
        Offset(face.left + face.width * 0.1, y),
        Offset(face.right - face.width * 0.1, y + (i.isEven ? 0.6 : -0.6)),
        grain,
      );
    }

    final nail = Paint()..color = const Color(0xFFC8A070);
    for (final nx in [0.14, 0.86]) {
      canvas.drawCircle(
        Offset(face.left + face.width * nx, face.top + face.height * 0.2),
        math.max(1.0, w * 0.018),
        nail,
      );
    }
  }

  static void _paintSpaceBoard(Canvas canvas, Rect frame) {
    final w = frame.width;
    final h = frame.height;
    final face = _face(frame);

    // Soft earth under the posts.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(frame.center.dx, frame.bottom - h * 0.04),
        width: w * 0.88,
        height: h * 0.18,
      ),
      Paint()..color = const Color(0xFF100E0A),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(frame.center.dx, frame.bottom - h * 0.015),
        width: w * 0.55,
        height: h * 0.08,
      ),
      Paint()..color = const Color(0xFF16140E),
    );

    final postW = w * 0.055;
    final postTop = face.top + face.height * 0.12;
    final postBottom = frame.bottom - h * 0.012;
    for (final x in [frame.left + w * 0.17, frame.right - w * 0.17 - postW]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x, postTop, x + postW, postBottom),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFF16141C),
      );
    }

    final board = RRect.fromRectAndRadius(face, const Radius.circular(2));
    canvas.drawRRect(board, Paint()..color = const Color(0xFF080A10));
    canvas.drawRRect(
      board,
      Paint()
        ..shader = ui.Gradient.linear(
          face.topLeft,
          face.bottomRight,
          const [
            Color(0xFF161820),
            Color(0xFF101218),
            Color(0xFF0A0C12),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );

    final grain = Paint()
      ..color = const Color(0xFF2A303C)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 2; i++) {
      final y = face.top + face.height * (0.36 + i * 0.24);
      canvas.drawLine(
        Offset(face.left + face.width * 0.1, y),
        Offset(face.right - face.width * 0.1, y),
        grain,
      );
    }

    final nail = Paint()..color = const Color(0xFF4A505C);
    for (final nx in [0.14, 0.86]) {
      canvas.drawCircle(
        Offset(face.left + face.width * nx, face.top + face.height * 0.22),
        math.max(1.0, w * 0.016),
        nail,
      );
    }
  }
}
