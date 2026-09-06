import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../subscription/subscription_config.dart';
import '../subscription/subscription_debug_sheet.dart';
import '../subscription/subscription_service.dart';

/// Soft settings panel — sound, Plus, welcome, contact.
Future<void> showSettingsSheet(
  BuildContext context, {
  required VoidCallback onNatureVolume,
  required VoidCallback onReplayWelcome,
}) {
  final hostContext = context;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1E22),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => _SettingsSheet(
      hostContext: hostContext,
      onNatureVolume: onNatureVolume,
      onReplayWelcome: onReplayWelcome,
    ),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.hostContext,
    required this.onNatureVolume,
    required this.onReplayWelcome,
  });

  final BuildContext hostContext;
  final VoidCallback onNatureVolume;
  final VoidCallback onReplayWelcome;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _busy = false;
  String? _message;

  SubscriptionService get _sub => SubscriptionService.instance;

  Future<void> _run(Future<PurchaseAttempt> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.message;
    });
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(
      const ClipboardData(text: 'parallel@gmail.com'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('메일 주소를 복사했어요'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sub,
      builder: (context, _) {
        final product = _sub.defaultPackage?.storeProduct ??
            (_sub.directProducts.isNotEmpty ? _sub.directProducts.first : null);
        final price = product?.priceString;
        final status = _sub.isSubscribed
            ? 'Parallel Plus 이용 중'
            : _sub.isInTrial
                ? '체험 중 · ${_sub.trialDaysLeft}일+'
                : _sub.trialEnded
                    ? '체험이 끝났어요'
                    : '아직 구독하지 않았어요';

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '설정',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Georgia',
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _tile(
                    icon: Icons.graphic_eq_rounded,
                    title: '배경 소리',
                    subtitle: '이 장소의 환경음 크기',
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onNatureVolume();
                    },
                  ),
                  const SizedBox(height: 6),
                  _tile(
                    icon: Icons.auto_stories_outlined,
                    title: '안내 다시 보기',
                    subtitle: '처음처럼 살짝 안내해 드려요',
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onReplayWelcome();
                    },
                  ),
                  const SizedBox(height: 6),
                  _tile(
                    icon: Icons.mail_outline_rounded,
                    title: '문의',
                    subtitle: 'parallel@gmail.com · 탭하면 복사',
                    onTap: _copyEmail,
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Parallel Plus',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Georgia',
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontFamily: 'Georgia',
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    SubscriptionConfig.plusBenefitsLine,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontFamily: 'Georgia',
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (price != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '월 $price',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontFamily: 'Georgia',
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: TextStyle(
                        color: _message!.contains('반영') ||
                                _message!.contains('완료') ||
                                _message!.contains('있')
                            ? const Color(0xFFA5D6A7)
                            : const Color(0xFFFF8A80),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (!_sub.isSubscribed) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _busy || !_sub.isConfigured
                          ? null
                          : () => _run(_sub.purchaseDefaultPackage),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.92),
                        foregroundColor: const Color(0xFF1A1E22),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        price == null ? '구독하기' : '구독하기 · $price',
                        style: const TextStyle(fontFamily: 'Georgia'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _busy || !_sub.isConfigured
                          ? null
                          : () => _run(_sub.restorePurchases),
                      child: Text(
                        '구매 복원',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ),
                  ],
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 20),
                    Divider(color: Colors.white.withValues(alpha: 0.12)),
                    const SizedBox(height: 8),
                    Text(
                      '개발',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _tile(
                      icon: Icons.bug_report_outlined,
                      title: '구독 테스트',
                      subtitle: SubscriptionConfig.entitlementId,
                      onTap: () {
                        Navigator.of(context).pop();
                        showSubscriptionDebugSheet(widget.hostContext);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.75)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Georgia',
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
