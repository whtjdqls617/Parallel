import 'package:flutter/material.dart';

import 'subscription_service.dart';

/// Soft gate when a Parallel Plus feature is tapped.
Future<void> showSubscriptionGate(
  BuildContext context, {
  required String reason,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _SubscriptionGateSheet(reason: reason),
  );
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

  Future<void> _purchase() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await _sub.purchaseDefaultPackage();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.message;
    });
    if (result.ok && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await _sub.restorePurchases();
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
    final price = _sub.defaultPackage?.storeProduct.priceString ??
        (_sub.directProducts.isNotEmpty
            ? _sub.directProducts.first.priceString
            : null);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Parallel Plus',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.reason,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Georgia',
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '숲 · 바다 · 흔적 남기기',
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'Georgia',
                fontSize: 13,
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  color: _message!.contains('반영') || _message!.contains('완료')
                      ? const Color(0xFFA5D6A7)
                      : const Color(0xFFFF8A80),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy || !_sub.isConfigured ? null : _purchase,
              child: Text(price == null ? '구독하기' : '구독하기 ($price)'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy || !_sub.isConfigured ? null : _restore,
              child: const Text(
                '구매 복원',
                style: TextStyle(color: Colors.white70),
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
  }
}
