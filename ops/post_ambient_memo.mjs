#!/usr/bin/env node
/**
 * Posts ambient memos from memo_pool.json into Firestore `memos`.
 *
 * Setup (once):
 *   1. Firebase Console → Project settings → Service accounts
 *      → Generate new private key → save as ops/serviceAccount.json
 *   2. cd ops && npm install
 *
 * Usage:
 *   node post_ambient_memo.mjs              # random 1
 *   node post_ambient_memo.mjs --count 3    # random 3
 *   node post_ambient_memo.mjs --theme desert
 *   node post_ambient_memo.mjs --all-themes # one random per theme that has entries
 *   node post_ambient_memo.mjs --dry-run    # print only, no write
 */

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const admin = require('firebase-admin');

const __dir = dirname(fileURLToPath(import.meta.url));
const poolPath = join(__dir, 'memo_pool.json');

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

const THEMES = new Set(['desert', 'forest', 'ocean', 'space']);
const MAX_TEXT = 80;
const MAX_ARTIST = 40;
const MAX_SONG = 40;
const LIFETIME_MS = 24 * 60 * 60 * 1000;

// Fake “people” so boards don’t look like one operator account.
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
    count: 1,
    theme: null,
    allThemes: false,
    dryRun: false,
    text: null,
    song: '',
    artist: '',
  };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry-run') out.dryRun = true;
    else if (a === '--all-themes') out.allThemes = true;
    else if (a === '--count') out.count = Math.max(1, Number(argv[++i] || 1));
    else if (a === '--theme') out.theme = String(argv[++i] || '').trim();
    else if (a === '--text') out.text = String(argv[++i] || '');
    else if (a === '--song') out.song = String(argv[++i] || '');
    else if (a === '--artist') out.artist = String(argv[++i] || '');
    else if (a === '--help' || a === '-h') out.help = true;
  }
  return out;
}

function loadPool() {
  const raw = JSON.parse(readFileSync(poolPath, 'utf8'));
  const entries = (raw.entries || [])
    .map((e) => ({
      theme: String(e.theme || '').trim(),
      text: String(e.text || '').trim(),
      artist: String(e.artist || '').trim(),
      song: String(e.song || '').trim(),
    }))
    .filter((e) => e.text && THEMES.has(e.theme));

  for (const e of entries) {
    if (e.text.length > MAX_TEXT) {
      throw new Error(`text too long (${e.text.length}>${MAX_TEXT}): ${e.text}`);
    }
    if (e.artist.length > MAX_ARTIST) {
      throw new Error(`artist too long: ${e.artist}`);
    }
    if (e.song.length > MAX_SONG) {
      throw new Error(`song too long: ${e.song}`);
    }
  }
  return entries;
}

function pick(list) {
  return list[Math.floor(Math.random() * list.length)];
}

function pickUid() {
  return pick(AMBIENT_UIDS);
}

async function postOne(db, entry) {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + LIFETIME_MS);
  const uid = pickUid();
  const ref = db.collection('memos').doc();
  const data = {
    theme: entry.theme,
    text: entry.text,
    artist: entry.artist,
    song: entry.song,
    createdAt: admin.firestore.Timestamp.fromDate(now),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    uid,
    replies: {},
  };
  await ref.set(data);
  return { id: ref.id, uid, theme: entry.theme, text: entry.text };
}

function usage() {
  console.log(`Usage:
  node post_ambient_memo.mjs [--count N] [--theme desert|forest|ocean|space]
  node post_ambient_memo.mjs --all-themes
  node post_ambient_memo.mjs --theme desert --text "직접 쓴 글" [--song "..."] [--artist "..."]
  node post_ambient_memo.mjs --dry-run

Edit content in: memo_pool.json
Service account:  serviceAccount.json  (not committed)
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

  const pool = loadPool();
  if (args.text == null && pool.length === 0) {
    console.error('memo_pool.json has no valid entries');
    process.exit(1);
  }

  if (args.theme && !THEMES.has(args.theme)) {
    console.error(`Unknown theme: ${args.theme}`);
    process.exit(1);
  }

  let picks = [];
  if (args.text != null) {
    const theme = args.theme || 'desert';
    if (!THEMES.has(theme)) {
      console.error(`Unknown theme: ${theme}`);
      process.exit(1);
    }
    const one = {
      theme,
      text: String(args.text).trim(),
      song: String(args.song || '').trim(),
      artist: String(args.artist || '').trim(),
    };
    if (!one.text) {
      console.error('--text is empty');
      process.exit(1);
    }
    if (one.text.length > MAX_TEXT) {
      console.error(`text too long (${one.text.length}>${MAX_TEXT})`);
      process.exit(1);
    }
    picks = [one];
  } else if (args.allThemes) {
    for (const theme of THEMES) {
      const subset = pool.filter((e) => e.theme === theme);
      if (subset.length) picks.push(pick(subset));
    }
  } else {
    const subset = args.theme
      ? pool.filter((e) => e.theme === args.theme)
      : pool;
    if (subset.length === 0) {
      console.error(`No entries for theme: ${args.theme}`);
      process.exit(1);
    }
    for (let i = 0; i < args.count; i++) {
      picks.push(pick(subset));
    }
  }

  if (args.dryRun) {
    console.log('[dry-run] would post:');
    for (const e of picks) {
      console.log(`  [${e.theme}] ${e.text}${e.song ? ` ♪ ${e.song}` : ''}`);
    }
    return;
  }

  const sa = JSON.parse(readFileSync(keyPath, 'utf8'));
  admin.initializeApp({
    credential: admin.credential.cert(sa),
  });
  const db = admin.firestore();

  for (const entry of picks) {
    const posted = await postOne(db, entry);
    console.log(
      `posted ${posted.id} [${posted.theme}] uid=${posted.uid} — ${posted.text}`,
    );
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
