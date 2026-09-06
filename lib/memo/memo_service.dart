import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../subscription/subscription_config.dart';
import 'memo.dart';
import 'memo_content_filter.dart';

/// User-facing write failure (filter / daily quota).
class MemoWriteException implements Exception {
  MemoWriteException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Shared memos backed by Firestore `memos/{id}`.
class MemoService {
  MemoService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const _collection = 'memos';
  static const _poolLimit = 200;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _memos =>
      _db.collection(_collection);

  String? get currentUid => _auth.currentUser?.uid;

  /// Single memo by id (for push deep-link). Null if missing / invalid.
  Future<Memo?> fetchById(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    try {
      final snap = await _memos.doc(trimmed).get();
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return _fromData(snap.id, data);
    } catch (e) {
      debugPrint('Memo fetchById failed: $e');
      return null;
    }
  }

  Stream<List<Memo>> watchPool(MemoTheme theme) {
    return _memos
        .where('theme', isEqualTo: theme.key)
        .orderBy('createdAt', descending: true)
        .limit(_poolLimit)
        .snapshots()
        .map((snap) {
      final now = DateTime.now().toUtc();
      final alive = <Memo>[];
      final expiredIds = <String>[];

      for (final doc in snap.docs) {
        final memo = _fromDoc(doc);
        if (memo == null) continue;
        if (!memo.expiresAt.toUtc().isAfter(now)) {
          expiredIds.add(doc.id);
          continue;
        }
        alive.add(memo);
      }

      if (expiredIds.isNotEmpty && _auth.currentUser != null) {
        _purgeExpired(expiredIds);
      }

      return alive;
    });
  }

  Future<Memo> create({
    required MemoTheme theme,
    required String text,
    required String artist,
    required String song,
    bool unlimited = false,
  }) async {
    final trimmed = text.trim();
    final artistTrimmed = artist.trim();
    final songTrimmed = song.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Memo text is empty');
    }
    if (trimmed.length > Memo.maxTextLength) {
      throw ArgumentError('Memo text is too long');
    }
    if (artistTrimmed.length > Memo.maxArtistLength) {
      throw ArgumentError('Artist is too long');
    }
    if (songTrimmed.length > Memo.maxSongLength) {
      throw ArgumentError('Song title is too long');
    }

    final blocked = MemoContentFilter.rejectReason(trimmed);
    if (blocked != null) {
      throw MemoWriteException(blocked);
    }
    if (artistTrimmed.isNotEmpty || songTrimmed.isNotEmpty) {
      final songBlocked = MemoContentFilter.rejectReason(
        '$artistTrimmed $songTrimmed',
      );
      if (songBlocked != null) {
        throw MemoWriteException(songBlocked);
      }
    }

    final uid = await _ensureUid();
    if (!unlimited) {
      final used = await countCreatedToday(uid);
      if (used >= SubscriptionConfig.freeMemosPerDay) {
        throw MemoWriteException(
          '오늘은 이미 한 장 남겼어요. Plus면 무제한으로 남길 수 있어요.',
        );
      }
    }

    final ref = _memos.doc();
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(Memo.lifetime);
    await ref.set({
      'theme': theme.key,
      'text': trimmed,
      'artist': artistTrimmed,
      'song': songTrimmed,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'uid': uid,
      'replies': <String, dynamic>{},
    });

    return Memo(
      id: ref.id,
      theme: theme,
      text: trimmed,
      artist: artistTrimmed,
      song: songTrimmed,
      createdAt: now,
      expiresAt: expiresAt,
      uid: uid,
    );
  }

  /// Memos this uid created since start of today (Asia/Seoul).
  Future<int> countCreatedToday(String uid) async {
    final start = _startOfTodayKst();
    final snap = await _memos
        .where('uid', isEqualTo: uid)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .limit(SubscriptionConfig.freeMemosPerDay + 5)
        .get();
    return snap.docs.length;
  }

  static DateTime _startOfTodayKst() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final startKst = DateTime(kst.year, kst.month, kst.day);
    return startKst.subtract(const Duration(hours: 9));
  }

  /// Leave one quiet reply sticky — at most once per person per memo.
  Future<Memo> addReply({
    required String memoId,
    required String text,
    String artist = '',
    String song = '',
    required double x,
    required double y,
  }) async {
    final trimmed = text.trim();
    final artistTrimmed = artist.trim();
    final songTrimmed = song.trim();
    final nx = x.clamp(0.0, 1.0);
    final ny = y.clamp(0.0, 1.0);
    if (trimmed.isEmpty) {
      throw ArgumentError('Reply text is empty');
    }
    if (trimmed.length > Memo.maxReplyLength) {
      throw ArgumentError('Reply text is too long');
    }
    if (artistTrimmed.length > Memo.maxArtistLength) {
      throw ArgumentError('Artist is too long');
    }
    if (songTrimmed.length > Memo.maxSongLength) {
      throw ArgumentError('Song title is too long');
    }

    final blocked = MemoContentFilter.rejectReason(trimmed);
    if (blocked != null) {
      throw MemoWriteException(blocked);
    }

    final uid = await _ensureUid();
    final ref = _memos.doc(memoId);
    final now = DateTime.now().toUtc();

    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Memo is gone');
      }
      final data = snap.data();
      if (data == null) {
        throw StateError('Memo is gone');
      }

      final expiresTs = data['expiresAt'];
      if (expiresTs is Timestamp &&
          !expiresTs.toDate().toUtc().isAfter(now)) {
        throw StateError('Memo expired');
      }

      final replies = _parseReplies(data);
      if (replies.any((r) => r.uid == uid)) {
        throw StateError('Already replied');
      }
      if (replies.length >= Memo.maxReplies) {
        throw StateError('Too many replies');
      }

      final next = [
        ...replies,
        MemoReply(
          uid: uid,
          text: trimmed,
          artist: artistTrimmed,
          song: songTrimmed,
          createdAt: now,
          x: nx,
          y: ny,
        ),
      ];

      tx.update(ref, {
        'replies': {
          for (final r in next)
            r.uid: _replyFields(r, requireAnchor: r.uid == uid),
        },
        'replyText': FieldValue.delete(),
        'replyUid': FieldValue.delete(),
        'replyCreatedAt': FieldValue.delete(),
      });

      final memo = _fromData(snap.id, data);
      if (memo == null) {
        throw StateError('Memo is invalid');
      }
      return memo.copyWithReplies(next);
    });
  }

  /// Edit the current user's reply (keeps createdAt; optional new anchor).
  Future<Memo> updateReply({
    required String memoId,
    required String text,
    String artist = '',
    String song = '',
    double? x,
    double? y,
  }) async {
    final trimmed = text.trim();
    final artistTrimmed = artist.trim();
    final songTrimmed = song.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Reply text is empty');
    }
    if (trimmed.length > Memo.maxReplyLength) {
      throw ArgumentError('Reply text is too long');
    }
    if (artistTrimmed.length > Memo.maxArtistLength) {
      throw ArgumentError('Artist is too long');
    }
    if (songTrimmed.length > Memo.maxSongLength) {
      throw ArgumentError('Song title is too long');
    }

    final blocked = MemoContentFilter.rejectReason(trimmed);
    if (blocked != null) {
      throw MemoWriteException(blocked);
    }

    final uid = await _ensureUid();
    final ref = _memos.doc(memoId);

    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Memo is gone');
      }
      final data = snap.data();
      if (data == null) {
        throw StateError('Memo is gone');
      }

      final now = DateTime.now().toUtc();
      final expiresTs = data['expiresAt'];
      if (expiresTs is Timestamp &&
          !expiresTs.toDate().toUtc().isAfter(now)) {
        throw StateError('Memo expired');
      }

      final replies = _parseReplies(data);
      final mine = replies.where((r) => r.uid == uid).toList();
      if (mine.isEmpty) {
        throw StateError('No reply to edit');
      }
      final old = mine.first;
      final nx = (x ?? old.x ?? 0.52).clamp(0.0, 1.0);
      final ny = (y ?? old.y ?? 0.62).clamp(0.0, 1.0);

      final next = [
        for (final r in replies)
          if (r.uid == uid)
            MemoReply(
              uid: uid,
              text: trimmed,
              artist: artistTrimmed,
              song: songTrimmed,
              createdAt: old.createdAt,
              x: nx,
              y: ny,
            )
          else
            r,
      ];

      tx.update(ref, {
        'replies': {
          for (final r in next)
            r.uid: _replyFields(r, requireAnchor: r.uid == uid),
        },
      });

      final memo = _fromData(snap.id, data);
      if (memo == null) {
        throw StateError('Memo is invalid');
      }
      return memo.copyWithReplies(next);
    });
  }

  /// Remove the current user's reply.
  Future<Memo> removeReply({required String memoId}) async {
    final uid = await _ensureUid();
    final ref = _memos.doc(memoId);

    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Memo is gone');
      }
      final data = snap.data();
      if (data == null) {
        throw StateError('Memo is gone');
      }

      final now = DateTime.now().toUtc();
      final expiresTs = data['expiresAt'];
      if (expiresTs is Timestamp &&
          !expiresTs.toDate().toUtc().isAfter(now)) {
        throw StateError('Memo expired');
      }

      final replies = _parseReplies(data);
      if (!replies.any((r) => r.uid == uid)) {
        throw StateError('No reply to remove');
      }
      final next = [for (final r in replies) if (r.uid != uid) r];

      tx.update(ref, {
        'replies': {
          for (final r in next)
            r.uid: _replyFields(r, requireAnchor: false),
        },
      });

      final memo = _fromData(snap.id, data);
      if (memo == null) {
        throw StateError('Memo is invalid');
      }
      return memo.copyWithReplies(next);
    });
  }

  Map<String, dynamic> _replyFields(
    MemoReply r, {
    required bool requireAnchor,
  }) {
    final m = <String, dynamic>{
      'text': r.text,
      'artist': r.artist,
      'song': r.song,
      'createdAt': Timestamp.fromDate(r.createdAt),
    };
    if (r.hasAnchor) {
      m['x'] = r.x;
      m['y'] = r.y;
    } else if (requireAnchor) {
      m['x'] = 0.52;
      m['y'] = 0.62;
    }
    return m;
  }

  Future<String> _ensureUid() async {
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;
    final uid = user?.uid;
    if (uid == null) {
      throw StateError('Anonymous sign-in required');
    }
    return uid;
  }

  void _purgeExpired(List<String> ids) {
    Future<void>(() async {
      final batch = _db.batch();
      for (final id in ids.take(40)) {
        batch.delete(_memos.doc(id));
      }
      try {
        await batch.commit();
      } catch (_) {}
    });
  }

  Memo? _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      _fromData(doc.id, doc.data());

  Memo? _fromData(String id, Map<String, dynamic> data) {
    final theme = Memo.themeFromString(data['theme'] as String?);
    final text = (data['text'] as String?)?.trim();
    if (theme == null || text == null || text.isEmpty) return null;

    var artist = (data['artist'] as String?)?.trim() ?? '';
    var song = (data['song'] as String?)?.trim() ?? '';
    if (song.isEmpty && artist.isEmpty && data['kind'] == 'song') {
      song = text;
    }

    final createdTs = data['createdAt'];
    final createdAt = createdTs is Timestamp
        ? createdTs.toDate().toUtc()
        : DateTime.now().toUtc();

    final expiresTs = data['expiresAt'];
    final expiresAt = expiresTs is Timestamp
        ? expiresTs.toDate().toUtc()
        : createdAt.add(Memo.lifetime);

    return Memo(
      id: id,
      theme: theme,
      text: text,
      artist: artist,
      song: song,
      createdAt: createdAt,
      expiresAt: expiresAt,
      uid: data['uid'] as String?,
      replies: _parseReplies(data),
    );
  }

  List<MemoReply> _parseReplies(Map<String, dynamic> data) {
    final out = <MemoReply>[];

    final map = data['replies'];
    if (map is Map) {
      for (final entry in map.entries) {
        final uid = entry.key.toString();
        final value = entry.value;
        if (value is! Map) continue;
        final text = (value['text'] as String?)?.trim() ?? '';
        if (text.isEmpty) continue;
        DateTime createdAt = DateTime.now().toUtc();
        final ts = value['createdAt'];
        if (ts is Timestamp) createdAt = ts.toDate().toUtc();
        out.add(
          MemoReply(
            uid: uid,
            text: text,
            artist: (value['artist'] as String?)?.trim() ?? '',
            song: (value['song'] as String?)?.trim() ?? '',
            createdAt: createdAt,
            x: _asUnit(value['x']),
            y: _asUnit(value['y']),
          ),
        );
      }
    }

    // Legacy single-reply fields → one entry.
    if (out.isEmpty) {
      final legacy = (data['replyText'] as String?)?.trim();
      final legacyUid = data['replyUid'] as String?;
      if (legacy != null && legacy.isNotEmpty && legacyUid != null) {
        DateTime createdAt = DateTime.now().toUtc();
        final ts = data['replyCreatedAt'];
        if (ts is Timestamp) createdAt = ts.toDate().toUtc();
        out.add(MemoReply(uid: legacyUid, text: legacy, createdAt: createdAt));
      }
    }

    out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  double? _asUnit(dynamic value) {
    if (value is num) {
      final v = value.toDouble();
      if (v >= 0 && v <= 1) return v;
    }
    return null;
  }
}
