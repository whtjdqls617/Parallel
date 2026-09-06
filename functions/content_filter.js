/**
 * Soft blocklist for ambient replies / optional server checks.
 * Keep in sync spirit with lib/memo/memo_content_filter.dart
 */

const BLOCKED = [
  "씨발",
  "시발",
  "병신",
  "지랄",
  "꺼져",
  "좆",
  "새끼",
  "니미",
  "니애미",
  "창녀",
  "성괴",
  "한남",
  "한녀",
  "급식충",
  "야동",
  "성인방송",
  "원조교제",
  "조건만남",
  "성매매",
  "자살해",
  "죽어라",
  "목매",
  "투신해",
  "fuck",
  "shit",
  "bitch",
  "nigger",
  "rape",
  "kill yourself",
  "kys",
];

const CONTACT_RE =
  /(https?:\/\/|www\.|카톡\s*아이디|카카오톡\s*아이디|kakao\s*id|오픈채팅|\d{2,3}[-\s]?\d{3,4}[-\s]?\d{4}|[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,})/i;

function isAllowed(raw) {
  const text = String(raw || "").trim();
  if (!text) return true;
  const lower = text.toLowerCase();
  for (const w of BLOCKED) {
    if (text.includes(w) || lower.includes(w.toLowerCase())) return false;
  }
  if (CONTACT_RE.test(text)) return false;
  return true;
}

module.exports = { isAllowed };
