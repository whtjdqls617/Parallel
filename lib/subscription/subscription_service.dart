import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_config.dart';
import 'subscription_keys.dart';

class PurchaseAttempt {
  const PurchaseAttempt({required this.ok, required this.message});
  final bool ok;
  final String message;
}

/// RevenueCat subscription + local/cloud 7-day Plus trial.
///
/// Call [start] once after Firebase Auth has a uid. Feature gates use
/// [hasPlusAccess] (subscribed **or** still in trial).
class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const _prefsTrialKey = 'plus_trial_started_ms';

  bool _configured = false;
  bool _subscribed = false;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;
  String? _lastOfferingsNote;
  List<StoreProduct> _directProducts = const [];

  DateTime? _trialStartedAt;
  Timer? _trialEndTimer;
  String? _firebaseUid;

  bool get isConfigured => _configured;

  /// Paying entitlement only (RevenueCat).
  bool get isSubscribed => _subscribed;

  /// Feature unlock: active sub **or** within the first-week trial.
  bool get hasPlusAccess => _subscribed || isInTrial;

  bool get isInTrial {
    if (_subscribed) return false;
    final start = _trialStartedAt;
    if (start == null) return false;
    final end = start.add(SubscriptionConfig.trialDuration);
    return DateTime.now().isBefore(end);
  }

  bool get trialEnded {
    if (_subscribed) return false;
    final start = _trialStartedAt;
    if (start == null) return false;
    return !isInTrial;
  }

  DateTime? get trialStartedAt => _trialStartedAt;

  DateTime? get trialEndsAt {
    final start = _trialStartedAt;
    if (start == null) return null;
    return start.add(SubscriptionConfig.trialDuration);
  }

  /// Whole days left (0 when last day or expired).
  int get trialDaysLeft {
    final end = trialEndsAt;
    if (end == null || _subscribed) return 0;
    final left = end.difference(DateTime.now());
    if (left.isNegative) return 0;
    return left.inDays;
  }

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
    final trial = _trialStartedAt == null
        ? 'trial=unset'
        : 'trial=${isInTrial ? 'active' : 'ended'} '
            'daysLeft=$trialDaysLeft start=$_trialStartedAt';
    return 'current=$currentId offering=$offeringId '
        'availablePackages=$available '
        'direct=[${direct.isEmpty ? 'empty' : direct}] '
        '$trial'
        '${_lastOfferingsNote == null ? '' : ' note=$_lastOfferingsNote'}';
  }

  /// Configure SDK + bind Firebase uid + ensure trial clock.
  Future<void> start({String? firebaseUid}) async {
    _firebaseUid = firebaseUid;
    await _ensureTrialStarted(firebaseUid: firebaseUid);

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
    _firebaseUid = uid;
    if (!_configured || uid.isEmpty) return;
    try {
      final result = await Purchases.logIn(uid);
      _applyCustomerInfo(result.customerInfo);
    } catch (e) {
      debugPrint('[Subscription] logIn failed: $e');
    }
    // Prefer cloud trial start if prefs were wiped but uid persisted.
    await _ensureTrialStarted(firebaseUid: uid);
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

  /// Debug — pretend the trial already ended.
  Future<void> debugEndTrial() async {
    final ended = DateTime.now().subtract(SubscriptionConfig.trialDuration +
        const Duration(hours: 1));
    await _setTrialStarted(ended);
  }

  /// Debug — restart a fresh 7-day trial from now.
  Future<void> debugRestartTrial() async {
    await _setTrialStarted(DateTime.now());
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
      _scheduleTrialEndNotify();
      notifyListeners();
    }
  }

  Future<void> _ensureTrialStarted({String? firebaseUid}) async {
    DateTime? local;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_prefsTrialKey);
      if (ms != null) local = DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {}

    DateTime? cloud;
    final uid = firebaseUid ?? _firebaseUid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final snap =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final raw = snap.data()?['plusTrialStartedAt'];
        if (raw is Timestamp) cloud = raw.toDate();
      } catch (e) {
        debugPrint('[Subscription] trial cloud read failed: $e');
      }
    }

    // Earliest known start wins (prevents reinstall/prefs wipe from extending).
    DateTime? start;
    if (local != null && cloud != null) {
      start = local.isBefore(cloud) ? local : cloud;
    } else {
      start = local ?? cloud;
    }
    start ??= DateTime.now();

    await _setTrialStarted(start, notify: false);
  }

  Future<void> _setTrialStarted(DateTime start, {bool notify = true}) async {
    _trialStartedAt = start;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsTrialKey, start.millisecondsSinceEpoch);
    } catch (_) {}

    final uid = _firebaseUid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {
            'plusTrialStartedAt': Timestamp.fromDate(start),
            'uid': uid,
          },
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('[Subscription] trial cloud write failed: $e');
      }
    }

    _scheduleTrialEndNotify();
    if (notify) notifyListeners();
  }

  void _scheduleTrialEndNotify() {
    _trialEndTimer?.cancel();
    if (_subscribed || !isInTrial) return;
    final end = trialEndsAt;
    if (end == null) return;
    var left = end.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    // Timer max ~practical; clamp to avoid huge delays issues.
    if (left > const Duration(days: 8)) {
      left = const Duration(days: 8);
    }
    _trialEndTimer = Timer(left, () {
      notifyListeners();
    });
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
