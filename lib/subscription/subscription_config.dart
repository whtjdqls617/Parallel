/// Product / entitlement IDs — must match RevenueCat dashboard.
///
/// Dashboard checklist:
/// 1. Create apps (iOS + Android) and paste public SDK keys via dart-define
/// 2. Entitlement id: [entitlementId]
/// 3. Offering (usually `default`) with a monthly/yearly package attached
/// 4. Link App Store / Play products to that package
/// 5. (Optional later) RevenueCat Firebase Extension → sync to Firestore
class SubscriptionConfig {
  const SubscriptionConfig._();

  /// Active entitlement that means “subscribed”.
  /// Must match RevenueCat Entitlements → Identifier exactly.
  static const entitlementId = 'Parallel Pro';

  /// Offering identifier in RevenueCat (default offering if null/current).
  static const offeringId = 'default';

  /// App Store Connect / RevenueCat product id.
  static const monthlyProductId = 'parallel_plus_monthly';

  /// Full Parallel Plus access from first open, before paywall.
  static const trialDuration = Duration(days: 7);
}
