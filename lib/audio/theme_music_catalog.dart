import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'ambient_music.dart';

class ThemeTrack {
  const ThemeTrack({required this.uri, required this.fileStem});

  final Uri uri;

  /// Filename without extension, e.g. `flight_vesper`.
  final String fileStem;

  /// Display label for UI, e.g. `flight vesper`.
  String get title {
    // Collapse upload typos like "flight_ vesper" → "flight vesper".
    return fileStem
        .replaceAll(RegExp(r'[\s_]+'), ' ')
        .trim();
  }
}

/// Resolves streaming URLs from Firebase Storage theme folders.
///
/// Play order is always **vesper → nocturne → vigil**.
class ThemeMusicCatalog {
  ThemeMusicCatalog({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  final Map<AmbienceScene, List<ThemeTrack>> _cache = {};

  static String folderFor(AmbienceScene scene) => switch (scene) {
    AmbienceScene.desert => 'music/desert',
    AmbienceScene.forest => 'music/night_forest',
    AmbienceScene.ocean => 'music/beach',
    AmbienceScene.space => 'music/star',
    AmbienceScene.rain => 'music/flight',
    AmbienceScene.fire => 'music/fire',
  };

  static String filePrefix(AmbienceScene scene) => switch (scene) {
    AmbienceScene.desert => 'desert',
    AmbienceScene.forest => 'night_forest',
    AmbienceScene.ocean => 'beach',
    AmbienceScene.space => 'star',
    AmbienceScene.rain => 'flight',
    AmbienceScene.fire => 'fire',
  };

  static const suiteSuffixes = ['vesper', 'nocturne', 'vigil'];

  /// Strip spaces so `flight_ vesper` matches `flight_vesper`.
  static String compactStem(String fileStem) =>
      fileStem.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static int suiteRank(String fileStem) {
    final compact = compactStem(fileStem);
    for (var i = 0; i < suiteSuffixes.length; i++) {
      final s = suiteSuffixes[i];
      if (compact == s || compact.endsWith('_$s')) return i;
    }
    return suiteSuffixes.length;
  }

  Future<List<ThemeTrack>> tracksFor(AmbienceScene scene) async {
    final cached = _cache[scene];
    if (cached != null && cached.isNotEmpty) return List.of(cached);

    final folder = folderFor(scene);
    final prefix = filePrefix(scene);
    final bySuffix = <String, ThemeTrack>{};

    void put(ThemeTrack track) {
      final rank = suiteRank(track.fileStem);
      if (rank >= suiteSuffixes.length) return;
      final suffix = suiteSuffixes[rank];
      bySuffix.putIfAbsent(suffix, () => track);
    }

    // Folder listing is source of truth (handles `flight_ vesper.wav` typos).
    try {
      final listed = await _storage.ref(folder).listAll();
      for (final item in listed.items) {
        final name = item.name;
        final lower = name.toLowerCase();
        if (!(lower.endsWith('.wav') ||
            lower.endsWith('.mp3') ||
            lower.endsWith('.m4a') ||
            lower.endsWith('.aac') ||
            lower.endsWith('.ogg'))) {
          continue;
        }
        try {
          final url = await item.getDownloadURL();
          final stem = name.replaceAll(RegExp(r'\.[^.]+$'), '');
          put(ThemeTrack(uri: Uri.parse(url), fileStem: stem));
        } catch (e) {
          debugPrint('ThemeMusicCatalog skip $name: $e');
        }
      }
    } catch (e) {
      debugPrint('ThemeMusicCatalog listAll($folder) failed: $e');
    }

    // Fill gaps with exact / spaced path tries.
    for (final suffix in suiteSuffixes) {
      if (bySuffix.containsKey(suffix)) continue;
      final track = await _tryLoad(folder, prefix, suffix);
      if (track != null) put(track);
    }

    final found = <ThemeTrack>[
      for (final suffix in suiteSuffixes)
        if (bySuffix[suffix] != null) bySuffix[suffix]!,
    ];

    debugPrint(
      'ThemeMusicCatalog[$scene] '
      '${found.map((t) => t.fileStem).join(' → ')}',
    );

    if (found.isNotEmpty) _cache[scene] = found;
    return found;
  }

  Future<ThemeTrack?> _tryLoad(
    String folder,
    String prefix,
    String suffix,
  ) async {
    // Common upload typo: space after underscore (`flight_ vesper.wav`).
    final stems = ['${prefix}_$suffix', '${prefix}_ $suffix'];
    for (final stem in stems) {
      for (final ext in ['wav', 'mp3']) {
        try {
          final url =
              await _storage.ref('$folder/$stem.$ext').getDownloadURL();
          return ThemeTrack(uri: Uri.parse(url), fileStem: stem);
        } catch (_) {
          // try next
        }
      }
    }
    return null;
  }

  void clearCache() => _cache.clear();

  void clearCacheFor(AmbienceScene scene) => _cache.remove(scene);
}
