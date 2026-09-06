import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../notify/push_service.dart';
import 'memo.dart';

/// Tracks which reply sets on *my* memos I've already opened.
///
/// Used to show a soft “new trace” cue on [MemoPlace] until the owner reads.
class MemoReplyInbox {
  MemoReplyInbox._();
  static final MemoReplyInbox instance = MemoReplyInbox._();

  static const _prefsKey = 'memo_reply_seen_v1';

  final Map<String, String> _seen = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            _seen[k.toString()] = v.toString();
          });
        }
      }
    } catch (_) {}
    _loaded = true;
  }

  /// Stable fingerprint of the reply set (count + latest time).
  static String signature(Memo memo) {
    if (memo.replies.isEmpty) return '0';
    var latest = 0;
    for (final r in memo.replies) {
      final ms = r.createdAt.toUtc().millisecondsSinceEpoch;
      if (ms > latest) latest = ms;
    }
    return '${memo.replies.length}:$latest';
  }

  bool isUnread(Memo memo, String? uid) {
    if (!_loaded) return false;
    if (!memo.isOwnedBy(uid) || !memo.hasReply) return false;
    return _seen[memo.id] != signature(memo);
  }

  bool anyUnread(Iterable<Memo> pool, String? uid) {
    for (final m in pool) {
      if (isUnread(m, uid)) return true;
    }
    return false;
  }

  Future<void> markSeen(Memo memo) async {
    await ensureLoaded();
    if (!memo.hasReply) {
      _seen.remove(memo.id);
    } else {
      _seen[memo.id] = signature(memo);
    }
    await _persist();
    // Push always sets badge:1 — clear once the guest has opened that trace.
    await PushService.instance.clearAppBadge();
  }

  /// Clear the icon badge when there is nothing left to check.
  Future<void> clearBadgeIfCaughtUp(Iterable<Memo> pool, String? uid) async {
    await ensureLoaded();
    if (anyUnread(pool, uid)) return;
    await PushService.instance.clearAppBadge();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_seen));
    } catch (_) {}
  }
}
