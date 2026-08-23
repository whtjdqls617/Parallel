# Ambient auto-replies + reply push

## Ambient replies

누군가 메모를 남기면 **3~15분 뒤** 답장이 없을 때, `ambient_*`가 위로 한마디를 남깁니다.

1. **Vertex AI Gemini** (`gemini-2.5-flash-lite`)가 원문에 맞게 짧은 한국어 답장 생성  
2. 실패 시 `reply_pool.json` 분위기 매칭으로 fallback

Firebase 프로젝트의 서비스 계정을 쓰므로 별도 API 키 시크릿은 필요 없습니다.  
GCP에서 **Vertex AI API**가 켜져 있어야 합니다.

## Reply push

`replies`에 새 스티커가 생기면 글 작성자의 FCM으로 푸시:
- 제목: Parallel  
- 본문: 마음걸이에 새 흔적이 닿았어요.

앱이 `users/{uid}.fcmToken`을 저장해 둬야 합니다.

### iOS 필수

Firebase Console → Project settings → Cloud Messaging → **APNs Authentication Key** 업로드.

## 배포

```bash
cd functions && npm install && cd ..
firebase deploy --only functions,firestore:rules
```
