/**
 * Auto comfort replies + reply push for Parallel memos.
 *
 * Flow:
 *  1) memo created → schedule ambientReplyAt (random 3–15 min later)
 *  2) every 2 min → Vertex Gemini reply (pool fallback) if unreplied
 *  3) replies map gains a key → FCM to memo author (if token saved)
 *
 * Deploy:
 *   cd functions && npm install && cd ..
 *   firebase deploy --only functions
 *
 * Needs Vertex AI API enabled on the Firebase GCP project.
 */

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const { VertexAI } = require("@google-cloud/vertexai");
const pool = require("./reply_pool.json");

initializeApp();
setGlobalOptions({ region: "asia-northeast3", maxInstances: 5 });

const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "parallel-e7b98";
const VERTEX_LOCATION = "us-central1";
const GEMINI_MODEL = "gemini-2.5-flash-lite";

const db = getFirestore();
const messaging = getMessaging();

let vertexModel = null;

function getVertexModel() {
  if (vertexModel) return vertexModel;
  const vertex = new VertexAI({ project: PROJECT_ID, location: VERTEX_LOCATION });
  vertexModel = vertex.getGenerativeModel({
    model: GEMINI_MODEL,
    generationConfig: {
      temperature: 0.55,
      maxOutputTokens: 220,
    },
  });
  return vertexModel;
}

const AMBIENT_UIDS = [
  "ambient_breeze",
  "ambient_tide",
  "ambient_moss",
  "ambient_ember",
  "ambient_quiet",
  "ambient_lantern",
];

const MIN_DELAY_MS = 3 * 60 * 1000;
const MAX_DELAY_MS = 15 * 60 * 1000;
const MAX_REPLIES = 12;
const MAX_REPLY_LEN = 80;

function pick(list) {
  return list[Math.floor(Math.random() * list.length)];
}

function randomDelayMs() {
  return MIN_DELAY_MS + Math.floor(Math.random() * (MAX_DELAY_MS - MIN_DELAY_MS));
}

function randomAnchor() {
  return {
    x: Number((0.35 + Math.random() * 0.4).toFixed(3)),
    y: Number((0.45 + Math.random() * 0.35).toFixed(3)),
  };
}

function replyEntries() {
  return (pool.entries || []).filter((e) => String(e.text || "").trim());
}

/** Keyword → mood fallback when Gemini is unavailable. */
const MOOD_KEYWORDS = {
  tired: [
    "피곤",
    "힘들",
    "힘들었",
    "지쳤",
    "지침",
    "버거",
    "야근",
    "바빴",
    "바빠",
    "죽겠",
    "녹초",
    "긴 하루",
    "하루가 길",
    "하루가 길었",
  ],
  lonely: ["혼자", "외로", "쓸쓸", "아무도", "적막", "빈자리"],
  hard: ["울고", "울었", "눈물", "아파", "상처", "무거", "답답", "불안", "괴로", "슬펐", "슬퍼"],
  rest: ["쉬고", "쉬엄", "잠시", "앉아", "쉴게", "쉬자", "한숨", "쉬는"],
  okay: ["괜찮", "고마", "다행", "따뜻", "좋아", "좋았", "위로", "평화"],
  night: ["밤", "새벽", "잠이", "잠 안", "불면", "오늘 밤"],
  place: ["바람", "파도", "하늘", "별", "숲", "바다", "사막", "모래", "나무", "달"],
};

function detectMoods(memoText, hasSong) {
  const text = String(memoText || "");
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
  if (ranked.length === 0) return ["any"];
  const top = ranked[0][1];
  return ranked.filter(([, s]) => s === top).map(([m]) => m);
}

function pickReplyForMemo(entries, memoText, hasSong) {
  const moods = detectMoods(memoText, hasSong);
  const matched = entries.filter((e) => {
    const tags = Array.isArray(e.moods) ? e.moods : ["any"];
    return tags.some((t) => moods.includes(t));
  });
  if (matched.length) return pick(matched);

  const soft = entries.filter((e) => {
    const tags = Array.isArray(e.moods) ? e.moods : ["any"];
    return tags.includes("any") || tags.length === 0;
  });
  return pick(soft.length ? soft : entries);
}

function pickAmbientUid(used) {
  const free = AMBIENT_UIDS.filter((u) => !used.has(u));
  if (free.length) return pick(free);
  return `ambient_${Date.now().toString(36)}_${Math.floor(Math.random() * 999)}`;
}

function replyKeys(data) {
  const map = data && data.replies;
  if (!map || typeof map !== "object") return [];
  return Object.keys(map);
}

function sanitizeField(raw, max) {
  return String(raw || "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, max);
}

function sanitizeReply(raw) {
  let text = sanitizeField(raw, MAX_REPLY_LEN);
  text = text.replace(/^["'「『]|["'」』]$/g, "").trim();
  text = text.replace(/^(답장|답|reply)\s*[:：\-]\s*/i, "");
  if (text.length > MAX_REPLY_LEN) text = text.slice(0, MAX_REPLY_LEN).trim();
  return text;
}

function extractVertexText(result) {
  const parts = result?.response?.candidates?.[0]?.content?.parts || [];
  return parts.map((p) => p.text || "").join("");
}

function parseGeminiPayload(raw) {
  const cleaned = String(raw || "")
    .replace(/```json/gi, "")
    .replace(/```/g, "")
    .trim();
  try {
    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");
    if (start >= 0 && end > start) {
      const obj = JSON.parse(cleaned.slice(start, end + 1));
      const text = sanitizeReply(obj.text || obj.reply || "");
      if (!text) return null;
      return {
        text,
        song: sanitizeField(obj.song || obj.title || "", 40),
        artist: sanitizeField(obj.artist || obj.singer || "", 40),
      };
    }
  } catch (_) {
    // plain text fallback
  }
  const text = sanitizeReply(cleaned);
  if (!text) return null;
  return { text, song: "", artist: "" };
}

async function generateGeminiReply({ memoText, song, artist, theme }) {
  const body = String(memoText || "").trim();
  if (!body) return null;

  const songLine =
    String(song || "").trim() || String(artist || "").trim()
      ? `원문 노래: ${[artist, song].filter(Boolean).join(" - ")}`
      : "원문 노래: 없음";

  const prompt = [
    "당신은 Parallel 앱에서 모르는 사람이 남긴 쪽지에 답하는 일반인입니다.",
    "운영진·상담사·코치 말투 금지.",
    "",
    "가장 중요: 원문의 핵심 말·상황에 직접 반응하세요.",
    "예) 원문이 '기다려요' → 기다림에 대한 답 (같이 기다림, 기다릴 가치, 천천히 와도 됨 등).",
    "예) 원문이 '피곤해요' → 피곤/쉼에 대한 답.",
    "예) 원문이 '혼자예요' → 혼자에 대한 답.",
    "풍경·테마 비유만으로 흐리게 가지 마세요. 원문 키워드를 놓치면 실패입니다.",
    "",
    "한국어 해요체, 1~2문장, 80자 이내.",
    "분위기에 맞는 실제 곡을 자주 추천 (약 70%). 원문과 같은 곡 금지. 어색하면 song/artist 빈 문자열.",
    "JSON만 출력. 키: text, song, artist.",
    '예: {"text":"기다림도 괜찮아요. 천천히 와도 돼요.","song":"Wait","artist":"M83"}',
    "",
    `테마(참고만, 답의 주제로 쓰지 말 것): ${theme || "unknown"}`,
    songLine,
    `원문: ${body}`,
  ].join("\n");

  try {
    const model = getVertexModel();
    const result = await model.generateContent({
      contents: [{ role: "user", parts: [{ text: prompt }] }],
    });
    return parseGeminiPayload(extractVertexText(result));
  } catch (err) {
    console.error("vertex gemini reply failed:", err.message || err);
    return null;
  }
}

/** Push the memo author when a new reply sticky appears. */
async function notifyAuthorOfReply({ memoId, authorUid, theme }) {
  if (!authorUid || String(authorUid).startsWith("ambient_")) return;

  const userSnap = await db.collection("users").doc(authorUid).get();
  if (!userSnap.exists) {
    console.log(`no user doc for ${authorUid}`);
    return;
  }
  const token = String(userSnap.data()?.fcmToken || "").trim();
  if (!token) {
    console.log(`no fcmToken for ${authorUid}`);
    return;
  }

  try {
    await messaging.send({
      token,
      notification: {
        title: "Parallel",
        body: "마음걸이에 새 흔적이 닿았어요.",
      },
      data: {
        type: "memo_reply",
        memoId: String(memoId || ""),
        theme: String(theme || ""),
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
      android: {
        priority: "high",
        notification: {
          channelId: "parallel_traces",
          sound: "default",
        },
      },
    });
    console.log(`push sent to ${authorUid} for memo ${memoId}`);
  } catch (err) {
    console.error(`push failed for ${authorUid}:`, err.message || err);
    if (
      err.code === "messaging/registration-token-not-registered" ||
      err.code === "messaging/invalid-registration-token"
    ) {
      await userSnap.ref.set(
        { fcmToken: FieldValue.delete(), fcmUpdatedAt: FieldValue.delete() },
        { merge: true },
      );
    }
  }
}

/** After a memo lands, schedule a soft delayed ambient reply. */
exports.onMemoCreated = onDocumentCreated("memos/{memoId}", async (event) => {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data() || {};
  const uid = String(data.uid || "");
  const due = Timestamp.fromMillis(Date.now() + randomDelayMs());

  await snap.ref.set(
    {
      ambientReplyAt: due,
      ambientReplied: false,
    },
    { merge: true },
  );

  console.log(
    `scheduled ambient reply for ${event.params.memoId} uid=${uid} at ${due.toDate().toISOString()}`,
  );
});

/** When replies grow, notify the memo author. */
exports.onMemoReply = onDocumentUpdated("memos/{memoId}", async (event) => {
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  const beforeKeys = new Set(replyKeys(before));
  const added = replyKeys(after).filter((k) => !beforeKeys.has(k));
  if (added.length === 0) return;

  const authorUid = String(after.uid || "");
  const external = added.filter((k) => k !== authorUid);
  if (external.length === 0) return;

  await notifyAuthorOfReply({
    memoId: event.params.memoId,
    authorUid,
    theme: after.theme,
  });
});

/** Sweep due memos and leave one comfort sticky. */
exports.ambientReplySweep = onSchedule("every 2 minutes", async () => {
  const entries = replyEntries();
  if (entries.length === 0) {
    console.warn("reply_pool.json is empty");
    return;
  }

  const now = Timestamp.now();
  const snap = await db
    .collection("memos")
    .where("ambientReplied", "==", false)
    .where("ambientReplyAt", "<=", now)
    .limit(20)
    .get();

  if (snap.empty) {
    console.log("no due ambient replies");
    return;
  }

  let posted = 0;
  for (const doc of snap.docs) {
    const ok = await tryPostAmbientReply(doc, entries);
    if (ok) posted += 1;
    if (posted >= 5) break;
  }
  console.log(`ambient replies posted: ${posted}`);
});

async function tryPostAmbientReply(doc, entries) {
  const data = doc.data() || {};
  if (data.ambientReplied === true) return false;

  const expiresAt = data.expiresAt;
  if (expiresAt && expiresAt.toMillis && expiresAt.toMillis() <= Date.now()) {
    await doc.ref.set({ ambientReplied: true }, { merge: true });
    return false;
  }

  const existing =
    data.replies && typeof data.replies === "object" ? data.replies : {};
  if (Object.keys(existing).length > 0) {
    await doc.ref.set({ ambientReplied: true }, { merge: true });
    return false;
  }

  const memoText = String(data.text || "");
  const song = String(data.song || "").trim();
  const artist = String(data.artist || "").trim();
  const hasSong = song.length > 0 || artist.length > 0;

  let payload = await generateGeminiReply({
    memoText,
    song,
    artist,
    theme: data.theme,
  });
  let source = "gemini";
  if (!payload?.text) {
    const entry = pickReplyForMemo(entries, memoText, hasSong);
    payload = {
      text: String(entry?.text || "").trim().slice(0, MAX_REPLY_LEN),
      song: String(entry?.song || "").trim().slice(0, 40),
      artist: String(entry?.artist || "").trim().slice(0, 40),
    };
    source = "pool";
  }
  if (!payload?.text) return false;

  const replyText = payload.text;
  const replySong = String(payload.song || "").trim().slice(0, 40);
  const replyArtist = String(payload.artist || "").trim().slice(0, 40);

  const ref = doc.ref;
  return db.runTransaction(async (tx) => {
    const fresh = await tx.get(ref);
    if (!fresh.exists) return false;

    const live = fresh.data() || {};
    if (live.ambientReplied === true) return false;

    const liveExpires = live.expiresAt;
    if (liveExpires && liveExpires.toMillis && liveExpires.toMillis() <= Date.now()) {
      tx.set(ref, { ambientReplied: true }, { merge: true });
      return false;
    }

    const replies =
      live.replies && typeof live.replies === "object" ? { ...live.replies } : {};
    const used = new Set(Object.keys(replies));
    if (used.size > 0 || used.size >= MAX_REPLIES) {
      tx.set(ref, { ambientReplied: true }, { merge: true });
      return false;
    }

    const author = String(live.uid || "");
    const uid = pickAmbientUid(new Set([...used, author]));
    const anchor = randomAnchor();
    replies[uid] = {
      text: replyText,
      artist: replyArtist,
      song: replySong,
      createdAt: Timestamp.now(),
      x: anchor.x,
      y: anchor.y,
    };

    tx.update(ref, {
      replies,
      ambientReplied: true,
      ambientReplyAt: FieldValue.delete(),
      replyText: FieldValue.delete(),
      replyUid: FieldValue.delete(),
      replyCreatedAt: FieldValue.delete(),
    });
    console.log(
      `ambient reply (${source}) for ${doc.id}: ${replyText}` +
        (replySong ? ` ♪ ${replyArtist} - ${replySong}` : ""),
    );
    return true;
  });
}
