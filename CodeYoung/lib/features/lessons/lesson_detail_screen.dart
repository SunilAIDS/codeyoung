import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/common.dart';

/// Fetches a single lesson by id.
final lessonDetailProvider = FutureProvider.autoDispose.family<Lesson, int>((ref, id) async {
  final api = ref.watch(apiServiceProvider);
  final json = await api.getJson('/api/lessons/$id');
  return Lesson.fromJson(json);
});

/// Lesson player/detail: embedded video (YouTube or MP4), objectives and
/// progress marking that persists to the backend.
class LessonDetailScreen extends ConsumerStatefulWidget {
  const LessonDetailScreen({super.key, required this.lessonId});

  final int lessonId;

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  bool _saving = false;

  Future<void> _markCompleted(Lesson lesson) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.postJson(
        '/api/progress',
        {'lesson_id': lesson.id, 'completed': true, 'percent': 100},
        requireAuth: true,
      );
      ref.invalidate(lessonDetailProvider(widget.lessonId));
      ref.invalidate(lessonsProvider);
      ref.invalidate(statsProvider);
      if (mounted) {
        showAppSnackBar(context, 'Nice work — lesson marked as completed!');
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not save progress. Please try again.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setPercent(Lesson lesson, int percent) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.postJson(
        '/api/progress',
        {'lesson_id': lesson.id, 'percent': percent},
        requireAuth: true,
      );
      ref.invalidate(lessonDetailProvider(widget.lessonId));
      ref.invalidate(lessonsProvider);
    } catch (_) {
      // Non-blocking: progress sync is best-effort while watching.
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(lessonDetailProvider(widget.lessonId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: const AppHeader(showBack: true, subtitle: 'Lesson'),
      body: detail.when(
        loading: () => const LoadingState(label: 'Loading lesson...'),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(lessonDetailProvider(widget.lessonId)),
        ),
        data: (lesson) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Player(lesson: lesson),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            LevelChip(label: lesson.category),
                            const SizedBox(width: 8),
                            if (lesson.duration != null)
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded,
                                      size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    lesson.duration!,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.textOnDark.withValues(alpha: 0.7)
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            const Spacer(),
                            if (lesson.completed)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.accentGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_rounded,
                                        size: 14, color: AppColors.accentGreen),
                                    SizedBox(width: 5),
                                    Text(
                                      'Completed',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.accentGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          lesson.title,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.2,
                            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                          ),
                        ),
                        if (lesson.courseTitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            lesson.courseTitle!,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                        if (lesson.description != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            lesson.description!,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.65,
                              color: isDark
                                  ? AppColors.textOnDark.withValues(alpha: 0.85)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],

                        if (lesson.objectives.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _Objectives(objectives: lesson.objectives),
                        ],

                        const SizedBox(height: 22),
                        if (lesson.percent > 0 && !lesson.completed) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.bgDarkCard
                                  : AppColors.bgWhite,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Watched ${lesson.percent}%',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.textOnDark
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Slider(
                                  value: lesson.percent.toDouble(),
                                  min: 0,
                                  max: 100,
                                  divisions: 20,
                                  activeColor: AppColors.primaryBlue,
                                  onChanged: (v) =>
                                      _setPercent(lesson, v.round()),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        GradientButton(
                          label: lesson.completed
                              ? 'Review lesson again'
                              : 'Mark lesson as completed',
                          icon: lesson.completed
                              ? Icons.replay_rounded
                              : Icons.check_circle_rounded,
                          gradient: lesson.completed
                              ? AppGradients.ocean
                              : AppGradients.mint,
                          loading: _saving,
                          onPressed: () => _markCompleted(lesson),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (lesson.courseSlug != null &&
                                lesson.courseSlug!.isNotEmpty) {
                              context.push('/courses/${lesson.courseSlug}');
                            } else {
                              context.push('/lessons');
                            }
                          },
                          icon: const Icon(Icons.menu_book_rounded, size: 18),
                          label: Text(
                            lesson.courseSlug != null
                                ? 'Back to course'
                                : 'All lessons',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryBlue,
                            side: BorderSide(
                              color: AppColors.primaryBlue.withValues(alpha: 0.4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Player                                                                     */
/* -------------------------------------------------------------------------- */

class _Player extends ConsumerStatefulWidget {
  const _Player({required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<_Player> createState() => _PlayerState();
}

class _PlayerState extends ConsumerState<_Player> {
  VideoPlayerController? _mp4Controller;
  ChewieController? _chewieController;
  YoutubePlayerController? _ytController;
  bool _initialising = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final lesson = widget.lesson;
    try {
      if (lesson.videoType == 'youtube' &&
          (lesson.videoId?.isNotEmpty ?? false)) {
        _ytController = YoutubePlayerController.fromVideoId(
          videoId: lesson.videoId!,
          autoPlay: false,
          params: const YoutubePlayerParams(
            mute: false,
            enableCaption: true,
          ),
        );
      } else if ((lesson.videoUrl?.isNotEmpty ?? false)) {
        final controller =
            VideoPlayerController.networkUrl(Uri.parse(lesson.videoUrl!));
        await controller.initialize();
        _mp4Controller = controller;
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: false,
          looping: false,
          allowPlaybackSpeedChanging: true,
          showControls: true,
          additionalOptions: (context) => [
            OptionItem(
              onTap: (ctx) => Navigator.pop(ctx),
              iconData: Icons.closed_caption_rounded,
              title: 'Captions',
            ),
          ],
        );
        controller.addListener(_onProgress);
      } else {
        _error = 'no_video';
      }
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _initialising = false);
    }
  }

  void _onProgress() {
    final c = _mp4Controller;
    if (c == null || !c.value.isInitialized) return;
    final duration = c.value.duration.inMilliseconds;
    if (duration <= 0) return;
    final pct = (c.value.position.inMilliseconds / duration * 100)
        .clamp(0, 100)
        .round();
    // Sync roughly every 10% to avoid hammering the API.
    if (pct % 10 == 0 && pct != _lastReported) {
      _lastReported = pct;
      _report(pct);
    }
  }

  int _lastReported = -1;

  Future<void> _report(int pct) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.postJson(
        '/api/progress',
        {'lesson_id': widget.lesson.id, 'percent': pct},
        requireAuth: true,
      );
    } catch (_) {
      // best effort
    }
  }

  @override
  void dispose() {
    _mp4Controller?.removeListener(_onProgress);
    _mp4Controller?.dispose();
    _chewieController?.dispose();
    _ytController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialising) {
      return Container(
        width: double.infinity,
        height: 232,
        color: const Color(0xFF0F1220),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_error == 'no_video') {
      return Container(
        width: double.infinity,
        height: 210,
        decoration: const BoxDecoration(
          gradient: AppGradients.nightSky,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded, size: 46, color: Colors.white70),
            const SizedBox(height: 12),
            const Text(
              'Reading lesson',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This lesson is text based — study the notes below and mark it complete when ready.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        width: double.infinity,
        height: 210,
        decoration: const BoxDecoration(
          gradient: AppGradients.nightSky,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 42, color: Colors.white70),
            const SizedBox(height: 10),
            const Text(
              'Video unavailable right now',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _initialising = true;
                  _error = null;
                });
                _setup();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.nightSky,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (_ytController != null)
            SizedBox(
              width: double.infinity,
              child: YoutubePlayer(controller: _ytController!),
            )
          else if (_chewieController != null)
            SizedBox(
              width: double.infinity,
              height: 232,
              child: Chewie(controller: _chewieController!),
            ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */

class _Objectives extends StatelessWidget {
  const _Objectives({required this.objectives});

  final List<String> objectives;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentPurple.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.track_changes_rounded,
                    color: AppColors.accentPurple, size: 19),
              ),
              const SizedBox(width: 10),
              Text(
                'Learning objectives',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...objectives.map(
            (o) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      o,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: isDark
                            ? AppColors.textOnDark.withValues(alpha: 0.85)
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Unused helper kept for the objective decoder (defensive JSON parsing).
List<String> decodeObjectives(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.map((e) => '$e').toList();
  } catch (_) {}
  return [raw];
}
