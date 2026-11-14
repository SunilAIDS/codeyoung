"""
CodeYoung Mentor Service
========================

Flask service that powers the in-app chatbot:

  POST /chat   -> answers a question, searching the live internet first and
                  falling back to a built-in CodeYoung knowledge base.
  POST /tts    -> synthesises speech (text -> mp3, base64) so replies can be
                  read aloud in the app.
  GET  /health -> liveness probe.

Run:  python app.py            (defaults to 0.0.0.0:5001)
Env:  PORT, HOST, TTS_ENGINE, TTS_VOICE, SEARCH_ENABLED, SEARCH_DEADLINE
"""

from __future__ import annotations

import base64
import hashlib
import html
import io
import json
import os
import re
import threading
import time
import unicodedata
from collections import deque
from concurrent.futures import Future

import requests
from flask import Flask, jsonify, request

# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #

HOST = os.environ.get("HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT", "5001"))
# edge = Microsoft neural voices: much faster and far more natural than gTTS,
# and the default voice below is a female one (see TTS_VOICE).
TTS_ENGINE = os.environ.get("TTS_ENGINE", "edge")  # edge | gtts | none
TTS_VOICE = os.environ.get("TTS_VOICE", "en-US-JennyNeural")
TTS_CACHE_MAX = int(os.environ.get("TTS_CACHE_MAX", "128"))
SEARCH_ENABLED = os.environ.get("SEARCH_ENABLED", "1") not in ("0", "false", "no")
UA = {"User-Agent": "Mozilla/5.0 (CodeYoungMentor/1.0)"}
HTTP_TIMEOUT = float(os.environ.get("HTTP_TIMEOUT", "5"))

app = Flask(__name__)

# Simple in-memory rate limiting per session.
_HITS: dict[str, deque[float]] = {}
_RATE_LIMIT = int(os.environ.get("RATE_LIMIT", "40"))
_RATE_WINDOW = 60.0

# Per-request search budget. Flask runs each request on its own thread, so a
# thread-local deadline lets every search helper stop early without threading
# a `deadline` argument through five call layers.
SEARCH_DEADLINE = float(os.environ.get("SEARCH_DEADLINE", "5"))
_REQ = threading.local()


def _deadline() -> float | None:
    return getattr(_REQ, "deadline", None)


def _expired() -> bool:
    """True once this request has spent its whole search budget."""
    d = _deadline()
    return d is not None and time.time() > d


def _remaining() -> float | None:
    """Seconds left in this request's search budget, or None if untimed."""
    d = _deadline()
    return None if d is None else max(0.0, d - time.time())


# --------------------------------------------------------------------------- #
# Knowledge base (CodeYoung-specific facts + curriculum answers)
# --------------------------------------------------------------------------- #

KNOWLEDGE_BASE: list[dict] = [
    {
        "topics": ["codeyoung", "about", "company", "who are you", "founded", "story", "mission"],
        "answer": (
            "Codeyoung is an online learning platform for kids, founded in late 2019 by "
            "Shailendra Dhakad (Co-founder & CEO, IIT Delhi) and Rupika Taneja "
            "(Co-founder & COO, IIT Delhi). Our mission is that kids of today are the "
            "innovators of tomorrow, and we empower them through effective and simplified "
            "education. Over 20,000 students and 50,000+ parents trust us, with a 4.5+/5 "
            "rating. The company operates as Smart Owl Education Pvt Ltd."
        ),
        "source": "codeyoung",
    },
    {
        "topics": ["founder", "ceo", "shailendra", "rupika", "co-founder", "coo"],
        "answer": (
            "Codeyoung has two co-founders, both IIT Delhi graduates: "
            "Shailendra Dhakad, Co-founder & CEO, who says 'Meaning of Education should be "
            "a process that empowers an individual to do something which otherwise they "
            "cannot'; and Rupika Taneja, Co-founder & COO, who believes that if the innate "
            "creativity in kids is properly nurtured and finds expression, we can cultivate "
            "leaders."
        ),
        "source": "codeyoung",
    },
    {
        "topics": ["course", "courses", "curriculum", "subjects", "classes", "programs", "learn"],
        "answer": (
            "We run 1:1 live online courses in Coding, Math, English, Science, Robotics and "
            "Financial Literacy. Coding tracks include Scratch (ages 6-9), Python for "
            "Beginners (9-13), Web Development (10-15), JavaScript Game Dev (11-16) and "
            "Robotics & Arduino (10-15). Every course is mentor-led, mastery-based and "
            "starts as low as $22 per class, with a free trial available."
        ),
        "source": "codeyoung",
    },
    {
        "topics": ["price", "cost", "fee", "fees", "how much", "payment", "trial", "free"],
        "answer": (
            "Courses start at about $22 per class, and the Sandbox learning platform is $60 "
            "per year (free when you take an online course). Every new family can book a "
            "FREE trial class first — you choose the course, pick a mentor and a time slot, "
            "and only enroll if you like it."
        ),
        "source": "codeyoung",
    },
    {
        "topics": ["trial", "book", "demo", "enroll", "join", "sign up", "register"],
        "answer": (
            "Getting started takes three steps: 1) select a course based on your child's age "
            "or grade, 2) book the FREE trial class by choosing a mentor and a preferred time "
            "slot, 3) enroll for the course if you like the demo. All you need is a "
            "functioning PC and a stable internet connection."
        ),
        "source": "codeyoung",
    },
    {
        "topics": ["1:1", "one on one", "bloom", "sigma", "personal", "attention", "mentor", "teacher"],
        "answer": (
            "Our model is 1:1 live learning: one child, one mentor, real attention and clear "
            "progress. It's based on Benjamin Bloom's 2 Sigma research, which found that a "
            "one-to-one tutored student performs better than 98% of peers. Mentors adapt "
            "lessons to each child's pace, track mastery before moving on, and give "
            "real-time feedback. Fewer than 1% of applicants become Codeyoung mentors."
        ),
        "source": "codeyoung",
    },
    {
        "topics": ["python", "variables", "loops", "function", "list", "dictionary", "string"],
        "answer": (
            "In Python, variables hold values without a type declaration, so `name = \"Ada\"` "
            "stores text and `count = 5` stores a number. Use `for i in range(5):` to repeat "
            "a block five times, `if/elif/else` to branch, and `def greet():` to define a "
            "function. Lists like `fruits = [\"apple\", \"banana\"]` keep items in order, and "
            "you index them from zero: `fruits[0]` is \"apple\"."
        ),
        "source": "curriculum",
    },
    {
        "topics": ["html", "css", "web", "website", "div", "flexbox", "responsive", "tag"],
        "answer": (
            "HTML gives a page structure and CSS styles it. A minimal page is `<!doctype "
            "html><html><head><title>Hi</title></head><body><h1>Hello</h1></body></html>`. "
            "For layout, Flexbox arranges items in one direction with `display:flex` and "
            "`justify-content`, while Grid handles two dimensions with `grid-template-columns`. "
            "Make it responsive with a media query like `@media (max-width: 600px) { ... }`."
        ),
        "source": "curriculum",
    },
    {
        "topics": ["javascript", "array", "object", "dom", "event", "const", "let", "async"],
        "answer": (
            "JavaScript adds behaviour to a page. Declare with `const` for values that never "
            "rebind and `let` for ones that change. Arrays have methods like `.map()`, "
            "`.filter()` and `.reduce()`. Select an element with `document.querySelector('#id')`, "
            "then attach behaviour with `el.addEventListener('click', () => { ... })`. Modern "
            "code uses `async`/`await` for network requests."
        ),
        "source": "curriculum",
    },
    {
        "topics": ["robot", "arduino", "sensor", "motor", "circuit", "hardware"],
        "answer": (
            "An Arduino is a small microcontroller you program to sense and control the "
            "physical world. You write a sketch, upload it over USB, and it reads sensors "
            "(ultrasonic, IR, temperature) through analog or digital pins and drives motors "
            "through a driver board. Our Robotics & Arduino course builds up to an autonomous "
            "line-following robot."
        ),
        "source": "curriculum",
    },
    {
        "topics": ["math", "fraction", "algebra", "geometry", "number", "multiplication"],
        "answer": (
            "A good way to think about fractions is as parts of a whole: 3/4 means three of "
            "four equal pieces. Equivalent fractions like 1/2 and 2/4 cover the same amount, "
            "which you can see with an area model. For algebra, the key move is balance — "
            "whatever you do to one side of the equation, do to the other."
        ),
        "source": "curriculum",
    },
    {
        "topics": ["science", "force", "gravity", "experiment", "matter"],
        "answer": (
            "Science at Codeyoung is learned by doing. For example, forces are pushes and "
            "pulls that change an object's motion — friction resists motion, and gravity pulls "
            "objects toward each other. In our States of Matter experiment you can heat ice "
            "and watch it go solid to liquid to gas, then cool it back down to see the "
            "reverse happen."
        ),
        "source": "curriculum",
    },
    {
        "topics": ["code", "programming", "algorithm", "bug", "debug", "what is coding"],
        "answer": (
            "Coding is writing precise instructions a computer follows exactly. An algorithm "
            "is the step-by-step plan for solving a problem, and a bug is any place where "
            "those instructions don't do what you intended. Debugging is the craft of finding "
            "that gap — usually by printing values, checking assumptions one at a time, and "
            "reproducing the problem in the smallest possible case."
        ),
        "source": "curriculum",
    },
    {
        "topics": ["certificate", "progress", "report", "track", "assessment", "evaluation"],
        "answer": (
            "Progress is tracked mastery-based: a concept is marked complete only when the "
            "student genuinely understands it, not when the clock runs out. Parents receive "
            "detailed personalised progress reports, and students earn certificates on course "
            "completion. Periodic assessments identify areas for growth."
        ),
        "source": "codeyoung",
    },
    {
        "topics": ["schedule", "timing", "duration", "how long", "frequency", "times per week"],
        "answer": (
            "Live online classes typically run for about an hour and are held 2 to 4 times "
            "weekly, with flexible scheduling to fit around school. The Mini Course is a "
            "shorter option: 8 sessions of 50 minutes, 1:1 live online, with one dedicated "
            "mentor — currently 33% off."
        ),
        "source": "codeyoung",
    },
    {
        "topics": ["hello", "hi", "hey", "good morning", "good evening", "how are you", "thanks", "thank you"],
        "answer": (
            "Hello! I'm your CodeYoung mentor. You can ask me about any of our courses, how "
            "1:1 classes work, pricing and the free trial — or about coding, maths and science "
            "topics like Python, HTML, JavaScript, robotics or fractions. What would you like "
            "to explore?"
        ),
        "source": "codeyoung",
    },
    {
        "topics": ["sandbox", "afterschool", "app", "quiz", "practice"],
        "answer": (
            "Sandbox is our practice platform: everything in the free AfterSchool app plus "
            "coding subjects, in-depth interactive exercises, a coding workbench, whiteboard "
            "and unlimited file storage. It's $60 per year, comes free with online courses, "
            "and the first 15 days are a free trial."
        ),
        "source": "codeyoung",
    },
]

WELCOME = (
    "Hi! I'm your CodeYoung mentor. I search the live internet for answers and can read "
    "them aloud. Ask me about our courses, the free trial, 1:1 mentors — or any coding, "
    "maths or science question."
)


# --------------------------------------------------------------------------- #
# Internet search
# --------------------------------------------------------------------------- #

def _strip_html(fragment: str) -> str:
    text = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", fragment, flags=re.S | re.I)
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)
    text = unicodedata.normalize("NFKD", text)
    return re.sub(r"\s+", " ", text).strip()


def _key_terms(query: str) -> list[str]:
    """Significant terms from a natural-language question.

    Strips question framing, common filler phrases and stopwords so we can
    both build a tighter search query and judge whether a result is actually
    relevant.
    """
    q = query.lower()
    # Filler phrasings that carry no subject matter of their own. Removing
    # "made of" is what turns "what is a website made of?" into the single
    # useful term `website` instead of `website made`.
    for pattern in (
        r"\bwhat\s+(is|are|was|were)\b",
        r"\bhow\s+(do|does|did|can|could|is|are|to)\b",
        r"\bwhy\s+(is|are|was|were|do|does|did)\b",
        r"\bwho\s+(is|are|was|were|did|invented|created|built)\b",
        r"\bmade\s+(of|from|up\s+of)\b",
        r"\bconsists?\s+of\b",
        r"\bcomposed\s+of\b",
        r"\bknown\s+as\b",
        r"\blook\s+like\b",
        r"\bworks?\s+by\b",
        r"\bplease\b",
        r"\bcan\s+you\b",
        r"\btell\s+me\b",
        r"\bi\s+am\b",
        r"\bi'?m\b",
    ):
        q = re.sub(pattern, " ", q)

    stop = {
        "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
        "do", "does", "did", "can", "could", "will", "would", "shall", "should",
        "may", "might", "must", "what", "which", "who", "whom", "whose", "when",
        "where", "why", "how", "in", "on", "at", "to", "for", "of", "and", "or",
        "with", "from", "by", "as", "it", "its", "this", "that", "these",
        "those", "i", "you", "we", "they", "me", "my", "your", "our", "us",
        "he", "she", "him", "her", "his", "tell", "explain", "describe", "give",
        "about", "please", "so", "very", "really", "just", "there", "here",
        "like", "get", "got", "have", "has", "had", "not", "no", "yes", "if",
        "into", "than", "then", "them", "their", "also", "any", "some", "much",
        "many", "more", "most", "other", "another", "all", "each", "every",
        "out", "up", "down", "over", "under", "between", "because", "while",
        "famous", "important", "useful", "good", "bad", "best", "worst",
        "am", "was", "being",
    }
    terms = re.findall(r"[a-z0-9]+", q)
    return [t for t in terms if t not in stop and len(t) > 1]


# Kids' app: never surface adult or otherwise unsuitable articles, whatever
# the search engine ranks.
_UNSAFE = re.compile(
    r"\b(porn|pornographic|xxx|nude|nudity|erotic|sexual|hentai|onlyfans"
    r"|only\s*.fans|boobs|naked|escort|fetish|bdsm|playboy|hustler"
    r"|pornhub|xvideos|redtube|youporn|tube8)\b",
    re.I,
)


def _safe(title: str, snippet: str) -> bool:
    """False when an article is clearly unsuitable for a child user."""
    return not _UNSAFE.search(f"{title} {snippet}")


def _relevant(query: str, title: str, snippet: str) -> float:
    """0..1 score of how well a result matches the user's question.

    Combines three signals:

    * recall  — do the question's key terms appear in the result?
    * precision — is the *title* made only of words the user actually asked
      about? "Capital punishment in France" answers "capital of France" far
      worse than the plain "France" article does, and this is what tells
      them apart.
    * noise   — explicit penalty for every title word unrelated to the
      question (that is what used to surface "Nicknames of San Francisco"
      for a question about France).

    The snippet counts for less than the title: search snippets are
    query-dependent and therefore noisy.
    """
    qt = set(_key_terms(query))
    if not qt:
        return 1.0

    tt = set(re.findall(r"[a-z0-9]+", title.lower()))
    st = set(re.findall(r"[a-z0-9]+", snippet.lower()))
    if not tt:
        return 0.0

    title_hits = len(qt & tt)
    snippet_hits = len(qt & st)

    recall = (title_hits * 2.0 + snippet_hits * 1.0) / (len(qt) * 3.0)
    precision = title_hits / len(tt)
    noise = len(tt - qt)

    score = 0.70 * recall + 0.30 * precision - 0.10 * noise
    return max(0.0, min(score, 1.0))


def _wiki_get(params: dict, tries: int = 3):
    """GET the MediaWiki action API with a short-lived cache.

    Two hard-won lessons live here:

    * Wikipedia answers 429 once a burst of questions arrives. Retrying into
      a 429 just extends the ban, so the *first* 429 sets a per-host cooldown
      and we stop asking that host until it expires.
    * Identical questions repeat constantly in a chat (a suggested prompt is
      tapped twice), so successful responses are cached.
    """
    global _WIKI_HITS

    key = "&".join(f"{k}={v}" for k, v in sorted(params.items()))
    now = time.time()
    hit = _WIKI_CACHE.get(key)
    if hit and now - hit[0] < _WIKI_TTL:
        return hit[1]

    if _cooldown_active(_WIKI_ACTION_HOST) or not _wiki_budget_ok():
        # Known-throttled or out of budget: don't add to the pile of
        # rejected requests — that only makes the ban last longer.
        return None

    for attempt in range(tries):
        if _expired():
            # Out of budget for this question — better a knowledge-base
            # answer now than a correct one in fifteen seconds.
            return None
        try:
            r = requests.get(
                "https://en.wikipedia.org/w/api.php",
                params=params,
                headers=UA,
                timeout=min(HTTP_TIMEOUT, max(1.0, _remaining() or HTTP_TIMEOUT)),
            )
        except Exception:
            if attempt < tries - 1 and not _expired():
                time.sleep(0.4 * (attempt + 1))
            continue

        if r.status_code == 200:
            data = r.json()
            _WIKI_CACHE[key] = (time.time(), data)
            if len(_WIKI_CACHE) > 256:
                # Drop the oldest entries; dict preserves insert order.
                for stale in list(_WIKI_CACHE)[:64]:
                    _WIKI_CACHE.pop(stale, None)
            return data

        if r.status_code == 429:
            _set_cooldown(_WIKI_ACTION_HOST, r)
            return None

        if attempt < tries - 1:
            time.sleep(0.4 * (attempt + 1))
    return None


# Hosts are cooled down independently: api.wikimedia.org is a separate
# service with its own limits, so a 429 from en.wikipedia.org must not
# silence it — that fallback is exactly what we need during a throttle.
_WIKI_ACTION_HOST = "en.wikipedia.org"
_WIKI_REST_HOST = "en.wikipedia.org"
_WIKI_CORE_HOST = "api.wikimedia.org"

_WIKI_COOLDOWNS: dict[str, float] = {}


def _cooldown_active(host: str) -> bool:
    return time.time() < _WIKI_COOLDOWNS.get(host, 0.0)


def _set_cooldown(host: str, response) -> None:
    """Back off from `host`, honouring Retry-After when the server sends it."""
    try:
        wait = float(response.headers.get("Retry-After", ""))
    except (TypeError, ValueError):
        wait = _WIKI_COOLDOWN_SECONDS
    _WIKI_COOLDOWNS[host] = time.time() + max(5.0, min(wait, 60.0))


def _wiki_budget_ok() -> bool:
    """True if we may spend one more Wikipedia-family request this minute.

    A proactive cap keeps us under the limit instead of discovering it via a
    429: during a burst of questions the chat degrades to the knowledge base
    rather than getting every host rate-limited for the next minute.
    """
    global _WIKI_HITS
    now = time.time()
    _WIKI_HITS = [t for t in _WIKI_HITS if now - t < _WIKI_WINDOW]
    if len(_WIKI_HITS) >= _WIKI_BUDGET:
        return False
    _WIKI_HITS.append(now)
    return True


_WIKI_HITS: list[float] = []
_WIKI_WINDOW = 60.0
_WIKI_BUDGET = int(os.environ.get("WIKI_BUDGET", "24"))


def _wiki_rest_search(srsearch: str, limit: int = 8) -> list[dict]:
    """Fallback search, tried only while the action API is unusable.

    Uses api.wikimedia.org first — a genuinely separate service, so it keeps
    answering during an en.wikipedia.org cooldown — then the REST endpoint on
    the same host as a last resort. Returns action-API shaped hits
    ({title, snippet}) so callers do not care which one answered.

    Only reached when the action API produced no usable hits at all (a 429,
    a network error, or an empty result), so trying it costs little.
    """
    for host, url in (
        (_WIKI_CORE_HOST, "https://api.wikimedia.org/core/v1/wikipedia/en/search/page"),
        (_WIKI_REST_HOST, "https://en.wikipedia.org/w/rest.php/v1/search/page"),
    ):
        if _expired():
            return []
        if _cooldown_active(host) or not _wiki_budget_ok():
            continue
        try:
            r = requests.get(
                url,
                params={"q": srsearch, "limit": limit},
                headers=UA,
                timeout=min(HTTP_TIMEOUT, max(1.0, _remaining() or HTTP_TIMEOUT)),
            )
        except Exception:
            continue
        if r.status_code == 429:
            _set_cooldown(host, r)
            continue
        if r.status_code != 200:
            continue

        try:
            payload = r.json()
        except Exception:
            continue
        # The two endpoints wrap results differently.
        pages = payload.get("pages") or payload.get("items") or []
        hits = []
        for page in pages:
            title = page.get("title") or page.get("key") or ""
            if not title:
                continue
            hits.append({"title": title, "snippet": page.get("excerpt") or ""})
        if hits:
            return hits
    return []


_WIKI_CACHE: dict[str, tuple[float, dict]] = {}
_WIKI_TTL = float(os.environ.get("WIKI_CACHE_TTL", "600"))
_WIKI_COOLDOWN_SECONDS = float(os.environ.get("WIKI_COOLDOWN", "20"))


def _duckduckgo_instant(query: str) -> tuple[str | None, list[dict]]:
    """Instant-answer API. Returns (abstract, sources)."""
    if _expired():
        return None, []
    try:
        r = requests.get(
            "https://api.duckduckgo.com/",
            params={"q": query, "format": "json", "no_html": 1, "skip_disambig": 1},
            headers=UA,
            timeout=min(HTTP_TIMEOUT, max(1.0, _remaining() or HTTP_TIMEOUT)),
        )
        # DuckDuckGo answers 202 (Accepted) as well as 200 — both carry a
        # usable body, and treating 202 as failure silently disabled it.
        if not (200 <= r.status_code < 300):
            return None, []
        data = r.json()
    except Exception:
        return None, []

    parts: list[str] = []
    if data.get("AbstractText"):
        parts.append(data["AbstractText"])
    answer = data.get("Answer") or data.get("AnswerType")
    if isinstance(answer, dict) and answer.get("Text"):
        parts.append(answer["Text"])
    elif isinstance(answer, str) and not answer.startswith("http"):
        parts.append(answer)

    related = data.get("RelatedTopics") or []
    for item in related[:6]:
        if isinstance(item, dict) and item.get("Text"):
            parts.append(item["Text"])
        elif isinstance(item, dict):
            for sub in (item.get("Topics") or [])[:3]:
                if isinstance(sub, dict) and sub.get("Text"):
                    parts.append(sub["Text"])

    sources = []
    if data.get("AbstractURL"):
        sources.append({"title": data.get("AbstractSource") or "DuckDuckGo", "url": data["AbstractURL"]})
    for item in related[:4]:
        if isinstance(item, dict) and item.get("FirstURL"):
            sources.append({"title": _strip_html(item.get("Text", ""))[:60] or "Source", "url": item["FirstURL"]})

    text = " ".join(p for p in parts if p).strip()
    return (text or None), sources[:5]


def _wiki_summary(title: str) -> str | None:
    """Fetch the intro paragraph for a Wikipedia article."""
    if _expired():
        return None
    try:
        r = requests.get(
            "https://en.wikipedia.org/api/rest_v1/page/summary/" + requests.utils.quote(title),
            headers=UA,
            timeout=min(HTTP_TIMEOUT, max(1.0, _remaining() or HTTP_TIMEOUT)),
        )
        if r.status_code == 200:
            extract = _strip_html(r.json().get("extract", ""))
            return extract or None
    except Exception:
        pass
    return None

def _wikipedia(query: str) -> tuple[str | None, list[dict]]:
    """Search Wikipedia and pick the most relevant hit, not merely the first.

    Full-text search on a whole question returns noisy ordering (a question
    about France can surface an unrelated article), so every candidate is
    scored against the question's key terms and rejected if it does not
    match. A second pass retries with just the key terms.
    """
    qt = _key_terms(query)
    if not qt:
        return None, []

    # Try several phrasings: the bare question, the key terms, and the key
    # terms minus anything that is also in the title of a wrong-answer trap.
    # Wikipedia ranks short keyword queries far better than full questions.
    key_query = " ".join(qt)
    passes: list[str] = []
    for candidate in (key_query, query):
        if candidate and candidate not in passes:
            passes.append(candidate)

    seen: set[str] = set()
    # (score, title, snippet, rank)
    best: tuple[float, str, str, int] | None = None

    def absorb(hits: list[dict]) -> None:
        """Score every candidate hit and keep the best one."""
        nonlocal best
        for rank, hit in enumerate(hits):
            title = hit.get("title", "")
            if not title or title in seen:
                continue
            seen.add(title)
            snippet = _strip_html(hit.get("snippet", ""))
            if not _safe(title, snippet):
                continue

            score = _relevant(query, title, snippet)
            # Small nudge for the search engine's own ordering — a decent
            # tie-break when our scores are equal, but never strong enough
            # to override an obviously better-matching title.
            score += max(0.0, 0.06 * (1.0 - rank / 8.0))
            score = min(score, 1.0)

            if best is None or score > best[0] + 1e-9:
                best = (score, title, snippet, rank)

    for term_query in passes:
        if _expired():
            break
        data = _wiki_get(
            {
                "action": "query",
                "list": "search",
                "srsearch": term_query,
                "format": "json",
                "srlimit": 8,
                "utf8": 1,
            }
        )
        absorb((data.get("query", {}).get("search") or []) if data else [])

        if best and best[0] >= 0.55:
            break

        if data is None:
            # The action API *failed* (429, timeout, network) rather than
            # simply having no article for this query — so it is worth
            # trying the separate api.wikimedia.org service before giving
            # up. Without this a good question answers "I don't know"
            # purely because we asked too fast.
            absorb(_wiki_rest_search(term_query))
            if best and best[0] >= 0.55:
                break

    if best is None:
        return None, []

    score, title, snippet, _rank = best
    if score < 0.34:
        # Nothing matched the question well enough — never serve an
        # unrelated article just because it came back first.
        return None, []

    url = f"https://en.wikipedia.org/wiki/{title.replace(' ', '_')}"
    source = [{"title": f"Wikipedia: {title}", "url": url}]

    extract = _wiki_summary(title)
    if extract:
        # Final guards: the summary must still answer the question, and it
        # must still be suitable for a child.
        if not _safe(title, extract):
            return None, []
        if _text_relevant(query, extract) < 0.34:
            return None, []
        return extract, source

    return (snippet or None), source


def _text_relevant(query: str, text: str) -> float:
    """How much of the question's key terms appear in a block of answer text.

    Used for DuckDuckGo instant answers, where there is no article title to
    judge against — only the prose itself.
    """
    qt = set(_key_terms(query))
    if not qt:
        return 1.0
    st = set(re.findall(r"[a-z0-9]+", text.lower()))
    return len(qt & st) / len(qt)


def _looks_like_maths(query: str) -> bool:
    """True for arithmetic/percentage questions that a web search cannot answer.

    Without this, "what is 15% of 240" happily returns the Wikipedia article
    for the year 240 — confidently wrong, and useless to a child.
    """
    q = query.strip()
    if not q:
        return False
    low = q.lower()
    # Contains digits with an operator, a %, or a bare "x of y" sum.
    if re.search(r"\d\s*[%×x*/+\-]\s*\d", q) or re.search(r"%\s*of\b", low):
        return True
    if re.search(r"\d+\s*(%|percent|percentage)\b", q, re.I):
        return True
    if re.search(r"\b(add|subtract|multiply|divide|sum|percentage|percent)\b", q, re.I) and re.search(r"\d", q):
        return True
    return False


def _search_web(query: str) -> tuple[str | None, list[dict]]:
    """Try DuckDuckGo first, then Wikipedia.

    A result is only returned if it actually relates to the question — a
    confidently-wrong answer is worse than admitting we don't know.
    """
    if not SEARCH_ENABLED:
        return None, []
    if _looks_like_maths(query):
        # Sums are answered locally, not by an encyclopedia lookup.
        return None, []

    text, sources = _duckduckgo_instant(query)
    if text and len(text) > 60 and _text_relevant(query, text) >= 0.5:
        return text, sources

    # Wikipedia is the slower of the two — only spend the remaining budget
    # on it when DuckDuckGo had nothing useful to say.
    if _expired():
        return None, []

    wiki_text, wiki_sources = _wikipedia(query)
    if wiki_text:
        return wiki_text, (sources + wiki_sources)[:5]

    return None, []


# --------------------------------------------------------------------------- #
# Answer composition
# --------------------------------------------------------------------------- #

def _match_knowledge(message: str) -> dict | None:
    low = message.lower()
    best, best_score = None, 0
    for entry in KNOWLEDGE_BASE:
        score = sum(1 for t in entry["topics"] if t in low)
        if score > best_score:
            best, best_score = entry, score
    return best if best_score > 0 else None


def _trim(text: str, limit: int = 700) -> str:
    text = text.strip()
    if len(text) <= limit:
        return text
    cut = text[:limit]
    for sep in (". ", "! ", "? "):
        idx = cut.rfind(sep)
        if idx > limit * 0.5:
            return cut[: idx + 1].strip()
    return cut.rsplit(" ", 1)[0].strip() + "..."


def solve_maths(message: str) -> str | None:
    """Evaluate simple arithmetic the user typed, or return None.

    Covers the shapes kids actually ask about: 12 + 7, 8*6, 15% of 240,
    half of 30, 20 percent of 150. Results are rounded to 2 decimals.
    """
    msg = message.strip()
    if not msg:
        return None

    low = msg.lower()

    # "15% of 240" / "20 percent of 150"
    m = re.search(r"(-?\d+(?:\.\d+)?)\s*(?:%|percent|percentage)\s+of\s+(-?\d+(?:\.\d+)?)", low)
    if m:
        pct, val = float(m.group(1)), float(m.group(2))
        return _fmt(pct / 100.0 * val) + f"  ({pct:g}% of {val:g} is {pct / 100.0 * val:g})"

    # "half of 30" / "quarter of 20"
    m = re.search(r"\b(half|quarter|third|double|twice)\s+of\s+(-?\d+(?:\.\d+)?)", low)
    if m:
        word, val = m.group(1), float(m.group(2))
        factor = {"half": 0.5, "quarter": 0.25, "third": 1 / 3,
                  "double": 2, "twice": 2}[word]
        return _fmt(val * factor) + f"  ({word} of {val:g})"

    # Plain binary arithmetic: "12 + 7", "8 * 6", "144 / 12", "9 - 3"
    m = re.fullmatch(
        r"\s*(-?\d+(?:\.\d+)?)\s*([+\-*/×÷x])\s*(-?\d+(?:\.\d+)?)\s*[?.!]*\s*",
        msg,
    )
    if m:
        a, op, b = float(m.group(1)), m.group(2), float(m.group(3))
        if op in ("*", "×", "x"):
            return _fmt(a * b) + f"  ({_fmt(a)} × {_fmt(b)} = {_fmt(a * b)})"
        if op in ("/", "÷"):
            if b == 0:
                return "You can't divide by zero — that one has no answer!"
            return _fmt(a / b) + f"  ({_fmt(a)} ÷ {_fmt(b)} = {_fmt(a / b)})"
        if op == "+":
            return _fmt(a + b) + f"  ({_fmt(a)} + {_fmt(b)} = {_fmt(a + b)})"
        if op == "-":
            return _fmt(a - b) + f"  ({_fmt(a)} − {_fmt(b)} = {_fmt(a - b)})"

    # Percentages written as "what is 15% of 240" with extra words.
    m = re.search(r"(-?\d+(?:\.\d+)?)\s*%\s*(?:of\s+)?(-?\d+(?:\.\d+)?)", low)
    if m:
        pct, val = float(m.group(1)), float(m.group(2))
        return _fmt(pct / 100.0 * val) + f"  ({pct:g}% of {val:g})"

    return None


def _fmt(value: float) -> str:
    if abs(value - round(value)) < 1e-9:
        return str(int(round(value)))
    return f"{value:.4g}"


def build_answer(message: str, history: list | None = None) -> dict:
    """Return {reply, source, sources, live}."""
    msg = (message or "").strip()
    if not msg:
        return {"reply": WELCOME, "source": "codeyoung", "sources": [], "live": False}

    # Small talk / thanks handled directly for a natural feel.
    if re.fullmatch(r"(hi|hey|hello|yo|namaste|good (morning|afternoon|evening))[!. ]*", msg, re.I):
        return {"reply": WELCOME, "source": "codeyoung", "sources": [], "live": False}
    if re.fullmatch(r"(thanks|thank you|thx|ty)[!. ]*", msg, re.I):
        return {
            "reply": "You're welcome! Ask me anything else — about our courses, the free trial, or any coding, maths or science topic.",
            "source": "codeyoung",
            "sources": [],
            "live": False,
        }

    kb = _match_knowledge(msg)

    # Arithmetic is solved exactly rather than looked up — a search engine
    # has no idea what 15% of 240 is.
    maths = solve_maths(msg)
    if maths:
        return {
            "reply": (
                f"{maths}\n\nWant a trick for it? To find any percentage, "
                "find 10% first (move the decimal one place left), then "
                "scale up from there."
            ),
            "source": "calculator",
            "sources": [],
            "live": False,
        }

    live_text, live_sources = _search_web(msg)

    # Prefer live internet results when they add real substance, otherwise KB.
    if live_text and len(live_text) > 80:
        # Only lead with the knowledge base when it genuinely talks about what
        # was asked. The science entry lists "photosynthesis" as a topic but
        # its answer is about forces — prepending that to a real definition
        # would be a confidently-wrong non-sequitur, which is worse than none.
        kb_relevant = bool(kb) and _text_relevant(msg, kb["answer"]) >= 0.34
        if kb_relevant:
            reply = f"{_trim(kb['answer'], 420)}\n\nWhat the web says: {_trim(live_text, 380)}"
            source = "codeyoung+web"
        else:
            reply = f"Here's what I found live: {_trim(live_text, 700)}"
            source = "web"
        return {"reply": reply, "source": source, "sources": live_sources, "live": True}

    if kb:
        return {"reply": kb["answer"], "source": kb["source"], "sources": live_sources, "live": False}

    if live_text:
        return {"reply": _trim(live_text, 700), "source": "web", "sources": live_sources, "live": True}

    # Last resort — stay useful rather than refusing.
    return {
        "reply": (
            "I don't have a confident answer for that one just yet. Try rephrasing it, or ask "
            "me about Codeyoung's courses and free trial, 1:1 mentors and pricing, or a topic "
            "like Python, HTML, JavaScript, robotics, fractions or forces."
        ),
        "source": "fallback",
        "sources": [],
        "live": False,
    }


# --------------------------------------------------------------------------- #
# Text-to-speech
#
# Latency strategy: synthesising a reply used to block the response *and* the
# app then asked for the same text a second time, so one message paid for TTS
# twice (13.6s vs 2.6s without audio). Now /chat warms the cache in a
# background thread and returns the text immediately; the follow-up /tts joins
# the already-running job instead of starting a duplicate.
# --------------------------------------------------------------------------- #

_TTS_LOCK = threading.Lock()
_TTS_CACHE: dict[str, dict] = {}
_TTS_JOBS: dict[str, Future] = {}


def _tts_key(text: str, lang: str) -> str:
    # Key on exactly what will be spoken (see _synthesise_uncached's trim) so
    # two long messages that share their first 600 chars share one cache entry.
    spoken = text.strip()
    if len(spoken) > 600:
        spoken = _trim(spoken, 600)
    return hashlib.sha1(f"{lang}|{TTS_ENGINE}|{TTS_VOICE}|{spoken}".encode("utf-8")).hexdigest()


def tts_cached(text: str, lang: str = "en") -> dict | None:
    """Return already-synthesised speech for `text`, if we have it."""
    with _TTS_LOCK:
        return _TTS_CACHE.get(_tts_key(text, lang))


def _tts_put(key: str, value: dict) -> None:
    with _TTS_LOCK:
        _TTS_CACHE[key] = value
        while len(_TTS_CACHE) > TTS_CACHE_MAX:
            _TTS_CACHE.pop(next(iter(_TTS_CACHE)))


def _synthesise_uncached(text: str, lang: str) -> dict | None:
    """Return {'engine', 'mime', 'audio'} (base64) or None."""
    if TTS_ENGINE == "none":
        return None

    # Keep it short — speech is for spoken replies, not walls of text.
    spoken = text.strip()
    if len(spoken) > 600:
        spoken = _trim(spoken, 600)

    if TTS_ENGINE == "edge":
        try:
            import asyncio

            import edge_tts

            async def _gen() -> bytes:
                buf = io.BytesIO()
                communicate = edge_tts.Communicate(spoken, voice=TTS_VOICE)
                async for chunk in communicate.stream():
                    if chunk["type"] == "audio":
                        buf.write(chunk["data"])
                return buf.getvalue()

            audio = asyncio.run(_gen())
            if audio:
                return {"engine": "edge", "mime": "audio/mpeg", "audio": base64.b64encode(audio).decode()}
        except Exception:
            pass  # fall through to gTTS

    try:
        from gtts import gTTS

        buf = io.BytesIO()
        gTTS(text=spoken, lang=lang, slow=False).write_to_fp(buf)
        buf.seek(0)
        return {"engine": "gtts", "mime": "audio/mpeg", "audio": base64.b64encode(buf.read()).decode()}
    except Exception:
        return None


def synthesise(text: str, lang: str = "en") -> dict | None:
    """Cached synchronous synthesis — safe to call straight from /tts."""
    key = _tts_key(text, lang)
    with _TTS_LOCK:
        hit = _TTS_CACHE.get(key)
    if hit is not None:
        return hit

    out = _synthesise_uncached(text, lang)
    if out is not None:
        _tts_put(key, out)
    return out


def _tts_worker(fut: Future, key: str, text: str, lang: str) -> None:
    try:
        out = _synthesise_uncached(text, lang)
    except Exception:
        out = None
    if out is not None:
        _tts_put(key, out)
    # Always release waiters — even on failure — so a /tts that joined this
    # job falls back to its own retry instead of hanging until timeout.
    if not fut.done():
        fut.set_result(out)
    with _TTS_LOCK:
        _TTS_JOBS.pop(key, None)


def tts_warm(text: str, lang: str = "en") -> Future | None:
    """Start (or join) synthesis for `text` without blocking the caller.

    Returns the in-flight Future so a follow-up /tts can wait on the same job,
    or None when speech is disabled.
    """
    if TTS_ENGINE == "none":
        return None
    key = _tts_key(text, lang)
    with _TTS_LOCK:
        if key in _TTS_CACHE:
            return None
        fut = _TTS_JOBS.get(key)
        if fut is None:
            fut = Future()
            _TTS_JOBS[key] = fut
        else:
            return fut
    threading.Thread(
        target=_tts_worker, args=(fut, key, text, lang), daemon=True
    ).start()
    return fut


def tts_wait(fut: Future | None, timeout: float = 20.0) -> dict | None:
    """Block on a warm-up job (used only by /tts, never by /chat)."""
    if fut is None:
        return None
    try:
        return fut.result(timeout=timeout)
    except Exception:
        return None


def tts_get(text: str, lang: str = "en", timeout: float = 20.0) -> dict | None:
    """Speech for `text`: cache hit, else join the running job, else do it now.

    Joining matters — without it a /tts that lands while /chat's warm-up is
    still running would synthesise the same text a second time, which is
    exactly the double-cost this whole section exists to remove.
    """
    key = _tts_key(text, lang)
    with _TTS_LOCK:
        hit = _TTS_CACHE.get(key)
        if hit is not None:
            return hit
        fut = _TTS_JOBS.get(key)
    if fut is not None:
        out = tts_wait(fut, timeout)
        if out is not None:
            return out
    return synthesise(text, lang)


# --------------------------------------------------------------------------- #
# Routes
# --------------------------------------------------------------------------- #

def _rate_limited(key: str) -> bool:
    now = time.time()
    hits = _HITS.setdefault(key, deque())
    while hits and now - hits[0] > _RATE_WINDOW:
        hits.popleft()
    if len(hits) >= _RATE_LIMIT:
        return True
    hits.append(now)
    return False


@app.get("/health")
def health():
    return jsonify(
        {
            "status": "ok",
            "service": "codeyoung-mentor",
            "tts_engine": TTS_ENGINE,
            "tts_voice": TTS_VOICE if TTS_ENGINE == "edge" else None,
            "search_enabled": SEARCH_ENABLED,
            "knowledge_entries": len(KNOWLEDGE_BASE),
            "timestamp": time.time(),
        }
    )


@app.post("/chat")
def chat():
    payload = request.get_json(silent=True) or {}
    message = str(payload.get("message", "")).strip()
    history = payload.get("history") or []
    speak = bool(payload.get("speak"))
    lang = str(payload.get("lang", "en"))

    if not message:
        return jsonify({"error": "message is required", "reply": WELCOME}), 400

    session = str(payload.get("session_id") or request.remote_addr or "anon")
    if _rate_limited(session):
        return jsonify({"error": "rate_limited", "reply": "You're asking questions very quickly — please pause a moment and try again."}), 429

    started = time.time()
    _REQ.deadline = started + SEARCH_DEADLINE
    try:
        answer = build_answer(message, history)
    except Exception:
        # A bug in search/synthesis must never break the conversation —
        # degrade to the knowledge base, then to a polite fallback.
        app.logger.exception("build_answer failed for %r", message[:80])
        kb_only = _match_knowledge(message)
        answer = {
            "reply": kb_only["answer"] if kb_only else (
                "I hit a snag answering that one. Try rephrasing it, or ask me "
                "about Codeyoung's courses, the free trial, 1:1 mentors and pricing."
            ),
            "source": kb_only["source"] if kb_only else "fallback",
            "sources": [],
            "live": False,
        }
    elapsed = round((time.time() - started) * 1000)

    result = {
        "reply": answer["reply"],
        "source": answer["source"],
        "sources": answer.get("sources", []),
        "live": answer.get("live", False),
        "latency_ms": elapsed,
    }

    if speak:
        # Never block the reply on speech. Warm the cache in the background so
        # the app's follow-up /tts joins this job (or hits the cache) instead
        # of synthesising the same text a second time.
        try:
            cached = tts_cached(answer["reply"], lang)
            if cached:
                result["audio"] = cached["audio"]
                result["audio_mime"] = cached["mime"]
                result["tts_engine"] = cached["engine"]
            else:
                tts_warm(answer["reply"], lang)
                result["tts_pending"] = True
        except Exception:
            app.logger.exception("tts warm-up failed")

    return jsonify(result)


@app.post("/tts")
def tts():
    payload = request.get_json(silent=True) or {}
    text = str(payload.get("text", "")).strip()
    lang = str(payload.get("lang", "en"))

    if not text:
        return jsonify({"error": "text is required"}), 400
    if len(text) > 4000:
        text = text[:4000]

    # Join a warm-up started by /chat when there is one, otherwise synthesise
    # here. Either way the result lands in the cache for next time.
    out = tts_get(text, lang)
    if not out:
        return jsonify({"error": "text-to-speech engine unavailable"}), 503

    return jsonify(
        {
            "audio": out["audio"],
            "mime": out["mime"],
            "engine": out["engine"],
            "length": len(text),
        }
    )


@app.post("/search")
def search():
    """Exposed for debugging / the app's 'search the web' affordance."""
    payload = request.get_json(silent=True) or {}
    query = str(payload.get("query", "")).strip()
    if not query:
        return jsonify({"error": "query is required"}), 400
    _REQ.deadline = time.time() + SEARCH_DEADLINE
    text, sources = _search_web(query)
    return jsonify({"query": query, "result": text, "sources": sources})


@app.errorhandler(404)
def not_found(_e):
    return jsonify({"error": "not found", "endpoints": ["/health", "/chat", "/tts", "/search"]}), 404


@app.errorhandler(500)
def server_error(e):
    return jsonify({"error": "internal error", "detail": str(e)}), 500


if __name__ == "__main__":
    print(f"CodeYoung Mentor listening on http://{HOST}:{PORT}")
    print(f"  tts      : {TTS_ENGINE} ({TTS_VOICE})")
    print(f"  search   : {'enabled' if SEARCH_ENABLED else 'disabled'} ({SEARCH_DEADLINE:.0f}s budget)")
    print(f"  kb       : {len(KNOWLEDGE_BASE)} entries")
    app.run(host=HOST, port=PORT, threaded=True, debug=os.environ.get("FLASK_DEBUG") == "1")
