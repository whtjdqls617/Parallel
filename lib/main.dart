import 'package:flutter/material.dart';

import 'app/parallel_app.dart';
import 'audio/ambient_music.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Don't pause Spotify / other apps when our nature bed starts.
  await AmbientMusic.ensureMixWithOthers();
  runApp(const ParallelApp());
}
