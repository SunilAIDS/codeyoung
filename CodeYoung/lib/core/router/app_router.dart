import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/about_screen.dart';
import '../../features/account/account_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/courses/course_detail_screen.dart';
import '../../features/courses/courses_screen.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/lessons/lesson_detail_screen.dart';
import '../../features/lessons/lessons_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/videos/video_player_screen.dart';
import '../../features/videos/video_screen.dart';

import '../../core/widgets/app_header.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),

      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      // Shell route keeps the bottom navigation persistent across the five
      // primary tabs while allowing nested pushes for detail screens.
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/courses', builder: (_, __) => const CoursesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
          ]),
        ],
      ),

      // Pushed detail routes (full-screen, above the shell).
      GoRoute(path: '/courses/:slug', builder: (_, s) => CourseDetailScreen(slug: s.pathParameters['slug'] ?? '')),
      GoRoute(path: '/lessons', builder: (_, __) => const LessonsScreen()),
      GoRoute(path: '/lessons/:id', builder: (_, s) => LessonDetailScreen(lessonId: int.tryParse(s.pathParameters['id'] ?? '') ?? 0)),
      GoRoute(path: '/videos', builder: (_, __) => const VideosScreen()),
      GoRoute(path: '/videos/:id', builder: (_, s) => VideoPlayerScreen(videoId: int.tryParse(s.pathParameters['id'] ?? '') ?? 0)),
      GoRoute(path: '/gallery', builder: (_, __) => const GalleryScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreenShell()),

      // Legacy paths from earlier builds — keep deep links working.
      GoRoute(path: '/', redirect: (_, __) => '/home'),
      GoRoute(path: '/profile', redirect: (_, __) => '/account'),
    ],
    errorBuilder: (_, state) => NotFoundScreen(location: state.uri.toString()),
  );
});

/// Simple 404 so bad deep links never white-screen.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(showBack: true, subtitle: 'Page not found'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('No page at $location', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('The link may be out of date.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
