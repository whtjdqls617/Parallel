import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/parallel_app.dart';
import 'audio/ambient_music.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Don't pause Spotify / other apps when our nature bed starts.
  await AmbientMusic.ensureMixWithOthers();
  runApp(const ParallelApp());
}
