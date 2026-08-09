import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../memo/memo.dart';

/// Live “함께 보는” count per theme via Firestore heartbeats.
///
/// Each signed-in device writes `presence/{uid}` while resting in a theme.
/// Peers count docs whose [lastSeen] is fresh.
class PresenceService {
  PresenceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const _collection = 'presence';
  static const heartbeatEvery = Duration(seconds: 25);
  static const staleAfter = Duration(seconds: 70);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Timer? _heartbeat;
  MemoTheme? _theme;
  bool _active = false;

  CollectionReference<Map<String, dynamic>> get _presence =>
      _db.collection(_collection);

  DocumentReference<Map<String, dynamic>>? get _myDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _presence.doc(uid);
  }

  /// Watch how many people are currently resting in [theme].
  Stream<int> watchCount(MemoTheme theme) {
    return _presence
        .where('theme', isEqualTo: theme.key)
        .snapshots()
        .map((snap) {
      final cutoff = DateTime.now().toUtc().subtract(staleAfter);
      var count = 0;
      final staleIds = <String>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['lastSeen'];
        final lastSeen = ts is Timestamp
            ? ts.toDate().toUtc()
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        if (lastSeen.isBefore(cutoff)) {
          staleIds.add(doc.id);
          continue;
        }
        count++;
      }

      if (staleIds.isNotEmpty && _auth.currentUser != null) {
        _purgeStale(staleIds);
      }

      return count;
    });
  }

  /// Start / move presence into [theme]. Safe to call repeatedly.
  Future<void> enter(MemoTheme theme) async {
    await _ensureAuth();
    _theme = theme;
    _active = true;
    await _touch();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatEvery, (_) {
      unawaited(_touch());
    });
  }

  /// Leave the shared room (app background / dispose).
  Future<void> leave() async {
    _active = false;
    _heartbeat?.cancel();
    _heartbeat = null;
    _theme = null;
    final doc = _myDoc;
    if (doc == null) return;
    try {
      await doc.delete();
    } catch (_) {
      // Best-effort; stale purge will clear us later.
    }
  }

  Future<void> _ensureAuth() async {
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;
    if (user == null) {
      throw StateError('Anonymous sign-in required for presence');
    }
  }

  Future<void> _touch() async {
    if (!_active) return;
    final theme = _theme;
    final doc = _myDoc;
    if (theme == null || doc == null) return;
    final uid = _auth.currentUser!.uid;
    try {
      await doc.set({
        'theme': theme.key,
        'uid': uid,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Offline / rules — next heartbeat retries.
    }
  }

  void _purgeStale(List<String> ids) {
    Future<void>(() async {
      final batch = _db.batch();
      for (final id in ids.take(40)) {
        batch.delete(_presence.doc(id));
      }
      try {
        await batch.commit();
      } catch (_) {}
    });
  }

  void dispose() {
    unawaited(leave());
  }
}
