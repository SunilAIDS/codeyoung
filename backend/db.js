'use strict';

/**
 * CodeYoung data layer.
 *
 * Uses Node's built-in `node:sqlite` so we get real SQL persistence with
 * zero native build steps. The database file lives next to the server and
 * is created/seeded automatically on first boot.
 */

const { DatabaseSync } = require('node:sqlite');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

const DB_PATH = process.env.DB_PATH || path.join(DATA_DIR, 'codeyoung.db');
const db = new DatabaseSync(DB_PATH);

db.exec('PRAGMA journal_mode = WAL;');
db.exec('PRAGMA foreign_keys = ON;');

/* ------------------------------------------------------------------ */
/* Schema                                                              */
/* ------------------------------------------------------------------ */

db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  salt          TEXT NOT NULL,
  name          TEXT NOT NULL,
  avatar_url    TEXT,
  bio           TEXT,
  role          TEXT NOT NULL DEFAULT 'student',
  is_premium    INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sessions (
  token      TEXT PRIMARY KEY,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  expires_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS courses (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  slug         TEXT NOT NULL UNIQUE,
  title        TEXT NOT NULL,
  subtitle     TEXT,
  description  TEXT,
  category     TEXT NOT NULL,
  level        TEXT NOT NULL,
  age_group    TEXT,
  duration     TEXT,
  price        REAL,
  currency     TEXT NOT NULL DEFAULT 'USD',
  lessons_count INTEGER NOT NULL DEFAULT 0,
  image_url    TEXT,
  icon         TEXT,
  color        TEXT,
  is_featured  INTEGER NOT NULL DEFAULT 0,
  sort_order   INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS lessons (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  course_id    INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  description  TEXT,
  category     TEXT NOT NULL,
  level        TEXT NOT NULL,
  duration     TEXT,
  thumbnail_url TEXT,
  video_id     TEXT,
  video_url    TEXT,
  video_type   TEXT NOT NULL DEFAULT 'youtube',
  objectives   TEXT,
  content      TEXT,
  sort_order   INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS videos (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  title         TEXT NOT NULL,
  description   TEXT,
  category      TEXT NOT NULL,
  level         TEXT NOT NULL,
  duration      TEXT,
  thumbnail_url TEXT,
  video_id      TEXT,
  video_url     TEXT,
  video_type    TEXT NOT NULL DEFAULT 'youtube',
  views         INTEGER NOT NULL DEFAULT 0,
  is_featured   INTEGER NOT NULL DEFAULT 0,
  sort_order    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS gallery_images (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  title       TEXT NOT NULL,
  description TEXT,
  url         TEXT NOT NULL,
  category    TEXT NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS banners (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  title      TEXT NOT NULL,
  subtitle   TEXT,
  badge      TEXT,
  image_url  TEXT,
  gradient   TEXT,
  cta_label  TEXT,
  cta_route  TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS progress (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lesson_id  INTEGER NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  completed  INTEGER NOT NULL DEFAULT 0,
  percent    INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(user_id, lesson_id)
);

CREATE TABLE IF NOT EXISTS achievements (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title      TEXT NOT NULL,
  icon       TEXT NOT NULL,
  earned     INTEGER NOT NULL DEFAULT 0,
  earned_at  TEXT,
  UNIQUE(user_id, title)
);

CREATE TABLE IF NOT EXISTS chat_messages (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER REFERENCES users(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL,
  role       TEXT NOT NULL,
  content    TEXT NOT NULL,
  source     TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_lessons_course  ON lessons(course_id);
CREATE INDEX IF NOT EXISTS idx_videos_category ON videos(category);
CREATE INDEX IF NOT EXISTS idx_gallery_category ON gallery_images(category);
CREATE INDEX IF NOT EXISTS idx_progress_user   ON progress(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_session    ON chat_messages(session_id);
`);

/* ------------------------------------------------------------------ */
/* Password helpers (scrypt — no native deps)                          */
/* ------------------------------------------------------------------ */

function hashPassword(password, saltHex) {
  const salt = saltHex || crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(String(password), salt, 64).toString('hex');
  return { salt, hash };
}

function verifyPassword(password, salt, expectedHash) {
  const { hash } = hashPassword(password, salt);
  const a = Buffer.from(hash, 'hex');
  const b = Buffer.from(expectedHash, 'hex');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/* ------------------------------------------------------------------ */
/* Seed                                                                */
/* ------------------------------------------------------------------ */

const IMG = (id, w = 900) =>
  `https://images.unsplash.com/${id}?w=${w}&q=80&auto=format&fit=crop`;

// Only photo IDs verified to return 200/206.
const PHOTOS = {
  code: IMG('photo-1461749280684-dccba630e2f6'),
  laptopCode: IMG('photo-1517694712202-14dd9538aa97'),
  macbook: IMG('photo-1498050108023-c5249f4df085'),
  working: IMG('photo-1531482615713-2afd69097998'),
  team: IMG('photo-1522202176988-66273c2fd55f'),
  laptopDesk: IMG('photo-1516321318423-f06f85e504b3'),
  mathBoard: IMG('photo-1503676260728-1c00da094a0b'),
  classroom: IMG('photo-1509062522246-3755977927d7'),
  kidsLearn: IMG('photo-1546410531-bb4caa6b424d'),
  desk: IMG('photo-1427504494785-3a9ca7044f45'),
  lecture: IMG('photo-1524178232363-1fb2b075b655'),
  kidsGroup: IMG('photo-1596495578065-6e0763fa1178'),
  kidsStudy: IMG('photo-1571260899304-425eee4c7efc'),
  robot: IMG('photo-1485827404703-89b55fcc595e'),
  codeScreen: IMG('photo-1555949963-aa79dcee981c'),
  codingHands: IMG('photo-1587620962725-abab7fe55159'),
  codeMonitor: IMG('photo-1550439062-609e1531270e'),
  python: IMG('photo-1607799279861-4dd421887fb3'),
  react: IMG('photo-1633356122544-f134324a6cee'),
  html: IMG('photo-1618477388954-7852f32655ec'),
  womanDev: IMG('photo-1573497019940-1c28c88b4f3e'),
  teamwork: IMG('photo-1531545514256-b1400bc00f31'),
  meeting: IMG('photo-1580894732444-8ecded7900cd'),
  groupWork: IMG('photo-1552581234-26160f608093'),
  students: IMG('photo-1543269865-cbf427effbad'),
  laptops: IMG('photo-1523240795612-9a054b0db644'),
  kidsRobot: IMG('photo-1560785496-3c9d27877182'),
  thinking: IMG('photo-1509228468518-180dd4864904'),
  circuit: IMG('photo-1518770660439-4636190af475'),
};

// YouTube IDs verified via the oEmbed endpoint (all return 200).
const YT = (id) => `https://www.youtube.com/watch?v=${id}`;
const YT_THUMB = (id) => `https://img.youtube.com/vi/${id}/hqdefault.jpg`;

// Direct MP4 sources verified reachable (range requests return 206).
const MP4 = {
  bunny: 'https://www.w3schools.com/html/mov_bbb.mp4',
  flower: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
  bunnyShort: 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4',
};

const SEED = {
  courses: [
    {
      slug: 'scratch-programming', title: 'Scratch Programming',
      subtitle: 'Visual coding fundamentals for ages 6-9',
      description: 'Drag-and-drop blocks that teach loops, variables and event-driven thinking through playable games and animations.',
      category: 'Coding', level: 'Beginner', age_group: '6-9 years', duration: '12 weeks',
      price: 22, lessons_count: 12, image_url: PHOTOS.kidsLearn, icon: 'blocks', color: '#FF6B6B', is_featured: 1, sort_order: 1,
    },
    {
      slug: 'python-basics', title: 'Python for Beginners',
      subtitle: 'From first line to first real program',
      description: 'Learn syntax, data types, loops and functions by building quizzes, hangman and automation scripts.',
      category: 'Coding', level: 'Beginner', age_group: '9-13 years', duration: '16 weeks',
      price: 22, lessons_count: 16, image_url: PHOTOS.python, icon: 'code', color: '#1E88E5', is_featured: 1, sort_order: 2,
    },
    {
      slug: 'web-development', title: 'Web Development',
      subtitle: 'HTML, CSS & responsive layouts',
      description: 'Build and publish real websites. Covers semantic markup, flexbox, grid and mobile-first design.',
      category: 'Coding', level: 'Intermediate', age_group: '10-15 years', duration: '14 weeks',
      price: 24, lessons_count: 14, image_url: PHOTOS.html, icon: 'web', color: '#FF9800', is_featured: 1, sort_order: 3,
    },
    {
      slug: 'javascript-games', title: 'JavaScript Game Dev',
      subtitle: 'Arcade games in the browser',
      description: 'Canvas animation, collision detection and game loops while shipping playable titles.',
      category: 'Coding', level: 'Intermediate', age_group: '11-16 years', duration: '15 weeks',
      price: 24, lessons_count: 15, image_url: PHOTOS.codeScreen, icon: 'sports_esports', color: '#9C27B0', is_featured: 0, sort_order: 4,
    },
    {
      slug: 'robotics-arduino', title: 'Robotics & Arduino',
      subtitle: 'Hardware that responds to code',
      description: 'Wire sensors, drive motors and program microcontrollers to build a line-following robot.',
      category: 'Robotics', level: 'Intermediate', age_group: '10-15 years', duration: '16 weeks',
      price: 28, lessons_count: 12, image_url: PHOTOS.kidsRobot, icon: 'smart_toy', color: '#4CAF50', is_featured: 1, sort_order: 5,
    },
    {
      slug: 'math-mastery', title: 'Math Mastery',
      subtitle: 'Grade 1-8, mastery based',
      description: 'Number sense, fractions, algebra and geometry taught with manipulatives and adaptive practice.',
      category: 'Math', level: 'Beginner', age_group: '6-14 years', duration: 'Ongoing',
      price: 22, lessons_count: 20, image_url: PHOTOS.mathBoard, icon: 'calculate', color: '#00BCD4', is_featured: 0, sort_order: 6,
    },
    {
      slug: 'english-language', title: 'English Language',
      subtitle: 'Reading, grammar & confident speaking',
      description: 'Phonics to fluent composition with live 1:1 mentor feedback on every assignment.',
      category: 'English', level: 'Beginner', age_group: '6-14 years', duration: 'Ongoing',
      price: 22, lessons_count: 18, image_url: PHOTOS.lecture, icon: 'menu_book', color: '#E91E63', is_featured: 0, sort_order: 7,
    },
    {
      slug: 'science-explorers', title: 'Science Explorers',
      subtitle: 'Experiments that make concepts stick',
      description: 'Physics, chemistry and biology through guided experiments and observation journals.',
      category: 'Science', level: 'Beginner', age_group: '7-14 years', duration: 'Ongoing',
      price: 22, lessons_count: 16, image_url: PHOTOS.circuit, icon: 'science', color: '#FFC107', is_featured: 0, sort_order: 8,
    },
  ],

  lessons: [
    // Scratch
    { course: 'scratch-programming', title: 'What Is Programming?', description: 'Understand instructions, sequence and why computers do exactly what you tell them.', category: 'Beginner', level: 'Beginner', duration: '12 min', thumbnail_url: PHOTOS.kidsLearn, video_id: '3JluqTojuME', video_type: 'youtube', sort_order: 1 },
    { course: 'scratch-programming', title: 'Sprites & The Stage', description: 'Create characters, set costumes and position them with coordinates.', category: 'Beginner', level: 'Beginner', duration: '14 min', thumbnail_url: PHOTOS.kidsGroup, video_id: '5MgBikgcWnY', video_type: 'youtube', sort_order: 2 },
    { course: 'scratch-programming', title: 'Loops Without Fear', description: 'Repeat actions cleanly with forever and repeat blocks.', category: 'Beginner', level: 'Beginner', duration: '15 min', thumbnail_url: PHOTOS.kidsStudy, video_id: null, video_url: MP4.bunny, video_type: 'mp4', sort_order: 3 },
    { course: 'scratch-programming', title: 'Events & Broadcasting', description: 'Make sprites react to clicks, keys and messages.', category: 'Beginner', level: 'Beginner', duration: '16 min', thumbnail_url: PHOTOS.classroom, video_id: null, video_url: MP4.flower, video_type: 'mp4', sort_order: 4 },

    // Python
    { course: 'python-basics', title: 'Python Setup & First Program', description: 'Install Python, run a script and understand the REPL.', category: 'Beginner', level: 'Beginner', duration: '18 min', thumbnail_url: PHOTOS.python, video_id: 'rfscVS0vtbw', video_type: 'youtube', sort_order: 1 },
    { course: 'python-basics', title: 'Variables & Data Types', description: 'Store text, numbers and booleans; convert between types.', category: 'Beginner', level: 'Beginner', duration: '16 min', thumbnail_url: PHOTOS.codeMonitor, video_id: 'rfscVS0vtbw', video_type: 'youtube', sort_order: 2 },
    { course: 'python-basics', title: 'Conditionals & Loops', description: 'Branch with if/elif/else and iterate with for and while.', category: 'Beginner', level: 'Beginner', duration: '20 min', thumbnail_url: PHOTOS.codingHands, video_id: 'rfscVS0vtbw', video_type: 'youtube', sort_order: 3 },
    { course: 'python-basics', title: 'Functions & Modules', description: 'Write reusable functions and import the standard library.', category: 'Intermediate', level: 'Intermediate', duration: '22 min', thumbnail_url: PHOTOS.laptopCode, video_id: 'rfscVS0vtbw', video_type: 'youtube', sort_order: 4 },
    { course: 'python-basics', title: 'Build Hangman', description: 'Combine loops, lists and randomness into a complete game.', category: 'Intermediate', level: 'Intermediate', duration: '28 min', thumbnail_url: PHOTOS.code, video_id: null, video_url: MP4.bunnyShort, video_type: 'mp4', sort_order: 5 },

    // Web
    { course: 'web-development', title: 'HTML Document Structure', description: 'Head, body, semantic tags and accessible landmarks.', category: 'Beginner', level: 'Beginner', duration: '15 min', thumbnail_url: PHOTOS.html, video_id: '3JluqTojuME', video_type: 'youtube', sort_order: 1 },
    { course: 'web-development', title: 'Styling With CSS', description: 'Selectors, the box model, colour and typography.', category: 'Beginner', level: 'Beginner', duration: '18 min', thumbnail_url: PHOTOS.macbook, video_id: '3JluqTojuME', video_type: 'youtube', sort_order: 2 },
    { course: 'web-development', title: 'Flexbox & Grid', description: 'Two-dimensional layout systems for real page structure.', category: 'Intermediate', level: 'Intermediate', duration: '24 min', thumbnail_url: PHOTOS.laptopDesk, video_id: '3JluqTojuME', video_type: 'youtube', sort_order: 3 },
    { course: 'web-development', title: 'Responsive Design', description: 'Media queries and mobile-first breakpoints.', category: 'Intermediate', level: 'Intermediate', duration: '20 min', thumbnail_url: PHOTOS.desk, video_id: null, video_url: MP4.flower, video_type: 'mp4', sort_order: 4 },

    // JavaScript
    { course: 'javascript-games', title: 'JavaScript Crash Course', description: 'Types, functions, arrays and DOM basics in one sitting.', category: 'Beginner', level: 'Beginner', duration: '26 min', thumbnail_url: PHOTOS.codeScreen, video_id: 'hdI2bqOjy3c', video_type: 'youtube', sort_order: 1 },
    { course: 'javascript-games', title: 'Canvas & Game Loops', description: 'Draw shapes and animate with requestAnimationFrame.', category: 'Intermediate', level: 'Intermediate', duration: '25 min', thumbnail_url: PHOTOS.working, video_id: 'W6NZfCO5SIk', video_type: 'youtube', sort_order: 2 },
    { course: 'javascript-games', title: 'Collision Detection', description: 'AABB collision and scoring systems.', category: 'Intermediate', level: 'Intermediate', duration: '22 min', thumbnail_url: PHOTOS.team, video_id: 'jS4aFq5-91M', video_type: 'youtube', sort_order: 3 },

    // Robotics
    { course: 'robotics-arduino', title: 'Meet Your Arduino', description: 'Board anatomy, pins and safely uploading your first sketch.', category: 'Beginner', level: 'Beginner', duration: '17 min', thumbnail_url: PHOTOS.circuit, video_id: null, video_url: MP4.bunny, video_type: 'mp4', sort_order: 1 },
    { course: 'robotics-arduino', title: 'Sensors & Signals', description: 'Read ultrasonic and IR sensors into your program.', category: 'Intermediate', level: 'Intermediate', duration: '21 min', thumbnail_url: PHOTOS.kidsRobot, video_id: null, video_url: MP4.flower, video_type: 'mp4', sort_order: 2 },
    { course: 'robotics-arduino', title: 'Build a Line Follower', description: 'Combine motors and sensors into an autonomous robot.', category: 'Advanced', level: 'Advanced', duration: '30 min', thumbnail_url: PHOTOS.robot, video_id: null, video_url: MP4.bunnyShort, video_type: 'mp4', sort_order: 3 },

    // Math
    { course: 'math-mastery', title: 'Number Sense Warm-ups', description: 'Mental maths patterns that build speed and confidence.', category: 'Beginner', level: 'Beginner', duration: '12 min', thumbnail_url: PHOTOS.mathBoard, video_id: null, video_url: MP4.flower, video_type: 'mp4', sort_order: 1 },
    { course: 'math-mastery', title: 'Fractions Made Visual', description: 'Equivalent fractions using area models.', category: 'Beginner', level: 'Beginner', duration: '14 min', thumbnail_url: PHOTOS.thinking, video_id: null, video_url: MP4.bunny, video_type: 'mp4', sort_order: 2 },

    // English
    { course: 'english-language', title: 'Parts of Speech', description: 'Nouns, verbs and adjectives explained with examples.', category: 'Beginner', level: 'Beginner', duration: '13 min', thumbnail_url: PHOTOS.lecture, video_id: null, video_url: MP4.bunnyShort, video_type: 'mp4', sort_order: 1 },
    { course: 'english-language', title: 'Paragraph Writing', description: 'Plan, draft and revise a clear paragraph.', category: 'Intermediate', level: 'Intermediate', duration: '19 min', thumbnail_url: PHOTOS.students, video_id: null, video_url: MP4.flower, video_type: 'mp4', sort_order: 2 },

    // Science
    { course: 'science-explorers', title: 'States of Matter', description: 'Solids, liquids and gases with kitchen experiments.', category: 'Beginner', level: 'Beginner', duration: '15 min', thumbnail_url: PHOTOS.circuit, video_id: null, video_url: MP4.bunny, video_type: 'mp4', sort_order: 1 },
    { course: 'science-explorers', title: 'Forces & Motion', description: 'Push, pull, friction and Newtons laws made simple.', category: 'Intermediate', level: 'Intermediate', duration: '18 min', thumbnail_url: PHOTOS.classroom, video_id: null, video_url: MP4.flower, video_type: 'mp4', sort_order: 2 },
  ],

  videos: [
    { title: 'Learn Python - Full Course for Beginners', description: 'A complete beginner path: syntax, data structures, functions and four practical projects.', category: 'Python', level: 'Beginner', duration: '4:26:43', video_id: 'rfscVS0vtbw', video_type: 'youtube', views: 4200000, is_featured: 1, sort_order: 1 },
    { title: 'Learn JavaScript - Full Course for Beginners', description: 'Variables through closures and async, with exercises after every chapter.', category: 'JavaScript', level: 'Beginner', duration: '3:27:00', video_id: 'PkZNo7MFNFg', video_type: 'youtube', views: 3100000, is_featured: 1, sort_order: 2 },
    { title: 'JavaScript Crash Course For Beginners', description: 'Fast-paced overview of types, functions, the DOM and events.', category: 'JavaScript', level: 'Beginner', duration: '1:47:00', video_id: 'hdI2bqOjy3c', video_type: 'youtube', views: 1900000, is_featured: 0, sort_order: 3 },
    { title: 'Web Development Tutorial for Beginners', description: 'Build your first webpages with HTML and CSS from zero.', category: 'Web', level: 'Beginner', duration: '1:30:00', video_id: '3JluqTojuME', video_type: 'youtube', views: 1200000, is_featured: 1, sort_order: 4 },
    { title: 'JavaScript Course for Beginners', description: 'Your first step to web development, project driven.', category: 'JavaScript', level: 'Beginner', duration: '2:10:00', video_id: 'W6NZfCO5SIk', video_type: 'youtube', views: 860000, is_featured: 0, sort_order: 5 },
    { title: 'React JS - React Tutorial for Beginners', description: 'Components, props, state and hooks explained by building an app.', category: 'React', level: 'Intermediate', duration: '2:05:00', video_id: 'Ke90Tje7VS0', video_type: 'youtube', views: 1500000, is_featured: 0, sort_order: 6 },
    { title: 'Node.js Tutorial for Beginners', description: 'Learn Node in one hour: modules, HTTP, and your first API.', category: 'Backend', level: 'Intermediate', duration: '1:00:00', video_id: 'TlB_eWDSMt4', video_type: 'youtube', views: 2400000, is_featured: 0, sort_order: 7 },
    { title: 'JavaScript Programming - Full Course', description: 'Deep dive covering the language end to end.', category: 'JavaScript', level: 'Intermediate', duration: '3:00:00', video_id: 'jS4aFq5-91M', video_type: 'youtube', views: 780000, is_featured: 0, sort_order: 8 },
    { title: 'Algorithms and Data Structures', description: 'Big-O, arrays, linked lists, trees and searching explained visually.', category: 'Computer Science', level: 'Advanced', duration: '4:37:00', video_id: '8hly31xKli0', video_type: 'youtube', views: 1100000, is_featured: 0, sort_order: 9 },
    { title: 'Animation Fundamentals', description: 'A short demonstration clip used in our motion-design module.', category: 'Creative', level: 'Beginner', duration: '0:10', video_url: MP4.bunny, video_type: 'mp4', views: 64000, is_featured: 0, sort_order: 10 },
    { title: 'Nature Timelapse Sample', description: 'Colour and timing reference used in the video-editing lesson.', category: 'Creative', level: 'Beginner', duration: '0:30', video_url: MP4.flower, video_type: 'mp4', views: 42000, is_featured: 0, sort_order: 11 },
    { title: 'Motion Graphics Sample', description: 'Short sample clip for the intro-to-animation exercise.', category: 'Creative', level: 'Beginner', duration: '0:10', video_url: MP4.bunnyShort, video_type: 'mp4', views: 38000, is_featured: 0, sort_order: 12 },
  ],

  gallery: [
    { title: 'Kids Coding Together', description: 'Young learners pairing up on a programming challenge', url: PHOTOS.kidsGroup, category: 'Classroom', sort_order: 1 },
    { title: 'Build Session', description: 'Focused hands-on workshop with a mentor guiding', url: PHOTOS.kidsStudy, category: 'Classroom', sort_order: 2 },
    { title: 'First Lines of Code', description: 'A first program running for the very first time', url: PHOTOS.kidsLearn, category: 'Learning', sort_order: 3 },
    { title: 'Lab Work', description: 'Modern computers in a tech-enabled learning space', url: PHOTOS.classroom, category: 'Technology', sort_order: 4 },
    { title: 'Circuit Exploration', description: 'Understanding hardware through close inspection', url: PHOTOS.circuit, category: 'Robotics', sort_order: 5 },
    { title: 'Robot Build', description: 'Assembling and testing a working robot', url: PHOTOS.kidsRobot, category: 'Robotics', sort_order: 6 },
    { title: 'Algorithm Thinking', description: 'Working through a problem step by step', url: PHOTOS.thinking, category: 'Learning', sort_order: 7 },
    { title: 'Pair Programming', description: 'Two minds, one keyboard, better code', url: PHOTOS.teamwork, category: 'Collaboration', sort_order: 8 },
    { title: 'Team Review', description: 'Reviewing a project together before demo day', url: PHOTOS.groupWork, category: 'Collaboration', sort_order: 9 },
    { title: 'Deep Focus', description: 'Flow state during a build sprint', url: PHOTOS.working, category: 'Development', sort_order: 10 },
    { title: 'Screen Time', description: 'Code filling the screen mid-refactor', url: PHOTOS.codeScreen, category: 'Development', sort_order: 11 },
    { title: 'Keyboard Craft', description: 'Typing out the solution', url: PHOTOS.codingHands, category: 'Programming', sort_order: 12 },
    { title: 'Desk Setup', description: 'A clean workspace ready for the next lesson', url: PHOTOS.desk, category: 'Technology', sort_order: 13 },
    { title: 'Study Group', description: 'Learning together after class', url: PHOTOS.students, category: 'Event', sort_order: 14 },
    { title: 'Award Day', description: 'Celebrating course completion', url: PHOTOS.kidsGroup, category: 'Achievement', sort_order: 15 },
    { title: 'Python Corner', description: 'A quiet nook for scripting practice', url: PHOTOS.python, category: 'Programming', sort_order: 16 },
    { title: 'Web Workshop', description: 'Layouts coming together on screen', url: PHOTOS.html, category: 'Web', sort_order: 17 },
    { title: 'Creative Coding', description: 'Art generated from code', url: PHOTOS.react, category: 'Creative', sort_order: 18 },
  ],

  banners: [
    {
      title: '1:1 live learning for your child',
      subtitle: 'One child. One mentor. Real attention. Clear progress.',
      badge: 'FREE trial', image_url: 'students.png',
      gradient: 'linear-gradient(135deg,#1E88E5 0%,#1565C0 55%,#0D47A1 100%)',
      cta_label: 'Book a FREE trial', cta_route: '/courses', sort_order: 1,
    },
    {
      title: 'Codeyoung Mini Course is here',
      subtitle: '8 x 50-minute sessions • 1:1 live online • 1 dedicated mentor',
      badge: '33% off', image_url: 'elevate_2.png',
      gradient: 'linear-gradient(135deg,#7B61FF 0%,#6A11CB 50%,#2575FC 100%)',
      cta_label: 'See courses', cta_route: '/courses', sort_order: 2,
    },
    {
      title: 'Ask anything, any time',
      subtitle: 'Your AI mentor answers with live internet results and reads them aloud',
      badge: 'New', image_url: 'elevate_1.png',
      gradient: 'linear-gradient(135deg,#00BFA6 0%,#00897B 50%,#004D40 100%)',
      cta_label: 'Open mentor', cta_route: '/chat', sort_order: 3,
    },
  ],
};

function seedIfEmpty() {
  const row = db.prepare('SELECT COUNT(*) AS n FROM courses').get();
  if (row.n > 0) return false;

  const insertCourse = db.prepare(`
    INSERT INTO courses (slug,title,subtitle,description,category,level,age_group,duration,price,currency,lessons_count,image_url,icon,color,is_featured,sort_order)
    VALUES (@slug,@title,@subtitle,@description,@category,@level,@age_group,@duration,@price,'USD',@lessons_count,@image_url,@icon,@color,@is_featured,@sort_order)
  `);
  const insertLesson = db.prepare(`
    INSERT INTO lessons (course_id,title,description,category,level,duration,thumbnail_url,video_id,video_url,video_type,objectives,content,sort_order)
    VALUES (@course_id,@title,@description,@category,@level,@duration,@thumbnail_url,@video_id,@video_url,@video_type,@objectives,@content,@sort_order)
  `);
  const insertVideo = db.prepare(`
    INSERT INTO videos (title,description,category,level,duration,thumbnail_url,video_id,video_url,video_type,views,is_featured,sort_order)
    VALUES (@title,@description,@category,@level,@duration,@thumbnail_url,@video_id,@video_url,@video_type,@views,@is_featured,@sort_order)
  `);
  const insertImage = db.prepare(`
    INSERT INTO gallery_images (title,description,url,category,sort_order)
    VALUES (@title,@description,@url,@category,@sort_order)
  `);
  const insertBanner = db.prepare(`
    INSERT INTO banners (title,subtitle,badge,image_url,gradient,cta_label,cta_route,sort_order)
    VALUES (@title,@subtitle,@badge,@image_url,@gradient,@cta_label,@cta_route,@sort_order)
  `);

  const objectives = JSON.stringify([
    'Understand the core concept with a worked example',
    'Practise with guided, hands-on exercises',
    'Build a mini-project that applies the skill',
    'Get feedback from an experienced mentor',
    'Earn a completion certificate',
  ]);

  db.exec('BEGIN');
  try {
    const courseIdBySlug = {};
    for (const c of SEED.courses) {
      const r = insertCourse.run(c);
      courseIdBySlug[c.slug] = Number(r.lastInsertRowid);
    }

    for (const l of SEED.lessons) {
      insertLesson.run({
        course_id: courseIdBySlug[l.course],
        title: l.title,
        description: l.description,
        category: l.category,
        level: l.level,
        duration: l.duration,
        thumbnail_url: l.thumbnail_url,
        video_id: l.video_id || null,
        video_url: l.video_url || null,
        video_type: l.video_type,
        objectives,
        content: l.description,
        sort_order: l.sort_order,
      });
    }

    for (const v of SEED.videos) {
      const thumb = v.video_type === 'youtube' && v.video_id
        ? YT_THUMB(v.video_id)
        : (v.video_id ? YT_THUMB(v.video_id) : PHOTOS.code);
      insertVideo.run({
        title: v.title, description: v.description, category: v.category,
        level: v.level, duration: v.duration, thumbnail_url: thumb,
        video_id: v.video_id || null, video_url: v.video_url || null,
        video_type: v.video_type, views: v.views,
        is_featured: v.is_featured, sort_order: v.sort_order,
      });
    }

    for (const g of SEED.gallery) insertImage.run(g);
    for (const b of SEED.banners) insertBanner.run(b);

    db.exec('COMMIT');
  } catch (err) {
    db.exec('ROLLBACK');
    throw err;
  }
  return true;
}

/* ------------------------------------------------------------------ */
/* Public helpers                                                      */
/* ------------------------------------------------------------------ */

const DEFAULT_ACHIEVEMENTS = [
  { title: 'First Login', icon: 'login' },
  { title: 'First Lesson', icon: 'book' },
  { title: 'First Project', icon: 'code' },
  { title: '10 Lessons Completed', icon: 'format_list_numbered' },
  { title: '50 Hours Learned', icon: 'schedule' },
];

function ensureAchievements(userId) {
  const insert = db.prepare(
    'INSERT OR IGNORE INTO achievements (user_id, title, icon, earned) VALUES (?,?,?,0)'
  );
  for (const a of DEFAULT_ACHIEVEMENTS) insert.run(userId, a.title, a.icon);
}

module.exports = {
  db,
  seedIfEmpty,
  hashPassword,
  verifyPassword,
  ensureAchievements,
  PHOTOS,
  DEFAULT_ACHIEVEMENTS,
};
