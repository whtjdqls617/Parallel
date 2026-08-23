import 'package:flutter/material.dart';

import 'welcome_host.dart';

class WelcomeScope extends InheritedNotifier<WelcomeHost> {
  const WelcomeScope({
    super.key,
    required WelcomeHost host,
    required super.child,
  }) : super(notifier: host);

  static WelcomeHost? maybeOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<WelcomeScope>();
    return scope?.notifier;
  }

  static WelcomeHost of(BuildContext context) {
    final host = maybeOf(context);
    assert(host != null, 'WelcomeScope not found');
    return host!;
  }
}
