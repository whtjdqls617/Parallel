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
const { isAllowed } = require("./content_filter");

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
      temperature: 0.95,
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
  // Wide paper scatter — keep clear of upper-left body text when possible.
  const band = Math.random();
  if (band < 0.45) {
    // lower strip
    return {
      x: Number((0.08 + Math.random() * 0.78).toFixed(3)),
      y: Number((0.58 + Math.random() * 0.32).toFixed(3)),
    };
  }
  if (band < 0.75) {
    // right margin
    return {
      x: Number((0.62 + Math.random() * 0.28).toFixed(3)),
      y: Number((0.36 + Math.random() * 0.52).toFixed(3)),
    };
  }
  // soft mid/low elsewhere
  return {
    x: Number((0.12 + Math.random() * 0.70).toFixed(3)),
    y: Number((0.48 + Math.random() * 0.40).toFixed(3)),
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
  place: [
    "바람",
    "파도",
    "하늘",
    "별",
    "숲",
    "바다",
    "사막",
    "모래",
    "나무",
    "달",
    "불",
    "장작",
    "벽난로",
    "온기",
    "온정",
    "불빛",
    "불멍",
  ],
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
  const usable = entries.filter((e) => {
    const tags = Array.isArray(e.moods) ? e.moods : ["any"];
    const text = String(e.text || "");
    // Never claim the author left a song unless they did.
    if (!hasSong) {
      if (tags.length === 1 && tags[0] === "song") return false;
      if (/노래|곡까지|곡을 남|곡 남|♪/.test(text)) return false;
    }
    return true;
  });
  const pool = usable.length ? usable : entries;

  const matched = pool.filter((e) => {
    const tags = Array.isArray(e.moods) ? e.moods : ["any"];
    return tags.some((t) => moods.includes(t));
  });
  if (matched.length) return pick(matched);

  const soft = pool.filter((e) => {
    const tags = Array.isArray(e.moods) ? e.moods : ["any"];
    return tags.includes("any") || tags.length === 0;
  });
  return pick(soft.length ? soft : pool);
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
    "당신은 Parallel 앱에서 스쳐 가는 사람이 남긴 쪽지에 답하는 평범한 사람입니다.",
    "운영진·상담사·코치·AI 티 나는 말투 금지.",
    "",
    "가장 중요: 원문의 핵심 말·상황에 직접 반응하세요.",
    "풍경·테마 비유만으로 흐리게 가지 마세요. 원문 키워드를 놓치면 실패입니다.",
    "",
    "말투: 반말·존댓말·해요체 모두 OK. 사람마다 다르게. 같은 패턴 반복 금지.",
    "길이: 한국어 1~2문장, 80자 이내. 따뜻하되 과하게 상담하지 말 것.",
    "",
    "노래 규칙 (매우 중요):",
    `- ${songLine}`,
    "- 원문에 노래가 없으면: text에서 '곡 남겨줘서', '노래 고른 거', '그 노래'처럼 원문이 노래를 올렸다고 말하지 말 것.",
    "- 원문에 노래가 있을 때만 그 곡에 반응해도 됨. 같은 곡을 다시 추천하지 말 것.",
    "- 분위기에 맞는 실제 곡 추천은 선택(약 35%). 추천할 때만 song/artist 채우고, 안 하면 둘 다 빈 문자열.",
    "- 곡 추천은 JSON 필드로만. text에 '이 노래 들어봐: ○○'처럼 억지로 끼워 넣지 말 것.",
    "- 가수 한국이면 이름 한글. 곡 제목은 공식 표기(한글 제목은 한글, 영어 제목은 영어).",
    "",
    "JSON만 출력. 키: text, song, artist.",
    '예(노래 없음): {"text":"그 말 읽으니까 괜히 숨이 느려지네.","song":"","artist":""}',
    '예(존댓말): {"text":"그 온기, 저도 느껴졌어요. 천천히 계세요.","song":"","artist":""}',
    '예(추천만 필드): {"text":"오늘 같은 밤에 잘 어울리는 말이네요.","song":"Holocene","artist":"Bon Iver"}',
    "",
    `테마(참고만, 답의 주제로 쓰지 말 것): ${theme || "unknown"}`,
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
  if (!isAllowed(memoText)) {
    console.log(`skip ambient reply (blocked memo) ${doc.id}`);
    await doc.ref.set({ ambientReplied: true }, { merge: true });
    return false;
  }

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
  // Drop replies that pretend the memo left a song when it didn't.
  if (
    payload?.text &&
    !hasSong &&
    /곡까지|곡을 남|곡 남|노래 고른|그 노래|♪/.test(payload.text)
  ) {
    payload = null;
  }
  if (!payload?.text || !isAllowed(payload.text)) {
    const entry = pickReplyForMemo(entries, memoText, hasSong);
    payload = {
      text: String(entry?.text || "").trim().slice(0, MAX_REPLY_LEN),
      song: String(entry?.song || "").trim().slice(0, 40),
      artist: String(entry?.artist || "").trim().slice(0, 40),
    };
    source = "pool";
  }
  if (!payload?.text || !isAllowed(payload.text)) return false;

  // Drop song fields if they trip the filter.
  let replySong = String(payload.song || "").trim().slice(0, 40);
  let replyArtist = String(payload.artist || "").trim().slice(0, 40);
  if (!isAllowed(`${replyArtist} ${replySong}`.trim())) {
    replySong = "";
    replyArtist = "";
  }
  const replyText = payload.text;

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
