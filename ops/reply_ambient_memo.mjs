#!/usr/bin/env node
/**
 * List live memos / leave ambient comfort replies.
 *
 * Usage:
 *   node reply_ambient_memo.mjs --list
 *   node reply_ambient_memo.mjs --list --theme desert
 *   node reply_ambient_memo.mjs --memo <memoId>
 *   node reply_ambient_memo.mjs --memo <memoId> --text "여기 있어도 괜찮아요."
 *   node reply_ambient_memo.mjs --unreplied --count 3
 *   node reply_ambient_memo.mjs --unreplied --theme ocean --dry-run
 */

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const admin = require('firebase-admin');

const __dir = dirname(fileURLToPath(import.meta.url));
const poolPath = join(__dir, 'reply_pool.json');

function findServiceAccountPath() {
  const preferred = join(__dir, 'serviceAccount.json');
  if (existsSync(preferred)) return preferred;
  for (const name of readdirSync(__dir)) {
    if (name.includes('firebase-adminsdk') && name.endsWith('.json')) {
      return join(__dir, name);
    }
  }
  return null;
}

const THEMES = new Set(['desert', 'forest', 'ocean', 'space', 'rain', 'fire']);
const MAX_TEXT = 80;
const MAX_ARTIST = 40;
const MAX_SONG = 40;
const MAX_REPLIES = 12;

const AMBIENT_UIDS = [
  'ambient_breeze',
  'ambient_tide',
  'ambient_moss',
  'ambient_ember',
  'ambient_quiet',
  'ambient_lantern',
];

function parseArgs(argv) {
  const out = {
    list: false,
    unreplied: false,
    memoId: null,
    theme: null,
    count: 1,
    text: null,
    song: '',
    artist: '',
    dryRun: false,
    help: false,
  };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--list') out.list = true;
    else if (a === '--unreplied') out.unreplied = true;
    else if (a === '--dry-run') out.dryRun = true;
    else if (a === '--help' || a === '-h') out.help = true;
    else if (a === '--memo') out.memoId = String(argv[++i] || '').trim();
    else if (a === '--theme') out.theme = String(argv[++i] || '').trim();
    else if (a === '--count') out.count = Math.max(1, Number(argv[++i] || 1));
    else if (a === '--text') out.text = String(argv[++i] || '');
    else if (a === '--song') out.song = String(argv[++i] || '');
    else if (a === '--artist') out.artist = String(argv[++i] || '');
  }
  return out;
}

function pick(list) {
  return list[Math.floor(Math.random() * list.length)];
}

function loadReplyPool() {
  const raw = JSON.parse(readFileSync(poolPath, 'utf8'));
  return (raw.entries || [])
    .map((e) => ({
      text: String(e.text || '').trim(),
      artist: String(e.artist || '').trim(),
      song: String(e.song || '').trim(),
      moods: Array.isArray(e.moods) ? e.moods : ['any'],
    }))
    .filter((e) => e.text);
}

const MOOD_KEYWORDS = {
  tired: [
    '피곤',
    '힘들',
    '힘들었',
    '지쳤',
    '지침',
    '버거',
    '야근',
    '바빴',
    '바빠',
    '죽겠',
    '녹초',
    '긴 하루',
    '하루가 길',
    '하루가 길었',
  ],
  lonely: ['혼자', '외로', '쓸쓸', '아무도', '적막', '빈자리'],
  hard: ['울고', '울었', '눈물', '아파', '상처', '무거', '답답', '불안', '괴로', '슬펐', '슬퍼'],
  rest: ['쉬고', '쉬엄', '잠시', '앉아', '쉴게', '쉬자', '한숨', '쉬는'],
  okay: ['괜찮', '고마', '다행', '따뜻', '좋아', '좋았', '위로', '평화'],
  night: ['밤', '새벽', '잠이', '잠 안', '불면', '오늘 밤'],
  place: [
    '바람',
    '파도',
    '하늘',
    '별',
    '숲',
    '바다',
    '사막',
    '모래',
    '나무',
    '달',
    '불',
    '장작',
    '벽난로',
    '온기',
    '온정',
    '불빛',
    '불멍',
  ],
};

function detectMoods(memoText, hasSong) {
  const text = String(memoText || '');
  const scores = {};
  for (const [mood, words] of Object.entries(MOOD_KEYWORDS)) {
    let score = 0;
    for (const w of words) {
      if (text.includes(w)) score += 1;
    }
    if (score > 0) scores[mood] = score;
  }
  if (hasSong) scores.song = (scores.song || 0) + 2;
  const ranked = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  if (ranked.length === 0) return ['any'];
  const top = ranked[0][1];
  return ranked.filter(([, s]) => s === top).map(([m]) => m);
}

function pickReplyForMemo(pool, memoText, hasSong) {
  const moods = detectMoods(memoText, hasSong);
  const usable = pool.filter((e) => {
    const tags = Array.isArray(e.moods) ? e.moods : ['any'];
    const text = String(e.text || '');
    if (!hasSong) {
      if (tags.length === 1 && tags[0] === 'song') return false;
      if (/노래|곡까지|곡을 남|곡 남|♪/.test(text)) return false;
    }
    return true;
  });
  const base = usable.length ? usable : pool;
  const matched = base.filter((e) => e.moods.some((t) => moods.includes(t)));
  if (matched.length) return pick(matched);
  const soft = base.filter((e) => e.moods.includes('any') || e.moods.length === 0);
  return pick(soft.length ? soft : base);
}

function validateReply(entry) {
  if (!entry.text || entry.text.length > MAX_TEXT) {
    throw new Error(`reply text invalid (1–${MAX_TEXT}): ${entry.text}`);
  }
  if (entry.artist.length > MAX_ARTIST) {
    throw new Error(`artist too long: ${entry.artist}`);
  }
  if (entry.song.length > MAX_SONG) {
    throw new Error(`song too long: ${entry.song}`);
  }
}

function replyCount(data) {
  const map = data.replies;
  if (!map || typeof map !== 'object') return 0;
  return Object.keys(map).length;
}

function replyUids(data) {
  const map = data.replies;
  if (!map || typeof map !== 'object') return new Set();
  return new Set(Object.keys(map));
}

function shortPreview(text, n = 36) {
  const t = String(text || '').replace(/\s+/g, ' ').trim();
  return t.length <= n ? t : `${t.slice(0, n)}…`;
}

function randomAnchor() {
  const band = Math.random();
  if (band < 0.45) {
    return {
      x: Number((0.08 + Math.random() * 0.78).toFixed(3)),
      y: Number((0.58 + Math.random() * 0.32).toFixed(3)),
    };
  }
  if (band < 0.75) {
    return {
      x: Number((0.62 + Math.random() * 0.28).toFixed(3)),
      y: Number((0.36 + Math.random() * 0.52).toFixed(3)),
    };
  }
  return {
    x: Number((0.12 + Math.random() * 0.70).toFixed(3)),
    y: Number((0.48 + Math.random() * 0.40).toFixed(3)),
  };
}

function pickAmbientUid(used) {
  const free = AMBIENT_UIDS.filter((u) => !used.has(u));
  if (free.length === 0) {
    // Fall back to unique synthetic uid so we can still reply.
    return `ambient_${Date.now().toString(36)}_${Math.floor(Math.random() * 999)}`;
  }
  return pick(free);
}

async function fetchLiveMemos(db, { theme = null, limit = 40 } = {}) {
  const now = admin.firestore.Timestamp.now();
  let q = db.collection('memos').where('expiresAt', '>', now);
  if (theme) q = q.where('theme', '==', theme);
  // Prefer newest; may need composite index if theme filter is used.
  q = q.orderBy('expiresAt', 'desc').limit(limit);
  const snap = await q.get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

async function addReply(db, memoId, entry) {
  validateReply(entry);
  const ref = db.collection('memos').doc(memoId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error(`memo not found: ${memoId}`);
  const data = snap.data() || {};
  const expiresAt = data.expiresAt;
  if (expiresAt && expiresAt.toDate && expiresAt.toDate() <= new Date()) {
    throw new Error(`memo expired: ${memoId}`);
  }
  const used = replyUids(data);
  if (used.size >= MAX_REPLIES) {
    throw new Error(`memo full (${MAX_REPLIES} replies): ${memoId}`);
  }
  const uid = pickAmbientUid(used);
  const anchor = randomAnchor();
  const now = admin.firestore.Timestamp.now();
  const next = {
    ...(data.replies && typeof data.replies === 'object' ? data.replies : {}),
    [uid]: {
      text: entry.text,
      artist: entry.artist || '',
      song: entry.song || '',
      createdAt: now,
      x: anchor.x,
      y: anchor.y,
    },
  };
  await ref.update({
    replies: next,
    replyText: admin.firestore.FieldValue.delete(),
    replyUid: admin.firestore.FieldValue.delete(),
    replyCreatedAt: admin.firestore.FieldValue.delete(),
  });
  return { memoId, uid, text: entry.text, theme: data.theme };
}

function usage() {
  console.log(`Usage:
  node reply_ambient_memo.mjs --list [--theme desert]
  node reply_ambient_memo.mjs --memo <id> [--text "..."] [--song "..."] [--artist "..."]
  node reply_ambient_memo.mjs --unreplied [--count N] [--theme desert]
  node reply_ambient_memo.mjs --dry-run ...

Edit pool: reply_pool.json
`);
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help) {
    usage();
    return;
  }

  const keyPath = findServiceAccountPath();
  if (!keyPath) {
    console.error(
      'Missing ops/serviceAccount.json (or *firebase-adminsdk*.json)\n' +
        'Firebase Console → Project settings → Service accounts → Generate new private key',
    );
    process.exit(1);
  }

  if (args.theme && !THEMES.has(args.theme)) {
    console.error(`Unknown theme: ${args.theme}`);
    process.exit(1);
  }

  if (!args.list && !args.memoId && !args.unreplied) {
    usage();
    process.exit(1);
  }

  const sa = JSON.parse(readFileSync(keyPath, 'utf8'));
  admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  const pool = loadReplyPool();
  if (!args.list && !args.text && pool.length === 0) {
    console.error('reply_pool.json is empty and no --text given');
    process.exit(1);
  }

  function resolveEntry(memo = null) {
    if (args.text != null) {
      return {
        text: String(args.text).trim(),
        song: String(args.song || '').trim(),
        artist: String(args.artist || '').trim(),
      };
    }
    const hasSong =
      String(memo?.song || '').trim().length > 0 ||
      String(memo?.artist || '').trim().length > 0;
    const picked = pickReplyForMemo(pool, memo?.text || '', hasSong);
    return {
      text: picked.text,
      song: picked.song || '',
      artist: picked.artist || '',
    };
  }

  if (args.list) {
    const memos = await fetchLiveMemos(db, { theme: args.theme, limit: 50 });
    if (memos.length === 0) {
      console.log('(no live memos)');
      return;
    }
    // Sort by createdAt desc when available.
    memos.sort((a, b) => {
      const ta = a.createdAt?.toMillis?.() ?? 0;
      const tb = b.createdAt?.toMillis?.() ?? 0;
      return tb - ta;
    });
    for (const m of memos) {
      const n = replyCount(m);
      const flag = n === 0 ? '  [no reply]' : `  [replies:${n}]`;
      console.log(
        `${m.id}  [${m.theme}]${flag}  ${shortPreview(m.text)}`,
      );
    }
    return;
  }

  if (args.memoId) {
    const snap = await db.collection('memos').doc(args.memoId).get();
    const memo = snap.exists ? { id: snap.id, ...snap.data() } : { id: args.memoId };
    const entry = resolveEntry(memo);
    if (args.dryRun) {
      console.log(`[dry-run] reply to ${args.memoId}: ${entry.text}`);
      return;
    }
    const posted = await addReply(db, args.memoId, entry);
    console.log(
      `replied ${posted.memoId} [${posted.theme}] as ${posted.uid} — ${posted.text}`,
    );
    return;
  }

  // --unreplied: comfort N memos that currently have zero replies
  const memos = await fetchLiveMemos(db, { theme: args.theme, limit: 80 });
  const targets = memos
    .filter((m) => replyCount(m) === 0)
    .sort((a, b) => {
      const ta = a.createdAt?.toMillis?.() ?? 0;
      const tb = b.createdAt?.toMillis?.() ?? 0;
      return tb - ta;
    })
    .slice(0, args.count);

  if (targets.length === 0) {
    console.log('No unreplied live memos found');
    return;
  }

  for (const m of targets) {
    const entry = resolveEntry(m);
    if (args.dryRun) {
      console.log(
        `[dry-run] ${m.id} [${m.theme}] ${shortPreview(m.text)} ← ${entry.text}`,
      );
      continue;
    }
    const posted = await addReply(db, m.id, entry);
    console.log(
      `replied ${posted.memoId} [${posted.theme}] as ${posted.uid} — ${posted.text}`,
    );
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
