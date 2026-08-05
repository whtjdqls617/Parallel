import 'package:firebase_storage/firebase_storage.dart';

import 'ambient_music.dart';

/// Resolves streaming URLs from Firebase Storage theme folders:
/// `music/desert/…`, `music/forest/…`
class ThemeMusicCatalog {
  ThemeMusicCatalog({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final Map<AmbienceScene, Uri> _cache = {};

  static String folderFor(AmbienceScene scene) => switch (scene) {
    AmbienceScene.desert => 'music/desert',
    AmbienceScene.forest => 'music/forest',
  };

  /// Preferred fixed filename; falls back to first audio object in the folder.
  static String preferredFile(AmbienceScene scene) => switch (scene) {
    AmbienceScene.desert => 'desert_1.mp3',
    AmbienceScene.forest => 'forest_ambient.mp3',
  };

  Future<Uri?> resolveTrack(AmbienceScene scene) async {
    final cached = _cache[scene];
    if (cached != null) return cached;

    final folder = folderFor(scene);
    final preferred = preferredFile(scene);

    try {
      final preferredRef = _storage.ref('$folder/$preferred');
      final url = await preferredRef.getDownloadURL();
      final uri = Uri.parse(url);
      _cache[scene] = uri;
      return uri;
    } catch (_) {
      // Prefer missing file → try listing the folder.
    }

    try {
      final listed = await _storage.ref(folder).listAll();
      final items = listed.items.where(_looksLikeAudio).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (items.isEmpty) return null;
      final url = await items.first.getDownloadURL();
      final uri = Uri.parse(url);
      _cache[scene] = uri;
      return uri;
    } catch (_) {
      return null;
    }
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
