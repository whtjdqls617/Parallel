#!/usr/bin/env node
/**
 * One-shot: post all unique fire memos from memo_pool, then attach several replies.
 * For screenshot density (looks actively used).
 *
 *   cd ops && node seed_fire_screenshot.mjs
 *   cd ops && node seed_fire_screenshot.mjs --dry-run
 */

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const admin = require('firebase-admin');

const __dir = dirname(fileURLToPath(import.meta.url));

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

const AMBIENT_UIDS = [
  'ambient_breeze',
  'ambient_tide',
  'ambient_moss',
  'ambient_ember',
  'ambient_quiet',
  'ambient_lantern',
  'ambient_hearth',
  'ambient_glow',
  'ambient_kind',
  'ambient_soft',
  'ambient_warm',
  'ambient_nest',
];

const LIFETIME_MS = 24 * 60 * 60 * 1000;
const MAX_REPLIES = 12;

function pick(list) {
  return list[Math.floor(Math.random() * list.length)];
}

function loadFireMemos() {
  const raw = JSON.parse(readFileSync(join(__dir, 'memo_pool.json'), 'utf8'));
  const seen = new Set();
  const out = [];
  for (const e of raw.entries || []) {
    if (e.theme !== 'fire') continue;
    const text = String(e.text || '').trim();
    if (!text || seen.has(text)) continue;
    seen.add(text);
    out.push({
      theme: 'fire',
      text,
      song: String(e.song || '').trim(),
      artist: String(e.artist || '').trim(),
    });
  }
  return out;
}

function loadReplies() {
  const raw = JSON.parse(readFileSync(join(__dir, 'reply_pool.json'), 'utf8'));
  return (raw.entries || [])
    .map((e) => ({
      text: String(e.text || '').trim(),
      song: String(e.song || '').trim(),
      artist: String(e.artist || '').trim(),
    }))
    .filter((e) => e.text);
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

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const memos = loadFireMemos();
  const replies = loadReplies();
  if (memos.length === 0) {
    console.error('No fire memos in memo_pool.json');
    process.exit(1);
  }
  if (replies.length === 0) {
    console.error('No replies in reply_pool.json');
    process.exit(1);
  }

  console.log(`fire memos: ${memos.length}, reply pool: ${replies.length}`);

  if (dryRun) {
    for (const m of memos) console.log(`  [fire] ${m.text}`);
    console.log('[dry-run] no writes');
    return;
  }

  const keyPath = findServiceAccountPath();
  if (!keyPath) {
    console.error('Missing service account JSON in ops/');
    process.exit(1);
  }
  const sa = JSON.parse(readFileSync(keyPath, 'utf8'));
  admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  const postedIds = [];
  for (const entry of memos) {
    const now = new Date();
    // Stagger createdAt a bit so list feels lived-in (newest → older).
    const ageMin = Math.floor(Math.random() * 18 * 60);
    const created = new Date(now.getTime() - ageMin * 60 * 1000);
    const expiresAt = new Date(created.getTime() + LIFETIME_MS);
    const uid = pick(AMBIENT_UIDS);
    const ref = db.collection('memos').doc();
    await ref.set({
      theme: 'fire',
      text: entry.text,
      artist: entry.artist,
      song: entry.song,
      createdAt: admin.firestore.Timestamp.fromDate(created),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      uid,
      replies: {},
    });
    postedIds.push(ref.id);
    console.log(`posted ${ref.id} — ${entry.text}`);
  }

  // Most memos get 2–5 replies; a few get 1; a few stay empty for realism.
  let replyTotal = 0;
  for (let i = 0; i < postedIds.length; i++) {
    const roll = Math.random();
    let n = 0;
    if (roll < 0.12) n = 0;
    else if (roll < 0.28) n = 1;
    else if (roll < 0.55) n = 2;
    else if (roll < 0.78) n = 3;
    else if (roll < 0.92) n = 4;
    else n = 5;
    n = Math.min(n, MAX_REPLIES, AMBIENT_UIDS.length - 1);

    if (n === 0) {
      console.log(`replies ${postedIds[i]} — (none)`);
      continue;
    }

    const used = new Set();
    // Don't reuse memo author uid if we can avoid it — optional.
    const map = {};
    for (let r = 0; r < n; r++) {
      const free = AMBIENT_UIDS.filter((u) => !used.has(u));
      if (free.length === 0) break;
      const uid = pick(free);
      used.add(uid);
      const entry = pick(replies);
      const anchor = randomAnchor();
      // Reply a bit after memo creation.
      const createdAt = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - Math.floor(Math.random() * 10 * 60) * 60 * 1000),
      );
      map[uid] = {
        text: entry.text,
        artist: entry.artist || '',
        song: entry.song || '',
        createdAt,
        x: anchor.x,
        y: anchor.y,
      };
      replyTotal += 1;
    }
    await db.collection('memos').doc(postedIds[i]).update({
      replies: map,
      replyText: admin.firestore.FieldValue.delete(),
      replyUid: admin.firestore.FieldValue.delete(),
      replyCreatedAt: admin.firestore.FieldValue.delete(),
    });
    console.log(`replies ${postedIds[i]} — ${Object.keys(map).length}`);
  }

  console.log(
    `\nDone. posted ${postedIds.length} fire memos, ${replyTotal} replies total.`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
