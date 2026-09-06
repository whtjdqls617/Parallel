import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'semver.dart';

/// Firestore: `config/appVersion`
///
/// Workflow:
/// 1. Bump native version (iOS Version.xcconfig / Android version.properties)
/// 2. Ship to store and confirm the build is live
/// 3. Set `ios` / `android` here to that store version
/// 4. Clients whose major.minor is behind are forced to the store
class ForceUpdateService {
  ForceUpdateService._();
  static final instance = ForceUpdateService._();

  static const docPath = 'config/appVersion';

  static const defaultAndroidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.parallel.android';

  /// Fill App Store id once listed; can also override via Firestore `iosStoreUrl`.
  static const defaultIosStoreUrl = 'https://apps.apple.com/app/id0000000000';

  Future<ForceUpdateCheck> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final client = SemVer.tryParse(info.version);
      if (client == null) {
        return ForceUpdateCheck.ok(clientLabel: info.version);
      }

      final snap =
          await FirebaseFirestore.instance.doc(docPath).get();
      if (!snap.exists) {
        return ForceUpdateCheck.ok(clientLabel: client.toString());
      }

      final data = snap.data() ?? const <String, dynamic>{};
      final platformKey = _platformKey();
      final requiredRaw = data[platformKey]?.toString();
      final required = SemVer.tryParse(requiredRaw);
      if (required == null) {
        return ForceUpdateCheck.ok(clientLabel: client.toString());
      }

      if (!client.needsForceUpdate(required)) {
        return ForceUpdateCheck.ok(
          clientLabel: client.toString(),
          requiredLabel: required.toString(),
        );
      }

      final storeUrl = _storeUrl(data, platformKey);
      return ForceUpdateCheck.force(
        clientLabel: client.toString(),
        requiredLabel: required.toString(),
        storeUrl: storeUrl,
      );
    } catch (e, st) {
      debugPrint('ForceUpdateService.check failed: $e\n$st');
      // Fail open — don't lock users out if Firestore is down.
      return ForceUpdateCheck.ok(clientLabel: '?');
    }
  }

  String _platformKey() {
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return 'android';
  }

  String _storeUrl(Map<String, dynamic> data, String platformKey) {
    if (platformKey == 'ios') {
      final override = data['iosStoreUrl']?.toString().trim();
      if (override != null && override.isNotEmpty) return override;
      return defaultIosStoreUrl;
    }
    final override = data['androidStoreUrl']?.toString().trim();
    if (override != null && override.isNotEmpty) return override;
    return defaultAndroidStoreUrl;
  }
}

class ForceUpdateCheck {
  const ForceUpdateCheck._({
    required this.required,
    required this.clientLabel,
    this.requiredLabel,
    this.storeUrl,
  });

  final bool required;
  final String clientLabel;
  final String? requiredLabel;
  final String? storeUrl;

  factory ForceUpdateCheck.ok({
    required String clientLabel,
    String? requiredLabel,
  }) =>
      ForceUpdateCheck._(
        required: false,
        clientLabel: clientLabel,
        requiredLabel: requiredLabel,
      );

  factory ForceUpdateCheck.force({
    required String clientLabel,
    required String requiredLabel,
    required String storeUrl,
  }) =>
      ForceUpdateCheck._(
        required: true,
        clientLabel: clientLabel,
        requiredLabel: requiredLabel,
        storeUrl: storeUrl,
      );
}
