enum MemoTheme { desert, forest, ocean, space }

class MemoReply {
  const MemoReply({
    required this.uid,
    required this.text,
    required this.createdAt,
    this.artist = '',
    this.song = '',
    this.x,
    this.y,
  });

  final String uid;
  final String text;
  final String artist;
  final String song;
  final DateTime createdAt;

  /// Normalized top-left on the memo paper (0..1). Null = auto layout.
  final double? x;
  final double? y;

  bool get hasSong =>
      artist.trim().isNotEmpty || song.trim().isNotEmpty;

  bool get hasAnchor =>
      x != null && y != null && x! >= 0 && x! <= 1 && y! >= 0 && y! <= 1;

  String get songLabel {
    final a = artist.trim();
    final s = song.trim();
    if (s.isNotEmpty && a.isNotEmpty) return '$s / $a';
    if (s.isNotEmpty) return s;
    return a;
  }

  /// Stable post-it color for this reply (list badge + reader).
  int get stickyColorValue {
    final seed = text.hashCode ^ uid.hashCode ^ song.hashCode;
    return (seed & 1) == 0 ? 0xFFFFF59D : 0xFFF8BBD0;
  }
}

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
    this.replies = const [],
  });

  final String id;
  final MemoTheme theme;
  final String text;
  final String artist;
  final String song;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? uid;

  /// Quiet reply stickies — at most one per person (uid).
  final List<MemoReply> replies;

  static const maxTextLength = 80;
  static const maxReplyLength = 80;
  static const maxArtistLength = 40;
  static const maxSongLength = 40;
  static const maxReplies = 12;

  /// Memos are ephemeral — gone after this duration.
  static const lifetime = Duration(hours: 24);

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt.toUtc());

  bool get hasSong =>
      artist.trim().isNotEmpty || song.trim().isNotEmpty;

  bool get hasReply => replies.isNotEmpty;

  bool isOwnedBy(String? uid) =>
      uid != null && this.uid != null && this.uid == uid;

  bool hasReplyFrom(String? uid) =>
      uid != null && replies.any((r) => r.uid == uid);

  /// Compact line for list / reader: `제목 / 아티스트` (whichever exists).
  String get songLabel {
    final a = artist.trim();
    final s = song.trim();
    if (s.isNotEmpty && a.isNotEmpty) return '$s / $a';
    if (s.isNotEmpty) return s;
    return a;
  }

  Memo copyWithReplies(List<MemoReply> replies) {
    return Memo(
      id: id,
      theme: theme,
      text: text,
      artist: artist,
      song: song,
      createdAt: createdAt,
      expiresAt: expiresAt,
      uid: uid,
      replies: replies,
    );
  }

  static MemoTheme? themeFromString(String? value) => switch (value) {
    'desert' => MemoTheme.desert,
    'forest' => MemoTheme.forest,
    'ocean' => MemoTheme.ocean,
    'space' => MemoTheme.space,
    _ => null,
  };
}

extension MemoThemeX on MemoTheme {
  String get key => switch (this) {
    MemoTheme.desert => 'desert',
    MemoTheme.forest => 'forest',
    MemoTheme.ocean => 'ocean',
    MemoTheme.space => 'space',
  };

  /// Cool / dark themes share night-letter treatment in memo UI.
  bool get isCool =>
      this == MemoTheme.forest ||
      this == MemoTheme.ocean ||
      this == MemoTheme.space;
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
