import 'package:flutter/material.dart';

import 'welcome_fairy.dart';
import 'welcome_host.dart';

/// Soft tip drawn inside memo dialogs — fairy voice, actionable.
class WelcomePanelTip extends StatefulWidget {
  const WelcomePanelTip({
    super.key,
    required this.host,
    required this.hasMemos,
  });

  final WelcomeHost host;
  final bool hasMemos;

  @override
  State<WelcomePanelTip> createState() => _WelcomePanelTipState();
}

class _WelcomePanelTipState extends State<WelcomePanelTip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.host.step;
    final visible =
        step == WelcomeStep.read || step == WelcomeStep.compose;

    final (line, action) = switch (step) {
      WelcomeStep.read when !widget.hasMemos => (
          '아직은 비어 있네요. 나중에 채워져도 돼요.',
          '다음',
        ),
      WelcomeStep.read => (
          '쪽지 하나 눌러서 읽어 보실래요?',
          null,
        ),
      WelcomeStep.compose => (
          '아래 연필을 누르면, 글이나 노래를 남길 수도 있어요.',
          '다음',
        ),
      _ => ('', null),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 340),
        reverseDuration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          );
        },
        child: !visible || line.isEmpty
            ? const SizedBox.shrink(key: ValueKey('tip-empty'))
            : Padding(
                key: ValueKey('$step-$line'),
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
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
                            color:
                                const Color(0xFF5A3A20).withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                WelcomeFairy(t: _pulse.value, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: const TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 13,
                                      height: 1.35,
                                      color: Color(0xFF4A3018),
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                                if (action != null) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      // Compose tip: close the board → traces.
                                      if (widget.host.step ==
                                          WelcomeStep.compose) {
                                        Navigator.of(context).maybePop();
                                        return;
                                      }
                                      widget.host.advanceFromButton();
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Text(
                                      action,
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 13,
                                        letterSpacing: 0.8,
                                        color: const Color(0xFF8A4A28)
                                            .withValues(alpha: 0.9),
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (widget.host.canSkip) ...[
                              const SizedBox(height: 2),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: widget.host.skip,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      4,
                                      2,
                                      2,
                                    ),
                                    child: Text(
                                      'Skip',
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 11,
                                        color: const Color(0xFF4A3018)
                                            .withValues(alpha: 0.38),
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// Tip on the letter — fairy nudge.
class WelcomeReaderTip extends StatefulWidget {
  const WelcomeReaderTip({super.key});

  @override
  State<WelcomeReaderTip> createState() => _WelcomeReaderTipState();
}

class _WelcomeReaderTipState extends State<WelcomeReaderTip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WelcomeFairy(t: _pulse.value, size: 11),
              const SizedBox(width: 6),
              Text(
                '답장은 하나만요. 모르는 이의 짧은 말이 힘이 될 때도 있어요.',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 12,
                  letterSpacing: 0.2,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.62),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
