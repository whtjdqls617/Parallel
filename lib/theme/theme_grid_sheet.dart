import 'package:flutter/material.dart';

import '../memo/memo.dart';

class ThemeGridEntry {
  const ThemeGridEntry({
    required this.theme,
    required this.label,
    required this.line,
    required this.thumbAsset,
    required this.placeholder,
  });

  final MemoTheme theme;
  final String label;
  final String line;
  final String thumbAsset;
  final Color placeholder;
}

const themeGridEntries = <ThemeGridEntry>[
  ThemeGridEntry(
    theme: MemoTheme.desert,
    label: '사막',
    line: '따뜻한 바람',
    thumbAsset: 'assets/theme_thumbs/desert.png',
    placeholder: Color(0xFFC48A48),
  ),
  ThemeGridEntry(
    theme: MemoTheme.forest,
    label: '숲',
    line: '달빛 호숫가',
    thumbAsset: 'assets/theme_thumbs/forest.png',
    placeholder: Color(0xFF1A2830),
  ),
  ThemeGridEntry(
    theme: MemoTheme.ocean,
    label: '바다',
    line: '멀리 파도',
    thumbAsset: 'assets/theme_thumbs/ocean.png',
    placeholder: Color(0xFF7EB6C9),
  ),
  ThemeGridEntry(
    theme: MemoTheme.space,
    label: '별',
    line: '넓은 밤',
    thumbAsset: 'assets/theme_thumbs/space.png',
    placeholder: Color(0xFF1A2240),
  ),
  ThemeGridEntry(
    theme: MemoTheme.rain,
    label: '하늘',
    line: '비행기 창밖',
    thumbAsset: 'assets/theme_thumbs/rain.png',
    placeholder: Color(0xFF3A6A98),
  ),
  ThemeGridEntry(
    theme: MemoTheme.fire,
    label: '불',
    line: '벽난로 불멍',
    thumbAsset: 'assets/theme_thumbs/fire.png',
    placeholder: Color(0xFF8A4020),
  ),
];

/// Full-bleed place picker — 2-column scene tiles, not a settings grid.
Future<MemoTheme?> showThemeGridSheet(
  BuildContext context, {
  required MemoTheme current,
  required bool Function(MemoTheme theme) isLocked,
}) {
  return showGeneralDialog<MemoTheme>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close places',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondary) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _ThemeGridBody(
          current: current,
          isLocked: isLocked,
        ),
      );
    },
  );
}

class _ThemeGridBody extends StatelessWidget {
  const _ThemeGridBody({
    required this.current,
    required this.isLocked,
  });

  final MemoTheme current;
  final bool Function(MemoTheme theme) isLocked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF12141A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '어디로 갈까요',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.6,
                        color: Color(0xFFF2EDE4),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.close_rounded,
                        color: Color(0xCCF2EDE4),
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '같은 자리에 잠시 앉아 보세요',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 13,
                  height: 1.35,
                  color: const Color(0xFFF2EDE4).withValues(alpha: 0.55),
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: themeGridEntries.length,
                  itemBuilder: (context, index) {
                    final entry = themeGridEntries[index];
                    return _ThemeTile(
                      entry: entry,
                      selected: entry.theme == current,
                      locked: isLocked(entry.theme),
                      onTap: () => Navigator.of(context).pop(entry.theme),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeTile extends StatefulWidget {
  const _ThemeTile({
    required this.entry,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final ThemeGridEntry entry;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  State<_ThemeTile> createState() => _ThemeTileState();
}

class _ThemeTileState extends State<_ThemeTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final dim = widget.locked ? 0.55 : 1.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: dim,
          duration: const Duration(milliseconds: 180),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: entry.placeholder),
                Image.asset(
                  entry.thumbAsset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 88,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x99000000),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(
                            alpha: widget.locked ? 0.75 : 0.95,
                          ),
                          shadows: const [
                            Shadow(
                              color: Color(0x66000000),
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ],
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.line,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.72),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.selected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.locked)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Text(
                      'Plus',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 11,
                        letterSpacing: 0.8,
                        color: Colors.white.withValues(alpha: 0.7),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
