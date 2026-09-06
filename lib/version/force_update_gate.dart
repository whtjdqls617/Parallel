import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'force_update_service.dart';

/// Wraps the app; blocks interaction when store major/minor is ahead.
class ForceUpdateHost extends StatefulWidget {
  const ForceUpdateHost({super.key, required this.child});

  final Widget child;

  @override
  State<ForceUpdateHost> createState() => _ForceUpdateHostState();
}

class _ForceUpdateHostState extends State<ForceUpdateHost>
    with WidgetsBindingObserver {
  ForceUpdateCheck? _check;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    if (_checking) return;
    _checking = true;
    try {
      final next = await ForceUpdateService.instance.check();
      if (!mounted) return;
      setState(() => _check = next);
    } finally {
      _checking = false;
    }
  }

  Future<void> _openStore() async {
    final url = _check?.storeUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final force = _check?.required == true;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (force)
          Positioned.fill(
            child: _ForceUpdateBarrier(
              clientLabel: _check!.clientLabel,
              requiredLabel: _check!.requiredLabel ?? '',
              onUpdate: _openStore,
            ),
          ),
      ],
    );
  }
}

class _ForceUpdateBarrier extends StatelessWidget {
  const _ForceUpdateBarrier({
    required this.clientLabel,
    required this.requiredLabel,
    required this.onUpdate,
  });

  final String clientLabel;
  final String requiredLabel;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6111418),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '업데이트가 필요해요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF3EBE2),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '이 버전($clientLabel)은 더 이상 쓸 수 없어요.\n'
                '스토어에서 $requiredLabel 이상으로 올려 주세요.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFA89888),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onUpdate,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A574),
                    foregroundColor: const Color(0xFF1A120C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '스토어로 이동',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
