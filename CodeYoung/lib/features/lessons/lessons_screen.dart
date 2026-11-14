import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/common.dart';

/// Lessons tab — every lesson across all courses with filters and progress.
class LessonsScreen extends ConsumerStatefulWidget {
  const LessonsScreen({super.key});

  @override
  ConsumerState<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends ConsumerState<LessonsScreen> {
  String _query = '';
  String _category = 'All';
  String _sort = 'course';
  bool _showCompleted = true;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessons = ref.watch(lessonsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppHeader(
        showBack: true,
        subtitle: 'Lessons',
        actions: [
          IconButton(
            tooltip: 'Sort',
            onPressed: _showSortSheet,
            icon: const Icon(Icons.sort_rounded),
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: _showFilterSheet,
            icon: Badge(
              isLabelVisible: _category != 'All' || !_showCompleted,
              backgroundColor: AppColors.accentOrange,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: lessons.when(
        loading: () => const LoadingState(label: 'Loading lessons...'),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(lessonsProvider),
        ),
        data: (all) {
          final categories = <String>{'All', ...all.map((l) => l.category)}.toList();

          final q = _query.trim().toLowerCase();
          var filtered = all.where((l) {
            final matchesQuery = q.isEmpty ||
                l.title.toLowerCase().contains(q) ||
                (l.description?.toLowerCase().contains(q) ?? false) ||
                (l.courseTitle?.toLowerCase().contains(q) ?? false);
            final matchesCat = _category == 'All' || l.category == _category;
            final matchesDone = _showCompleted || !l.completed;
            return matchesQuery && matchesCat && matchesDone;
          }).toList();

          if (_sort == 'title') {
            filtered.sort((a, b) => a.title.compareTo(b.title));
          } else if (_sort == 'progress') {
            filtered.sort((a, b) => b.percent.compareTo(a.percent));
          }
          // 'course' keeps API order (course + lesson sort_order).

          final done = all.where((l) => l.completed).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Container(
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
                      hintText: 'Search lessons...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textOnDark.withValues(alpha: 0.45)
                            : AppColors.textSecondary,
                      ),
                      prefixIcon:
                          const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
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
              ),

              // Progress summary strip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: AppColors.accentGold, size: 26),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$done of ${all.length} lessons completed',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: all.isEmpty ? 0 : done / all.length,
                                minHeight: 6,
                                backgroundColor: Colors.white.withValues(alpha: 0.3),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 11),
                      Text(
                        all.isEmpty ? '0%' : '${((done / all.length) * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              if (categories.length > 1)
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
                        child: AnimatedContainer(
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
                              onTap: () => setState(() => _category = c),
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 9),
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight:
                                        selected ? FontWeight.w700 : FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.textOnDark
                                            : AppColors.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(lessonsProvider),
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 60),
                            EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No lessons match',
                              subtitle:
                                  'Try another search term, or clear the filters to see everything.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) =>
                              _LessonTile(lesson: filtered[i], index: i),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _Sheet(
        title: 'Sort lessons',
        children: [
          _OptionTile(
            icon: Icons.menu_book_rounded,
            label: 'Course order',
            selected: _sort == 'course',
            onTap: () {
              setState(() => _sort = 'course');
              Navigator.pop(sheetContext);
            },
          ),
          _OptionTile(
            icon: Icons.sort_by_alpha_rounded,
            label: 'Alphabetical',
            selected: _sort == 'title',
            onTap: () {
              setState(() => _sort = 'title');
              Navigator.pop(sheetContext);
            },
          ),
          _OptionTile(
            icon: Icons.trending_up_rounded,
            label: 'Most progress first',
            selected: _sort == 'progress',
            onTap: () {
              setState(() => _sort = 'progress');
              Navigator.pop(sheetContext);
            },
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _Sheet(
        title: 'Filters',
        children: [
          _OptionTile(
            icon: Icons.check_circle_rounded,
            label: 'Show completed lessons',
            trailing: Switch(
              value: _showCompleted,
              activeThumbColor: AppColors.primaryBlue,
              onChanged: (v) => setState(() => _showCompleted = v),
            ),
            onTap: () => setState(() => _showCompleted = !_showCompleted),
          ),
          _OptionTile(
            icon: Icons.filter_alt_off_rounded,
            label: 'Clear category filter',
            onTap: () {
              setState(() => _category = 'All');
              Navigator.pop(sheetContext);
            },
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkSurface : AppColors.bgWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon,
          color: selected ? AppColors.primaryBlue : AppColors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
        ),
      ),
      trailing: trailing ??
          (selected
              ? const Icon(Icons.check_rounded, color: AppColors.primaryBlue)
              : null),
      onTap: onTap,
    );
  }
}

/* -------------------------------------------------------------------------- */

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.index});

  final dynamic lesson;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = lesson.completed == true;
    final percent = (lesson.percent as num?)?.toInt() ?? 0;
    final color = Color(
      int.tryParse((lesson.courseColor as String? ?? '#1E88E5').replaceAll('#', 'FF')) ??
          0xFF1E88E5,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: completed
                ? AppColors.accentGreen.withValues(alpha: 0.42)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
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
            onTap: () => context.push('/lessons/${lesson.id}'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail — always renders something via RemoteImage.
                SizedBox(
                  width: 116,
                  height: 116,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RemoteImage(
                        url: lesson.thumbnailUrl,
                        memCacheWidth: 320,
                        errorIcon: Icons.school_rounded,
                      ),
                      if (lesson.hasVideo == true)
                        const Center(
                          child: _MiniPlay(),
                        ),
                      if (completed)
                        Positioned(
                          right: 7,
                          top: 7,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.accentGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded,
                                size: 13, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (lesson.courseTitle != null)
                          Text(
                            '${lesson.courseTitle}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                              letterSpacing: 0.2,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${lesson.title}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            LevelChip(label: lesson.category),
                            const SizedBox(width: 8),
                            const Icon(Icons.schedule_rounded,
                                size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '${lesson.duration ?? ''}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? AppColors.textOnDark.withValues(alpha: 0.6)
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (percent > 0) ...[
                          const SizedBox(height: 9),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: percent / 100,
                              minHeight: 5,
                              backgroundColor:
                                  AppColors.primaryBlue.withValues(alpha: 0.14),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            completed ? 'Completed' : '$percent% watched',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: completed
                                  ? AppColors.accentGreen
                                  : AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 44),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark
                        ? AppColors.textOnDark.withValues(alpha: 0.45)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 380.ms, delay: Duration(milliseconds: (index * 45).clamp(0, 400)))
        .slide(begin: const Offset(0, 0.04));
  }
}

class _MiniPlay extends StatelessWidget {
  const _MiniPlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.6),
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
    );
  }
}
