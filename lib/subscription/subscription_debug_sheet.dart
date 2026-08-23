import 'package:flutter/material.dart';

import 'subscription_config.dart';
import 'subscription_service.dart';

/// Temporary — remove once subscription UI is real.
Future<void> showSubscriptionDebugSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1C1C1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _SubscriptionDebugSheet(),
  );
}

class _SubscriptionDebugSheet extends StatefulWidget {
  const _SubscriptionDebugSheet();

  @override
  State<_SubscriptionDebugSheet> createState() =>
      _SubscriptionDebugSheetState();
}

class _SubscriptionDebugSheetState extends State<_SubscriptionDebugSheet> {
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sub,
      builder: (context, _) {
        final pkg = _sub.defaultPackage;
        final product = pkg?.storeProduct ??
            (_sub.directProducts.isNotEmpty ? _sub.directProducts.first : null);
        final price = product?.priceString;
        final productId = product?.identifier;

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '구독 테스트 (임시)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _row('SDK', _sub.isConfigured ? '연결됨' : '미연결'),
                  _row('Entitlement', SubscriptionConfig.entitlementId),
                  _row(
                    '구독 상태',
                    _sub.isSubscribed
                        ? '활성 (Parallel Pro)'
                        : _sub.isInTrial
                            ? '체험 중 (${_sub.trialDaysLeft}일+)'
                            : _sub.trialEnded
                                ? '체험 종료'
                                : '없음',
                  ),
                  _row(
                    'Plus 접근',
                    _sub.hasPlusAccess ? '열림' : '잠김',
                  ),
                  _row('상품', productId ?? '(패키지 없음)'),
                  _row('가격', price ?? '-'),
                  const SizedBox(height: 8),
                  Text(
                    _sub.debugStatus,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  if (_sub.lastOfferingsNote != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _sub.lastOfferingsNote!,
                      style: const TextStyle(
                        color: Color(0xFFFFB74D),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await _sub.debugEndTrial();
                            if (!mounted) return;
                            setState(() => _message = '체험 종료 처리됨');
                          },
                    child: const Text('디버그: 체험 종료'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await _sub.debugRestartTrial();
                            if (!mounted) return;
                            setState(() => _message = '체험 다시 시작됨');
                          },
                    child: const Text('디버그: 체험 다시 시작'),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _message!,
                      style: TextStyle(
                        color: _message!.contains('반영') ||
                                _message!.contains('완료') ||
                                _message!.contains('있음')
                            ? const Color(0xFFA5D6A7)
                            : const Color(0xFFFF8A80),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || !_sub.isConfigured
                        ? null
                        : () => _run(_sub.purchaseDefaultPackage),
                    child: Text(
                      price == null ? '구독하기' : '구독하기 ($price)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy || !_sub.isConfigured
                        ? null
                        : () => _run(_sub.restorePurchases),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    child: const Text('구매 복원'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await _sub.refreshCustomerInfo();
                            await _sub.refreshOfferings();
                            if (!mounted) return;
                            setState(() {
                              _busy = false;
                              _message = '새로고침 완료\n${_sub.debugStatus}';
                            });
                          },
                    child: const Text(
                      '상태 새로고침',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
