import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../subscription/subscription_gate.dart';
import '../subscription/subscription_service.dart';
import '../welcome/welcome_host.dart';
import '../welcome/welcome_panel_tip.dart';
import 'memo.dart';
import 'memo_reply_place_sheet.dart';
import 'memo_reply_sheet.dart';
import 'memo_service.dart';
import 'memo_sticky_layout.dart';

/// Center overlay — torn scrap of letter paper, stuck on (theme-flavored).
Future<Memo?> showMemoReader(
  BuildContext context, {
  required Memo memo,
  required MemoTheme theme,
  MemoService? service,
  WelcomeHost? welcome,
}) {
  return showGeneralDialog<Memo>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close memo',
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondary) {
      return SafeArea(
        child: Center(
          child: _MemoReaderLetter(
            memo: memo,
            theme: theme,
            service: service ?? MemoService(),
            welcome: welcome,
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondary, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      final scale = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(scale),
          child: child,
        ),
      );
    },
  );
}

class _MemoReaderLetter extends StatefulWidget {
  const _MemoReaderLetter({
    required this.memo,
    required this.theme,
    required this.service,
    this.welcome,
  });

  final Memo memo;
  final MemoTheme theme;
  final MemoService service;
  final WelcomeHost? welcome;

  @override
  State<_MemoReaderLetter> createState() => _MemoReaderLetterState();
}

class _MemoReaderLetterState extends State<_MemoReaderLetter> {
  late Memo _memo;
  bool _submitting = false;
  bool _hideReplies = false;

  @override
  void initState() {
    super.initState();
    _memo = widget.memo;
  }

  bool get _canReply =>
      !_memo.hasReplyFrom(widget.service.currentUid) && !_submitting;

  Future<void> _reply() async {
    if (!_canReply) return;
    if (!SubscriptionService.instance.hasPlusAccess) {
      await showSubscriptionGate(
        context,
        reason: SubscriptionService.instance.trialEnded
            ? '체험이 끝났어요. 답장을 남기려면 Parallel Plus가 필요해요.'
            : '답장을 남기려면 Parallel Plus가 필요해요.',
      );
      return;
    }

    final draft = await showMemoReplySheet(context, theme: widget.theme);
    if (draft == null || draft.text.trim().isEmpty || !mounted) return;

    final place = await showMemoReplyPlaceSheet(
      context,
      memo: _memo,
      draft: draft,
      theme: widget.theme,
    );
    if (place == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      final updated = await widget.service.addReply(
        memoId: _memo.id,
        text: draft.text,
        artist: draft.artist,
        song: draft.song,
        x: place.dx,
        y: place.dy,
      );
      if (!mounted) return;
      setState(() {
        _memo = updated;
        _hideReplies = false;
      });
    } catch (e, st) {
      debugPrint('Memo reply failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('답장을 남기지 못했어요'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openReply(MemoReply reply) async {
    final mine = reply.uid == widget.service.currentUid;
    final seed = (reply.text.hashCode ^ reply.uid.hashCode).abs();
    final rng = math.Random(seed);
    final tilt = -0.04 + rng.nextDouble() * 0.08;
    final size = MediaQuery.sizeOf(context);
    final side = math.min(size.width * 0.72, size.height * 0.48);

    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close reply',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondary) {
        return SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: tilt,
                  child: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: CustomPaint(
                        painter: _ReplyPostItPainter(
                          paper: Color(reply.stickyColorValue),
                          seed: seed,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    reply.text,
                                    style: const TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 20,
                                      height: 1.45,
                                      color: Color(0xFF3A3428),
                                    ),
                                  ),
                                ),
                              ),
                              if (reply.hasSong) ...[
                                const SizedBox(height: 12),
                                Text(
                                  '♪  ${reply.songLabel}',
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 15,
                                    height: 1.35,
                                    color: const Color(0xFF3A3428)
                                        .withValues(alpha: 0.78),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (mine) ...[
                  const SizedBox(height: 20),
                  _ReplyOwnerActions(
                    theme: widget.theme,
                    onEdit: () => Navigator.of(context).pop('edit'),
                    onDelete: () => Navigator.of(context).pop('delete'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondary, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );
        final scale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(scale),
            child: child,
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _editReply(reply);
    } else if (action == 'delete') {
      await _deleteReply(reply);
    }
  }

  Future<void> _editReply(MemoReply reply) async {
    final draft = await showMemoReplySheet(
      context,
      theme: widget.theme,
      initial: MemoDraft(
        text: reply.text,
        artist: reply.artist,
        song: reply.song,
      ),
      title: '답장 수정',
      actionLabel: '저장',
    );
    if (draft == null || draft.text.trim().isEmpty || !mounted) return;

    final place = await showMemoReplyPlaceSheet(
      context,
      memo: _memo,
      draft: draft,
      theme: widget.theme,
      initial: reply.hasAnchor ? Offset(reply.x!, reply.y!) : null,
      hideUid: reply.uid,
    );
    if (place == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      final updated = await widget.service.updateReply(
        memoId: _memo.id,
        text: draft.text,
        artist: draft.artist,
        song: draft.song,
        x: place.dx,
        y: place.dy,
      );
      if (!mounted) return;
      setState(() {
        _memo = updated;
        _hideReplies = false;
      });
    } catch (e, st) {
      debugPrint('Memo reply edit failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('답장을 수정하지 못했어요'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteReply(MemoReply reply) async {
    final ok = await _confirmDeleteReply(context, theme: widget.theme);
    if (ok != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final updated = await widget.service.removeReply(memoId: _memo.id);
      if (!mounted) return;
      setState(() => _memo = updated);
    } catch (e, st) {
      debugPrint('Memo reply delete failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('답장을 지우지 못했어요'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isForest = theme == MemoTheme.forest;
    final isOcean = theme == MemoTheme.ocean;
    final isSpace = theme == MemoTheme.space;
    final isMine = _memo.isOwnedBy(widget.service.currentUid);
    final paper = isMine
        ? (isSpace
            ? const Color(0xFFECE8F4)
            : isOcean
                ? const Color(0xFFF2EAD8)
                : isForest
                    ? const Color(0xFFF2EAC8)
                    : const Color(0xFFFFF4D8))
        : (isSpace
            ? const Color(0xFFDCE0EC)
            : isOcean
                ? const Color(0xFFE4ECF0)
                : isForest
                    ? const Color(0xFFE4E8D8)
                    : const Color(0xFFF8EBD4));
    final nest = isMine
        ? (isSpace
            ? const Color(0xFFF4F2FA)
            : isOcean
                ? const Color(0xFFF8F2E6)
                : isForest
                    ? const Color(0xFFF6F0DC)
                    : const Color(0xFFFFFAEC))
        : (isSpace
            ? const Color(0xFFE8ECF4)
            : isOcean
                ? const Color(0xFFEEF4F6)
                : isForest
                    ? const Color(0xFFEEF2E4)
                    : const Color(0xFFFFF6E6));
    final songNest = isSpace
        ? const Color(0xFFC8D0E4)
        : isOcean
            ? const Color(0xFFD4E0E6)
            : isForest
                ? const Color(0xFFDCE4D0)
                : const Color(0xFFF2E0C0);
    final ink = isSpace
        ? const Color(0xFF1C2438)
        : isOcean
            ? const Color(0xFF1C3038)
            : isForest
                ? const Color(0xFF243428)
                : const Color(0xFF5A3A20);
    final tilt = isSpace
        ? -0.008
        : isOcean
            ? -0.01
            : isForest
                ? 0.014
                : -0.022;
    final size = MediaQuery.sizeOf(context);
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.welcome?.step == WelcomeStep.read)
            const WelcomeReaderTip(),
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: size.width * 0.72,
              maxWidth: size.width * 0.86,
              minHeight: size.height * 0.52,
              maxHeight: size.height * 0.78,
            ),
            child: AspectRatio(
          aspectRatio: 0.68,
          child: Transform.rotate(
            angle: tilt,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: _TornPaper(
                    theme: theme,
                    paper: paper,
                    seed: isSpace ? 27 : isOcean ? 23 : isForest ? 19 : 11,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 22, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, right: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '누군가의 마음',
                                    style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 12,
                                      letterSpacing: 2.2,
                                      color: ink.withValues(alpha: 0.42),
                                    ),
                                  ),
                                ),
                                if (_memo.hasReply)
                                  TextButton(
                                    onPressed: () => setState(
                                      () => _hideReplies = !_hideReplies,
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          ink.withValues(alpha: 0.55),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      _hideReplies ? '답장 보기' : '답장 가리기',
                                      style: const TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 12,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(_memo),
                                  icon: Icon(
                                    Icons.close,
                                    color: ink.withValues(alpha: 0.5),
                                    size: 22,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            flex: _memo.hasSong ? 3 : 5,
                            child: _TornNest(
                              theme: theme,
                              color: nest,
                              seed: isSpace ? 33 : isOcean ? 31 : isForest ? 29 : 21,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(22, 20, 22, 20),
                                child: SingleChildScrollView(
                                  child: Text(
                                    _memo.text,
                                    style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 20,
                                      height: 1.6,
                                      fontWeight: FontWeight.w400,
                                      color: ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_memo.hasSong) ...[
                            const SizedBox(height: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 56),
                              child: _TornNest(
                                theme: theme,
                                color: songNest,
                                seed: isSpace ? 47 : isOcean ? 43 : isForest ? 41 : 37,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(22, 16, 22, 16),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '♪  ${_memo.songLabel}',
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 16,
                                        height: 1.4,
                                        color: ink.withValues(alpha: 0.88),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_canReply) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _submitting ? null : _reply,
                                style: TextButton.styleFrom(
                                  foregroundColor: ink.withValues(alpha: 0.7),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                child: Text(
                                  _submitting ? '붙이는 중…' : '작은 답장 남기기',
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 13,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (_memo.hasReply && !_hideReplies)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final replies = _memo.replies;
                        final shown = replies.length > 5
                            ? replies.sublist(replies.length - 5)
                            : replies;
                        const maxTilt = 0.10;
                        final base = math.min(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ) *
                            (_memo.hasSong ? 0.22 : 0.27);
                        final sticky =
                            MemoStickyPlacer.sized(base, shown.length);
                        final positions = MemoStickyPlacer.layoutReplies(
                          bounds: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          size: base,
                          replies: shown,
                          seed: _memo.id.hashCode,
                          lowerBand: !_memo.hasSong,
                          avoid: [
                            Rect.fromLTRB(
                              0.06,
                              0.08,
                              0.62,
                              _memo.hasSong ? 0.50 : 0.58,
                            ),
                            if (_memo.hasSong)
                              const Rect.fromLTRB(0.04, 0.50, 0.62, 0.82),
                          ],
                        );
                        final stickies = <Widget>[];
                        for (var i = 0; i < shown.length; i++) {
                          final reply = shown[i];
                          final seed =
                              (reply.text.hashCode ^ reply.uid.hashCode).abs();
                          final rng = math.Random(seed);
                          final pos = positions[i];
                          stickies.add(
                            Positioned(
                              left: pos.dx,
                              top: pos.dy,
                              width: sticky,
                              height: sticky,
                              child: GestureDetector(
                                onTap: () => _openReply(reply),
                                behavior: HitTestBehavior.opaque,
                                child: Transform.rotate(
                                  angle:
                                      -maxTilt + rng.nextDouble() * maxTilt * 2,
                                  child: CustomPaint(
                                    painter: _ReplyPostItPainter(
                                      paper: Color(reply.stickyColorValue),
                                      seed: seed,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        9,
                                        12,
                                        9,
                                        9,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              reply.text,
                                              maxLines: reply.hasSong ? 3 : 5,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontFamily: 'Georgia',
                                                fontSize: 12,
                                                height: 1.35,
                                                color: Color(0xFF3A3428),
                                              ),
                                            ),
                                          ),
                                          if (reply.hasSong)
                                            Text(
                                              '♪ ${reply.songLabel}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'Georgia',
                                                fontSize: 10,
                                                height: 1.2,
                                                color: const Color(0xFF3A3428)
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return Stack(children: stickies);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
          ),
        ],
      ),
    );
  }
}

Future<bool?> _confirmDeleteReply(
  BuildContext context, {
  required MemoTheme theme,
}) {
  final cool = theme.isCool;
  final surface = switch (theme) {
    MemoTheme.forest => const Color(0xFF1A2820),
    MemoTheme.ocean => const Color(0xFF1A2830),
    MemoTheme.space => const Color(0xFF12182A),
    MemoTheme.desert => const Color(0xFFE8C898),
  };
  final ink = switch (theme) {
    MemoTheme.forest => const Color(0xFFE8DCC8),
    MemoTheme.ocean => const Color(0xFFD8E4E8),
    MemoTheme.space => const Color(0xFFD8DCE8),
    MemoTheme.desert => const Color(0xFF4A3018),
  };
  final accent = switch (theme) {
    MemoTheme.forest => const Color(0xFF3A4A38),
    MemoTheme.ocean => const Color(0xFF3A5460),
    MemoTheme.space => const Color(0xFF3A4860),
    MemoTheme.desert => const Color(0xFF8A5A30),
  };
  final accentInk = cool
      ? const Color(0xFFE0ECF0)
      : const Color(0xFFF3E6C8);

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cancel delete',
    barrierColor: Colors.black.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondary) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Material(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '이 답장을 뗄까요?',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 18,
                          letterSpacing: 0.6,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '포스트잇만 조용히 사라져요.\n원하면 나중에 다시 붙일 수 있어요.',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 14,
                          height: 1.5,
                          color: ink.withValues(alpha: 0.62),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(false),
                              style: TextButton.styleFrom(
                                foregroundColor: ink.withValues(alpha: 0.55),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                '남겨두기',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 14,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: accentInk,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                '떼어내기',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 14,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondary, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      final scale = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(scale),
          child: child,
        ),
      );
    },
  );
}

class _ReplyOwnerActions extends StatelessWidget {
  const _ReplyOwnerActions({
    required this.theme,
    required this.onEdit,
    required this.onDelete,
  });

  final MemoTheme theme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cool = theme.isCool;
    final fill = cool
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFF3E6C8).withValues(alpha: 0.92);
    final ink = cool
        ? Colors.white.withValues(alpha: 0.88)
        : const Color(0xFF4A3018).withValues(alpha: 0.82);
    final mute = cool
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF4A3018).withValues(alpha: 0.5);
    final line = cool
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFF4A3018).withValues(alpha: 0.18);

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(22),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OwnerActionChip(
              label: '수정',
              color: ink,
              onTap: onEdit,
            ),
            Container(width: 1, height: 18, color: line),
            _OwnerActionChip(
              label: '삭제',
              color: mute,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerActionChip extends StatelessWidget {
  const _OwnerActionChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 14,
            letterSpacing: 1.4,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _TornNest extends StatelessWidget {
  const _TornNest({
    required this.theme,
    required this.color,
    required this.seed,
    required this.child,
  });

  final MemoTheme theme;
  final Color color;
  final int seed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _TornPaper(
      theme: theme,
      paper: color,
      seed: seed,
      recessed: true,
      child: child,
    );
  }
}

class _TornPaper extends StatelessWidget {
  const _TornPaper({
    required this.theme,
    required this.paper,
    required this.seed,
    required this.child,
    this.recessed = false,
  });

  final MemoTheme theme;
  final Color paper;
  final int seed;
  final Widget child;
  final bool recessed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TornSheetPainter(
        theme: theme,
        paper: paper,
        seed: seed,
        recessed: recessed,
      ),
      child: ClipPath(
        clipper: _TornClipper(
          theme: theme,
          seed: seed,
          recessed: recessed,
        ),
        child: child,
      ),
    );
  }
}

Path _buildTornPath(
  Size size, {
  required MemoTheme theme,
  required int seed,
  required bool recessed,
}) {
  final cool = theme.isCool;
  final rng = math.Random(seed);
  final w = size.width;
  final h = size.height;
  final path = Path();

  final inset = recessed ? 2.0 : 4.0;
  final tl = Offset(inset + rng.nextDouble() * 3, inset + rng.nextDouble() * 3);
  final tr = Offset(w - inset - rng.nextDouble() * 4, inset + rng.nextDouble() * 2);
  final br = Offset(w - inset - rng.nextDouble() * 3, h - inset - rng.nextDouble() * 4);
  final bl = Offset(inset + rng.nextDouble() * 2, h - inset - rng.nextDouble() * 3);

  void desertEdge(
    Offset from,
    Offset to, {
    required int steps,
    required Offset normal,
    required double amp,
  }) {
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final base = Offset.lerp(from, to, t)!;
      final n = (rng.nextDouble() - 0.28) * amp * 1.15;
      final side =
          Offset(-normal.dy, normal.dx) *
          (rng.nextDouble() - 0.5) *
          amp *
          0.3;
      path.lineTo(
        base.dx + normal.dx * n + side.dx,
        base.dy + normal.dy * n + side.dy,
      );
    }
  }

  void softEdge(
    Offset from,
    Offset to, {
    required int lobes,
    required Offset normal,
    required double amp,
  }) {
    for (var i = 1; i <= lobes; i++) {
      final t0 = (i - 1) / lobes;
      final t1 = i / lobes;
      final midT = (t0 + t1) * 0.5;
      final end = Offset.lerp(from, to, t1)!;
      final mid = Offset.lerp(from, to, midT)!;
      final bulge = (rng.nextDouble() * 0.7 + 0.35) *
          amp *
          (rng.nextBool() ? 1.0 : -0.55);
      final ctrl = Offset(
        mid.dx + normal.dx * bulge,
        mid.dy + normal.dy * bulge,
      );
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    }
  }

  final baseAmp = recessed
      ? (cool ? 3.2 : 2.3)
      : (cool ? 5.0 : 3.9);

  path.moveTo(tl.dx, tl.dy);
  if (cool) {
    softEdge(tl, tr, lobes: 5, normal: const Offset(0, -1), amp: baseAmp);
    softEdge(tr, br, lobes: 4, normal: const Offset(1, 0), amp: baseAmp * 0.85);
    softEdge(br, bl, lobes: 5, normal: const Offset(0, 1), amp: baseAmp);
    softEdge(bl, tl, lobes: 4, normal: const Offset(-1, 0), amp: baseAmp * 0.85);
  } else {
    desertEdge(tl, tr, steps: 10, normal: const Offset(0, -1), amp: baseAmp);
    desertEdge(tr, br, steps: 8, normal: const Offset(1, 0), amp: baseAmp * 0.9);
    desertEdge(br, bl, steps: 10, normal: const Offset(0, 1), amp: baseAmp);
    desertEdge(bl, tl, steps: 8, normal: const Offset(-1, 0), amp: baseAmp * 0.9);
  }
  path.close();
  return path;
}

class _TornClipper extends CustomClipper<Path> {
  _TornClipper({
    required this.theme,
    required this.seed,
    required this.recessed,
  });

  final MemoTheme theme;
  final int seed;
  final bool recessed;

  @override
  Path getClip(Size size) => _buildTornPath(
        size,
        theme: theme,
        seed: seed,
        recessed: recessed,
      );

  @override
  bool shouldReclip(covariant _TornClipper old) =>
      old.theme != theme || old.seed != seed || old.recessed != recessed;
}

class _TornSheetPainter extends CustomPainter {
  _TornSheetPainter({
    required this.theme,
    required this.paper,
    required this.seed,
    required this.recessed,
  });

  final MemoTheme theme;
  final Color paper;
  final int seed;
  final bool recessed;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildTornPath(
      size,
      theme: theme,
      seed: seed,
      recessed: recessed,
    );
    canvas.drawPath(
      path.shift(Offset(recessed ? 1 : 2, recessed ? 1.5 : 3)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawPath(path, Paint()..color = paper);

    final cool = theme.isCool;
    final rim = Paint()
      ..color = cool
          ? (theme == MemoTheme.space
              ? const Color(0x66587098)
              : theme == MemoTheme.ocean
                  ? const Color(0x66507080)
                  : const Color(0x665A6A50))
          : const Color(0x668A6030)
      ..style = PaintingStyle.stroke
      ..strokeWidth = recessed ? 0.8 : 1.1;
    canvas.drawPath(path, rim);
  }

  @override
  bool shouldRepaint(covariant _TornSheetPainter old) =>
      old.theme != theme ||
      old.paper != paper ||
      old.seed != seed ||
      old.recessed != recessed;
}

/// Everyday square sticky — yellow / pink reply note.
class _ReplyPostItPainter extends CustomPainter {
  _ReplyPostItPainter({required this.paper, required this.seed});

  final Color paper;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 3, size.height - 3),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(
      r.shift(Offset(1.5 + rng.nextDouble() * 0.3, 2.2)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRRect(r, Paint()..color = paper);
  }

  @override
  bool shouldRepaint(covariant _ReplyPostItPainter oldDelegate) =>
      oldDelegate.paper != paper || oldDelegate.seed != seed;
}
