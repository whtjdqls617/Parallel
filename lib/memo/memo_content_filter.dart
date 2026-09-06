/// Soft blocklist for Parallel memos / replies.
/// Prefer quiet refusal over heavy moderation tone.
class MemoContentFilter {
  MemoContentFilter._();

  /// Null if ok; otherwise a short user-facing reason.
  static String? rejectReason(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final lower = text.toLowerCase();

    for (final w in _blocked) {
      if (text.contains(w) || lower.contains(w.toLowerCase())) {
        return '이 글은 남기기 어려워요. 다른 말로 적어 볼래요?';
      }
    }

    // Contact / spam bait
    if (_contact.hasMatch(text) || _contact.hasMatch(lower)) {
      return '연락처나 외부 링크는 남길 수 없어요.';
    }

    return null;
  }

  static bool isAllowed(String raw) => rejectReason(raw) == null;

  static final _contact = RegExp(
    r'(https?:\/\/|www\.|카톡\s*아이디|카카오톡\s*아이디|kakao\s*id|오픈채팅|'
    r'\d{2,3}[-\s]?\d{3,4}[-\s]?\d{4}|'
    r'[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,})',
    caseSensitive: false,
  );

  /// Keep short; expand carefully. Matching is substring-based.
  static const _blocked = [
    // Korean hate / severe insults
    '씨발', '시발', '병신', '지랄', '꺼져', '좆', '새끼', '니미', '니애미',
    '창녀', '성괴', '한남', '한녀', '급식충', '장애인 새끼',
    // Sexual / exploitative
    '야동', '성인방송', '원조교제', '조건만남', '성매매',
    // Self-harm encouragement (block active urging, not soft feelings)
    '자살해', '죽어라', '목매', '투신해',
    // English
    'fuck', 'shit', 'bitch', 'nigger', 'rape', 'kill yourself', 'kys',
  ];
}
