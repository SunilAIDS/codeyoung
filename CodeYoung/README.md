# CodeYoung — Flutter App

The client for the CodeYoung learning platform: a premium, child-friendly UI
for learning to code, watching video lessons, tracking progress, and talking
to a voice mentor.

## Features

- **Home** — explains CodeYoung, the founders (Shailendra Dhakad, Co-founder
  & CEO; Rupika Taneja, Co-founder & COO — both IIT Delhi), the story and the
  journey.
- **About Us** — mission, how it works, flow chart, gallery.
- **Courses** — 8 courses → course detail → lessons → lesson detail, with
  per-user progress that follows you between screens.
- **Mentor** — Python-powered voice chatbot: speech-to-text input, live
  internet answers, and spoken (gTTS) replies.
- **Account** — profile, XP/level, stats, sign out.
- **Videos** — MP4 + YouTube lessons with reliable `img.youtube.com`
  thumbnails and a full-screen player.
- **Gallery** — zoomable, swipeable images (`photo_view`).
- **Settings** — theme, account and app options.

Bottom nav has 5 tabs (Home, About, Courses, Mentor, Account); Videos,
Lessons, Gallery, Settings, Login and Splash are pushed routes.

## Architecture

- **Flutter 3.x / Dart 3**
- **Riverpod** (`ProviderScope`) for state
- **GoRouter** for navigation (`lib/core/router/app_router.dart`)
- **Dio** wrapper with a bearer-token interceptor
  (`lib/core/services/api_service.dart`)
- **Poppins** bundled locally (5 weights), registered in `pubspec.yaml`

```
lib/
├── main.dart                  ProviderScope + GoRouter + theme + i18n
├── core/
│   ├── router/app_router.dart     all routes + 404
│   ├── services/api_service.dart  Dio + auth interceptor + ApiException
│   ├── services/repositories.dart every Riverpod provider + sendChat()
│   ├── theme/app_theme.dart       light/dark, Poppins
│   └── widgets/                   shared UI (banner carousel, etc.)
└── features/
    ├── splash/ home/ about/ courses/ lessons/ videos/
    ├── gallery/ chat/ account/ settings/ login/
    └── shell/app_shell.dart       bottom navigation
```

## Getting started

```bash
cd CodeYoung
flutter pub get
flutter run                # any device
flutter run -d chrome      # web
flutter build web          # production web build
```

The backend must be running first — see the
[root README](../README.md) or run `scripts\start-all.ps1`.

The API base URL resolves automatically to `http://10.0.2.2:3000` on the
Android emulator and `http://127.0.0.1:3000` elsewhere.

## Quality

```bash
flutter analyze     # No issues found
flutter build web   # succeeds
```

### Known environment limits

- `flutter test` cannot run on this machine: Windows Application Control/WDAC
  blocks `flutter_tester.exe`. This is an environment restriction, not a code
  issue.
- No Android SDK is installed here, so `flutter build apk` fails with
  "Android SDK could not be found". Use `flutter build web` as the compile
  check, or install the SDK to produce APKs.

## Assets

- `assets/images/primary_logo.png` — the official logo from www.codeyoung.com
- `assets/images/` — founders, story, journey, flow chart, banners, gallery
- `assets/fonts/Poppins-*.woff2` — bundled font family
- Video thumbnails: `https://img.youtube.com/vi/<id>/hqdefault.jpg`

## Support

For questions, contact support@codeyoung.com.
