import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'memo.dart';

/// Board teaser reveal — up to [maxVisible] notes, front of pool, one by one.
class MemoRevealController extends ChangeNotifier {
  MemoRevealController({
    this.maxVisible = 3,
    math.Random? random,
  }) : _rng = random ?? math.Random();

  final int maxVisible;
  final math.Random _rng;

  List<Memo> _pool = const [];
  final List<Memo> _visible = [];
  final Set<String> _revealedIds = {};
  String? _priorityId;

  Timer? _staggerTimer;
  int _staggerIndex = 0;
  List<Memo> _pendingReveal = const [];

  List<Memo> get visibleMemos => List.unmodifiable(_visible);

  /// Full theme pool (for the center list); board shows only teasers.
  List<Memo> get pool => List.unmodifiable(_pool);

  @override
  void dispose() {
    _staggerTimer?.cancel();
    super.dispose();
  }

  void reset() {
    _staggerTimer?.cancel();
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
      if (priority != null) {
        _visible.removeWhere((m) => m.id == priority.id);
        if (_visible.length >= maxVisible) _visible.removeLast();
        _visible.insert(0, priority);
        _revealedIds.add(priority.id);
        _priorityId = null;
      }
    }

    // Fill toward the front three if we have room and aren't mid-stagger.
    final staggering = _staggerTimer?.isActive ?? false;
    if (!staggering && _visible.length < maxVisible) {
      for (final m in _pool.take(maxVisible)) {
        if (_visible.length >= maxVisible) break;
        if (_visible.any((v) => v.id == m.id)) continue;
        _visible.add(m);
        _revealedIds.add(m.id);
      }
    }

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
  }

  List<Memo> _pick() {
    final n = math.min(maxVisible, _pool.length);
    return _pool.take(n).toList();
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
      final delayMs = 700 + _rng.nextInt(500);
      _staggerTimer = Timer(Duration(milliseconds: delayMs), _revealNext);
    }
  }
}
