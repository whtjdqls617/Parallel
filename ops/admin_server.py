#!/usr/bin/env python3
"""Local Parallel admin UI — post memos / comfort replies.

  cd ops
  python3 -m pip install -r requirements.txt
  python3 admin_server.py

  open http://127.0.0.1:8787
"""

from __future__ import annotations

import json
import mimetypes
import random
import re
import traceback
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import firebase_admin
from firebase_admin import credentials, firestore

ROOT = Path(__file__).resolve().parent
PUBLIC = ROOT / "admin-public"
HOST = "127.0.0.1"
PORT = 8787

THEMES = {"desert", "forest", "ocean", "space", "rain", "fire"}
MAX_TEXT = 80
MAX_ARTIST = 40
MAX_SONG = 40
MAX_REPLIES = 12
LIFETIME = timedelta(hours=24)

AMBIENT_UIDS = [
    "ambient_breeze",
    "ambient_tide",
    "ambient_moss",
    "ambient_ember",
    "ambient_quiet",
    "ambient_lantern",
]

VERSION_DOC = "config/appVersion"
VERSION_RE = re.compile(r"^(\d+)\.(\d+)(?:\.(\d+))?$")
DEFAULT_ANDROID_STORE = (
    "https://play.google.com/store/apps/details?id=com.parallel.android"
)
DEFAULT_IOS_STORE = "https://apps.apple.com/app/id0000000000"


def find_service_account() -> Path:
    preferred = ROOT / "serviceAccount.json"
    if preferred.exists():
        return preferred
    for path in ROOT.glob("*firebase-adminsdk*.json"):
        return path
    raise SystemExit(
        "Missing service account JSON in ops/\n"
        "Save as serviceAccount.json or keep *firebase-adminsdk*.json here"
    )


def clamp(value, max_len: int) -> str:
    return str(value or "").strip()[:max_len]


def reply_uids(data: dict) -> set:
    replies = data.get("replies") or {}
    if not isinstance(replies, dict):
        return set()
    return set(replies.keys())


def pick_ambient_uid(used: set) -> str:
    free = [u for u in AMBIENT_UIDS if u not in used]
    if free:
        return random.choice(free)
    return f"ambient_{int(datetime.now().timestamp())}_{random.randint(0, 999)}"


def random_anchor():
    return {
        "x": round(0.35 + random.random() * 0.4, 3),
        "y": round(0.45 + random.random() * 0.35, 3),
    }


def init_db():
    key = find_service_account()
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(str(key)))
    print(f"Using key: {key.name}")
    return firestore.client()


DB = None


def list_memos(theme: str | None):
    now = datetime.now(timezone.utc)
    q = DB.collection("memos").where("expiresAt", ">", now)
    if theme and theme in THEMES:
        q = q.where("theme", "==", theme)
    q = q.order_by("expiresAt", direction=firestore.Query.DESCENDING).limit(80)
    rows = []
    for doc in q.stream():
        data = doc.to_dict() or {}
        created = data.get("createdAt")
        expires = data.get("expiresAt")
        rows.append(
            {
                "id": doc.id,
                "theme": data.get("theme") or "",
                "text": data.get("text") or "",
                "song": data.get("song") or "",
                "artist": data.get("artist") or "",
                "uid": data.get("uid") or "",
                "replies": len(reply_uids(data)),
                "createdAt": created.isoformat() if hasattr(created, "isoformat") else None,
                "expiresAt": expires.isoformat() if hasattr(expires, "isoformat") else None,
            }
        )
    rows.sort(key=lambda r: r.get("createdAt") or "", reverse=True)
    return rows


def post_memo(body: dict):
    theme = str(body.get("theme") or "").strip()
    text = clamp(body.get("text"), MAX_TEXT)
    song = clamp(body.get("song"), MAX_SONG)
    artist = clamp(body.get("artist"), MAX_ARTIST)
    if theme not in THEMES:
        raise ValueError("theme must be desert|forest|ocean|space|rain|fire")
    if not text:
        raise ValueError("text is required")

    now = datetime.now(timezone.utc)
    uid = random.choice(AMBIENT_UIDS)
    ref = DB.collection("memos").document()
    ref.set(
        {
            "theme": theme,
            "text": text,
            "artist": artist,
            "song": song,
            "createdAt": now,
            "expiresAt": now + LIFETIME,
            "uid": uid,
            "replies": {},
        }
    )
    return {"id": ref.id, "theme": theme, "text": text, "song": song, "artist": artist, "uid": uid}


def post_reply(body: dict):
    memo_id = str(body.get("memoId") or "").strip()
    text = clamp(body.get("text"), MAX_TEXT)
    song = clamp(body.get("song"), MAX_SONG)
    artist = clamp(body.get("artist"), MAX_ARTIST)
    if not memo_id:
        raise ValueError("memoId is required")
    if not text:
        raise ValueError("text is required")

    ref = DB.collection("memos").document(memo_id)
    snap = ref.get()
    if not snap.exists:
        raise ValueError("memo not found")
    data = snap.to_dict() or {}
    expires = data.get("expiresAt")
    if expires and hasattr(expires, "timestamp") and expires < datetime.now(timezone.utc):
        raise ValueError("memo expired")

    used = reply_uids(data)
    if len(used) >= MAX_REPLIES:
        raise ValueError("memo already has max replies")

    uid = pick_ambient_uid(used)
    anchor = random_anchor()
    now = datetime.now(timezone.utc)
    next_replies = dict(data.get("replies") or {})
    next_replies[uid] = {
        "text": text,
        "artist": artist,
        "song": song,
        "createdAt": now,
        "x": anchor["x"],
        "y": anchor["y"],
    }
    ref.update(
        {
            "replies": next_replies,
            "replyText": firestore.DELETE_FIELD,
            "replyUid": firestore.DELETE_FIELD,
            "replyCreatedAt": firestore.DELETE_FIELD,
        }
    )
    return {
        "memoId": memo_id,
        "uid": uid,
        "text": text,
        "song": song,
        "artist": artist,
        "theme": data.get("theme"),
    }


def normalize_version(raw: str) -> str:
    text = str(raw or "").strip()
    m = VERSION_RE.match(text)
    if not m:
        raise ValueError("version must look like 1.2.3 (major.minor.patch)")
    major, minor, patch = m.group(1), m.group(2), m.group(3) or "0"
    return f"{major}.{minor}.{patch}"


def get_app_version():
    ref = DB.document(VERSION_DOC)
    snap = ref.get()
    if not snap.exists:
        payload = {
            "ios": "1.0.0",
            "android": "1.0.0",
            "iosStoreUrl": DEFAULT_IOS_STORE,
            "androidStoreUrl": DEFAULT_ANDROID_STORE,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        ref.set(payload)
        return {
            "ios": "1.0.0",
            "android": "1.0.0",
            "iosStoreUrl": DEFAULT_IOS_STORE,
            "androidStoreUrl": DEFAULT_ANDROID_STORE,
        }
    data = snap.to_dict() or {}
    return {
        "ios": data.get("ios") or "1.0.0",
        "android": data.get("android") or "1.0.0",
        "iosStoreUrl": data.get("iosStoreUrl") or DEFAULT_IOS_STORE,
        "androidStoreUrl": data.get("androidStoreUrl") or DEFAULT_ANDROID_STORE,
    }


def set_app_version(body: dict):
    current = get_app_version()
    next_ios = normalize_version(body["ios"]) if "ios" in body and body["ios"] not in (None, "") else current["ios"]
    next_android = (
        normalize_version(body["android"])
        if "android" in body and body["android"] not in (None, "")
        else current["android"]
    )
    ios_url = str(body.get("iosStoreUrl") or current["iosStoreUrl"]).strip() or DEFAULT_IOS_STORE
    android_url = (
        str(body.get("androidStoreUrl") or current["androidStoreUrl"]).strip()
        or DEFAULT_ANDROID_STORE
    )
    payload = {
        "ios": next_ios,
        "android": next_android,
        "iosStoreUrl": ios_url,
        "androidStoreUrl": android_url,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    DB.document(VERSION_DOC).set(payload, merge=True)
    return {
        "ios": next_ios,
        "android": next_android,
        "iosStoreUrl": ios_url,
        "androidStoreUrl": android_url,
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args))

    def _json(self, status: int, body: dict):
        raw = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw.decode("utf-8") or "{}")

    def _serve_static(self, path: str):
        rel = "/index.html" if path == "/" else path
        if ".." in rel:
            self.send_error(400)
            return
        file_path = (PUBLIC / rel.lstrip("/")).resolve()
        if not str(file_path).startswith(str(PUBLIC.resolve())) or not file_path.is_file():
            self.send_error(404)
            return
        data = file_path.read_bytes()
        ctype = mimetypes.guess_type(str(file_path))[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        parsed = urlparse(self.path)
        try:
            if parsed.path == "/api/memos":
                qs = parse_qs(parsed.query)
                theme = (qs.get("theme") or [""])[0]
                self._json(200, {"memos": list_memos(theme)})
                return
            if parsed.path == "/api/version":
                self._json(200, {"version": get_app_version()})
                return
            self._serve_static(parsed.path)
        except Exception as exc:
            traceback.print_exc()
            self._json(400, {"error": str(exc)})

    def do_POST(self):
        parsed = urlparse(self.path)
        try:
            body = self._read_json()
            if parsed.path == "/api/memos":
                self._json(200, {"ok": True, "posted": post_memo(body)})
                return
            if parsed.path == "/api/replies":
                self._json(200, {"ok": True, "posted": post_reply(body)})
                return
            if parsed.path == "/api/version":
                self._json(200, {"ok": True, "version": set_app_version(body)})
                return
            self._json(404, {"error": "not found"})
        except Exception as exc:
            traceback.print_exc()
            self._json(400, {"error": str(exc)})


def main():
    global DB
    DB = init_db()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Parallel admin → http://{HOST}:{PORT}")
    print("(localhost only — do not expose this port)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nbye")


if __name__ == "__main__":
    main()
