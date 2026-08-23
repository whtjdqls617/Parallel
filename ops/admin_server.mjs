#!/usr/bin/env node
/**
 * Local admin UI for posting memos / comfort replies.
 *
 *   cd ops && npm install && npm run admin
 *   open http://127.0.0.1:8787
 *
 * Binds to localhost only. Needs serviceAccount.json (or *firebase-adminsdk*.json).
 */

import { createServer } from 'node:http';
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, join, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const admin = require('firebase-admin');

const __dir = dirname(fileURLToPath(import.meta.url));
const publicDir = join(__dir, 'admin-public');
const PORT = Number(process.env.PORT || 8787);
const HOST = '127.0.0.1';

const THEMES = new Set(['desert', 'forest', 'ocean', 'space']);
const MAX_TEXT = 80;
const MAX_ARTIST = 40;
const MAX_SONG = 40;
const MAX_REPLIES = 12;
const LIFETIME_MS = 24 * 60 * 60 * 1000;

const AMBIENT_UIDS = [
  'ambient_breeze',
  'ambient_tide',
  'ambient_moss',
  'ambient_ember',
  'ambient_quiet',
  'ambient_lantern',
];

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

function pick(list) {
  return list[Math.floor(Math.random() * list.length)];
}

function randomAnchor() {
  return {
    x: Number((0.35 + Math.random() * 0.4).toFixed(3)),
    y: Number((0.45 + Math.random() * 0.35).toFixed(3)),
  };
}

function replyUids(data) {
  const map = data?.replies;
  if (!map || typeof map !== 'object') return new Set();
  return new Set(Object.keys(map));
}

function replyCount(data) {
  return replyUids(data).size;
}

function pickAmbientUid(used) {
  const free = AMBIENT_UIDS.filter((u) => !used.has(u));
  if (free.length) return pick(free);
  return `ambient_${Date.now().toString(36)}_${Math.floor(Math.random() * 999)}`;
}

function clampStr(v, max) {
  return String(v ?? '').trim().slice(0, max);
}

function json(res, status, body) {
  const raw = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(raw);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch (e) {
        reject(new Error('Invalid JSON body'));
      }
    });
    req.on('error', reject);
  });
}

function contentType(path) {
  switch (extname(path)) {
    case '.html':
      return 'text/html; charset=utf-8';
    case '.css':
      return 'text/css; charset=utf-8';
    case '.js':
      return 'text/javascript; charset=utf-8';
    default:
      return 'application/octet-stream';
  }
}

function serveStatic(res, urlPath) {
  const safe = urlPath === '/' ? '/index.html' : urlPath;
  if (safe.includes('..')) {
    res.writeHead(400);
    res.end('bad path');
    return;
  }
  const file = join(publicDir, safe);
  if (!existsSync(file)) {
    res.writeHead(404);
    res.end('not found');
    return;
  }
  res.writeHead(200, { 'Content-Type': contentType(file) });
  res.end(readFileSync(file));
}

async function listMemos(db, theme) {
  const now = admin.firestore.Timestamp.now();
  let q = db.collection('memos').where('expiresAt', '>', now);
  if (theme && THEMES.has(theme)) q = q.where('theme', '==', theme);
  q = q.orderBy('expiresAt', 'desc').limit(80);
  const snap = await q.get();
  const rows = snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      theme: data.theme || '',
      text: data.text || '',
      song: data.song || '',
      artist: data.artist || '',
      uid: data.uid || '',
      replies: replyCount(data),
      createdAt: data.createdAt?.toDate?.()?.toISOString?.() ?? null,
      expiresAt: data.expiresAt?.toDate?.()?.toISOString?.() ?? null,
    };
  });
  rows.sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
  return rows;
}

async function postMemo(db, body) {
  const theme = String(body.theme || '').trim();
  const text = clampStr(body.text, MAX_TEXT);
  const song = clampStr(body.song, MAX_SONG);
  const artist = clampStr(body.artist, MAX_ARTIST);
  if (!THEMES.has(theme)) throw new Error('theme must be desert|forest|ocean|space');
  if (!text) throw new Error('text is required');

  const now = new Date();
  const expiresAt = new Date(now.getTime() + LIFETIME_MS);
  const uid = pick(AMBIENT_UIDS);
  const ref = db.collection('memos').doc();
  await ref.set({
    theme,
    text,
    artist,
    song,
    createdAt: admin.firestore.Timestamp.fromDate(now),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    uid,
    replies: {},
  });
  return { id: ref.id, theme, text, song, artist, uid };
}

async function postReply(db, body) {
  const memoId = String(body.memoId || '').trim();
  const text = clampStr(body.text, MAX_TEXT);
  const song = clampStr(body.song, MAX_SONG);
  const artist = clampStr(body.artist, MAX_ARTIST);
  if (!memoId) throw new Error('memoId is required');
  if (!text) throw new Error('text is required');

  const ref = db.collection('memos').doc(memoId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('memo not found');
  const data = snap.data() || {};
  if (data.expiresAt?.toDate && data.expiresAt.toDate() <= new Date()) {
    throw new Error('memo expired');
  }
  const used = replyUids(data);
  if (used.size >= MAX_REPLIES) throw new Error('memo already has max replies');

  const uid = pickAmbientUid(used);
  const anchor = randomAnchor();
  const now = admin.firestore.Timestamp.now();
  const next = {
    ...(data.replies && typeof data.replies === 'object' ? data.replies : {}),
    [uid]: {
      text,
      artist,
      song,
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
  return { memoId, uid, text, song, artist, theme: data.theme };
}

async function main() {
  const keyPath = findServiceAccountPath();
  if (!keyPath) {
    console.error(
      'Missing service account JSON in ops/\n' +
        'Save as serviceAccount.json (or keep *firebase-adminsdk*.json here)',
    );
    process.exit(1);
  }

  const sa = JSON.parse(readFileSync(keyPath, 'utf8'));
  admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  const server = createServer(async (req, res) => {
    const url = new URL(req.url || '/', `http://${HOST}:${PORT}`);
    const { pathname } = url;

    try {
      if (req.method === 'GET' && pathname === '/api/memos') {
        const theme = url.searchParams.get('theme') || '';
        const memos = await listMemos(db, theme);
        return json(res, 200, { memos });
      }

      if (req.method === 'POST' && pathname === '/api/memos') {
        const body = await readBody(req);
        const posted = await postMemo(db, body);
        return json(res, 200, { ok: true, posted });
      }

      if (req.method === 'POST' && pathname === '/api/replies') {
        const body = await readBody(req);
        const posted = await postReply(db, body);
        return json(res, 200, { ok: true, posted });
      }

      if (req.method === 'GET') {
        return serveStatic(res, pathname);
      }

      json(res, 404, { error: 'not found' });
    } catch (err) {
      console.error(err);
      json(res, 400, { error: err.message || String(err) });
    }
  });

  server.listen(PORT, HOST, () => {
    console.log(`Parallel admin → http://${HOST}:${PORT}`);
    console.log(`Using key: ${keyPath.split('/').pop()}`);
    console.log('(localhost only — do not expose this port)');
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
