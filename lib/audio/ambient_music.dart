import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'theme_music_catalog.dart';

enum AmbienceScene { desert, forest }

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

  static const songVolume = 0.35;
  static const natureVolumeSolo = 0.30;
  static const natureVolumeWithSong = 0.16;

  /// Keep in sync with generated nature WAVs.
  static const _desertBedLength = Duration(milliseconds: 25200);
  static const _forestBedLength = Duration(milliseconds: 25000);
  static const _fadeOut = Duration(milliseconds: 450);
  static const _fadeIn = Duration(milliseconds: 350);

  static bool _audioContextReady = false;

  final ThemeMusicCatalog _catalog;

  AudioPlayer? _nature;
  AudioPlayer? _song;

  AmbienceScene? _natureScene;
  bool _songStarted = false;
  bool _disposed = false;
  bool _cycling = false;
  Timer? _loopTimer;
  int _natureEpoch = 0;

  /// Let other apps keep playing (Spotify, YouTube, etc.) while we mix in.
  static Future<void> ensureMixWithOthers() async {
    if (_audioContextReady) return;
    final ctx = AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build();
    await AudioPlayer.global.setAudioContext(ctx);
    _audioContextReady = true;
  }

  Future<AudioPlayer> _createPlayer() async {
    await ensureMixWithOthers();
    final player = AudioPlayer();
    await player.setAudioContext(
      AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build(),
    );
    return player;
  }

  bool get isSongPlaying => _song?.state == PlayerState.playing;

  double get _natureVolume =>
      isSongPlaying ? natureVolumeWithSong : natureVolumeSolo;

  String _naturePath(AmbienceScene scene) => switch (scene) {
    AmbienceScene.desert => desertNaturePath,
    AmbienceScene.forest => forestNaturePath,
  };

  Duration _bedLength(AmbienceScene scene) => switch (scene) {
    AmbienceScene.desert => _desertBedLength,
    AmbienceScene.forest => _forestBedLength,
  };

  Future<void> setScene(AmbienceScene scene) async {
    if (_disposed) return;

    final sceneChanged = _natureScene != scene;
    final songWasPlaying = isSongPlaying;

    if (_natureScene == scene && _nature != null) {
      if (_nature!.state != PlayerState.playing) {
        await _nature!.setVolume(0);
        await _nature!.resume();
        await _fade(
          _nature!,
          from: 0,
          to: _natureVolume,
          ms: _fadeIn.inMilliseconds,
        );
        _scheduleCycle();
      }
      return;
    }

    _natureScene = scene;
    final path = _naturePath(scene);
    final epoch = ++_natureEpoch;
    _loopTimer?.cancel();
    _cycling = false;

    final player = _nature ??= await _createPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setPlayerMode(PlayerMode.mediaPlayer);
    await player.setVolume(0);
    await player.play(AssetSource(path));
    if (_disposed || epoch != _natureEpoch) return;

    await _fade(player, from: 0, to: _natureVolume, ms: _fadeIn.inMilliseconds);
    if (_disposed || epoch != _natureEpoch) return;
    _scheduleCycle();

    if (sceneChanged && songWasPlaying) {
      _songStarted = false;
      await playSong();
    }
  }

  void _scheduleCycle() {
    _loopTimer?.cancel();
    final scene = _natureScene;
    if (_disposed || scene == null || _nature == null) return;

    final wait = _bedLength(scene) - _fadeOut;
    _loopTimer = Timer(wait, () {
      if (_disposed || _natureScene != scene) return;
      unawaited(_softCycle());
    });
  }

  Future<void> _softCycle() async {
    if (_disposed || _cycling) return;
    final scene = _natureScene;
    final player = _nature;
    if (scene == null || player == null) return;

    _cycling = true;
    final epoch = _natureEpoch;
    final path = _naturePath(scene);
    final target = _natureVolume;

    try {
      await _fade(player, from: target, to: 0, ms: _fadeOut.inMilliseconds);
      if (_disposed || epoch != _natureEpoch) return;

      await player.stop();
      await player.setVolume(0);
      await player.play(AssetSource(path));
      if (_disposed || epoch != _natureEpoch) return;

      await _fade(player, from: 0, to: _natureVolume, ms: _fadeIn.inMilliseconds);
    } catch (_) {
      // Retry on the next cycle rather than leave silence forever.
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
    await _nature?.setVolume(_natureVolume);
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
    await _song?.pause();
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
    final nature = _nature;
    final song = _song;
    _nature = null;
    _song = null;
    _songStarted = false;
    await nature?.dispose();
    await song?.dispose();
  }
}
