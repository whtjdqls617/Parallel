import 'package:flutter/material.dart';

import '../scenes/desert/desert_scene.dart';
import '../theme/desert_palette.dart';

class ParallelApp extends StatelessWidget {
  const ParallelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parallel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: DesertPalette.canvas,
        useMaterial3: true,
      ),
      home: const Scaffold(body: DesertScene()),
    );
  }
}
