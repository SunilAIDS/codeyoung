import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/models/models.dart';
import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/common.dart';

/// Fetches one video and bumps the view counter server-side.
final videoDetailProvider = FutureProvider.autoDispose.family<VideoItem, int>((ref, id) async {
  final api = ref.watch(apiServiceProvider);
  final json = await api.getJson('/api/videos/$id');
  return VideoItem.fromJson(json);
});

/// Full-screen player for a video lesson. Supports YouTube ids and direct
/// MP4 sources, with a description panel underneath.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.videoId});

  final int videoId;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _mp4;
  ChewieController? _chewie;
  YoutubePlayerController? _yt;
  bool _initialising = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    setState(() {
      _initialising = true;
      _error = null;
    });

    try {
      // The detail call both resolves the source and counts the view.
      final video = await ref.read(videoDetailProvider(widget.videoId).future);

      if (video.videoType == 'youtube' && (video.videoId?.isNotEmpty ?? false)) {
        _yt = YoutubePlayerController.fromVideoId(
          videoId: video.videoId!,
          autoPlay: true,
          params: const YoutubePlayerParams(
            mute: false,
            enableCaption: true,
          ),
        );
      } else if (video.videoUrl?.isNotEmpty ?? false) {
        final c = VideoPlayerController.networkUrl(Uri.parse(video.videoUrl!));
        await c.initialize();
        _mp4 = c;
        _chewie = ChewieController(
          videoPlayerController: c,
          autoPlay: true,
          looping: false,
          allowPlaybackSpeedChanging: true,
          showControls: true,
        );
      } else {
        _error = 'no_source';
      }
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _initialising = false);
    }
  }

  @override
  void dispose() {
    _mp4?.dispose();
    _chewie?.dispose();
    _yt?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(videoDetailProvider(widget.videoId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: const AppHeader(showBack: true, subtitle: 'Video'),
      body: detail.when(
        loading: () => const LoadingState(label: 'Loading video...'),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(videoDetailProvider(widget.videoId)),
        ),
        data: (video) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stage(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            LevelChip(label: video.category),
                            const SizedBox(width: 8),
                            LevelChip(label: video.level),
                            const Spacer(),
                            const Icon(Icons.remove_red_eye_rounded,
                                size: 15, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Text(
                              video.viewsLabel,
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
                        const SizedBox(height: 12),
                        Text(
                          video.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.25,
                            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                          ),
                        ),
                        if (video.description != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            video.description!,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.65,
                              color: isDark
                                  ? AppColors.textOnDark.withValues(alpha: 0.82)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.accentOrange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(Icons.schedule_rounded,
                                    color: AppColors.accentOrange, size: 21),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      video.duration ?? 'Short lesson',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.textOnDark
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Watch at your own pace — progress saves automatically',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: isDark
                                            ? AppColors.textOnDark.withValues(alpha: 0.62)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: GradientButton(
                            label: 'More video lessons',
                            icon: Icons.video_library_rounded,
                            gradient: AppGradients.premium,
                            onPressed: () => context.pop(),
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

  Widget _stage() {
    if (_initialising) {
      return Container(
        width: double.infinity,
        height: 234,
        color: const Color(0xFF0F1220),
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null) {
      return Container(
        width: double.infinity,
        height: 234,
        decoration: const BoxDecoration(
          gradient: AppGradients.nightSky,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_rounded, size: 44, color: Colors.white70),
            const SizedBox(height: 10),
            const Text(
              'This video could not be loaded',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(onPressed: _setup, child: const Text('Retry')),
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
          if (_yt != null)
            SizedBox(
              width: double.infinity,
              child: YoutubePlayer(controller: _yt!),
            )
          else if (_chewie != null)
            SizedBox(width: double.infinity, height: 234, child: Chewie(controller: _chewie!)),
        ],
      ),
    );
  }
}

/// Convenience so `ref.listen` style rebuilds stay cheap.
final videoCountProvider = Provider<int>((ref) => 0);
