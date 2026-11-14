import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codeyoung/features/home/home_screen.dart';
import 'package:codeyoung/features/videos/video_screen.dart';
import 'package:codeyoung/features/gallery/gallery_screen.dart';
import 'package:codeyoung/features/lessons/lessons_screen.dart';
import 'package:codeyoung/features/profile/profile_screen.dart';
import 'package:codeyoung/features/settings/settings_screen.dart';

final homeRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/videos',
        name: 'videos',
        builder: (context, state) => const VideosScreen(),
      ),
      GoRoute(
        path: '/gallery',
        name: 'gallery',
        builder: (context, state) => const GalleryScreen(),
      ),
      GoRoute(
        path: '/lessons',
        name: 'lessons',
        builder: (context, state) => const LessonsScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});