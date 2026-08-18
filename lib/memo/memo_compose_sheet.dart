import 'package:flutter/material.dart';

import 'memo.dart';

/// Quiet compose sheet — note + artist + song title.
Future<MemoDraft?> showMemoComposeSheet(
  BuildContext context, {
  required MemoTheme theme,
}) {
  return showModalBottomSheet<MemoDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _MemoComposeBody(theme: theme);
    },
  );
}

class _MemoComposeBody extends StatefulWidget {
  const _MemoComposeBody({required this.theme});

  final MemoTheme theme;

  @override
  State<_MemoComposeBody> createState() => _MemoComposeBodyState();
}

class _MemoComposeBodyState extends State<_MemoComposeBody> {
  final _text = TextEditingController();
  final _artist = TextEditingController();
  final _song = TextEditingController();
  final _focus = FocusNode();

  static const _fieldPadding = EdgeInsets.fromLTRB(4, 8, 4, 4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _artist.dispose();
    _song.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(
      MemoDraft(
        text: text,
        artist: _artist.text.trim(),
        song: _song.text.trim(),
      ),
    );
  }

  InputDecoration _decoration({
    required String hint,
    required Color hintColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 16,
        color: hintColor,
      ),
      counterStyle: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 11,
        color: hintColor,
      ),
      border: InputBorder.none,
      isDense: true,
      contentPadding: _fieldPadding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = switch (widget.theme) {
      MemoTheme.forest => const Color(0xFF1A2820),
      MemoTheme.ocean => const Color(0xFF1A2830),
      MemoTheme.desert => const Color(0xFFE8C898),
    };
    final ink = switch (widget.theme) {
      MemoTheme.forest => const Color(0xFFE8DCC8),
      MemoTheme.ocean => const Color(0xFFD8E4E8),
      MemoTheme.desert => const Color(0xFF4A3018),
    };
    final hint = ink.withValues(alpha: 0.4);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    final fieldStyle = TextStyle(
      fontFamily: 'Georgia',
      fontSize: 17,
      height: 1.4,
      color: ink,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close, color: ink.withValues(alpha: 0.55), size: 22),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
                TextField(
                  controller: _text,
                  focusNode: _focus,
                  maxLength: Memo.maxTextLength,
                  maxLines: 3,
                  minLines: 3,
                  style: fieldStyle,
                  cursorColor: ink,
                  decoration: _decoration(
                    hint: '남기고 싶은 한 줄…',
                    hintColor: hint,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _song,
                  maxLength: Memo.maxSongLength,
                  maxLines: 1,
                  style: fieldStyle,
                  cursorColor: ink,
                  decoration: _decoration(
                    hint: '제목…',
                    hintColor: hint,
                  ),
                ),
                TextField(
                  controller: _artist,
                  maxLength: Memo.maxArtistLength,
                  maxLines: 1,
                  style: fieldStyle,
                  cursorColor: ink,
                  decoration: _decoration(
                    hint: '아티스트…',
                    hintColor: hint,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: switch (widget.theme) {
                        MemoTheme.forest => const Color(0xFF3A4A38),
                        MemoTheme.ocean => const Color(0xFF3A5460),
                        MemoTheme.desert => const Color(0xFF8A5A30),
                      },
                      foregroundColor: switch (widget.theme) {
                        MemoTheme.forest => const Color(0xFFE8DCC8),
                        MemoTheme.ocean => const Color(0xFFE0ECF0),
                        MemoTheme.desert => const Color(0xFFF3E6C8),
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 14,
                        letterSpacing: 1.1,
                      ),
                    ),
                    child: const Text('흔적 남기기'),
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
