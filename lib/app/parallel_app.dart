import 'package:flutter/material.dart';

import '../scenes/desert/desert_scene.dart';
import '../scenes/forest/forest_scene.dart';
import '../theme/desert_palette.dart';
import '../theme/forest_palette.dart';

enum _SceneKind { desert, forest }

class ParallelApp extends StatelessWidget {
  const ParallelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parallel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const _ScenePicker(),
    );
  }
}

/// Temporary — swap themes while iterating. Remove when a real picker exists.
class _ScenePicker extends StatefulWidget {
  const _ScenePicker();

  @override
  State<_ScenePicker> createState() => _ScenePickerState();
}

class _ScenePickerState extends State<_ScenePicker> {
  _SceneKind _kind = _SceneKind.forest;

  @override
  Widget build(BuildContext context) {
    final isForest = _kind == _SceneKind.forest;
    return Scaffold(
      backgroundColor:
          isForest ? ForestPalette.canvas : DesertPalette.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (isForest) const ForestScene() else const DesertScene(),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Chip(
                          label: '사막',
                          selected: !isForest,
                          onTap: () =>
                              setState(() => _kind = _SceneKind.desert),
                        ),
                        _Chip(
                          label: '숲',
                          selected: isForest,
                          onTap: () =>
                              setState(() => _kind = _SceneKind.forest),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.92)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
            color: selected
                ? const Color(0xFF2A2A2A)
                : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
