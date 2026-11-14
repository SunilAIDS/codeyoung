'use strict';

require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const crypto = require('crypto');

const {
  db,
  seedIfEmpty,
  hashPassword,
  verifyPassword,
  ensureAchievements,
  PHOTOS,
} = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;
const CHAT_URL = process.env.CHAT_URL || 'http://127.0.0.1:5001';

/* ------------------------------------------------------------------ */
/* Middleware                                                          */
/* ------------------------------------------------------------------ */

app.use(cors({ origin: process.env.CORS_ORIGIN || '*', credentials: true }));
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));

app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    max: Number(process.env.RATE_LIMIT_MAX || 600),
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many requests from this IP, please try again later.' },
  })
);

/* ------------------------------------------------------------------ */
/* Auth helpers                                                        */
/* ------------------------------------------------------------------ */

const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 30; // 30 days

function createSession(userId) {
  const token = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + SESSION_TTL_MS).toISOString();
  db.prepare('INSERT INTO sessions (token, user_id, expires_at) VALUES (?,?,?)').run(
    token,
    userId,
    expiresAt
  );
  return { token, expiresAt };
}

function getUserByToken(token) {
  if (!token) return null;
  const row = db
    .prepare(
      `SELECT u.* FROM sessions s
       JOIN users u ON u.id = s.user_id
       WHERE s.token = ? AND s.expires_at > datetime('now')`
    )
    .get(token);
  return row || null;
}

function extractToken(req) {
  const header = req.headers.authorization || '';
  if (header.startsWith('Bearer ')) return header.slice(7).trim();
  return req.headers['x-auth-token'] || req.headers['x-user-id'] || null;
}

/** Requires a valid session; attaches req.user. */
function requireAuth(req, res, next) {
  const user = getUserByToken(extractToken(req));
  if (!user) return res.status(401).json({ error: 'Authentication required' });
  req.user = user;
  next();
}

/** Resolves a user when a token is present, but never rejects. */
function optionalAuth(req, _res, next) {
  req.user = getUserByToken(extractToken(req)) || null;
  next();
}

function publicUser(u) {
  if (!u) return null;
  const { password_hash, salt, ...rest } = u;
  return { ...rest, is_premium: Boolean(rest.is_premium) };
}

/* ------------------------------------------------------------------ */
/* Bootstrap                                                           */
/* ------------------------------------------------------------------ */

const seeded = seedIfEmpty();

// Demo accounts (password for both: "password") so the app is usable instantly.
(function ensureDemoUsers() {
  const demos = [
    { email: 'learner@codeyoung.com', name: 'CodeYoung Learner', role: 'student' },
    { email: 'student@codeyoung.com', name: 'CodeYoung Student', role: 'student' },
  ];
  for (const d of demos) {
    const exists = db.prepare('SELECT id FROM users WHERE email = ?').get(d.email);
    if (exists) continue;
    const { salt, hash } = hashPassword('password');
    const r = db
      .prepare(
        'INSERT INTO users (email, password_hash, salt, name, role) VALUES (?,?,?,?,?)'
      )
      .run(d.email, hash, salt, d.name, d.role);
    ensureAchievements(Number(r.lastInsertRowid));
  }
})();

/* ------------------------------------------------------------------ */
/* Health                                                              */
/* ------------------------------------------------------------------ */

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    service: 'codeyoung-backend',
    database: 'sqlite',
    seeded,
    timestamp: new Date().toISOString(),
  });
});

/* ------------------------------------------------------------------ */
/* Auth                                                                */
/* ------------------------------------------------------------------ */

app.post('/api/auth/register', (req, res) => {
  const { name, email, password } = req.body || {};
  if (!name || !email || !password) {
    return res.status(400).json({ error: 'Name, email and password are required' });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: 'Enter a valid email address' });
  }
  if (String(password).length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }

  const normalized = String(email).trim().toLowerCase();
  if (db.prepare('SELECT id FROM users WHERE email = ?').get(normalized)) {
    return res.status(409).json({ error: 'An account with that email already exists' });
  }

  const { salt, hash } = hashPassword(password);
  const r = db
    .prepare(
      'INSERT INTO users (email, password_hash, salt, name) VALUES (?,?,?,?)'
    )
    .run(normalized, hash, salt, String(name).trim());

  const userId = Number(r.lastInsertRowid);
  ensureAchievements(userId);
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  const session = createSession(userId);

  db.prepare(
    `INSERT INTO chat_messages (user_id, session_id, role, content, source)
     VALUES (?,?,?,?,?)`
  ).run(
    userId,
    `u${userId}`,
    'assistant',
    `Hi ${user.name.split(' ')[0]}! I'm your CodeYoung mentor. Ask me anything about coding, maths, science or your courses — I search the live internet and read answers aloud.`,
    'welcome'
  );

  res.status(201).json({
    message: 'Account created',
    token: session.token,
    userId: String(userId),
    user: publicUser(user),
  });
});

app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  const user = db
    .prepare('SELECT * FROM users WHERE email = ?')
    .get(String(email).trim().toLowerCase());

  if (!user || !verifyPassword(password, user.salt, user.password_hash)) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }

  const session = createSession(user.id);
  res.json({
    message: 'Login successful',
    token: session.token,
    userId: String(user.id),
    user: publicUser(user),
  });
});

app.post('/api/auth/logout', requireAuth, (req, res) => {
  db.prepare('DELETE FROM sessions WHERE token = ?').run(extractToken(req));
  res.json({ message: 'Logout successful' });
});

app.get('/api/auth/me', requireAuth, (req, res) => {
  res.json(publicUser(req.user));
});

app.post('/api/auth/change-password', requireAuth, (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: 'Current and new password are required' });
  }
  if (!verifyPassword(currentPassword, req.user.salt, req.user.password_hash)) {
    return res.status(401).json({ error: 'Current password is incorrect' });
  }
  if (String(newPassword).length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }
  const { salt, hash } = hashPassword(newPassword);
  db.prepare(
    `UPDATE users SET password_hash = ?, salt = ?, updated_at = datetime('now') WHERE id = ?`
  ).run(hash, salt, req.user.id);
  res.json({ message: 'Password changed successfully' });
});

/* ------------------------------------------------------------------ */
/* Users                                                               */
/* ------------------------------------------------------------------ */

app.get('/api/users/profile', requireAuth, (req, res) => {
  res.json(publicUser(req.user));
});

app.put('/api/users/profile', requireAuth, (req, res) => {
  const { name, email, bio, avatar_url } = req.body || {};
  if (name !== undefined && !String(name).trim()) {
    return res.status(400).json({ error: 'Name cannot be empty' });
  }
  if (email !== undefined && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: 'Enter a valid email address' });
  }
  if (email) {
    const normalized = String(email).trim().toLowerCase();
    const clash = db
      .prepare('SELECT id FROM users WHERE email = ? AND id != ?')
      .get(normalized, req.user.id);
    if (clash) return res.status(409).json({ error: 'That email is already in use' });
  }

  db.prepare(
    `UPDATE users SET
       name      = COALESCE(?, name),
       email     = COALESCE(?, email),
       bio       = COALESCE(?, bio),
       avatar_url= COALESCE(?, avatar_url),
       updated_at= datetime('now')
     WHERE id = ?`
  ).run(
    name !== undefined ? String(name).trim() : null,
    email !== undefined ? String(email).trim().toLowerCase() : null,
    bio !== undefined ? bio : null,
    avatar_url !== undefined ? avatar_url : null,
    req.user.id
  );

  res.json({ message: 'Profile updated', user: publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id)) });
});

app.put('/api/users/account', requireAuth, (req, res) => {
  const { email, newName } = req.body || {};
  db.prepare(
    `UPDATE users SET
       email = COALESCE(?, email),
       name  = COALESCE(?, name),
       updated_at = datetime('now')
     WHERE id = ?`
  ).run(
    email ? String(email).trim().toLowerCase() : null,
    newName ? String(newName).trim() : null,
    req.user.id
  );
  res.json({
    message: 'Account updated',
    user: publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id)),
  });
});

/* ------------------------------------------------------------------ */
/* Courses                                                             */
/* ------------------------------------------------------------------ */

function courseWithProgress(row, userId) {
  const total = db
    .prepare('SELECT COUNT(*) AS n FROM lessons WHERE course_id = ?')
    .get(row.id).n;
  let done = 0;
  if (userId) {
    done = db
      .prepare(
        `SELECT COUNT(*) AS n FROM progress p
         JOIN lessons l ON l.id = p.lesson_id
         WHERE l.course_id = ? AND p.user_id = ? AND p.completed = 1`
      )
      .get(row.id, userId).n;
  }
  return {
    ...row,
    is_featured: Boolean(row.is_featured),
    lessons_count: total,
    completed_count: done,
    progress_percent: total ? Math.round((done / total) * 100) : 0,
  };
}

app.get('/api/courses', optionalAuth, (req, res) => {
  const { category, level, q } = req.query;
  let sql = 'SELECT * FROM courses WHERE 1=1';
  const params = [];
  if (category && category !== 'All') {
    sql += ' AND category = ?';
    params.push(category);
  }
  if (level && level !== 'All') {
    sql += ' AND level = ?';
    params.push(level);
  }
  if (q) {
    sql += ' AND (title LIKE ? OR subtitle LIKE ? OR description LIKE ?)';
    const like = `%${q}%`;
    params.push(like, like, like);
  }
  sql += ' ORDER BY sort_order ASC, id ASC';

  const uid = req.user ? req.user.id : null;
  res.json(db.prepare(sql).all(...params).map((r) => courseWithProgress(r, uid)));
});

app.get('/api/courses/:id', optionalAuth, (req, res) => {
  const id = /^\d+$/.test(req.params.id) ? Number(req.params.id) : null;
  const row = id
    ? db.prepare('SELECT * FROM courses WHERE id = ?').get(id)
    : db.prepare('SELECT * FROM courses WHERE slug = ?').get(req.params.id);

  if (!row) return res.status(404).json({ error: 'Course not found' });

  const uid = req.user ? req.user.id : null;
  const lessons = db
    .prepare('SELECT * FROM lessons WHERE course_id = ? ORDER BY sort_order ASC, id ASC')
    .all(row.id)
    .map((l) => {
      let percent = 0;
      let completed = false;
      if (uid) {
        const p = db
          .prepare('SELECT percent, completed FROM progress WHERE user_id = ? AND lesson_id = ?')
          .get(uid, l.id);
        if (p) {
          percent = p.percent;
          completed = Boolean(p.completed);
        }
      }
      return { ...l, percent, completed, objectives: safeJson(l.objectives, []) };
    });

  res.json({ ...courseWithProgress(row, uid), lessons });
});

app.get('/api/courses/:id/lessons', optionalAuth, (req, res) => {
  const id = Number(req.params.id);
  const course = db.prepare('SELECT * FROM courses WHERE id = ?').get(id);
  if (!course) return res.status(404).json({ error: 'Course not found' });
  const uid = req.user ? req.user.id : null;
  const lessons = db
    .prepare('SELECT * FROM lessons WHERE course_id = ? ORDER BY sort_order ASC, id ASC')
    .all(id)
    .map((l) => {
      const p = uid
        ? db.prepare('SELECT percent, completed FROM progress WHERE user_id = ? AND lesson_id = ?').get(uid, l.id)
        : null;
      return {
        ...l,
        objectives: safeJson(l.objectives, []),
        percent: p ? p.percent : 0,
        completed: p ? Boolean(p.completed) : false,
      };
    });
  res.json({ course, lessons });
});

/* ------------------------------------------------------------------ */
/* Lessons                                                             */
/* ------------------------------------------------------------------ */

app.get('/api/lessons', optionalAuth, (req, res) => {
  const { category, level, course_id, q } = req.query;
  let sql = `
    SELECT l.*, c.title AS course_title, c.slug AS course_slug, c.color AS course_color
    FROM lessons l JOIN courses c ON c.id = l.course_id WHERE 1=1`;
  const params = [];
  if (category && category !== 'All') {
    sql += ' AND l.category = ?';
    params.push(category);
  }
  if (level && level !== 'All') {
    sql += ' AND l.level = ?';
    params.push(level);
  }
  if (course_id) {
    sql += ' AND l.course_id = ?';
    params.push(Number(course_id));
  }
  if (q) {
    sql += ' AND (l.title LIKE ? OR l.description LIKE ?)';
    params.push(`%${q}%`, `%${q}%`);
  }
  sql += ' ORDER BY c.sort_order ASC, l.sort_order ASC, l.id ASC';

  const uid = req.user ? req.user.id : null;
  const rows = db.prepare(sql).all(...params).map((l) => {
    const p = uid
      ? db.prepare('SELECT percent, completed FROM progress WHERE user_id = ? AND lesson_id = ?').get(uid, l.id)
      : null;
    return {
      ...l,
      objectives: safeJson(l.objectives, []),
      percent: p ? p.percent : 0,
      completed: p ? Boolean(p.completed) : false,
      thumbnail_url: l.thumbnail_url || PHOTOS.code,
    };
  });
  res.json(rows);
});

app.get('/api/lessons/:id', optionalAuth, (req, res) => {
  const l = db
    .prepare(
      `SELECT l.*, c.title AS course_title, c.slug AS course_slug, c.color AS course_color
       FROM lessons l JOIN courses c ON c.id = l.course_id WHERE l.id = ?`
    )
    .get(Number(req.params.id));
  if (!l) return res.status(404).json({ error: 'Lesson not found' });

  const uid = req.user ? req.user.id : null;
  const p = uid
    ? db.prepare('SELECT percent, completed FROM progress WHERE user_id = ? AND lesson_id = ?').get(uid, l.id)
    : null;

  res.json({
    ...l,
    objectives: safeJson(l.objectives, []),
    percent: p ? p.percent : 0,
    completed: p ? Boolean(p.completed) : false,
    thumbnail_url: l.thumbnail_url || PHOTOS.code,
  });
});

/* ------------------------------------------------------------------ */
/* Videos                                                              */
/* ------------------------------------------------------------------ */

function withThumb(v) {
  if (v.thumbnail_url) return v;
  return { ...v, thumbnail_url: v.video_id ? `https://img.youtube.com/vi/${v.video_id}/hqdefault.jpg` : PHOTOS.code };
}

app.get('/api/videos', (req, res) => {
  const { category, level, featured } = req.query;
  let sql = 'SELECT * FROM videos WHERE 1=1';
  const params = [];
  if (category && category !== 'All') {
    sql += ' AND category = ?';
    params.push(category);
  }
  if (level && level !== 'All') {
    sql += ' AND level = ?';
    params.push(level);
  }
  if (featured === '1') sql += ' AND is_featured = 1';
  sql += ' ORDER BY sort_order ASC, id ASC';
  res.json(db.prepare(sql).all(...params).map(withThumb));
});

app.get('/api/videos/:id', (req, res) => {
  const v = db.prepare('SELECT * FROM videos WHERE id = ?').get(Number(req.params.id));
  if (!v) return res.status(404).json({ error: 'Video not found' });
  db.prepare('UPDATE videos SET views = views + 1 WHERE id = ?').run(v.id);
  res.json({ ...withThumb(v), views: v.views + 1 });
});

app.get('/api/videos/categories', (_req, res) => {
  res.json(db.prepare('SELECT DISTINCT category FROM videos ORDER BY category').all().map((r) => r.category));
});

/* ------------------------------------------------------------------ */
/* Gallery                                                             */
/* ------------------------------------------------------------------ */

app.get('/api/gallery', (req, res) => {
  const { category } = req.query;
  let sql = 'SELECT * FROM gallery_images WHERE 1=1';
  const params = [];
  if (category && category !== 'All') {
    sql += ' AND category = ?';
    params.push(category);
  }
  sql += ' ORDER BY sort_order ASC, id ASC';
  res.json(db.prepare(sql).all(...params));
});

app.get('/api/gallery/categories', (_req, res) => {
  res.json(
    db.prepare('SELECT DISTINCT category FROM gallery_images ORDER BY category').all().map((r) => r.category)
  );
});

/* ------------------------------------------------------------------ */
/* Banners                                                             */
/* ------------------------------------------------------------------ */

app.get('/api/banners', (_req, res) => {
  res.json(db.prepare('SELECT * FROM banners ORDER BY sort_order ASC').all());
});

/* ------------------------------------------------------------------ */
/* Progress                                                            */
/* ------------------------------------------------------------------ */

app.get('/api/progress', requireAuth, (req, res) => {
  res.json(
    db
      .prepare(
        `SELECT p.*, l.title AS lesson_title, l.course_id, c.title AS course_title
         FROM progress p
         JOIN lessons l ON l.id = p.lesson_id
         JOIN courses c ON c.id = l.course_id
         WHERE p.user_id = ? ORDER BY p.updated_at DESC`
      )
      .all(req.user.id)
      .map((p) => ({ ...p, completed: Boolean(p.completed) }))
  );
});

app.post('/api/progress', requireAuth, (req, res) => {
  const { lesson_id, lessonId, completed, percent, progress: legacyPercent } = req.body || {};
  const lid = Number(lesson_id ?? lessonId);
  if (!lid) return res.status(400).json({ error: 'lesson_id is required' });

  const lesson = db.prepare('SELECT id FROM lessons WHERE id = ?').get(lid);
  if (!lesson) return res.status(404).json({ error: 'Lesson not found' });

  const pct =
    typeof percent === 'number'
      ? Math.max(0, Math.min(100, Math.round(percent)))
      : typeof legacyPercent === 'number'
        ? Math.max(0, Math.min(100, Math.round(legacyPercent)))
        : completed
          ? 100
          : 0;
  const done = completed === true || pct >= 100 ? 1 : 0;

  db.prepare(
    `INSERT INTO progress (user_id, lesson_id, completed, percent, updated_at)
     VALUES (?,?,?,?,datetime('now'))
     ON CONFLICT(user_id, lesson_id) DO UPDATE SET
       completed = excluded.completed,
       percent   = excluded.percent,
       updated_at = datetime('now')`
  ).run(req.user.id, lid, done, pct);

  if (done) {
    const doneCount = db
      .prepare(
        `SELECT COUNT(*) AS n FROM progress WHERE user_id = ? AND completed = 1`
      )
      .get(req.user.id).n;
    if (doneCount >= 10) {
      db.prepare(
        `UPDATE achievements SET earned = 1, earned_at = datetime('now')
         WHERE user_id = ? AND title = '10 Lessons Completed' AND earned = 0`
      ).run(req.user.id);
    }
    db.prepare(
      `UPDATE achievements SET earned = 1, earned_at = datetime('now')
       WHERE user_id = ? AND title = 'First Lesson' AND earned = 0`
    ).run(req.user.id);
  }

  const row = db
    .prepare('SELECT * FROM progress WHERE user_id = ? AND lesson_id = ?')
    .get(req.user.id, lid);

  res.json({ message: 'Progress updated', progress: { ...row, completed: Boolean(row.completed) } });
});

/* ------------------------------------------------------------------ */
/* Stats / achievements                                                */
/* ------------------------------------------------------------------ */

function statsFor(userId) {
  const rows = db.prepare('SELECT percent, completed FROM progress WHERE user_id = ?').all(userId);
  const lessonsCompleted = rows.filter((r) => r.completed).length;
  const totalPercent = rows.reduce((s, r) => s + (r.percent || 0), 0);
  const hoursLearned = Math.round(totalPercent / 10);

  const courses = db.prepare('SELECT COUNT(*) AS n FROM courses').get().n;
  const projectsBuilt = Math.min(
    courses,
    Math.floor(lessonsCompleted / 2) + (lessonsCompleted > 0 ? 1 : 0)
  );

  const distinctDays = db
    .prepare(
      `SELECT COUNT(DISTINCT substr(updated_at,1,10)) AS n FROM progress WHERE user_id = ?`
    )
    .get(userId).n;

  const level = Math.floor(totalPercent / 100) + 1;
  const achievementsList = db
    .prepare('SELECT title, icon, earned, earned_at FROM achievements WHERE user_id = ? ORDER BY id')
    .all(userId)
    .map((a) => ({ ...a, earned: Boolean(a.earned) }));

  return {
    lessonsCompleted,
    hoursLearned,
    projectsBuilt,
    streak: distinctDays,
    level,
    achievements: achievementsList.filter((a) => a.earned).length,
    totalXp: totalPercent * 10,
    achievementsList,
  };
}

app.get('/api/user/stats', requireAuth, (req, res) => res.json(statsFor(req.user.id)));
app.get('/api/user/lessons-completed', requireAuth, (req, res) =>
  res.json({ count: statsFor(req.user.id).lessonsCompleted })
);
app.get('/api/user/hours-learned', requireAuth, (req, res) =>
  res.json({ hours: statsFor(req.user.id).hoursLearned })
);
app.get('/api/user/projects-built', requireAuth, (req, res) =>
  res.json({ projects: statsFor(req.user.id).projectsBuilt })
);

/* ------------------------------------------------------------------ */
/* Chat (proxied to the Python mentor service)                         */
/* ------------------------------------------------------------------ */

async function callChat(path, body, timeoutMs = 30000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const r = await fetch(`${CHAT_URL}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const text = await r.text();
    let json;
    try {
      json = JSON.parse(text);
    } catch {
      json = { reply: text };
    }
    return { ok: r.ok, status: r.status, data: json };
  } finally {
    clearTimeout(timer);
  }
}

app.post('/api/chat', optionalAuth, async (req, res) => {
  const { message, session_id, history, speak } = req.body || {};
  if (!message || !String(message).trim()) {
    return res.status(400).json({ error: 'message is required' });
  }
  const sessionId = session_id || (req.user ? `u${req.user.id}` : `g${crypto.randomBytes(6).toString('hex')}`);
  const clean = String(message).slice(0, 2000);

  let result;
  try {
    result = await callChat('/chat', {
      message: clean,
      history: Array.isArray(history) ? history.slice(-10) : [],
      speak: Boolean(speak),
    });
  } catch (err) {
    result = {
      ok: false,
      data: {
        reply:
          "I couldn't reach my knowledge service just now. Please check that the Python mentor is running on port 5001, then try again.",
        source: 'offline',
        error: String(err.message || err),
      },
    };
  }

  const reply = result.data.reply || result.data.error || 'Sorry, I could not answer that.';

  try {
    db.prepare(
      'INSERT INTO chat_messages (user_id, session_id, role, content, source) VALUES (?,?,?,?,?)'
    ).run(req.user ? req.user.id : null, sessionId, 'user', clean, 'app');
    db.prepare(
      'INSERT INTO chat_messages (user_id, session_id, role, content, source) VALUES (?,?,?,?,?)'
    ).run(req.user ? req.user.id : null, sessionId, 'assistant', reply, result.data.source || 'mentor');
  } catch (e) {
    console.warn('chat persist failed:', e.message);
  }

  res.status(result.ok ? 200 : 200).json({
    reply,
    session_id: sessionId,
    source: result.data.source || 'mentor',
    sources: result.data.sources || [],
    audio: result.data.audio || null,
    audio_mime: result.data.audio_mime || 'audio/mpeg',
    tts_engine: result.data.tts_engine || null,
    live: Boolean(result.data.live),
  });
});

app.get('/api/chat/history', optionalAuth, (req, res) => {
  const sessionId = req.query.session_id || (req.user ? `u${req.user.id}` : null);
  if (!sessionId) return res.json([]);
  res.json(
    db
      .prepare(
        'SELECT role, content, source, created_at FROM chat_messages WHERE session_id = ? ORDER BY id ASC LIMIT 200'
      )
      .all(sessionId)
  );
});

app.delete('/api/chat/history', requireAuth, (req, res) => {
  db.prepare('DELETE FROM chat_messages WHERE session_id = ?').run(`u${req.user.id}`);
  res.json({ message: 'Conversation cleared' });
});

// Voice synthesis passthrough (text -> mp3 base64) served by Python.
app.post('/api/chat/tts', async (req, res) => {
  const { text, lang } = req.body || {};
  if (!text) return res.status(400).json({ error: 'text is required' });
  try {
    const r = await callChat('/tts', { text: String(text).slice(0, 4000), lang: lang || 'en' }, 30000);
    if (!r.ok) throw new Error(r.data.error || 'tts failed');
    res.json(r.data);
  } catch (err) {
    res.status(502).json({ error: `Voice service unavailable: ${err.message}` });
  }
});

/* ------------------------------------------------------------------ */
/* Home (aggregated payload for the landing screen)                    */
/* ------------------------------------------------------------------ */

app.get('/api/home', optionalAuth, (req, res) => {
  const uid = req.user ? req.user.id : null;
  const featuredCourses = db
    .prepare('SELECT * FROM courses WHERE is_featured = 1 ORDER BY sort_order LIMIT 6')
    .all()
    .map((c) => courseWithProgress(c, uid));
  const featuredVideos = db
    .prepare('SELECT * FROM videos WHERE is_featured = 1 ORDER BY sort_order LIMIT 4')
    .all()
    .map(withThumb);
  const latestVideos = db
    .prepare('SELECT * FROM videos ORDER BY sort_order ASC LIMIT 8')
    .all()
    .map(withThumb);
  const categories = db
    .prepare('SELECT DISTINCT category FROM courses ORDER BY category')
    .all()
    .map((r) => r.category);
  const banners = db.prepare('SELECT * FROM banners ORDER BY sort_order').all();

  res.json({
    user: uid ? publicUser(req.user) : null,
    stats: { students: 20000, parents: 50000, rating: 4.5, mentors: 500 },
    featuredCourses,
    featuredVideos,
    latestVideos,
    categories,
    banners,
    galleryPreview: db
      .prepare('SELECT * FROM gallery_images ORDER BY sort_order LIMIT 6')
      .all(),
  });
});

/* ------------------------------------------------------------------ */
/* Founders / about                                                    */
/* ------------------------------------------------------------------ */

app.get('/api/about', (_req, res) => {
  res.json({
    company: {
      name: 'Codeyoung',
      legalName: 'Smart Owl Education Pvt Ltd',
      cin: 'U80904KA2020PTC132006',
      founded: 2019,
      email: 'support@codeyoung.com',
      phone: '+91-88844-59977',
      mission:
        'Kids of today are the innovators of tomorrow. We empower them through effective and simplified education to unlock their learning potential to the maximum.',
      story:
        'Codeyoung started out in late 2019, and we have come a long way since then. We keep growing, serving parents the best we can and being a pivotal part of their kids’ adventure of learning and growth. Along the way we have been recognised by prestigious organisations and by parents themselves for our work in online education globally.',
    },
    founders: [
      {
        name: 'Shailendra Dhakad',
        role: 'Co-founder & CEO',
        almaMater: 'IIT Delhi',
        photo: 'founder_ceo.png',
        quote:
          'Meaning of Education should be a process that empowers an individual to do something which otherwise they cannot.',
      },
      {
        name: 'Rupika Taneja',
        role: 'Co-founder & COO',
        almaMater: 'IIT Delhi',
        photo: 'founder_coo.png',
        quote:
          'I deeply believe that if the innate creativity in kids is properly nurtured and finds expression, we can cultivate leaders.',
      },
    ],
    advantages: [
      { title: 'Live 1:1 online classes', description: 'Dedicated attention from a mentor who adapts lessons to your child’s pace and style.', icon: 'videocam' },
      { title: 'Mastery-based progress tracking', description: 'Students fully understand each concept before moving on to the next.', icon: 'trending_up' },
      { title: 'Real-time feedback & guidance', description: 'Immediate support accelerates learning and builds confidence.', icon: 'feedback' },
    ],
    awards: [
      { title: 'EdTech Startup of the Year', year: '2023' },
      { title: 'GSV Cup Finalists — Elite Top 25', year: '2021' },
      { title: 'Forbes India DGEMS Select 200', year: '2023' },
    ],
    subjects: ['Coding', 'Math', 'English', 'Science', 'Robotics', 'Financial Literacy'],
  });
});

/* ------------------------------------------------------------------ */
/* Utilities & errors                                                  */
/* ------------------------------------------------------------------ */

function safeJson(value, fallback) {
  if (value == null) return fallback;
  try {
    const parsed = JSON.parse(value);
    return parsed == null ? fallback : parsed;
  } catch {
    return fallback;
  }
}

app.use((err, _req, res, _next) => {
  console.error(err.stack || err);
  res.status(500).json({ error: 'Something went wrong!' });
});

app.use((req, res) => {
  res.status(404).json({ error: `Endpoint not found: ${req.method} ${req.originalUrl}` });
});

if (require.main === module) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`CodeYoung API listening on http://localhost:${PORT}`);
    console.log(`  database : sqlite (${seeded ? 'freshly seeded' : 'existing data'})`);
    console.log(`  mentor   : ${CHAT_URL}`);
    console.log(`  health   : http://localhost:${PORT}/health`);
  });
}

module.exports = app;
