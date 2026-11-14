import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/common.dart';

/// Videos tab — grid of playable video lessons with working thumbnails.
class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({super.key});

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen> {
  String _query = '';
  String _category = 'All';
  String _level = 'All';
  bool _grid = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(videosProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: const AppHeader(showBack: true),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Video Lessons',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.7,
                                color: isDark
                                    ? AppColors.textOnDark
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Free to watch, streamed live from the app',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textOnDark.withValues(alpha: 0.65)
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _grid ? 'List view' : 'Grid view',
                        onPressed: () => setState(() => _grid = !_grid),
                        icon: Icon(
                          _grid ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search videos...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textOnDark.withValues(alpha: 0.45)
                              : AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.primaryBlue),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded, size: 20),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      style: TextStyle(
                        fontSize: 14.5,
                        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: videos.when(
                loading: () => const LoadingState(label: 'Loading videos...'),
                error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(videosProvider),
                ),
                data: (all) {
                  final categories = <String>{'All', ...all.map((v) => v.category)}.toList();
                  final levels = <String>{'All', ...all.map((v) => v.level)}.toList();

                  final q = _query.trim().toLowerCase();
                  final filtered = all.where((v) {
                    final mq = q.isEmpty ||
                        v.title.toLowerCase().contains(q) ||
                        (v.description?.toLowerCase().contains(q) ?? false) ||
                        v.category.toLowerCase().contains(q);
                    final mc = _category == 'All' || v.category == _category;
                    final ml = _level == 'All' || v.level == _level;
                    return mq && mc && ml;
                  }).toList();

                  return Column(
                    children: [
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: categories.length,
                          itemBuilder: (context, i) {
                            final c = categories[i];
                            final selected = c == _category;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _Chip(
                                label: c,
                                selected: selected,
                                onTap: () => setState(() => _category = c),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                          itemCount: levels.length,
                          itemBuilder: (context, i) {
                            final l = levels[i];
                            final selected = l == _level;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _Chip(
                                label: l,
                                small: true,
                                selected: selected,
                                onTap: () => setState(() => _level = l),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              '${filtered.length} video${filtered.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textOnDark.withValues(alpha: 0.7)
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            if (_query.isNotEmpty || _category != 'All' || _level != 'All')
                              TextButton.icon(
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {
                                    _query = '';
                                    _category = 'All';
                                    _level = 'All';
                                  });
                                },
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Clear', style: TextStyle(fontSize: 13)),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryBlue,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async => ref.invalidate(videosProvider),
                          child: filtered.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 50),
                                    EmptyState(
                                      icon: Icons.videocam_off_rounded,
                                      title: 'No videos found',
                                      subtitle:
                                          'Try a different search or clear the filters.',
                                    ),
                                  ],
                                )
                              : _grid
                                  ? GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 0.86,
                                      ),
                                      itemCount: filtered.length,
                                      itemBuilder: (context, i) => _VideoTile(
                                        video: filtered[i],
                                        index: i,
                                        compact: true,
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      itemCount: filtered.length,
                                      itemBuilder: (context, i) => _VideoTile(
                                        video: filtered[i],
                                        index: i,
                                      ),
                                    ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.small = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: 220.ms,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryBlue
            : (isDark ? AppColors.bgDarkCard : AppColors.bgWhite),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? AppColors.primaryBlue
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.07)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: small ? 13 : 15, vertical: small ? 7 : 9),
            child: Text(
              label,
              style: TextStyle(
                fontSize: small ? 12.5 : 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color:
                    selected ? Colors.white : (isDark ? AppColors.textOnDark : AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.video, required this.index, this.compact = false});

  final dynamic video;
  final int index;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final thumbnail = Padding(
      padding: EdgeInsets.all(compact ? 0 : 14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 16 : 14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RemoteImage(
                url: video.thumb,
                memCacheWidth: compact ? 480 : 720,
                errorIcon: Icons.play_circle_fill_rounded,
              ),
              const Center(child: _PlayCircle()),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${video.duration ?? ''}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: LevelChip(label: '${video.level}'),
              ),
            ],
          ),
        ),
      ),
    );

    final meta = compact
        ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${video.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.remove_red_eye_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        video.viewsLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.textOnDark.withValues(alpha: 0.6)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${video.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${video.description ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: isDark
                        ? AppColors.textOnDark.withValues(alpha: 0.68)
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    LevelChip(label: '${video.category}'),
                    const SizedBox(width: 8),
                    const Icon(Icons.remove_red_eye_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      video.viewsLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textOnDark.withValues(alpha: 0.6)
                            : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.play_circle_fill_rounded,
                        size: 22, color: AppColors.primaryBlue),
                  ],
                ),
              ],
            ),
          );

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
          borderRadius: BorderRadius.circular(compact ? 16 : 20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/videos/${video.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                thumbnail,
                meta,
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: Duration(milliseconds: (index * 50).clamp(0, 400)))
        .slide(begin: const Offset(0, 0.05));
  }
}

class _PlayCircle extends StatelessWidget {
  const _PlayCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
    );
  }
}
