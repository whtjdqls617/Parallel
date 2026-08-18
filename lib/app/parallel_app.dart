import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/ambient_music.dart';
import '../memo/memo.dart';
import '../presence/presence_service.dart';
import '../scenes/desert/desert_scene.dart';
import '../scenes/forest/forest_scene.dart';
import '../scenes/ocean/ocean_scene.dart';
import '../subscription/subscription_debug_sheet.dart';
import '../subscription/subscription_gate.dart';
import '../subscription/subscription_service.dart';
import '../theme/desert_palette.dart';
import '../theme/forest_palette.dart';
import '../theme/ocean_palette.dart';

enum _SceneKind { desert, forest, ocean }

class ParallelApp extends StatelessWidget {
  const ParallelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parallel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const _ScenePicker(),
    );
  }
}

/// Temporary — swap themes while iterating. Remove when a real picker exists.
class _ScenePicker extends StatefulWidget {
  const _ScenePicker();

  @override
  State<_ScenePicker> createState() => _ScenePickerState();
}

class _ScenePickerState extends State<_ScenePicker>
    with WidgetsBindingObserver {
  /// Free tier starts in the desert; forest & ocean require Parallel Plus.
  _SceneKind _kind = _SceneKind.desert;
  final AmbientMusic _audio = AmbientMusic();
  final PresenceService _presence = PresenceService();
  final SubscriptionService _subscription = SubscriptionService.instance;
  bool _musicOn = false;
  int _presenceCount = 0;
  StreamSubscription<int>? _presenceSub;

  bool get _isPlus => _subscription.isSubscribed;

  bool get _needsPlus =>
      _kind == _SceneKind.forest || _kind == _SceneKind.ocean;

  AmbienceScene get _ambience => switch (_kind) {
    _SceneKind.desert => AmbienceScene.desert,
    _SceneKind.forest => AmbienceScene.forest,
    _SceneKind.ocean => AmbienceScene.ocean,
  };

  MemoTheme get _memoTheme => switch (_kind) {
    _SceneKind.desert => MemoTheme.desert,
    _SceneKind.forest => MemoTheme.forest,
    _SceneKind.ocean => MemoTheme.ocean,
  };

  Color get _canvas => switch (_kind) {
    _SceneKind.desert => DesertPalette.canvas,
    _SceneKind.forest => ForestPalette.canvas,
    _SceneKind.ocean => OceanPalette.canvas,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription.addListener(_onSubscriptionChanged);
    // Nature bed on by default; may be blocked until first gesture on some platforms.
    _startNature();
    unawaited(_joinPresence());
  }

  void _onSubscriptionChanged() {
    if (!mounted) return;
    // Drop back to desert if Plus lapses while on a premium scene.
    if (!_isPlus && _needsPlus) {
      unawaited(_selectScene(_SceneKind.desert));
      return;
    }
    setState(() {});
  }

  Future<void> _startNature() async {
    try {
      await _audio.setScene(_ambience);
    } catch (_) {
      // Retry on next scene tap / song tap.
    }
  }

  Future<void> _joinPresence() async {
    try {
      await _presence.enter(_memoTheme);
      _listenPresence();
    } catch (_) {
      // Keep local fallback count of 1.
    }
  }

  void _listenPresence() {
    _presenceSub?.cancel();
    _presenceSub = _presence.watchCount(_memoTheme).listen(
      (count) {
        if (!mounted) return;
        if (count == _presenceCount) return;
        setState(() => _presenceCount = count);
      },
      onError: (_) {},
    );
  }

  bool _isLocked(_SceneKind kind) =>
      (kind == _SceneKind.forest || kind == _SceneKind.ocean) && !_isPlus;

  String _gateReason(_SceneKind kind) => switch (kind) {
    _SceneKind.forest => '숲은 Parallel Plus에서 함께 쉴 수 있어요.',
    _SceneKind.ocean => '바다는 Parallel Plus에서 함께 쉴 수 있어요.',
    _SceneKind.desert => '',
  };

  Future<void> _selectScene(_SceneKind kind) async {
    if (kind == _kind) return;
    if (_isLocked(kind)) {
      await showSubscriptionGate(
        context,
        reason: _gateReason(kind),
      );
      return;
    }

    setState(() {
      _kind = kind;
      // Hide the number until the new theme's live count arrives.
      _presenceCount = 0;
    });
    _listenPresence();
    try {
      await _presence.enter(_memoTheme);
    } catch (_) {}
    try {
      await _audio.setScene(_ambience);
    } catch (_) {}
  }

  Future<void> _toggleMusic() async {
    try {
      // Unlock / keep nature going if autoplay was blocked earlier.
      await _audio.setScene(_ambience);
      await _audio.toggleSong();
      if (!mounted) return;
      setState(() => _musicOn = _audio.isSongPlaying);
    } catch (_) {
      if (!mounted) return;
      setState(() => _musicOn = false);
    }
  }

  Future<void> _showNatureVolumeSheet() async {
    final scene = _ambience;
    final label = switch (_kind) {
      _SceneKind.desert => '사막',
      _SceneKind.forest => '숲',
      _SceneKind.ocean => '바다',
    };
    var gain = _audio.natureGain(scene);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C2228),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: StatefulBuilder(
              builder: (context, setSheet) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '자연 소리 · $label',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 16,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '이 테마에만 적용돼요',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(
                          Icons.volume_mute_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.white.withValues(alpha: 0.85),
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                              thumbColor: Colors.white,
                              overlayColor: Colors.white.withValues(alpha: 0.12),
                              trackHeight: 2.5,
                            ),
                            child: Slider(
                              value: gain.clamp(0.0, 1.5),
                              min: 0,
                              max: 1.5,
                              onChanged: (v) {
                                setSheet(() => gain = v);
                                unawaited(_audio.setNatureGain(scene, v));
                              },
                            ),
                          ),
                        ),
                        Icon(
                          Icons.volume_up_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_joinPresence());
        unawaited(_subscription.refreshCustomerInfo());
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_presence.leave());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.removeListener(_onSubscriptionChanged);
    _presenceSub?.cancel();
    unawaited(_presence.leave());
    _audio.dispose();
    super.dispose();
  }

  Widget _sceneBody() => switch (_kind) {
    _SceneKind.desert => DesertScene(presenceCount: _presenceCount),
    _SceneKind.forest => ForestScene(presenceCount: _presenceCount),
    _SceneKind.ocean => OceanScene(presenceCount: _presenceCount),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _sceneBody(),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Chip(
                          label: '사막',
                          selected: _kind == _SceneKind.desert,
                          onTap: () => _selectScene(_SceneKind.desert),
                        ),
                        _Chip(
                          label: '숲',
                          selected: _kind == _SceneKind.forest,
                          locked: !_isPlus,
                          onTap: () => _selectScene(_SceneKind.forest),
                        ),
                        _Chip(
                          label: '바다',
                          selected: _kind == _SceneKind.ocean,
                          locked: !_isPlus,
                          onTap: () => _selectScene(_SceneKind.ocean),
                        ),
                        _MusicToggle(
                          on: _musicOn,
                          onTap: _toggleMusic,
                          onLongPress: _showNatureVolumeSheet,
                        ),
                        // Temporary subscription test entry — remove later.
                        _DebugSubButton(
                          onTap: () => showSubscriptionDebugSheet(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugSubButton extends StatelessWidget {
  const _DebugSubButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(
          Icons.workspace_premium_rounded,
          size: 18,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.92)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 2,
                color: selected
                    ? const Color(0xFF2A2A2A)
                    : Colors.white.withValues(alpha: locked ? 0.55 : 0.85),
              ),
            ),
            if (locked) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MusicToggle extends StatelessWidget {
  const _MusicToggle({
    required this.on,
    required this.onTap,
    this.onLongPress,
  });

  final bool on;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on
              ? Colors.white.withValues(alpha: 0.92)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          size: 18,
          color: on
              ? const Color(0xFF2A2A2A)
              : Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
