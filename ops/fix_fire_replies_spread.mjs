#!/usr/bin/env node
/**
 * Fix live fire memos for screenshots:
 * - respread reply sticky anchors across the paper
 * - replace duplicate / false-song reply texts with diverse pool lines
 *
 *   cd ops && node fix_fire_replies_spread.mjs
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

function loadPool() {
  const raw = JSON.parse(readFileSync(join(__dir, 'reply_pool.json'), 'utf8'));
  return (raw.entries || [])
    .map((e) => ({
      text: String(e.text || '').trim(),
      moods: Array.isArray(e.moods) ? e.moods : ['any'],
      song: String(e.song || '').trim(),
      artist: String(e.artist || '').trim(),
    }))
    .filter((e) => e.text);
}

function pick(list) {
  return list[Math.floor(Math.random() * list.length)];
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

function spreadAnchors(n) {
  const out = [];
  const minDist = 0.16;
  let guard = 0;
  while (out.length < n && guard < n * 40) {
    guard += 1;
    const a = randomAnchor();
    if (
      out.every(
        (b) => Math.hypot(a.x - b.x, a.y - b.y) >= minDist,
      )
    ) {
      out.push(a);
    }
  }
  while (out.length < n) out.push(randomAnchor());
  return out;
}

function usablePool(pool, hasSong) {
  return pool.filter((e) => {
    if (!hasSong) {
      if (e.moods.length === 1 && e.moods[0] === 'song') return false;
      if (/노래|곡까지|곡을 남|곡 남|♪/.test(e.text)) return false;
    }
    return true;
  });
}

function isBadText(text, hasSong) {
  if (!text) return true;
  if (!hasSong && /노래|곡까지|곡을 남|곡 남|♪/.test(text)) return true;
  return false;
}

async function main() {
  const dry = process.argv.includes('--dry-run');
  const keyPath = findServiceAccountPath();
  if (!keyPath) {
    console.error('Missing service account');
    process.exit(1);
  }
  const pool = loadPool();
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(readFileSync(keyPath, 'utf8'))),
  });
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const snap = await db
    .collection('memos')
    .where('expiresAt', '>', now)
    .orderBy('expiresAt', 'desc')
    .limit(200)
    .get();

  const docs = snap.docs.filter((d) => d.data()?.theme === 'fire');
  console.log(`live fire memos: ${docs.length}`);
  let fixed = 0;
  for (const doc of docs) {
    const data = doc.data() || {};
    const replies = data.replies && typeof data.replies === 'object' ? data.replies : {};
    const keys = Object.keys(replies);
    if (keys.length === 0) continue;

    const hasSong =
      String(data.song || '').trim().length > 0 ||
      String(data.artist || '').trim().length > 0;
    const base = usablePool(pool, hasSong);
    const anchors = spreadAnchors(keys.length);
    const usedTexts = new Set();
    const next = {};

    keys.forEach((uid, i) => {
      const old = replies[uid] || {};
      let text = String(old.text || '').trim();
      if (isBadText(text, hasSong) || usedTexts.has(text)) {
        let entry = pick(base);
        let tries = 0;
        while (usedTexts.has(entry.text) && tries < 12) {
          entry = pick(base);
          tries += 1;
        }
        text = entry.text;
      }
      usedTexts.add(text);
      const a = anchors[i];
      next[uid] = {
        ...old,
        text,
        // Don't invent song fields on stickies for no-song memos.
        song: hasSong ? String(old.song || '') : '',
        artist: hasSong ? String(old.artist || '') : '',
        x: a.x,
        y: a.y,
      };
    });

    if (dry) {
      console.log(`[dry] ${doc.id} replies=${keys.length}`);
      continue;
    }
    await doc.ref.update({ replies: next });
    fixed += 1;
    console.log(`fixed ${doc.id} replies=${keys.length}`);
  }
  console.log(`Done. updated ${fixed} memos.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
