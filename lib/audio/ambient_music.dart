import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_music_catalog.dart';

enum AmbienceScene { desert, forest, ocean }

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

  static const songVolume = 0.35;
  static const natureVolumeSolo = 0.30;
  static const natureVolumeWithSong = 0.16;

  /// Keep in sync with generated nature WAVs.
  static const _desertBedLength = Duration(milliseconds: 25200);
  static const _forestBedLength = Duration(milliseconds: 25000);
  static const _oceanBedLength = Duration(milliseconds: 192000);

  /// Overlap at the join — no hard stop (avoids desert crackle).
  static const _seamCrossfade = Duration(milliseconds: 1400);
  /// Ocean: long equal-power handoff on quiet bed — never a hard cut.
  static const _oceanSeamCrossfade = Duration(milliseconds: 6000);
  static const _cycleMargin = Duration(milliseconds: 300);
  /// Short ease in — present right away (avoids click without a slow swell).
  static const _fadeIn = Duration(milliseconds: 180);
  /// Ocean needs a longer ease so the bed never pops in/out.
  static const _oceanFadeIn = Duration(milliseconds: 700);
  static const _songCutFade = Duration(milliseconds: 280);

  static const _prefsPrefix = 'nature_gain_';

  static bool _audioContextReady = false;

  final ThemeMusicCatalog _catalog;

  AudioPlayer? _natureA;
  AudioPlayer? _natureB;
  AudioPlayer? _activeNature;
  AudioPlayer? _song;

  AmbienceScene? _natureScene;
  bool _songStarted = false;
  bool _disposed = false;
  bool _cycling = false;
  Timer? _loopTimer;
  int _natureEpoch = 0;

  /// Per-theme user gain (0 = mute, 1 = calibrated default, up to 1.5).
  final Map<AmbienceScene, double> _natureGain = {
    AmbienceScene.desert: 1.0,
    AmbienceScene.forest: 1.0,
    AmbienceScene.ocean: 1.0,
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

  bool get isSongPlaying => _song?.state == PlayerState.playing;

  double get _natureVolume {
    final base = isSongPlaying ? natureVolumeWithSong : natureVolumeSolo;
    final scene = _natureScene;
    var calibrated = base;
    if (scene == AmbienceScene.ocean) {
      calibrated = base * 0.52;
    } else if (scene == AmbienceScene.desert) {
      calibrated = (base * 1.45).clamp(0.0, 1.0);
    }
    final gain = scene == null ? 1.0 : natureGain(scene);
    return (calibrated * gain).clamp(0.0, 1.0);
  }

  /// Desert / forest / ocean all use dual-player equal-power handoff
  /// so the loop join never hard-cuts (ocean WAV is rest-aligned for a quiet fade).
  bool _usesNativeLoop(AmbienceScene scene) => false;

  Duration _seamFor(AmbienceScene scene) =>
      scene == AmbienceScene.ocean ? _oceanSeamCrossfade : _seamCrossfade;

  Duration _fadeInFor(AmbienceScene scene) =>
      scene == AmbienceScene.ocean ? _oceanFadeIn : _fadeIn;

  String _naturePath(AmbienceScene scene) => switch (scene) {
    AmbienceScene.desert => desertNaturePath,
    AmbienceScene.forest => forestNaturePath,
    AmbienceScene.ocean => oceanNaturePath,
  };

  Duration _bedLength(AmbienceScene scene) => switch (scene) {
    AmbienceScene.desert => _desertBedLength,
    AmbienceScene.forest => _forestBedLength,
    AmbienceScene.ocean => _oceanBedLength,
  };

  Future<void> setScene(AmbienceScene scene) async {
    if (_disposed) return;
    await _ensurePrefs();

    final sceneChanged = _natureScene != scene;
    final songWasPlaying = isSongPlaying;

    await _ensurePlayers();
    final active = _activeNature!;

    if (_natureScene == scene) {
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

    if (sceneChanged && songWasPlaying) {
      _songStarted = false;
      await playSong();
    }
  }

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

      final steps = scene == AmbienceScene.ocean ? 48 : 20;
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

  Future<void> playSong() async {
    if (_disposed) return;
    final scene = _natureScene;
    final player = _song ??= await _createPlayer();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(songVolume);

    if (_songStarted && player.state != PlayerState.stopped) {
      await player.resume();
      await _applyNatureVolume();
      return;
    }

    final source = await _songSourceFor(scene);
    await player.play(source);
    _songStarted = true;
    await _applyNatureVolume();
  }

  Future<Source> _songSourceFor(AmbienceScene? scene) async {
    if (scene != null) {
      try {
        final uri = await _catalog.resolveTrack(scene);
        if (uri != null) {
          return UrlSource(uri.toString());
        }
      } catch (_) {
        // Fall through to local asset.
      }
    }
    return AssetSource(songPath);
  }

  Future<void> pauseSong() async {
    if (_disposed) return;
    final player = _song;
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
    _loopTimer?.cancel();
    _loopTimer = null;
    _natureScene = null;
    final a = _natureA;
    final b = _natureB;
    final song = _song;
    _natureA = null;
    _natureB = null;
    _activeNature = null;
    _song = null;
    _songStarted = false;
    await a?.dispose();
    await b?.dispose();
    await song?.dispose();
  }
}
