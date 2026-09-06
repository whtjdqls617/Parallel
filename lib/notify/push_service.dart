import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../memo/memo.dart';

/// Where a tapped reply-push should land.
class PushOpenTarget {
  const PushOpenTarget({
    required this.theme,
    required this.memoId,
  });

  final MemoTheme theme;
  final String memoId;
}

/// FCM token → Firestore `users/{uid}`, and open-intents for reply pushes.
class PushService extends ChangeNotifier {
  PushService._();
  static final PushService instance = PushService._();

  static const _badgeChannel = MethodChannel('parallel/badge');

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _started = false;
  PushOpenTarget? _pending;

  PushOpenTarget? get pending => _pending;

  /// Take and clear the pending open (theme + memo).
  PushOpenTarget? consumePending() {
    final next = _pending;
    _pending = null;
    return next;
  }

  /// Clear the home-screen badge after the guest has checked new traces.
  Future<void> clearAppBadge() async {
    if (kIsWeb) return;
    try {
      await _badgeChannel.invokeMethod<void>('clear');
    } catch (e) {
      debugPrint('[Push] clearAppBadge failed: $e');
    }
  }

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;

    try {
      final messaging = FirebaseMessaging.instance;

      if (Platform.isIOS || Platform.isMacOS) {
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          debugPrint('[Push] permission denied');
          return;
        }
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        // FCM token needs APNs first on Apple platforms.
        await _waitForApnsToken(messaging);
      } else if (Platform.isAndroid) {
        await messaging.requestPermission();
      }

      await syncToken();

      _tokenSub?.cancel();
      _tokenSub = messaging.onTokenRefresh.listen((token) {
        unawaited(_saveToken(token));
      });

      _openedSub?.cancel();
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onMessage);

      final initial = await messaging.getInitialMessage();
      if (initial != null) _onMessage(initial);

      // Late APNs / auth race — one more try shortly after launch.
      unawaited(Future<void>.delayed(const Duration(seconds: 3), syncToken));
    } catch (e, st) {
      debugPrint('[Push] start failed: $e\n$st');
    }
  }

  Future<void> _waitForApnsToken(FirebaseMessaging messaging) async {
    for (var i = 0; i < 10; i++) {
      final apns = await messaging.getAPNSToken();
      if (apns != null && apns.isNotEmpty) {
        debugPrint('[Push] APNs ready');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    debugPrint('[Push] APNs token still null — getToken may fail on simulator');
  }

  /// Re-save token after auth is ready (or when returning to foreground).
  Future<void> syncToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[Push] getToken returned empty');
        return;
      }
      await _saveToken(token);
    } catch (e) {
      debugPrint('[Push] syncToken failed: $e');
    }
  }

  void _onMessage(RemoteMessage message) {
    final target = _parseTarget(message.data);
    if (target == null) return;
    _pending = target;
    notifyListeners();
  }

  PushOpenTarget? _parseTarget(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type != null && type != 'memo_reply') return null;
    final memoId = data['memoId']?.toString().trim() ?? '';
    if (memoId.isEmpty) return null;
    final theme = Memo.themeFromString(data['theme']?.toString());
    if (theme == null) return null;
    return PushOpenTarget(theme: theme, memoId: memoId);
  }

  Future<void> _saveToken(String? token) async {
    if (token == null || token.isEmpty) return;
    var user = FirebaseAuth.instance.currentUser;
    user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'uid': uid,
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
          'fcmPlatform': Platform.isIOS
              ? 'ios'
              : Platform.isAndroid
                  ? 'android'
                  : 'other',
        },
        SetOptions(merge: true),
      );
      debugPrint('[Push] token saved for $uid');
    } catch (e) {
      debugPrint('[Push] token save failed: $e');
    }
  }

  @override
  void dispose() {
    unawaited(_tokenSub?.cancel());
    unawaited(_openedSub?.cancel());
    _tokenSub = null;
    _openedSub = null;
    super.dispose();
  }
}
