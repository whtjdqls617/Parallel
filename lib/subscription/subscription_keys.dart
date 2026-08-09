/// Public RevenueCat SDK keys (client-safe).
///
/// Override at build/run time if needed:
/// ```
/// flutter run \
///   --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx \
///   --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx
/// ```
class SubscriptionKeys {
  const SubscriptionKeys._();

  static const iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: 'appl_cSGiNQkLfGAAahIwfaQyiArBUqT',
  );

  /// Add when Play Console account is ready.
  static const androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );

  static bool get hasAnyKey =>
      iosApiKey.isNotEmpty || androidApiKey.isNotEmpty;
}
