import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-visit guest guide — host voice, interactive where it matters.
enum WelcomeStep {
  greet,
  presence,
  board,
  read,
  compose,
  /// Day-long traces + soft replies — one quiet beat.
  traces,
  music,
  nature,
  /// Guest may play their own music and keep resting.
  ownMusic,
  /// Theme grid — pick another place (still starts in desert).
  places,
  /// Parallel Plus opens more — not a forced theme tap.
  plus,
  farewell,
}

const _prefsKey = 'welcome_seen_v13';

class WelcomeHost extends ChangeNotifier {
  WelcomeStep? _step;
  bool _checking = true;
  bool _shouldOffer = false;
  bool _boardPanelOpen = false;
  /// Stays true while the overlay finishes its exit fade.
  bool _overlayMounted = false;
  /// True when the guest skipped ahead to farewell.
  bool _skippedEarly = false;

  WelcomeStep? get step => _step;
  bool get isActive => _step != null;
  /// Parent should keep [WelcomeOverlay] in the tree for exit animation.
  bool get wantsOverlay => _step != null || _overlayMounted;
  bool get isChecking => _checking;
  bool get skippedEarly => _skippedEarly;

  bool get awaitsBoardOpen => _step == WelcomeStep.board;
  bool get awaitsMusicTap => _step == WelcomeStep.music;
  bool get awaitsNatureSettingsTap => _step == WelcomeStep.nature;
  bool get awaitsPlacesTap => _step == WelcomeStep.places;

  bool get hideChrome =>
      _step == WelcomeStep.read || _step == WelcomeStep.compose;

  bool get guidesPanel =>
      _step == WelcomeStep.read || _step == WelcomeStep.compose;

  /// Show skip on every step except farewell (that screen already ends).
  bool get canSkip =>
      _step != null && _step != WelcomeStep.farewell;

  Future<void> prepare() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_prefsKey) ?? false;
      _checking = false;
      _shouldOffer = !seen;
      notifyListeners();
    } catch (_) {
      _checking = false;
      notifyListeners();
    }
  }

  void beginIfNeeded() {
    if (!_shouldOffer || _step != null) return;
    _shouldOffer = false;
    _overlayMounted = true;
    _step = WelcomeStep.greet;
    notifyListeners();
  }

  void advanceFromButton() {
    final step = _step;
    if (step == WelcomeStep.greet) {
      _go(WelcomeStep.presence);
    } else if (step == WelcomeStep.presence) {
      _go(WelcomeStep.board);
    } else if (step == WelcomeStep.traces) {
      _go(WelcomeStep.music);
    } else if (step == WelcomeStep.ownMusic) {
      _go(WelcomeStep.places);
    } else if (step == WelcomeStep.plus) {
      _go(WelcomeStep.farewell);
    } else if (step == WelcomeStep.farewell) {
      unawaited(_complete());
    } else if (step == WelcomeStep.read) {
      _go(WelcomeStep.compose);
    }
  }

  /// Jump to a short farewell that also explains how to replay.
  void skip() {
    if (!canSkip) return;
    _skippedEarly = true;
    _boardPanelOpen = false;
    _go(WelcomeStep.farewell);
  }

  void onBoardOpened() {
    if (_step != WelcomeStep.board) return;
    _boardPanelOpen = true;
    _go(WelcomeStep.read);
  }

  void onBoardClosed() {
    if (!_boardPanelOpen &&
        _step != WelcomeStep.read &&
        _step != WelcomeStep.compose &&
        _step != WelcomeStep.board) {
      return;
    }
    _boardPanelOpen = false;
    if (_step == WelcomeStep.read ||
        _step == WelcomeStep.compose ||
        _step == WelcomeStep.board) {
      _go(WelcomeStep.traces);
    }
  }

  void onReaderOpened() {}

  void onReaderClosed() {
    if (_step != WelcomeStep.read) return;
    _go(WelcomeStep.compose);
  }

  void onComposeTried() {}

  void onMusicTapped() {
    if (_step != WelcomeStep.music) return;
    _go(WelcomeStep.nature);
  }

  void onNatureTried() {
    if (_step != WelcomeStep.nature) return;
    _go(WelcomeStep.ownMusic);
  }

  void onPlacesOpened() {
    if (_step != WelcomeStep.places) return;
    _go(WelcomeStep.plus);
  }

  void _go(WelcomeStep next) {
    _step = next;
    notifyListeners();
  }

  Future<void> _complete() async {
    _step = null;
    _boardPanelOpen = false;
    _skippedEarly = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, true);
    } catch (_) {}
  }

  /// Called by the overlay after its exit fade finishes.
  void onOverlayDismissed() {
    if (!_overlayMounted) return;
    _overlayMounted = false;
    notifyListeners();
  }

  Future<void> replay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      await prefs.remove('welcome_seen_v1');
      await prefs.remove('welcome_seen_v2');
      await prefs.remove('welcome_seen_v3');
      await prefs.remove('welcome_seen_v4');
      await prefs.remove('welcome_seen_v5');
      await prefs.remove('welcome_seen_v6');
      await prefs.remove('welcome_seen_v7');
      await prefs.remove('welcome_seen_v8');
      await prefs.remove('welcome_seen_v9');
      await prefs.remove('welcome_seen_v10');
      await prefs.remove('welcome_seen_v11');
      await prefs.remove('welcome_seen_v12');
    } catch (_) {}
    _boardPanelOpen = false;
    _shouldOffer = false;
    _skippedEarly = false;
    _overlayMounted = true;
    _step = WelcomeStep.greet;
    notifyListeners();
  }
}
