import 'package:flutter/material.dart';

import 'subscription_config.dart';
import 'subscription_service.dart';

/// Soft gate when a Parallel Plus feature is tapped.
/// Visual language matches [showSettingsSheet].
Future<void> showSubscriptionGate(
  BuildContext context, {
  required String reason,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1E22),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => _SubscriptionGateSheet(reason: reason),
  );
}

/// Prefixes trial-ended softener when the free week is over.
String subscriptionGateReason(String body) {
  if (SubscriptionService.instance.trialEnded) {
    return '체험이 끝났어요. $body';
  }
  return body;
}

class _SubscriptionGateSheet extends StatefulWidget {
  const _SubscriptionGateSheet({required this.reason});

  final String reason;

  @override
  State<_SubscriptionGateSheet> createState() => _SubscriptionGateSheetState();
}

class _SubscriptionGateSheetState extends State<_SubscriptionGateSheet> {
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
    if (result.ok && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sub,
      builder: (context, _) {
        final product = _sub.defaultPackage?.storeProduct ??
            (_sub.directProducts.isNotEmpty ? _sub.directProducts.first : null);
        final price = product?.priceString;

        return SafeArea(
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
                  'Parallel Plus',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.reason,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontFamily: 'Georgia',
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 18),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
