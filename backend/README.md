# CodeYoung Backend API

The REST API behind the CodeYoung app: a Node.js server with **real SQL
persistence** and no native build steps.

## Design choice

Storage uses Node's **built-in `node:sqlite`** module rather than a
native-compiled driver. That means `npm install` needs no compiler, no
prebuilt binaries, and no database server to run — the whole backend starts
with `node server.js`.

Passwords are hashed with **`scrypt`** from `node:crypto` (salted, with the
parameters stored alongside the hash).

## Install & run

```bash
cd backend
npm install
npm start            # → http://127.0.0.1:3000
```

Or from the repository root: `scripts\start-backend.cmd`

The database file is created and **seeded automatically on first run**, so
there is no migration step.

## Health check

```bash
curl http://localhost:3000/health
```

```json
{ "status": "ok", "database": "sqlite", "seeded": true }
```

## Endpoints

### Public content
| Method | Path | Notes |
|--------|------|-------|
| GET | `/health` | Service + DB status |
| GET | `/api/home` | Home payload (banners, story, founders, courses) |
| GET | `/api/about` | About payload |
| GET | `/api/banners` | 3 premium banners |
| GET | `/api/courses` | All 8 courses |
| GET | `/api/courses/:slug` | Course detail + lessons |
| GET | `/api/lessons` | All lessons (`?category=` to filter) |
| GET | `/api/lessons/:id` | Lesson detail (+ progress when authorised) |
| GET | `/api/videos` | All videos |
| GET | `/api/videos/:id` | Video detail |
| GET | `/api/gallery` | Gallery images |

### Auth & progress
| Method | Path | Notes |
|--------|------|-------|
| POST | `/api/auth/login` | Returns a bearer token |
| GET | `/api/auth/me` | Current user (auth) |
| POST | `/api/progress` | Record lesson progress (auth) |
| GET | `/api/user/stats` | Level, XP, lessons done (auth) |

### Mentor (proxied to the Python service on :5001)
| Method | Path | Notes |
|--------|------|-------|
| POST | `/api/chat` | Reply + optional base64 audio + sources |
| GET | `/api/chat/history` | Conversation history |
| DELETE | `/api/chat/history` | Clear it (auth) |
| POST | `/api/chat/tts` | Text → speech only |

## Demo accounts

| Email | Password |
|-------|----------|
| `learner@codeyoung.com` | `password` |
| `student@codeyoung.com` | `password` |

## Seeded data

8 courses, 25 lessons, 12 videos, 18 gallery images, 3 banners.

Course slugs: `scratch-programming`, `python-basics`, `web-development`,
`javascript-games`, `robotics-arduino`, `math-mastery`, `english-language`,
`science-explorers`.

Video thumbnails use `https://img.youtube.com/vi/<id>/hqdefault.jpg`, and the
lesson videos are served from verified-live public MP4 URLs.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `PORT` | `3000` | Server port |
| `CORS_ORIGIN` | `*` | Allowed CORS origin |
| `MENTOR_URL` | `http://127.0.0.1:5001` | Python mentor base URL |
| `DB_PATH` | `codeyoung.db` | SQLite file location |

## Notes

- Requests carry `Authorization: Bearer <token>`; the Flutter client attaches
  it via a Dio interceptor, so logged-in users see their own progress in the
  course and lesson lists.
- The chat endpoint always returns HTTP 200 with a graceful message when the
  Python mentor is unreachable, rather than failing the screen.
