import 'package:flutter/material.dart';

import 'memo.dart';

/// Quiet reply sticky — text + optional song, one per person per memo.
Future<MemoDraft?> showMemoReplySheet(
  BuildContext context, {
  required MemoTheme theme,
  MemoDraft? initial,
  String title = '작은 답장 남기기',
  String actionLabel = '붙이기',
}) {
  return showModalBottomSheet<MemoDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MemoReplyBody(
      theme: theme,
      initial: initial,
      title: title,
      actionLabel: actionLabel,
    ),
  );
}

class _MemoReplyBody extends StatefulWidget {
  const _MemoReplyBody({
    required this.theme,
    this.initial,
    required this.title,
    required this.actionLabel,
  });

  final MemoTheme theme;
  final MemoDraft? initial;
  final String title;
  final String actionLabel;

  @override
  State<_MemoReplyBody> createState() => _MemoReplyBodyState();
}

class _MemoReplyBodyState extends State<_MemoReplyBody> {
  late final TextEditingController _text;
  late final TextEditingController _artist;
  late final TextEditingController _song;
  final _focus = FocusNode();

  static const _fieldPadding = EdgeInsets.fromLTRB(4, 8, 4, 4);

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _text = TextEditingController(text: initial?.text ?? '');
    _artist = TextEditingController(text: initial?.artist ?? '');
    _song = TextEditingController(text: initial?.song ?? '');
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
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final surface = switch (widget.theme) {
      MemoTheme.forest => const Color(0xFF1A2820),
      MemoTheme.ocean => const Color(0xFF1A2830),
      MemoTheme.space => const Color(0xFF12182A),
      MemoTheme.desert => const Color(0xFFE8C898),
    };
    final ink = switch (widget.theme) {
      MemoTheme.forest => const Color(0xFFE8DCC8),
      MemoTheme.ocean => const Color(0xFFD8E4E8),
      MemoTheme.space => const Color(0xFFD8DCE8),
      MemoTheme.desert => const Color(0xFF4A3018),
    };
    final hint = ink.withValues(alpha: 0.4);
    final cool = widget.theme.isCool;

    final fieldStyle = TextStyle(
      fontFamily: 'Georgia',
      fontSize: 17,
      height: 1.45,
      color: ink,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 13,
                      letterSpacing: 1.4,
                      color: ink.withValues(alpha: 0.55),
                    ),
                  ),
                  if (widget.initial == null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '이 흔적에 한 번만 붙을 수 있어요',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 12,
                        color: ink.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _text,
                    focusNode: _focus,
                    maxLength: Memo.maxReplyLength,
                    maxLines: 4,
                    minLines: 3,
                    style: fieldStyle,
                    cursorColor: ink,
                    decoration: _decoration(
                      hint: '남기고 싶은 말을 적어요',
                      hintColor: hint,
                    ),
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.newline,
                  ),
                  TextField(
                    controller: _song,
                    maxLength: Memo.maxSongLength,
                    maxLines: 1,
                    style: fieldStyle,
                    cursorColor: ink,
                    decoration: _decoration(
                      hint: '제목… (선택)',
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
                      hint: '아티스트… (선택)',
                      hintColor: hint,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _text.text.trim().isEmpty ? null : _submit,
                      style: TextButton.styleFrom(
                        foregroundColor: cool
                            ? const Color(0xFFE0ECF0)
                            : const Color(0xFF4A3018),
                        disabledForegroundColor: ink.withValues(alpha: 0.25),
                      ),
                      child: Text(
                        widget.actionLabel,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 15,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
