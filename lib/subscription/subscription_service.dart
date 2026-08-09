import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'subscription_config.dart';
import 'subscription_keys.dart';

class PurchaseAttempt {
  const PurchaseAttempt({required this.ok, required this.message});
  final bool ok;
  final String message;
}

/// RevenueCat wiring only — no feature gating yet.
///
/// Call [start] once after Firebase Auth has a uid. Use [isSubscribed] later
/// when locking premium surfaces; for now the rest of the app ignores it.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  bool _configured = false;
  bool _subscribed = false;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;
  String? _lastOfferingsNote;
  List<StoreProduct> _directProducts = const [];

  bool get isConfigured => _configured;
  bool get isSubscribed => _subscribed;
  CustomerInfo? get customerInfo => _customerInfo;
  Offerings? get offerings => _offerings;
  String? get lastOfferingsNote => _lastOfferingsNote;
  List<StoreProduct> get directProducts => _directProducts;

  Offering? get _offering =>
      _offerings?.getOffering(SubscriptionConfig.offeringId) ??
      _offerings?.current;

  Package? get defaultPackage {
    final offering = _offering;
    if (offering == null || offering.availablePackages.isEmpty) return null;

    for (final pkg in offering.availablePackages) {
      if (pkg.packageType == PackageType.monthly) return pkg;
    }
    return offering.availablePackages.first;
  }

  String get debugStatus {
    final offering = _offering;
    final available = offering?.availablePackages.length ?? 0;
    final currentId = _offerings?.current?.identifier ?? '(none)';
    final offeringId = offering?.identifier ?? '(none)';
    final direct = _directProducts.map((p) => p.identifier).join(', ');
    return 'current=$currentId offering=$offeringId '
        'availablePackages=$available '
        'direct=[${direct.isEmpty ? 'empty' : direct}]'
        '${_lastOfferingsNote == null ? '' : ' note=$_lastOfferingsNote'}';
  }

  /// Configure SDK + bind Firebase uid. No-ops if API keys are missing.
  Future<void> start({String? firebaseUid}) async {
    if (_configured) {
      if (firebaseUid != null && firebaseUid.isNotEmpty) {
        await linkFirebaseUser(firebaseUid);
      }
      return;
    }

    final apiKey = _platformApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint(
        '[Subscription] Skipped — set REVENUECAT_IOS_API_KEY / '
        'REVENUECAT_ANDROID_API_KEY via --dart-define',
      );
      return;
    }

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      final config = PurchasesConfiguration(apiKey);
      if (firebaseUid != null && firebaseUid.isNotEmpty) {
        config.appUserID = firebaseUid;
      }
      await Purchases.configure(config);
      _configured = true;

      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);

      await Future.wait([
        refreshCustomerInfo(),
        refreshOfferings(),
      ]);
      debugPrint('[Subscription] $debugStatus');
    } catch (e, st) {
      debugPrint('[Subscription] configure failed: $e\n$st');
    }
  }

  /// Keep RevenueCat appUserID == Firebase Auth uid.
  Future<void> linkFirebaseUser(String uid) async {
    if (!_configured || uid.isEmpty) return;
    try {
      final result = await Purchases.logIn(uid);
      _applyCustomerInfo(result.customerInfo);
    } catch (e) {
      debugPrint('[Subscription] logIn failed: $e');
    }
  }

  Future<void> refreshCustomerInfo() async {
    if (!_configured) return;
    try {
      final info = await Purchases.getCustomerInfo();
      _applyCustomerInfo(info);
    } catch (e) {
      debugPrint('[Subscription] getCustomerInfo failed: $e');
    }
  }

  Future<void> refreshOfferings() async {
    if (!_configured) return;
    try {
      _offerings = await Purchases.getOfferings();
      _directProducts = await Purchases.getProducts(
        [SubscriptionConfig.monthlyProductId],
        productCategory: ProductCategory.subscription,
      );

      final offering = _offering;
      if (offering == null) {
        _lastOfferingsNote =
            'Offering "${SubscriptionConfig.offeringId}" / current 없음. '
            'RevenueCat에서 default를 Current로 설정했는지 확인.';
      } else if (offering.availablePackages.isEmpty) {
        _lastOfferingsNote =
            '스토어에서 상품을 못 불러옴. 시뮬레이터면 StoreKit 설정 필요, '
            '실기기는 Sandbox + App Store Connect 상품 상태 확인.';
      } else {
        _lastOfferingsNote = null;
      }

      debugPrint('[Subscription] $debugStatus');
      notifyListeners();
    } catch (e) {
      _lastOfferingsNote = 'getOfferings 실패: $e';
      debugPrint('[Subscription] getOfferings failed: $e');
      notifyListeners();
    }
  }

  Future<PurchaseAttempt> purchaseDefaultPackage() async {
    if (!_configured) {
      return const PurchaseAttempt(ok: false, message: 'SDK 미연결');
    }

    final package = defaultPackage;
    if (package != null) {
      return _purchase(() => Purchases.purchase(PurchaseParams.package(package)));
    }

    // Fallback: buy by product id when offering packages didn't hydrate.
    if (_directProducts.isEmpty) {
      await refreshOfferings();
    }
    if (_directProducts.isNotEmpty) {
      final product = _directProducts.first;
      return _purchase(
        () => Purchases.purchase(PurchaseParams.storeProduct(product)),
      );
    }

    return PurchaseAttempt(
      ok: false,
      message:
          '구매 가능 상품 없음.\n$debugStatus\n'
          '→ 시뮬: Xcode Scheme에 StoreKit 파일 연결 후 재실행\n'
          '→ 실기기: Sandbox 계정 + ASC 상품 Ready',
    );
  }

  Future<PurchaseAttempt> restorePurchases() async {
    if (!_configured) {
      return const PurchaseAttempt(ok: false, message: 'SDK 미연결');
    }
    try {
      final info = await Purchases.restorePurchases();
      _applyCustomerInfo(info);
      return PurchaseAttempt(
        ok: isSubscribed,
        message: isSubscribed ? '복원 완료 (구독 있음)' : '복원됨 / 구독 없음',
      );
    } catch (e) {
      return PurchaseAttempt(ok: false, message: _errorMessage(e));
    }
  }

  Future<PurchaseAttempt> _purchase(
    Future<PurchaseResult> Function() buy,
  ) async {
    try {
      final result = await buy();
      _applyCustomerInfo(result.customerInfo);
      return PurchaseAttempt(
        ok: isSubscribed,
        message: isSubscribed ? '구매/구독 반영됨' : '구매는 됐지만 entitlement 없음',
      );
    } catch (e) {
      return PurchaseAttempt(ok: false, message: _errorMessage(e));
    }
  }

  String _errorMessage(Object e) {
    if (e is PlatformException) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return '구매 취소됨';
      }
      if (code == PurchasesErrorCode.productNotAvailableForPurchaseError) {
        return '스토어에 상품 없음 (StoreKit/Sandbox 설정 필요)';
      }
      return '구매 실패: ${e.message ?? code.name}';
    }
    return '구매 실패: $e';
  }

  void _onCustomerInfo(CustomerInfo info) => _applyCustomerInfo(info);

  void _applyCustomerInfo(CustomerInfo info) {
    _customerInfo = info;
    final next =
        info.entitlements.active.containsKey(SubscriptionConfig.entitlementId);
    if (next != _subscribed || _customerInfo != null) {
      _subscribed = next;
      notifyListeners();
    }
  }

  String? _platformApiKey() {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => SubscriptionKeys.iosApiKey,
      TargetPlatform.android => SubscriptionKeys.androidApiKey,
      _ => null,
    };
  }
}
