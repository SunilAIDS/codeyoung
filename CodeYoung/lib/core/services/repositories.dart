import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'api_service.dart';

/// Session / auth state exposed to the widget tree.
class AuthState {
  const AuthState({this.user, this.initialised = false});

  final AppUser? user;
  final bool initialised;

  bool get isLoggedIn => user != null;

  AuthState copyWith({AppUser? user, bool? initialised, bool clearUser = false}) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        initialised: initialised ?? this.initialised,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._api) : super(const AuthState()) {
    _restore();
  }

  final ApiService _api;

  Future<void> _restore() async {
    await _api.restoreSession();
    if (_api.isAuthenticated) {
      try {
        // Give a cold server up to a minute before giving up on the saved
        // session — otherwise first launch after an idle day logs the user
        // out purely because the backend was asleep.
        final up = await _api.wake();
        if (!up) {
          // Keep the stored token: try again next launch.
          state = const AuthState(initialised: true);
          return;
        }
        final json = await _api.getJson('/api/auth/me', requireAuth: true);
        state = AuthState(user: AppUser.fromJson(json), initialised: true);
        return;
      } on ApiException catch (e) {
        // Only a definitive 401 means the session is really over.
        if (e.isUnauthorized) await _api.clearSession();
      } catch (_) {
        // Transient failure — keep the token, let the UI show logged-out
        // state for this run; next launch retries.
      }
    }
    state = const AuthState(initialised: true);
  }

  Future<String?> login(String email, String password) async {
    final json = await _api.postJson(
      '/api/auth/login',
      {'email': email.trim(), 'password': password},
      rawToken: true,
    );
    final userJson = json['user'];
    state = AuthState(
      user: userJson is Map<String, dynamic>
          ? AppUser.fromJson(userJson)
          : AppUser(id: '${json['userId'] ?? ''}', name: 'CodeYoung Learner', email: email),
      initialised: true,
    );
    return null;
  }

  Future<String?> register(String name, String email, String password) async {
    final json = await _api.postJson(
      '/api/auth/register',
      {'name': name.trim(), 'email': email.trim(), 'password': password},
      rawToken: true,
    );
    final userJson = json['user'];
    state = AuthState(
      user: userJson is Map<String, dynamic>
          ? AppUser.fromJson(userJson)
          : AppUser(id: '${json['userId'] ?? ''}', name: name, email: email),
      initialised: true,
    );
    return null;
  }

  Future<void> logout() async {
    try {
      if (_api.isAuthenticated) {
        await _api.postJson('/api/auth/logout', const {}, requireAuth: true);
      }
    } catch (_) {
      // Best effort — local session is cleared regardless.
    }
    await _api.clearSession();
    state = const AuthState(initialised: true);
  }

  Future<void> updateProfile({String? name, String? email, String? bio}) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (bio != null) 'bio': bio,
    };
    if (body.isEmpty) return;
    final json = await _api.putJson('/api/users/profile', body);
    final userJson = json['user'];
    if (userJson is Map<String, dynamic>) {
      state = state.copyWith(user: AppUser.fromJson(userJson));
    }
  }

  void refreshUser(AppUser user) => state = state.copyWith(user: user);
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService.instance);

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(apiServiceProvider));
});

/// True once the session has been restored (used by the splash screen).
final sessionReadyProvider = Provider<bool>((ref) => ref.watch(authProvider).initialised);

final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authProvider).user);

/* -------------------------------------------------------------------------- */
/* Content                                                                    */
/* -------------------------------------------------------------------------- */

final coursesProvider = FutureProvider.autoDispose<List<Course>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final json = await api.getList('/api/courses');
  return json
      .map((e) => Course.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
});

final courseDetailProvider = FutureProvider.autoDispose.family<Course, String>((ref, slug) async {
  final api = ref.watch(apiServiceProvider);
  final json = await api.getJson('/api/courses/$slug');
  return Course.fromJson(json);
});

final lessonsProvider = FutureProvider.autoDispose<List<Lesson>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final json = await api.getList('/api/lessons');
  return json
      .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
});

final videosProvider = FutureProvider.autoDispose<List<VideoItem>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final json = await api.getList('/api/videos');
  return json
      .map((e) => VideoItem.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
});

final galleryProvider = FutureProvider.autoDispose<List<GalleryImage>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final json = await api.getList('/api/gallery');
  return json
      .map((e) => GalleryImage.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
});

class HomeFeed {
  const HomeFeed({
    required this.banners,
    required this.featuredCourses,
    required this.featuredVideos,
    required this.latestVideos,
    required this.categories,
    required this.galleryPreview,
    required this.stats,
  });

  final List<PromoBanner> banners;
  final List<Course> featuredCourses;
  final List<VideoItem> featuredVideos;
  final List<VideoItem> latestVideos;
  final List<String> categories;
  final List<GalleryImage> galleryPreview;
  final Map<String, dynamic> stats;

  factory HomeFeed.fromJson(Map<String, dynamic> j) {
    List<T> cast<T>(String key, T Function(Map<String, dynamic>) map) {
      final v = j[key];
      if (v is! List) return <T>[];
      return v
          .whereType<Map>()
          .map((e) => map(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }

    return HomeFeed(
      banners: cast('banners', PromoBanner.fromJson),
      featuredCourses: cast('featuredCourses', Course.fromJson),
      featuredVideos: cast('featuredVideos', VideoItem.fromJson),
      latestVideos: cast('latestVideos', VideoItem.fromJson),
      categories: (j['categories'] is List)
          ? (j['categories'] as List).map((e) => '$e').toList()
          : const [],
      galleryPreview: cast('galleryPreview', GalleryImage.fromJson),
      stats: j['stats'] is Map ? Map<String, dynamic>.from(j['stats'] as Map) : const {},
    );
  }
}

final homeFeedProvider = FutureProvider.autoDispose<HomeFeed>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final json = await api.getJson('/api/home');
  return HomeFeed.fromJson(json);
});

final aboutProvider = FutureProvider.autoDispose<AboutInfo>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final json = await api.getJson('/api/about');
  return AboutInfo.fromJson(json);
});

final statsProvider = FutureProvider.autoDispose<UserStats>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final json = await api.getJson('/api/user/stats', requireAuth: true);
  return UserStats.fromJson(json);
});

/* -------------------------------------------------------------------------- */
/* Chat                                                                       */
/* -------------------------------------------------------------------------- */

/// Sends one message to the mentor (Node -> Python -> web search + TTS).
///
/// Returns the assistant reply, or throws [ApiException] with a message the
/// chat screen can render inline.
Future<ChatMessage> sendChat(
  WidgetRef ref, {
  required String message,
  required List<ChatMessage> history,
  bool speak = false,
  String? sessionId,
}) async {
  final api = ref.read(apiServiceProvider);
  final json = await api.postJson(
    '/api/chat',
    {
      'message': message,
      'history': history.take(10).map((m) => m.toHistoryJson()).toList(),
      'speak': speak,
      if (sessionId != null) 'session_id': sessionId,
    },
  );

  final sources = <Map<String, dynamic>>[];
  if (json['sources'] is List) {
    for (final s in json['sources'] as List) {
      if (s is Map) sources.add(Map<String, dynamic>.from(s));
    }
  }

  return ChatMessage(
    role: 'assistant',
    content: '${json['reply'] ?? 'Sorry, I could not answer that.'}',
    source: json['source'] as String?,
    sources: sources,
    audioBase64: json['audio'] as String?,
    timestamp: DateTime.now(),
  );
}
