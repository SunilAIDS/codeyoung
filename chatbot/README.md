# CodeYoung Mentor — Python Voice Chatbot

The Python service behind the in-app mentor: answers questions, optionally
speaks them aloud, and can search the live internet when it actually knows
what it is looking for.

## Run

```bash
cd chatbot
python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -r requirements.txt
python app.py                   # → http://127.0.0.1:5001
```

Or from the repository root: `scripts\start-chatbot.cmd`

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Status, TTS engine, KB size, search flag |
| POST | `/chat` | `{message, history?, speak?, lang?}` → `{reply, source, sources, live, audio?}` |
| POST | `/tts` | `{text, lang?}` → `{audio, mime, engine}` |

## How an answer is chosen

Priority order:

1. **Arithmetic** (`source: calculator`) — evaluated locally, never searched.
   `15% of 240` → `36`, `12 + 7` → `19`, `half of 30` → `15`, and division by
   zero is refused politely.
2. **Knowledge base** (`source: codeyoung`) — 17 curated entries covering
   courses, pricing, the free trial, founders and curriculum.
3. **Live internet** (`source: web` / `codeyoung+web`) — DuckDuckGo Instant
   Answer first, then Wikipedia. Sources are returned so the UI can show
   where the answer came from.
4. **Fallback** — a polite "I don't know" plus suggestions, rather than a
   fabricated answer.

### Why the guards exist

A confidently-wrong answer is worse than no answer — especially for children.
So:

- `_key_terms()` strips stopwords and filler phrases, then every candidate
  result is scored with `_relevant()` (recall + precision, minus a noise
  penalty). Below threshold → rejected.
- `_text_relevant()` applies the same idea to plain prose where there is no
  article title to judge against.
- `_safe()` is a kids-safety filter applied to both titles and snippets; adult
  articles never reach the model answer.
- `_looks_like_maths()` keeps sums away from the search engines entirely
  (otherwise `15% of 240` happily returns the Wikipedia article for the year
  240).

### Staying polite with Wikipedia

Wikipedia rate-limits bursts of questions. Handled by:

- a **600s TTL cache** (`WIKI_CACHE_TTL`) so repeat questions are instant,
- a **per-host cooldown** on the first 429, honouring `Retry-After`,
- a **per-minute request budget** (`WIKI_BUDGET`, default 24) so we stay
  under the limit instead of discovering it,
- a **fallback to `api.wikimedia.org`** — a separate service that keeps
  answering while `en.wikipedia.org` is cooling down.

The net effect: during a rapid burst, later questions degrade to the
knowledge base instead of every host getting banned for a minute.

## Text to speech

`gTTS` by default, `edge-tts` as fallback. The engine actually in use is
reported by `/health` and by every `/tts` response (`engine` field).

## Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `PORT` | `5001` | Service port |
| `TTS_ENGINE` | `gtts` | `gtts` or `edge` |
| `SEARCH_ENABLED` | `1` | Set `0` to disable live internet answers |
| `WIKI_CACHE_TTL` | `600` | Seconds to cache Wikipedia responses |
| `WIKI_COOLDOWN` | `20` | Seconds to back off after a 429 |
| `WIKI_BUDGET` | `24` | Max Wikipedia-family requests per minute |
| `HTTP_TIMEOUT` | `8` | Outbound HTTP timeout (seconds) |
| `RATE_LIMIT` | `40` | Max chat requests per client per minute |

## Verified

- `/health` → `{"tts_engine": "gtts", "knowledge_entries": 17, "search_enabled": true}`
- A 12-question burst through Node → Python returns correct answers for every
  question, including live-web ones.
