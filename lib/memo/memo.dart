enum MemoTheme { desert, forest }

class Memo {
  const Memo({
    required this.id,
    required this.theme,
    required this.text,
    required this.createdAt,
    required this.expiresAt,
    this.artist = '',
    this.song = '',
    this.uid,
  });

  final String id;
  final MemoTheme theme;
  final String text;
  final String artist;
  final String song;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? uid;

  static const maxTextLength = 80;
  static const maxArtistLength = 40;
  static const maxSongLength = 40;

  /// Memos are ephemeral — gone after this duration.
  static const lifetime = Duration(hours: 24);

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt.toUtc());

  bool get hasSong =>
      artist.trim().isNotEmpty || song.trim().isNotEmpty;

  /// Compact line for list / reader: `제목 / 아티스트` (whichever exists).
  String get songLabel {
    final a = artist.trim();
    final s = song.trim();
    if (s.isNotEmpty && a.isNotEmpty) return '$s / $a';
    if (s.isNotEmpty) return s;
    return a;
  }

  static MemoTheme? themeFromString(String? value) => switch (value) {
    'desert' => MemoTheme.desert,
    'forest' => MemoTheme.forest,
    _ => null,
  };
}

extension MemoThemeX on MemoTheme {
  String get key => switch (this) {
    MemoTheme.desert => 'desert',
    MemoTheme.forest => 'forest',
  };
}

/// Result of the unified compose sheet.
class MemoDraft {
  const MemoDraft({
    required this.text,
    required this.artist,
    required this.song,
  });

  final String text;
  final String artist;
  final String song;
}
