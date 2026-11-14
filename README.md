# CodeYoung — Learn Coding for Kids

A complete, working implementation of the CodeYoung learning platform
(www.codeyoung.com): a **Flutter** app, a **Node.js** REST API with real SQL
persistence, and a **Python** voice mentor with live-internet Q&A.

```
flutter_application_1/
├── CodeYoung/     Flutter app (UI, all screens)
├── backend/       Node.js REST API  → http://127.0.0.1:3000
├── chatbot/       Python mentor     → http://127.0.0.1:5001
└── scripts/       One-command runners
```

## Quick start

```powershell
# 1. Start both services (opens a window each)
powershell -ExecutionPolicy Bypass -File scripts\start-all.ps1

# 2. In a second terminal, run the app
cd CodeYoung
flutter run                 # any device
flutter run -d chrome       # web in Chrome
flutter build web           # production web build
```

Or start them individually:

| Script | Service | Port |
|--------|---------|------|
| `scripts\start-backend.cmd` | Node.js API (SQLite) | 3000 |
| `scripts\start-chatbot.cmd` | Python mentor (Flask) | 5001 |

The app auto-selects `http://10.0.2.2:3000` on the Android emulator and
`http://127.0.0.1:3000` everywhere else.

## What's in the app

Five bottom-nav tabs, plus pushed detail routes:

| Tab | Screen | Notes |
|-----|--------|-------|
| **Home** | `home_screen.dart` | Explains CodeYoung, founders & co-founders, the story/journey |
| **About** | `about_screen.dart` | Company, mission, flow chart, gallery |
| **Courses** | `courses_screen.dart` | 8 courses → detail → lessons → lesson detail |
| **Mentor** | `chat_screen.dart` | Voice chatbot: speech input + spoken replies |
| **Account** | `account_screen.dart` | Profile, XP/level, progress, sign out |

Pushed routes: **Videos** (MP4 + YouTube with thumbnails), **Gallery**
(zoom/swipe), **Lessons**, **Settings**, **Login/Splash**.

## Demo accounts

| Email | Password |
|-------|----------|
| `learner@codeyoung.com` | `password` |
| `student@codeyoung.com` | `password` |

## The mentor

Chat flow: `Flutter → Node /api/chat → Python /chat`. Replies are synthesised
to speech (gTTS, with edge-tts fallback) and returned as base64 audio.

Answer priority:

1. **Arithmetic** — solved exactly (`15% of 240` → `36`), never looked up.
2. **Knowledge base** — 17 curated CodeYoung entries (courses, pricing,
   founders, free trial, curriculum).
3. **Live internet** — DuckDuckGo Instant Answer, then Wikipedia, but only
   when the result actually matches the question.

Guardrails, because a confidently-wrong answer is worse than no answer:

- Every candidate is scored against the question's key terms; anything below
  threshold is rejected rather than served.
- A kids-safety filter drops adult articles from both search and snippets.
- Maths-looking questions never reach the search engines.
- Wikipedia results are cached (TTL 600s) with a per-host 429 cooldown, a
  polite per-minute request budget, and a fallback to the separate
  `api.wikimedia.org` service — so a burst of questions degrades to the
  knowledge base instead of getting rate-limited.

## API surface

```
GET  /health
GET  /api/home  /api/about  /api/banners
GET  /api/courses  /api/courses/:slug
GET  /api/lessons  /api/lessons/:id        (+ per-user progress when authorised)
GET  /api/videos  /api/videos/:id
GET  /api/gallery
POST /api/auth/login        GET /api/auth/me
POST /api/progress          GET /api/user/stats
POST /api/chat              GET/DELETE /api/chat/history
POST /api/chat/tts
```

Storage is SQLite via Node's built-in `node:sqlite` module (no native build
steps); passwords are hashed with `scrypt`.

## Verification status

- `flutter analyze` → **No issues found** (0 errors, 0 warnings, 0 infos)
- `flutter build web` → succeeds
- All API endpoints exercised end-to-end, including chat + TTS
- A 12-question burst through the full Node → Python chain returns correct
  answers for every question

### Known environment limits

- `flutter test` cannot run here: Windows Application Control/WDAC blocks
  `flutter_tester.exe`. Not a code issue.
- No Android SDK is installed in this environment, so APK/AAB builds are not
  possible — `flutter build web` is used as the compile check instead.

## Docs

- [`CodeYoung/README.md`](CodeYoung/README.md) — Flutter app detail
- [`backend/README.md`](backend/README.md) — API + database detail
