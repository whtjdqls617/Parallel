# Ambient memo 운영 (글 올리기 + 위로 답장)

사람이 적을 때 보드가 비지 않게, **글 남기기**와 **위로 답장**을 합니다.  
Admin SDK라서 앱 로그인 없이 동작하고, `ambient_*` 가짜 사람으로 보여서 한 계정처럼 안 보입니다.

---

## 추천: 관리자 웹 (로컬)

터미널에서 아래를 **한 번** 실행한 뒤, 주소로 들어가세요.
(브라우저만 열면 안 되고, 서버를 먼저 켜야 합니다.)

```bash
cd /Users/seocho/Projects/Parallel/ops
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python admin_server.py
```

끝나면 터미널에 `Parallel admin → http://127.0.0.1:8787` 이 뜹니다.  
그다음 브라우저에서 **http://127.0.0.1:8787** 열기.

끄려면 그 터미널에서 `Ctrl+C`.

(이미 `.venv` 만들어 둔 상태면 마지막 줄만:)
```bash
cd /Users/seocho/Projects/Parallel/ops
.venv/bin/python admin_server.py
```

(Node 18+ 있으면 `npm install && npm run admin:node` 도 가능)

- 위: **스토어 버전** (iOS/Android 따로 · 스토어 반영 확인 후 DB 올리기 → major/minor면 강제 업데이트)
- 그다음: 글 올리기 (테마 / 글 / 곡 / 가수)
- 아래: 살아 있는 글 목록 → **이 글에 답장** 누르면 id 채워짐 → 위로 쓰기
- **localhost만** 열려 있어요. 인터넷에 공개하지 마세요.

서비스 계정 JSON은 `ops/serviceAccount.json` 또는 `*firebase-adminsdk*.json` 이름이면 자동으로 찾습니다.

---

## 한 번만 준비

1. [Firebase Console](https://console.firebase.google.com) → 프로젝트  
   **Project settings → Service accounts → Generate new private key**
2. 받은 JSON을 여기에 저장:
   ```
   ops/serviceAccount.json
   ```
   (비밀키 — 깃에 올리지 마세요. 이미 `.gitignore`에 넣어둠.)
3. 터미널:
   ```bash
   cd ops
   npm install
   ```

---

## 터미널로 하기 (선택)

## ① 글 올리기 (마음걸이 흔적)

### 평소: 풀에 쌓아 두고 랜덤

`memo_pool.json`의 `entries`를 채웁니다.

| 필드 | 설명 | 제한 |
|------|------|------|
| `theme` | `desert` / `forest` / `ocean` / `space`(별) / `rain`(창공) / `fire`(불멍) | 필수 |
| `text` | 본문 | 1~80자 |
| `song` / `artist` | 없으면 `""` | ≤40자 |

```bash
cd ops
node post_ambient_memo.mjs                         # 랜덤 1개
node post_ambient_memo.mjs --theme desert --count 3
node post_ambient_memo.mjs --all-themes             # 테마마다 1개
node post_ambient_memo.mjs --dry-run                # 미리보기만
```

### 지금 당장 한 줄만

```bash
node post_ambient_memo.mjs --theme ocean --text "파도 소리만 듣고 가도 될 것 같아요."
node post_ambient_memo.mjs --theme desert --text "오늘도 여기 앉아 있어요." --song "Lost Stars" --artist "Adam Levine"
```

앱에서 해당 테마 마음걸이를 열면 보입니다. **24시간 후 만료**.

---

## ② 위로 답장

답장도 `ambient_*`로 남깁니다. (앱에서 본인 계정으로 답장해도 되지만, 운영용은 이 스크립트가 “지나가는 사람”처럼 보이게 합니다.)

### 평소: 위로 문구 풀

`reply_pool.json`의 `entries`를 채웁니다. (`text` / `song` / `artist`, 제한은 위와 동일)

### 살아 있는 글 목록 보기

```bash
cd ops
node reply_ambient_memo.mjs --list
node reply_ambient_memo.mjs --list --theme desert
```

출력 예:
```
abc123...  [desert]  [no reply]  오늘도 그냥 여기…
def456...  [ocean]   [replies:1]  파도 소리만…
```

앞에 나온 **id**가 답장할 때 쓰는 memo id입니다.

### 특정 글에 직접 위로

```bash
# 풀에서 랜덤 위로
node reply_ambient_memo.mjs --memo abc123...

# 지금 쓴 문장으로
node reply_ambient_memo.mjs --memo abc123... --text "여기 있어도 괜찮아요. 천천히 쉬어요."

# 노래 붙여서
node reply_ambient_memo.mjs --memo abc123... --text "남겨 줘서 고마워요." --song "Holocene" --artist "Bon Iver"
```

### 답장 없는 글에 자동으로 몇 개

```bash
node reply_ambient_memo.mjs --unreplied --count 3
node reply_ambient_memo.mjs --unreplied --theme ocean --count 2
node reply_ambient_memo.mjs --unreplied --count 5 --dry-run
```

---

## 추천 루틴

1. **아침에** `memo_pool` / `reply_pool`에 문장·노래 몇 개 추가  
2. `node post_ambient_memo.mjs --all-themes` 로 테마마다 글 올리기  
3. 하루 몇 번 `node reply_ambient_memo.mjs --list` 로 확인  
4. 사람 글·빈 글에 ` --memo ... --text "..."` 또는 `--unreplied` 로 위로  

초반 밀도 감: **테마당 하루 글 2~4개**, 답장은 **답 없는 글 위주**로. 너무 잦으면 티가 납니다.

---

## 앱에서 직접 해도 됨

- **글**: Plus(또는 체험)로 마음걸이에서 남기기  
- **답장**: 남의 흔적 열고 답장 스티커  

다만 앱으로 하면 **네 실제 uid**로 남습니다.  
“모르는 사람이 남긴 것처럼” 보이게 하려면 위 스크립트를 쓰세요.

---

## 참고

- 한 메모당 답장 **최대 12개**, **uid당 1개** (같은 ambient uid는 같은 글에 두 번 못 함 — 스크립트가 빈 uid를 고름).
- **자동 위로 답장**: `functions/` Cloud Function — 메모 후 3~15분, 답 없으면 달림. (`functions/README.md`)
- `serviceAccount.json`은 절대 공개하지 마세요.
- cron으로 자동 돌리기 예시는 아래.

**macOS cron 예 (3시간마다 글 1개)**  
`crontab -e`:

```
0 */3 * * * cd /절대경로/Parallel/ops && /usr/local/bin/node post_ambient_memo.mjs --count 1 >> /tmp/parallel-ambient.log 2>&1
```
