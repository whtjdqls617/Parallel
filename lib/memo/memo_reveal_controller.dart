import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'memo.dart';

/// Staggered / randomly sampled memo list for the panel.
class MemoRevealController extends ChangeNotifier {
  MemoRevealController({
    this.maxVisible = 10,
    this.smallPoolThreshold = 12,
    math.Random? random,
  }) : _rng = random ?? math.Random();

  final int maxVisible;
  final int smallPoolThreshold;
  final math.Random _rng;

  List<Memo> _pool = const [];
  final List<Memo> _visible = [];
  final Set<String> _revealedIds = {};
  String? _priorityId;

  Timer? _staggerTimer;
  Timer? _refreshTimer;
  int _staggerIndex = 0;
  List<Memo> _pendingReveal = const [];

  List<Memo> get visibleMemos => List.unmodifiable(_visible);

  /// Full theme pool (for the center list); board shows only a teaser.
  List<Memo> get pool => List.unmodifiable(_pool);

  @override
  void dispose() {
    _staggerTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void reset() {
    _staggerTimer?.cancel();
    _refreshTimer?.cancel();
    _pool = const [];
    _visible.clear();
    _revealedIds.clear();
    _pendingReveal = const [];
    _staggerIndex = 0;
    _priorityId = null;
    notifyListeners();
  }

  void setPool(List<Memo> pool, {String? preferId}) {
    _pool = List.of(pool);
    if (preferId != null) _priorityId = preferId;

    if (_visible.isEmpty) {
      _beginReveal();
      return;
    }

    _visible.removeWhere((m) => !_pool.any((p) => p.id == m.id));

    if (_priorityId != null) {
      final priority = _findById(_priorityId!);
      if (priority != null && !_visible.any((m) => m.id == priority.id)) {
        if (_visible.length >= maxVisible) _visible.removeLast();
        _visible.insert(0, priority);
        _revealedIds.add(priority.id);
        _priorityId = null;
        notifyListeners();
      }
    }

    _scheduleRefresh();
    notifyListeners();
  }

  Memo? _findById(String id) {
    for (final m in _pool) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _beginReveal() {
    _staggerTimer?.cancel();
    _visible.clear();
    _revealedIds.clear();
    _staggerIndex = 0;

    if (_pool.isEmpty) {
      notifyListeners();
      return;
    }

    _pendingReveal = _pick();

    if (_priorityId != null) {
      final p = _findById(_priorityId!);
      if (p != null) {
        _pendingReveal.removeWhere((m) => m.id == p.id);
        _pendingReveal.insert(0, p);
      }
      _priorityId = null;
    }

    _revealNext();
    _scheduleRefresh();
  }

  List<Memo> _pick() {
    final n = math.min(maxVisible, _pool.length);
    if (_pool.length <= smallPoolThreshold) return _pool.take(n).toList();
    final shuffled = List<Memo>.of(_pool)..shuffle(_rng);
    return shuffled.take(n).toList();
  }

  void _revealNext() {
    if (_staggerIndex >= _pendingReveal.length) {
      _staggerTimer?.cancel();
      return;
    }

    final memo = _pendingReveal[_staggerIndex++];
    if (!_revealedIds.contains(memo.id)) {
      _visible.add(memo);
      _revealedIds.add(memo.id);
      notifyListeners();
    }

    if (_staggerIndex < _pendingReveal.length) {
      // Quiet pace — one note, then a long pause before the next.
      final delayMs = 1600 + _rng.nextInt(1400);
      _staggerTimer = Timer(Duration(milliseconds: delayMs), _revealNext);
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (_pool.length <= smallPoolThreshold) return;
    final wait = Duration(seconds: 45 + _rng.nextInt(46));
    _refreshTimer = Timer(wait, _swapSome);
  }

  void _swapSome() {
    if (_pool.length <= smallPoolThreshold || _visible.isEmpty) {
      _scheduleRefresh();
      return;
    }

    final candidates = _pool
        .where((m) => !_visible.any((v) => v.id == m.id))
        .toList()
      ..shuffle(_rng);
    if (candidates.isEmpty) {
      _scheduleRefresh();
      return;
    }

    final replaceAt = _rng.nextInt(_visible.length);
    _visible[replaceAt] = candidates.first;
    _revealedIds.add(candidates.first.id);
    notifyListeners();
    _scheduleRefresh();
  }
}
