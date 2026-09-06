import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_music_catalog.dart';

enum AmbienceScene { desert, forest, ocean, space, rain, fire }

/// Nature bed (on by default) + optional song, mixed together.
///
/// Nature beds stay local. Theme songs stream from Firebase Storage when
/// available, with a local asset fallback for development.
class AmbientMusic {
  AmbientMusic({ThemeMusicCatalog? catalog})
    : _catalog = catalog ?? ThemeMusicCatalog();

  static const songPath = 'audio/maeumeul_deuryeoyo_mr.mp3';
  static const desertNaturePath = 'audio/nature_desert.wav';
  static const forestNaturePath = 'audio/nature_forest.wav';
  static const oceanNaturePath = 'audio/nature_ocean.wav';
  static const spaceNaturePath = 'audio/nature_space.wav';
  static const rainNaturePath = 'audio/nature_rain.wav'; // cabin drone (theme key: rain)
  static const fireNaturePath = 'audio/nature_fire.wav';

  static const songVolume = 0.30;
  /// Nature beds need to cut through earphones + song.
  static const natureVolumeSolo = 0.48;
  static const natureVolumeWithSong = 0.34;

  /// Keep in sync with generated nature WAVs.
  static const _desertBedLength = Duration(milliseconds: 25200);
  static const _forestBedLength = Duration(milliseconds: 25000);
  static const _oceanBedLength = Duration(milliseconds: 192000);
  static const _spaceBedLength = Duration(milliseconds: 28000);
  static const _rainBedLength = Duration(milliseconds: 28000);
  static const _fireBedLength = Duration(milliseconds: 25000);

  /// Overlap at the join — no hard stop (avoids desert crackle).
  static const _seamCrossfade = Duration(milliseconds: 1400);
  /// Cabin drone: longer equal-power handoff — continuous bed, no tick.
  static const _rainSeamCrossfade = Duration(milliseconds: 4000);
  /// Ocean: long equal-power handoff on quiet bed — never a hard cut.
  static const _oceanSeamCrossfade = Duration(milliseconds: 6000);
  static const _cycleMargin = Duration(milliseconds: 300);
  /// Short ease in — present right away (avoids click without a slow swell).
  static const _fadeIn = Duration(milliseconds: 180);
  /// Ocean needs a longer ease so the bed never pops in/out.
  static const _oceanFadeIn = Duration(milliseconds: 700);
  /// Cabin drone: slower ease so engine bed doesn't click on start.
  static const _rainFadeIn = Duration(milliseconds: 900);
  static const _songCutFade = Duration(milliseconds: 280);

  static const _prefsPrefix = 'nature_gain_';

  static bool _audioContextReady = false;

  final ThemeMusicCatalog _catalog;

  AudioPlayer? _natureA;
  AudioPlayer? _natureB;
  AudioPlayer? _activeNature;
  AudioPlayer? _songA;
  AudioPlayer? _songB;
  AudioPlayer? _activeSong;
  StreamSubscription<void>? _songCompleteSubA;
  StreamSubscription<void>? _songCompleteSubB;
  String? _preloadedStem;

  AmbienceScene? _natureScene;
  bool _songStarted = false;
  bool _disposed = false;
  bool _cycling = false;
  /// When true, finished tracks advance through the suite forever.
  bool _songSuiteActive = false;
  /// True while swapping players — ignore complete events from pause/stop.
  bool _songSwitching = false;
  Timer? _loopTimer;
  int _natureEpoch = 0;

  List<ThemeTrack> _songTracks = [];
  int _songIndex = 0;
  AmbienceScene? _songTracksScene;

  /// Fired when the current song title / playing state may have changed.
  void Function()? onSongChanged;

  /// Display title for the current theme track (e.g. Vesper).
  String? get songTitle {
    if (_songTracks.isEmpty) return null;
    final i = _songIndex.clamp(0, _songTracks.length - 1);
    return _songTracks[i].title;
  }

  int get songTrackCount => _songTracks.length;

  /// Per-theme user gain (0 = mute, 1 = calibrated default, up to 1.5).
  final Map<AmbienceScene, double> _natureGain = {
    AmbienceScene.desert: 1.0,
    AmbienceScene.forest: 1.0,
    AmbienceScene.ocean: 1.0,
    // Stars: silence by default — open-field wind doesn't match the sky.
    AmbienceScene.space: 0.0,
    AmbienceScene.rain: 1.0,
    AmbienceScene.fire: 1.0,
  };

  bool _prefsLoaded = false;

  static Future<void> ensureMixWithOthers() async {
    if (_audioContextReady) return;
    final ctx = AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build();
    await AudioPlayer.global.setAudioContext(ctx);
    _audioContextReady = true;
  }

  Future<void> _ensurePrefs() async {
    if (_prefsLoaded) return;
    _prefsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final scene in AmbienceScene.values) {
        final v = prefs.getDouble('$_prefsPrefix${scene.name}');
        if (v != null) {
          _natureGain[scene] = v.clamp(0.0, 1.5);
        }
      }
    } catch (_) {}
  }

  double natureGain(AmbienceScene scene) => _natureGain[scene] ?? 1.0;

  /// 0 = silent, 1 = default calibrated level, up to 1.5 = louder.
  Future<void> setNatureGain(AmbienceScene scene, double gain) async {
    final g = gain.clamp(0.0, 1.5);
    _natureGain[scene] = g;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_prefsPrefix${scene.name}', g);
    } catch (_) {}
    if (_natureScene == scene && !_cycling) {
      await _applyNatureVolume();
    }
  }

  Future<AudioPlayer> _createPlayer() async {
    await ensureMixWithOthers();
    final player = AudioPlayer();
    await player.setAudioContext(
      AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build(),
    );
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setPlayerMode(PlayerMode.mediaPlayer);
    await player.setVolume(0);
    return player;
  }

  Future<void> _ensurePlayers() async {
    _natureA ??= await _createPlayer();
    _natureB ??= await _createPlayer();
    _activeNature ??= _natureA;
  }

  bool get isSongPlaying => _activeSong?.state == PlayerState.playing;

  double get _natureVolume {
    final base = isSongPlaying ? natureVolumeWithSong : natureVolumeSolo;
    final scene = _natureScene;
    var calibrated = base;
    if (scene == AmbienceScene.ocean) {
      // Ocean WAV is already loud in peaks — keep a mild duck, not a heavy one.
      calibrated = base * 0.78;
    } else if (scene == AmbienceScene.desert) {
      calibrated = (base * 1.35).clamp(0.0, 1.0);
    } else if (scene == AmbienceScene.space) {
      // Star theme is silence — no nature bed.
      calibrated = 0;
    } else if (scene == AmbienceScene.rain) {
      calibrated = base * 0.92;
    } else if (scene == AmbienceScene.fire) {
      // Wood pops need headroom over theme BGM; bed is sparse, not a hiss bed.
      calibrated = (base * 1.15).clamp(0.0, 1.0);
    }
    final gain = scene == null ? 1.0 : natureGain(scene);
    return (calibrated * gain).clamp(0.0, 1.0);
  }

  /// Desert / forest / ocean all use dual-player equal-power handoff
  /// so the loop join never hard-cuts (ocean WAV is rest-aligned for a quiet fade).
  bool _usesNativeLoop(AmbienceScene scene) => false;

  Duration _seamFor(AmbienceScene scene) => switch (scene) {
    AmbienceScene.ocean => _oceanSeamCrossfade,
    AmbienceScene.rain => _rainSeamCrossfade,
    _ => _seamCrossfade,
  };

  Duration _fadeInFor(AmbienceScene scene) => switch (scene) {
    AmbienceScene.ocean => _oceanFadeIn,
    AmbienceScene.rain => _rainFadeIn,
    _ => _fadeIn,
  };

  String _naturePath(AmbienceScene scene) => switch (scene) {
    AmbienceScene.desert => desertNaturePath,
    AmbienceScene.forest => forestNaturePath,
    AmbienceScene.ocean => oceanNaturePath,
    AmbienceScene.space => spaceNaturePath,
    AmbienceScene.rain => rainNaturePath,
    AmbienceScene.fire => fireNaturePath,
  };

  Duration _bedLength(AmbienceScene scene) => switch (scene) {
    AmbienceScene.desert => _desertBedLength,
    AmbienceScene.forest => _forestBedLength,
    AmbienceScene.ocean => _oceanBedLength,
    AmbienceScene.space => _spaceBedLength,
    AmbienceScene.rain => _rainBedLength,
    AmbienceScene.fire => _fireBedLength,
  };

  Future<void> setScene(
    AmbienceScene scene, {
    bool restartSong = false,
  }) async {
    if (_disposed) return;

    final sceneChanged = _natureScene != scene;
    Future<void>? songRestart;

    if (sceneChanged) {
      // Mute old BGM before any prefs/network work.
      await _stopSongImmediate();
      _songTracks = [];
      _songTracksScene = null;
      _songIndex = 0;
      _songStarted = false;
      _preloadedStem = null;
      _natureScene = scene;
      if (restartSong) {
        // Start new theme BGM without waiting for the nature bed swap.
        songRestart = playSong(forceReload: true);
      }
    }

    await _ensurePrefs();

    await _ensurePlayers();
    final active = _activeNature!;

    // Stars: no nature bed — stop any leftover loop and keep quiet.
    if (scene == AmbienceScene.space) {
      final epoch = ++_natureEpoch;
      _loopTimer?.cancel();
      _cycling = false;
      final standby = identical(active, _natureA) ? _natureB! : _natureA!;
      await active.setVolume(0);
      await standby.setVolume(0);
      try {
        await active.stop();
      } catch (_) {}
      try {
        await standby.stop();
      } catch (_) {}
      if (songRestart != null) await songRestart;
      if (_disposed || epoch != _natureEpoch) return;
      return;
    }

    if (!sceneChanged && _natureScene == scene) {
      if (active.state != PlayerState.playing) {
        await active.setVolume(0);
        if (_usesNativeLoop(scene)) {
          await active.setReleaseMode(ReleaseMode.loop);
        } else {
          await active.setReleaseMode(ReleaseMode.stop);
        }
        await active.resume();
        await _fade(
          active,
          from: 0,
          to: _natureVolume,
          ms: _fadeInFor(scene).inMilliseconds,
        );
        if (!_usesNativeLoop(scene)) _scheduleCycle();
      } else {
        await _applyNatureVolume();
      }
      return;
    }

    final epoch = ++_natureEpoch;
    _loopTimer?.cancel();
    _cycling = false;

    final standby = identical(active, _natureA) ? _natureB! : _natureA!;
    await active.setVolume(0);
    await standby.setVolume(0);
    try {
      await active.stop();
    } catch (_) {}
    try {
      await standby.stop();
    } catch (_) {}

    // _natureScene already set when sceneChanged; keep in sync otherwise.
    _natureScene = scene;
    final path = _naturePath(scene);
    await active.setVolume(0);
    if (_usesNativeLoop(scene)) {
      await active.setReleaseMode(ReleaseMode.loop);
    } else {
      await active.setReleaseMode(ReleaseMode.stop);
    }
    await active.play(AssetSource(path));
    if (_disposed || epoch != _natureEpoch) return;

    await _fade(
      active,
      from: 0,
      to: _natureVolume,
      ms: _fadeInFor(scene).inMilliseconds,
    );
    if (_disposed || epoch != _natureEpoch) return;
    if (_usesNativeLoop(scene)) {
      _loopTimer?.cancel();
    } else {
      _scheduleCycle();
    }

    if (songRestart != null) await songRestart;
  }

  /// Hard-stop theme BGM with no fade (used on scene change).
  Future<void> _stopSongImmediate() async {
    _songSuiteActive = false;
    _songStarted = false;
    _preloadedStem = null;
    // Mute first — perceived cut is instant even if stop() is slow.
    for (final player in [_activeSong, _songA, _songB]) {
      if (player == null) continue;
      try {
        player.setVolume(0);
      } catch (_) {}
    }
    onSongChanged?.call();
    for (final player in [_activeSong, _songA, _songB]) {
      if (player == null) continue;
      try {
        await player.stop();
      } catch (_) {}
    }
  }

  /// Public instant mute+stop for UI theme switches.
  Future<void> cutSongNow() => _stopSongImmediate();

  void _scheduleCycle() {
    _loopTimer?.cancel();
    final scene = _natureScene;
    if (_disposed || scene == null || _activeNature == null) return;
    if (_usesNativeLoop(scene)) return;

    final wait = _bedLength(scene) - _seamFor(scene) - _cycleMargin;
    if (wait <= Duration.zero) return;
    _loopTimer = Timer(wait, () {
      if (_disposed || _natureScene != scene) return;
      unawaited(_seamCrossfadeCycle());
    });
  }

  /// Start the next pass under the current one, then hand off — no crackle.
  Future<void> _seamCrossfadeCycle() async {
    if (_disposed || _cycling) return;
    final scene = _natureScene;
    if (scene == null || _usesNativeLoop(scene)) return;

    await _ensurePlayers();
    final outgoing = _activeNature!;
    final incoming = identical(outgoing, _natureA) ? _natureB! : _natureA!;

    _cycling = true;
    final epoch = _natureEpoch;
    final path = _naturePath(scene);
    final target = _natureVolume;
    final ms = _seamFor(scene).inMilliseconds;

    try {
      await incoming.setReleaseMode(ReleaseMode.stop);
      await incoming.setVolume(0);
      await incoming.play(AssetSource(path));
      if (_disposed || epoch != _natureEpoch) return;

      final steps = switch (scene) {
        AmbienceScene.ocean => 48,
        AmbienceScene.rain => 36,
        _ => 20,
      };
      final frame = Duration(milliseconds: (ms / steps).round().clamp(20, 80));
      for (var i = 1; i <= steps; i++) {
        if (_disposed || epoch != _natureEpoch) return;
        final t = i / steps;
        final s = t * t * (3 - 2 * t);
        final outGain = math.cos(s * math.pi * 0.5);
        final inGain = math.sin(s * math.pi * 0.5);
        await outgoing.setVolume(target * outGain);
        await incoming.setVolume(target * inGain);
        await Future<void>.delayed(frame);
      }

      await outgoing.setVolume(0);
      try {
        await outgoing.stop();
      } catch (_) {}
      _activeNature = incoming;
      await incoming.setVolume(target);
    } catch (_) {
      // Retry next cycle.
    } finally {
      _cycling = false;
    }

    if (!_disposed && _natureScene == scene) {
      _scheduleCycle();
    }
  }

  Future<void> _fade(
    AudioPlayer player, {
    required double from,
    required double to,
    required int ms,
  }) async {
    if (_disposed) return;
    const steps = 12;
    final frame = Duration(milliseconds: (ms / steps).round().clamp(12, 40));
    for (var i = 1; i <= steps; i++) {
      if (_disposed) return;
      final t = i / steps;
      final s = t * t * (3 - 2 * t);
      await player.setVolume(from + (to - from) * s);
      await Future<void>.delayed(frame);
    }
    if (!_disposed) await player.setVolume(to);
  }

  Future<void> _applyNatureVolume() async {
    if (_cycling) return;
    await _activeNature?.setVolume(_natureVolume);
  }

  Future<void> _ensureSongPlayers() async {
    _songA ??= await _createSongPlayer(isA: true);
    _songB ??= await _createSongPlayer(isA: false);
    _activeSong ??= _songA;
  }

  Future<AudioPlayer> _createSongPlayer({required bool isA}) async {
    final player = await _createPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(0);
    final sub = player.onPlayerComplete.listen((_) {
      if (_disposed || !_songSuiteActive || _songSwitching) return;
      if (!identical(player, _activeSong)) return;
      unawaited(_advanceSongSuite());
    });
    if (isA) {
      _songCompleteSubA = sub;
    } else {
      _songCompleteSubB = sub;
    }
    return player;
  }

  AudioPlayer _standbySong(AudioPlayer active) =>
      identical(active, _songA) ? _songB! : _songA!;

  Future<void> _advanceSongSuite() async {
    if (_disposed || !_songSuiteActive || _songSwitching) return;
    final scene = _natureScene;
    if (scene == null) return;
    await _ensureSongTracks(scene);
    if (_songTracks.isEmpty) return;
    final next = (_songIndex + 1) % _songTracks.length;
    await _playTrackAt(next);
  }

  Future<void> prefetchSongTracks() async {
    final scene = _natureScene;
    if (scene == null || _disposed) return;
    await _ensureSongTracks(scene);
  }

  Future<void> playSong({bool forceReload = false}) async {
    if (_disposed) return;
    await _ensureSongPlayers();
    final player = _activeSong!;

    if (!forceReload &&
        _songStarted &&
        player.state != PlayerState.stopped &&
        player.state != PlayerState.completed) {
      _songSuiteActive = true;
      await player.setVolume(songVolume);
      await player.resume();
      await _applyNatureVolume();
      onSongChanged?.call();
      return;
    }

    final scene = _natureScene;
    if (scene != null) {
      if (forceReload) {
        _songTracks = [];
        _songTracksScene = null;
        _catalog.clearCacheFor(scene);
      }
      await _ensureSongTracks(scene);
    }
    if (_songTracks.isNotEmpty) {
      await _playTrackAt(_suiteStartIndex());
      return;
    }

    // No theme suite available — stay quiet (never play another theme's MR).
    debugPrint('AmbientMusic: no suite tracks for $scene');
    _songStarted = false;
    _songSuiteActive = false;
    onSongChanged?.call();
  }

  Future<void> _playTrackAt(int index) async {
    if (_disposed) return;
    await _ensureSongPlayers();
    final scene = _natureScene;
    if (scene != null) await _ensureSongTracks(scene);
    if (_songTracks.isEmpty) return;

    _songIndex = index.clamp(0, _songTracks.length - 1);
    final track = _songTracks[_songIndex];
    final active = _activeSong!;
    final standby = _standbySong(active);

    _songSwitching = true;
    _songSuiteActive = false;
    await active.setReleaseMode(ReleaseMode.stop);
    await standby.setReleaseMode(ReleaseMode.stop);

    try {
      await active.setVolume(0);
      await active.pause();
    } catch (_) {}
    try {
      await standby.setVolume(0);
      await standby.pause();
    } catch (_) {}

    try {
      await standby.setVolume(songVolume);
      await standby.play(UrlSource(track.uri.toString()));
      _activeSong = standby;
      _preloadedStem = null;
      _songStarted = true;
      _songSuiteActive = true;
      debugPrint(
        'AmbientMusic play [${_songIndex + 1}/${_songTracks.length}] '
        '${track.fileStem}',
      );
      await _applyNatureVolume();
      onSongChanged?.call();
      unawaited(_preloadNeighbor());
    } catch (e) {
      debugPrint('AmbientMusic play failed ${track.fileStem}: $e');
      _songStarted = false;
      _songSuiteActive = false;
      onSongChanged?.call();
    } finally {
      // Absorb late complete events from pause/stop during the swap.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _songSwitching = false;
    }
  }

  /// Warm the next track on the idle player so skips feel instant.
  Future<void> _preloadNeighbor() async {
    if (_disposed || _songTracks.length < 2) return;
    final active = _activeSong;
    if (active == null) return;
    final standby = _standbySong(active);
    final nextIndex = (_songIndex + 1) % _songTracks.length;
    final track = _songTracks[nextIndex];
    if (_preloadedStem == track.fileStem) return;
    try {
      await standby.setVolume(0);
      await standby.setSource(UrlSource(track.uri.toString()));
      try {
        await standby.seek(Duration.zero);
      } catch (_) {}
      await standby.pause();
      if (_disposed) return;
      _preloadedStem = track.fileStem;
    } catch (_) {
      _preloadedStem = null;
    }
  }

  Future<void> playNextSong() async {
    if (_disposed) return;
    final scene = _natureScene;
    if (scene == null) return;
    await _ensureSongTracks(scene);
    if (_songTracks.isEmpty) {
      await playSong(forceReload: true);
      return;
    }
    final next = (_songIndex + 1) % _songTracks.length;
    await _playTrackAt(next);
  }

  Future<void> playPreviousSong() async {
    if (_disposed) return;
    final scene = _natureScene;
    if (scene == null) return;
    await _ensureSongTracks(scene);
    if (_songTracks.isEmpty) {
      await playSong(forceReload: true);
      return;
    }
    var prev = _songIndex - 1;
    if (prev < 0) prev = _songTracks.length - 1;
    await _playTrackAt(prev);
  }

  Future<void> _ensureSongTracks(AmbienceScene scene) async {
    if (_songTracksScene != scene || _songTracks.isEmpty) {
      try {
        _catalog.clearCacheFor(scene);
        _songTracks = await _catalog.tracksFor(scene);
      } catch (e) {
        debugPrint('AmbientMusic tracks load failed: $e');
        _songTracks = [];
      }
      _songTracksScene = scene;
      _songIndex = _suiteStartIndex();
      _preloadedStem = null;
    }
  }

  /// Index of vesper (or first track if vesper is missing).
  int _suiteStartIndex() {
    if (_songTracks.isEmpty) return 0;
    final i = _songTracks.indexWhere(
      (t) => ThemeMusicCatalog.suiteRank(t.fileStem) == 0,
    );
    return i >= 0 ? i : 0;
  }

  Future<void> pauseSong() async {
    if (_disposed) return;
    _songSuiteActive = false;
    final player = _activeSong;
    if (player != null && player.state == PlayerState.playing) {
      await _fade(
        player,
        from: songVolume,
        to: 0,
        ms: _songCutFade.inMilliseconds,
      );
      await player.pause();
    }
    await _applyNatureVolume();
    onSongChanged?.call();
  }

  Future<void> toggleSong() async {
    if (_disposed) return;
    if (isSongPlaying) {
      await pauseSong();
    } else {
      await playSong();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _songSuiteActive = false;
    _loopTimer?.cancel();
    _loopTimer = null;
    _natureScene = null;
    _songTracks = [];
    _songTracksScene = null;
    _preloadedStem = null;
    await _songCompleteSubA?.cancel();
    await _songCompleteSubB?.cancel();
    _songCompleteSubA = null;
    _songCompleteSubB = null;
    final a = _natureA;
    final b = _natureB;
    final songA = _songA;
    final songB = _songB;
    _natureA = null;
    _natureB = null;
    _activeNature = null;
    _songA = null;
    _songB = null;
    _activeSong = null;
    _songStarted = false;
    await a?.dispose();
    await b?.dispose();
    await songA?.dispose();
    await songB?.dispose();
  }
}
