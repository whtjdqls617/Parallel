import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parallel/scenes/star/star_scene.dart';

import '../audio/ambient_music.dart';
import '../memo/memo.dart';
import '../memo/memo_reader.dart';
import '../memo/memo_reply_inbox.dart';
import '../memo/memo_service.dart';
import '../notify/push_service.dart';
import '../presence/ambient_presence.dart';
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
import '../theme/space_palette.dart';
import '../welcome/welcome_host.dart';
import '../welcome/welcome_overlay.dart';
import '../welcome/welcome_scope.dart';

enum _SceneKind { desert, forest, ocean, space }

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
  /// Free tier starts in the desert; forest / ocean / space require Parallel Plus.
  _SceneKind _kind = _SceneKind.desert;
  final AmbientMusic _audio = AmbientMusic();
  final PresenceService _presence = PresenceService();
  final SubscriptionService _subscription = SubscriptionService.instance;
  final WelcomeHost _welcome = WelcomeHost();
  final GlobalKey _musicBarKey = GlobalKey();
  final GlobalKey _musicTitleKey = GlobalKey();
  final GlobalKey _themeBarKey = GlobalKey();
  bool _musicOn = false;
  /// User intent — music starts on by default; pause clears this.
  bool _musicWanted = true;
  int _presenceCount = 2;
  StreamSubscription<int>? _presenceSub;
  bool _openingPush = false;
  final MemoService _memos = MemoService();

  bool get _isPlus => _subscription.hasPlusAccess;

  bool get _needsPlus =>
      _kind == _SceneKind.forest ||
      _kind == _SceneKind.ocean ||
      _kind == _SceneKind.space;

  AmbienceScene get _ambience => switch (_kind) {
    _SceneKind.desert => AmbienceScene.desert,
    _SceneKind.forest => AmbienceScene.forest,
    _SceneKind.ocean => AmbienceScene.ocean,
    _SceneKind.space => AmbienceScene.space,
  };

  MemoTheme get _memoTheme => switch (_kind) {
    _SceneKind.desert => MemoTheme.desert,
    _SceneKind.forest => MemoTheme.forest,
    _SceneKind.ocean => MemoTheme.ocean,
    _SceneKind.space => MemoTheme.space,
  };

  Color get _canvas => switch (_kind) {
    _SceneKind.desert => DesertPalette.canvas,
    _SceneKind.forest => ForestPalette.canvas,
    _SceneKind.ocean => OceanPalette.canvas,
    _SceneKind.space => SpacePalette.canvas,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription.addListener(_onSubscriptionChanged);
    _welcome.addListener(_onWelcomeChanged);
    PushService.instance.addListener(_onPushOpen);
    _audio.onSongChanged = _onSongChanged;
    // Nature + theme music on by default (may need a gesture on some platforms).
    _startAmbience();
    unawaited(_joinPresence());
    unawaited(_prepareWelcome());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_drainPushOpen());
    });
  }

  void _onPushOpen() {
    unawaited(_drainPushOpen());
  }

  Future<void> _drainPushOpen() async {
    if (!mounted || _openingPush) return;
    final target = PushService.instance.consumePending();
    if (target == null) return;
    _openingPush = true;
    try {
      await _openFromPush(target);
    } finally {
      _openingPush = false;
      // Another push may have queued while we were opening.
      if (PushService.instance.pending != null) {
        unawaited(_drainPushOpen());
      }
    }
  }

  Future<void> _openFromPush(PushOpenTarget target) async {
    if (!mounted) return;

    final kind = switch (target.theme) {
      MemoTheme.desert => _SceneKind.desert,
      MemoTheme.forest => _SceneKind.forest,
      MemoTheme.ocean => _SceneKind.ocean,
      MemoTheme.space => _SceneKind.space,
    };

    if (_isLocked(kind)) {
      await showSubscriptionGate(
        context,
        reason: _gateReason(kind),
      );
      if (!mounted || !_isPlus) return;
    }

    if (_kind != kind) {
      await _selectScene(kind);
      if (!mounted) return;
      // Let the scene / board mount before opening the reader.
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
    }

    final memo = await _memos.fetchById(target.memoId);
    if (!mounted) return;
    if (memo == null || memo.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('그 흔적은 이미 사라졌어요.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (memo.isOwnedBy(_memos.currentUid) && memo.hasReply) {
      await MemoReplyInbox.instance.markSeen(memo);
    }

    await showMemoReader(
      context,
      memo: memo,
      theme: memo.theme,
      service: _memos,
      welcome: _welcome,
    );
  }

  Future<void> _prepareWelcome() async {
    await _welcome.prepare();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _welcome.beginIfNeeded();
  }

  void _onWelcomeChanged() {
    if (mounted) setState(() {});
  }

  void _onSongChanged() {
    if (!mounted) return;
    setState(() => _musicOn = _audio.isSongPlaying);
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

  Future<void> _startAmbience() async {
    try {
      await _audio.setScene(_ambience, restartSong: _musicWanted);
      await _audio.prefetchSongTracks();
      if (!mounted) return;
      setState(() => _musicOn = _audio.isSongPlaying);
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
        // Soft companions so an empty launch board doesn't feel abandoned.
        final next = AmbientPresence.display(
          live: count,
          theme: _memoTheme,
        );
        if (next == _presenceCount) return;
        setState(() => _presenceCount = next);
      },
      onError: (_) {},
    );
  }

  bool _isLocked(_SceneKind kind) =>
      (kind == _SceneKind.forest ||
          kind == _SceneKind.ocean ||
          kind == _SceneKind.space) &&
      !_isPlus;

  String _gateReason(_SceneKind kind) {
    final ended = _subscription.trialEnded ? '체험이 끝났어요. ' : '';
    return switch (kind) {
      _SceneKind.forest => '$ended숲은 Parallel Plus에서 함께 쉴 수 있어요.',
      _SceneKind.ocean => '$ended바다는 Parallel Plus에서 함께 쉴 수 있어요.',
      _SceneKind.space => '$ended별은 Parallel Plus에서 함께 쉴 수 있어요.',
      _SceneKind.desert => '',
    };
  }

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
      // Soft floor until the new theme's live count arrives.
      final theme = switch (kind) {
        _SceneKind.desert => MemoTheme.desert,
        _SceneKind.forest => MemoTheme.forest,
        _SceneKind.ocean => MemoTheme.ocean,
        _SceneKind.space => MemoTheme.space,
      };
      _presenceCount = AmbientPresence.display(live: 1, theme: theme);
    });

    // Cut old theme music first — don't wait on presence/network.
    try {
      await _audio.cutSongNow();
    } catch (_) {}

    _listenPresence();
    try {
      await _audio.setScene(_ambience, restartSong: _musicWanted);
      if (!mounted) return;
      setState(() => _musicOn = _audio.isSongPlaying);
    } catch (_) {}
    try {
      await _presence.enter(_memoTheme);
    } catch (_) {}
  }

  void _noteMusicGesture() {
    if (_welcome.awaitsMusicTap) _welcome.onMusicTapped();
  }

  Future<void> _toggleMusic() async {
    _noteMusicGesture();
    try {
      await _audio.setScene(_ambience);
      if (_audio.isSongPlaying) {
        _musicWanted = false;
        await _audio.pauseSong();
      } else {
        _musicWanted = true;
        await _audio.playSong();
      }
      if (!mounted) return;
      setState(() => _musicOn = _audio.isSongPlaying);
    } catch (_) {
      if (!mounted) return;
      setState(() => _musicOn = false);
    }
  }

  Future<void> _playPreviousTrack() async {
    _noteMusicGesture();
    try {
      await _audio.setScene(_ambience);
      await _audio.playPreviousSong();
      if (!mounted) return;
      setState(() => _musicOn = _audio.isSongPlaying);
    } catch (_) {}
  }

  Future<void> _playNextTrack() async {
    _noteMusicGesture();
    try {
      await _audio.setScene(_ambience);
      await _audio.playNextSong();
      if (!mounted) return;
      setState(() => _musicOn = _audio.isSongPlaying);
    } catch (_) {}
  }

  Future<void> _showNatureVolumeSheet() async {
    final guidingNature = _welcome.awaitsNatureLongPress;
    final scene = _ambience;
    final label = switch (_kind) {
      _SceneKind.desert => '사막',
      _SceneKind.forest => '숲',
      _SceneKind.ocean => '바다',
      _SceneKind.space => '별',
    };
    final isSilentTheme = scene == AmbienceScene.space;
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
                      isSilentTheme
                          ? '별 테마는 자연 소리 없이 고요하게 두어요'
                          : '이 테마에만 적용돼요',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    if (!isSilentTheme) ...[
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
                                activeTrackColor:
                                    Colors.white.withValues(alpha: 0.85),
                                inactiveTrackColor:
                                    Colors.white.withValues(alpha: 0.18),
                                thumbColor: Colors.white,
                                overlayColor:
                                    Colors.white.withValues(alpha: 0.12),
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
                    ] else
                      const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (guidingNature) _welcome.onNatureTried();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_joinPresence());
        unawaited(_subscription.refreshCustomerInfo());
        unawaited(PushService.instance.syncToken());
        unawaited(_drainPushOpen());
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
    _welcome.removeListener(_onWelcomeChanged);
    PushService.instance.removeListener(_onPushOpen);
    _audio.onSongChanged = null;
    _presenceSub?.cancel();
    unawaited(_presence.leave());
    _audio.dispose();
    _welcome.dispose();
    super.dispose();
  }

  Widget _sceneBody() => switch (_kind) {
    _SceneKind.desert => DesertScene(presenceCount: _presenceCount),
    _SceneKind.forest => ForestScene(presenceCount: _presenceCount),
    _SceneKind.ocean => OceanScene(presenceCount: _presenceCount),
    _SceneKind.space => StarScene(presenceCount: _presenceCount),
  };

  @override
  Widget build(BuildContext context) {
    return WelcomeScope(
      host: _welcome,
      child: Scaffold(
        backgroundColor: _canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _sceneBody(),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 14, 0),
                  child: KeyedSubtree(
                    key: _musicBarKey,
                    child: _ThemeMusicBar(
                      titleKey: _musicTitleKey,
                      title: _audio.songTitle ?? 'Music',
                      playing: _musicOn,
                      onPrev: _playPreviousTrack,
                      onPlayPause: _toggleMusic,
                      onNext: _playNextTrack,
                      onTitleLongPress: _showNatureVolumeSheet,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: KeyedSubtree(
                    key: _themeBarKey,
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
                            _Chip(
                              label: '별',
                              selected: _kind == _SceneKind.space,
                              locked: !_isPlus,
                              onTap: () => _selectScene(_SceneKind.space),
                            ),
                            // Temporary subscription test entry — remove later.
                            // Long-press replays the welcome guide.
                            _DebugSubButton(
                              onTap: () => showSubscriptionDebugSheet(context),
                              onLongPress: () => unawaited(_welcome.replay()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_welcome.wantsOverlay)
              WelcomeOverlay(
                host: _welcome,
                musicKey: _musicBarKey,
                musicTitleKey: _musicTitleKey,
                placesKey: _themeBarKey,
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeMusicBar extends StatelessWidget {
  const _ThemeMusicBar({
    required this.title,
    required this.playing,
    required this.onPrev,
    required this.onPlayPause,
    required this.onNext,
    this.onTitleLongPress,
    this.titleKey,
  });

  final String title;
  final bool playing;
  final VoidCallback onPrev;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback? onTitleLongPress;
  final Key? titleKey;

  static const _white = Color(0xEEFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.music_note_rounded, size: 15, color: _white),
        const SizedBox(width: 5),
        GestureDetector(
          onLongPress: onTitleLongPress,
          child: KeyedSubtree(
            key: titleKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        _MusicIconButton(
          icon: Icons.skip_previous_rounded,
          onTap: onPrev,
        ),
        _MusicIconButton(
          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onTap: onPlayPause,
        ),
        _MusicIconButton(
          icon: Icons.skip_next_rounded,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _MusicIconButton extends StatelessWidget {
  const _MusicIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Icon(icon, size: 22, color: const Color(0xEEFFFFFF)),
      ),
    );
  }
}

class _DebugSubButton extends StatelessWidget {
  const _DebugSubButton({
    required this.onTap,
    this.onLongPress,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
