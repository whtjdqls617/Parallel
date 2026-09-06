// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parallel/memo/memo.dart';
import 'package:parallel/scenes/desert/desert_painter.dart';
import 'package:parallel/scenes/fire/fire_painter.dart';
import 'package:parallel/scenes/forest/forest_painter.dart';
import 'package:parallel/scenes/ocean/ocean_painter.dart';
import 'package:parallel/scenes/rain/rain_painter.dart';
import 'package:parallel/scenes/star/star_painter.dart';

/// One-shot bake: `flutter test tool/bake_theme_thumbs_test.dart`
/// Writes PNGs to assets/theme_thumbs/{theme}.png
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bake theme thumbnails', () async {
    const logical = Size(440, 564); // 2x for retina-ish crispness
    const t = 8.0;
    final outDir = Directory('assets/theme_thumbs');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    CustomPainter painterFor(MemoTheme theme) => switch (theme) {
      MemoTheme.desert => DesertPainter(t: t, showPresence: false),
      MemoTheme.forest => ForestPainter(t: t, showPresence: false),
      MemoTheme.ocean => OceanPainter(t: t, showPresence: false),
      MemoTheme.space => StarPainter(t: t, showPresence: false),
      MemoTheme.rain => RainPainter(
        t: t,
        presenceCount: 0,
        sandCount: 0,
        sandReveal: 1,
        sandErase: 0,
        showPresence: false,
      ),
      MemoTheme.fire => FirePainter(t: t, showPresence: false),
    };

    for (final theme in MemoTheme.values) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painterFor(theme).paint(canvas, logical);
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        logical.width.ceil(),
        logical.height.ceil(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      final file = File('${outDir.path}/${theme.name}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      print('wrote ${file.path} (${file.lengthSync()} bytes)');
      image.dispose();
      picture.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
