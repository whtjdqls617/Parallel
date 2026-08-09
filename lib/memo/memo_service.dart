import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'memo.dart';

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

    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;
    final uid = user?.uid;
    if (uid == null) {
      throw StateError('Anonymous sign-in required to leave a memo');
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

  Memo? _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final theme = Memo.themeFromString(data['theme'] as String?);
    final text = (data['text'] as String?)?.trim();
    if (theme == null || text == null || text.isEmpty) return null;

    var artist = (data['artist'] as String?)?.trim() ?? '';
    var song = (data['song'] as String?)?.trim() ?? '';
    // Legacy: kind=song stored tip only in text / song blob.
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
      id: doc.id,
      theme: theme,
      text: text,
      artist: artist,
      song: song,
      createdAt: createdAt,
      expiresAt: expiresAt,
      uid: data['uid'] as String?,
    );
  }
}
