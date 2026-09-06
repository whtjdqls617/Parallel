import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../memo/memo.dart';
import '../memo/memo_board_layout.dart';
import '../memo/memo_place.dart';
import 'welcome_fairy.dart';
import 'welcome_host.dart';

/// Dimmed coach overlay — a desert fairy guides with actionable prompts.
class WelcomeOverlay extends StatefulWidget {
  const WelcomeOverlay({
    super.key,
    required this.host,
    required this.musicKey,
    this.settingsKey,
    this.placesKey,
  });

  final WelcomeHost host;
  final GlobalKey musicKey;
  final GlobalKey? settingsKey;
  final GlobalKey? placesKey;

  @override
  State<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<WelcomeOverlay>
    with TickerProviderStateMixin {
  Rect? _hole;
  late final AnimationController _pulse;
  late final AnimationController _appear;
  late final Animation<double> _appearCurve;
  WelcomeStep? _speechStep;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _appear = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _appearCurve = CurvedAnimation(
      parent: _appear,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    widget.host.addListener(_onHost);
    _syncFromHost(animateIn: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHole());
  }

  @override
  void didUpdateWidget(covariant WelcomeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.host != widget.host) {
      oldWidget.host.removeListener(_onHost);
      widget.host.addListener(_onHost);
      _syncFromHost(animateIn: true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHole());
  }

  @override
  void dispose() {
    widget.host.removeListener(_onHost);
    _pulse.dispose();
    _appear.dispose();
    super.dispose();
  }

  void _onHost() {
    if (!mounted) return;
    _syncFromHost(animateIn: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHole());
  }

  void _syncFromHost({required bool animateIn}) {
    final host = widget.host;
    final step = host.step;
    final hide = step == null || host.hideChrome;

    if (hide) {
      if (_appear.isDismissed) {
        if (step == null) host.onOverlayDismissed();
        return;
      }
      unawaited(_appear.reverse().then((_) {
        if (!mounted) return;
        final again = widget.host.step;
        if (again != null && !widget.host.hideChrome) {
          setState(() => _speechStep = again);
          _appear.forward();
          return;
        }
        setState(() {
          _speechStep = null;
          _hole = null;
        });
        if (again == null) {
          widget.host.onOverlayDismissed();
        }
      }));
      return;
    }

    setState(() => _speechStep = step);
    if (animateIn || _appear.isDismissed || _appear.status == AnimationStatus.reverse) {
      _appear.forward();
    } else {
      // Step change while visible — speech swaps via AnimatedSwitcher.
      setState(() {});
    }
  }

  void _measureHole() {
    if (!mounted) return;
    final step = widget.host.step;
    if (step == null || widget.host.hideChrome) return;
    final size = MediaQuery.sizeOf(context);
    Rect? next;
    switch (step) {
      case WelcomeStep.presence:
        final c = Offset(size.width * 0.26, size.height * 0.80);
        next = Rect.fromCenter(center: c, width: 120, height: 56);
      case WelcomeStep.board:
        next = MemoBoardLayout.frameRect(size, MemoTheme.desert).inflate(10);
      case WelcomeStep.music:
        next = _rectForKey(widget.musicKey)?.inflate(8);
      case WelcomeStep.nature:
        next = _rectForKey(widget.settingsKey ?? widget.musicKey)?.inflate(8);
      case WelcomeStep.places:
      case WelcomeStep.plus:
        next = _rectForKey(widget.placesKey ?? widget.musicKey)?.inflate(8);
      default:
        next = null;
    }
    if (next != _hole) {
      setState(() => _hole = next);
    }
  }

  Rect? _rectForKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final step = _speechStep ?? host.step;
    final hole = _hole;
    final showSpeech = step != null && !host.hideChrome;
    final card = showSpeech
        ? _cardFor(step, skippedEarly: host.skippedEarly)
        : null;
    final needsTap = step == WelcomeStep.board ||
        step == WelcomeStep.music ||
        step == WelcomeStep.nature ||
        step == WelcomeStep.places;
    final showEmpty = card == null ||
        (card.line.isEmpty && (card.actions == null || card.actions!.isEmpty));

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _appear,
        builder: (context, _) {
          final opacity = _appearCurve.value;
          final blocking = opacity > 0.02 && showSpeech && !showEmpty;
          return IgnorePointer(
            ignoring: opacity < 0.05,
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: Opacity(
                    opacity: opacity,
                    child: CustomPaint(
                      painter: _HoleDimPainter(hole: hole),
                      size: Size.infinite,
                    ),
                  ),
                ),
                if (blocking) _HoleBarrier(hole: needsTap ? hole : null),
                if (hole != null &&
                    opacity > 0.05 &&
                    (needsTap || step == WelcomeStep.plus))
                  Positioned.fromRect(
                    rect: hole.inflate(4),
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: opacity,
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) {
                            final t =
                                0.5 + 0.5 * math.sin(_pulse.value * math.pi * 2);
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFFF4E0).withValues(
                                    alpha: (0.25 + 0.35 * t) * opacity,
                                  ),
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD090).withValues(
                                      alpha: (0.12 + 0.14 * t) * opacity,
                                    ),
                                    blurRadius: 20 + 12 * t,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                Opacity(
                  opacity: opacity,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    reverseDuration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (current, previous) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          ...previous,
                          if (current != null) current,
                        ],
                      );
                    },
                    transitionBuilder: (child, anim) {
                      final fade = CurvedAnimation(
                        parent: anim,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      );
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(fade);
                      return FadeTransition(
                        opacity: fade,
                        child: SlideTransition(
                          position: slide,
                          child: child,
                        ),
                      );
                    },
                    child: showEmpty
                        ? const SizedBox.shrink(key: ValueKey('empty'))
                        : _FairySpeech(
                            key: ValueKey(
                              '${step}_${host.skippedEarly ? 'skip' : 'flow'}',
                            ),
                            card: card,
                            hole: hole,
                            pulse: _pulse,
                            onContinue: card.buttonLabel != null
                                ? host.advanceFromButton
                                : null,
                            onSkip: host.canSkip ? host.skip : null,
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeCardData {
  const _WelcomeCardData({
    required this.line,
    this.hint,
    this.buttonLabel,
    this.actions,
  });

  final String line;
  final String? hint;
  final String? buttonLabel;
  /// Short actionable bullets the guest can try.
  final List<String>? actions;
}

_WelcomeCardData _cardFor(
  WelcomeStep step, {
  bool skippedEarly = false,
}) =>
    switch (step) {
      WelcomeStep.greet => const _WelcomeCardData(
          line: '오시느라 고생 많으셨어요.',
          hint: '여기서 잠깐만 쉬다 가셔도 돼요.',
          buttonLabel: '좋아요',
        ),
      WelcomeStep.presence => const _WelcomeCardData(
          line: '모래에 숫자랑 반짝이는 거, 보이세요?',
          hint: '이 공간에 머무는 온기예요. 혼자만은 아니에요.',
          buttonLabel: '네',
        ),
      WelcomeStep.board => _WelcomeCardData(
          line: '저쪽에 ${MemoPlace.name}가 있어요.',
          hint: '한번 열어 보실래요? 누가 쓴 건진 몰라도요.',
        ),
      WelcomeStep.read || WelcomeStep.compose => const _WelcomeCardData(
          line: '',
        ),
      WelcomeStep.traces => const _WelcomeCardData(
          line: '짧은 말이나 노래를 남겨도 되고요.',
          hint: '하루면 사라져요. 안 남겨도 괜찮아요.',
          buttonLabel: '알겠어요',
        ),
      WelcomeStep.music => const _WelcomeCardData(
          line: '위에 있는 버튼, 한번 눌러 보실래요?',
          hint: '이 테마에 맞춰 둔 음악이에요.',
        ),
      WelcomeStep.nature => const _WelcomeCardData(
          line: '왼쪽 위 설정에도 들러 보세요.',
          hint: '배경 소리 크기를 여기서 맞출 수 있어요.',
        ),
      WelcomeStep.ownMusic => const _WelcomeCardData(
          line: '음악이 취향이 아니셔도 괜찮아요.',
          hint: '다른 거 틀어 두시고, 그냥 여기 앉아 계셔도 돼요.',
          buttonLabel: '알겠어요',
        ),
      WelcomeStep.places => const _WelcomeCardData(
          line: '왼쪽 위에 지도가 있어요.',
          hint: '한번 열어 보실래요? 다른 장소로도 가실 수 있어요.\n처음은 사막에서 시작해요.',
        ),
      WelcomeStep.plus => const _WelcomeCardData(
          line: '일주일 동안은 다 열어둘게요.',
          hint: '숲·바다·별·하늘·불도 천천히 둘러보세요.',
          actions: [
            '${MemoPlace.name}에 글이랑 노래를 남겨 보세요',
            '답장은 글마다 하나만 가능해요\n누군가에겐 스쳐 가는 말이 힘이 될 수도 있어요',
            '이런 곳이 있으면 좋겠다 싶은 게 있으시면,\nparallel@gmail.com 으로 편하게 적어 주세요',
          ],
          buttonLabel: '알겠어요',
        ),
      WelcomeStep.farewell => _WelcomeCardData(
          line: skippedEarly
              ? '알겠어요. 편히 쉬고 계세요.'
              : '그럼 편히 쉬고 계세요.',
          hint: skippedEarly
              ? '다시 보고 싶으시면, 왼쪽 위 설정에서 안내 다시 보기를 눌러 주세요.'
              : '여기서의 시간이 조금이라도 도움이 되었으면 좋겠어요.\n\n다시 보고 싶으시면, 왼쪽 위 설정에서 안내 다시 보기를 눌러 주세요.',
          buttonLabel: '감사해요',
        ),
    };

class _HoleBarrier extends SingleChildRenderObjectWidget {
  const _HoleBarrier({required this.hole})
      : super(child: const SizedBox.expand());

  final Rect? hole;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHoleBarrier(hole: hole);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderHoleBarrier renderObject,
  ) {
    renderObject.hole = hole;
  }
}

class _RenderHoleBarrier extends RenderProxyBox {
  _RenderHoleBarrier({Rect? hole}) : _hole = hole;

  Rect? _hole;
  set hole(Rect? value) {
    if (_hole == value) return;
    _hole = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final h = _hole;
    if (h != null && h.inflate(4).contains(position)) {
      return false;
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}

class _HoleDimPainter extends CustomPainter {
  _HoleDimPainter({required this.hole});

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = const Color(0x7A1A1210);
    final full = Path()..addRect(Offset.zero & size);
    if (hole == null) {
      canvas.drawPath(full, dim);
      return;
    }
    final r = RRect.fromRectAndRadius(hole!, const Radius.circular(16));
    final cut = Path()..addRRect(r);
    final overlay = Path.combine(PathOperation.difference, full, cut);
    canvas.drawPath(overlay, dim);
  }

  @override
  bool shouldRepaint(covariant _HoleDimPainter oldDelegate) =>
      oldDelegate.hole != hole;
}

class _FairySpeech extends StatelessWidget {
  const _FairySpeech({
    super.key,
    required this.card,
    required this.hole,
    required this.pulse,
    this.onContinue,
    this.onSkip,
  });

  final _WelcomeCardData card;
  final Rect? hole;
  final Animation<double> pulse;
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    if (card.line.isEmpty && card.actions == null) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);

    Alignment align = Alignment.center;
    EdgeInsets margin =
        EdgeInsets.fromLTRB(28, pad.top + 48, 28, pad.bottom + 48);

    if (hole != null) {
      final holeCenterY = hole!.center.dy;
      if (holeCenterY > size.height * 0.55) {
        align = Alignment.topCenter;
        margin = EdgeInsets.fromLTRB(28, pad.top + 36, 28, 0);
      } else if (holeCenterY < size.height * 0.38) {
        align = Alignment.center;
        margin = EdgeInsets.fromLTRB(
          28,
          math.max(hole!.bottom + 24, size.height * 0.32),
          28,
          pad.bottom + 44,
        );
      }
    }

    return Align(
      alignment: align,
      child: Padding(
        padding: margin,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 310),
          child: AnimatedBuilder(
            animation: pulse,
            builder: (context, _) {
              final t = pulse.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WelcomeFairy(t: t, size: 26),
                  const SizedBox(height: 4),
                  _SpeechBubble(
                    card: card,
                    onContinue: onContinue,
                    onSkip: onSkip,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.card,
    this.onContinue,
    this.onSkip,
  });

  final _WelcomeCardData card;
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFAF2),
            Color(0xFFF5E6D0),
          ],
        ),
        border: Border.all(
          color: const Color(0x66E8C898),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A3A20).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFFFFD090).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            card.line,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 17,
              height: 1.4,
              letterSpacing: 0.2,
              color: Color(0xFF4A3018),
              decoration: TextDecoration.none,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (card.hint != null) ...[
            const SizedBox(height: 8),
            Text(
              card.hint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 13,
                height: 1.35,
                color: const Color(0xFF4A3018).withValues(alpha: 0.55),
                decoration: TextDecoration.none,
              ),
            ),
          ],
          if (card.actions != null) ...[
            const SizedBox(height: 14),
            for (final a in card.actions!) ...[
              _ActionLine(text: a),
              const SizedBox(height: 8),
            ],
          ],
          if (onContinue != null) ...[
            const SizedBox(height: 8),
            Center(
              child: _PressablePill(
                label: card.buttonLabel!,
                onTap: onContinue!,
              ),
            ),
          ],
          if (onSkip != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onSkip,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 2, 2),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 12,
                      height: 1.2,
                      color: const Color(0xFF4A3018).withValues(alpha: 0.38),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PressablePill extends StatefulWidget {
  const _PressablePill({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<_PressablePill> createState() => _PressablePillState();
}

class _PressablePillState extends State<_PressablePill> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _pressed
                ? const Color(0xFFE0B070)
                : const Color(0xFFE8C090),
            border: Border.all(
              color: const Color(0xFFD0A070).withValues(alpha: 0.55),
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: const Color(0xFF5A3A20).withValues(alpha: 0.12),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF5A3A20).withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 14,
              letterSpacing: 1.2,
              color: Color(0xFF4A3018),
              decoration: TextDecoration.none,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionLine extends StatelessWidget {
  const _ActionLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD090).withValues(alpha: 0.95),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD090).withValues(alpha: 0.55),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 13,
              height: 1.35,
              color: Color(0xFF5A3A20),
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}
