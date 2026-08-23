import 'package:firebase_storage/firebase_storage.dart';

import 'ambient_music.dart';

class ThemeTrack {
  const ThemeTrack({required this.uri, required this.fileStem});

  final Uri uri;

  /// Filename without extension, e.g. `desert_vesper`.
  final String fileStem;

  /// Display label for UI, e.g. `desert vesper`.
  String get title => fileStem.replaceAll('_', ' ');
}

/// Resolves streaming URLs from Firebase Storage theme folders:
/// `music/desert/…`, `music/beach/…`, `music/night_forest/…`, `music/star/…`
///
/// Files are named `{folder}_{vesper|nocturne|vigil}.wav` (or .mp3).
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
  };

  static String filePrefix(AmbienceScene scene) => switch (scene) {
    AmbienceScene.desert => 'desert',
    AmbienceScene.forest => 'night_forest',
    AmbienceScene.ocean => 'beach',
    AmbienceScene.space => 'star',
  };

  static const suiteSuffixes = ['vesper', 'nocturne', 'vigil'];

  Future<List<ThemeTrack>> tracksFor(AmbienceScene scene) async {
    final cached = _cache[scene];
    if (cached != null && cached.isNotEmpty) return cached;

    final folder = folderFor(scene);
    final prefix = filePrefix(scene);
    final found = <ThemeTrack>[];

    for (final suffix in suiteSuffixes) {
      final stem = '${prefix}_$suffix';
      final track = await _tryLoad(folder, stem);
      if (track != null) found.add(track);
    }

    if (found.isEmpty) {
      try {
        final listed = await _storage.ref(folder).listAll();
        final items = listed.items.where(_looksLikeAudio).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        for (final item in items) {
          final url = await item.getDownloadURL();
          final stem = item.name.replaceAll(RegExp(r'\.[^.]+$'), '');
          found.add(ThemeTrack(uri: Uri.parse(url), fileStem: stem));
        }
      } catch (_) {
        return const [];
      }
    }

    if (found.isNotEmpty) _cache[scene] = found;
    return found;
  }

  Future<ThemeTrack?> _tryLoad(String folder, String stem) async {
    for (final ext in ['wav', 'mp3']) {
      try {
        final url =
            await _storage.ref('$folder/$stem.$ext').getDownloadURL();
        return ThemeTrack(uri: Uri.parse(url), fileStem: stem);
      } catch (_) {
        // try next ext
      }
    }
    return null;
  }

  void clearCache() => _cache.clear();

  bool _looksLikeAudio(Reference ref) {
    final name = ref.name.toLowerCase();
    return name.endsWith('.mp3') ||
        name.endsWith('.m4a') ||
        name.endsWith('.wav') ||
        name.endsWith('.aac') ||
        name.endsWith('.ogg');
  }
}
