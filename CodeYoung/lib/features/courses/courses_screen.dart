import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/common.dart';

/// Courses tab — searchable, filterable catalogue served by the API.
class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  String _query = '';
  String _category = 'All';
  String _level = 'All';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _query = '';
      _category = 'All';
      _level = 'All';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: const AppHeader(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(
              controller: _searchController,
              onQuery: (v) => setState(() => _query = v),
              query: _query,
            ),
            courses.when(
              loading: () => const Expanded(child: LoadingState(label: 'Loading courses...')),
              error: (e, _) => Expanded(
                child: ErrorState(message: e.toString(), onRetry: () => ref.invalidate(coursesProvider)),
              ),
              data: (all) {
                final categories = <String>{
                  'All',
                  ...all.map((c) => c.category),
                }.toList();
                final levels = <String>{
                  'All',
                  ...all.map((c) => c.level),
                }.toList();

                final q = _query.trim().toLowerCase();
                final filtered = all.where((c) {
                  final matchesQuery = q.isEmpty ||
                      c.title.toLowerCase().contains(q) ||
                      (c.subtitle?.toLowerCase().contains(q) ?? false) ||
                      (c.description?.toLowerCase().contains(q) ?? false) ||
                      c.category.toLowerCase().contains(q);
                  final matchesCat = _category == 'All' || c.category == _category;
                  final matchesLevel = _level == 'All' || c.level == _level;
                  return matchesQuery && matchesCat && matchesLevel;
                }).toList();

                return Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => ref.invalidate(coursesProvider),
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 28),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _FilterBar(
                          categories: categories,
                          levels: levels,
                          selectedCategory: _category,
                          selectedLevel: _level,
                          onCategory: (v) => setState(() => _category = v),
                          onLevel: (v) => setState(() => _level = v),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                          child: Row(
                            children: [
                              Text(
                                '${filtered.length} course${filtered.length == 1 ? '' : 's'}',
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
                                  onPressed: _clearFilters,
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
                        if (filtered.isEmpty)
                          EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No courses found',
                            subtitle: 'Try a different search term or clear the filters.',
                            actionLabel: 'Clear filters',
                            onAction: _clearFilters,
                          )
                        else
                          ...filtered.asMap().entries.map(
                                (e) => _CourseCard(course: e.value, index: e.key),
                              ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onQuery, required this.query});

  final TextEditingController controller;
  final ValueChanged<String> onQuery;
  final String query;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
                      'Courses',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '1:1 live, mentor led, mastery based',
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
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.28 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  onPressed: () => context.push('/lessons'),
                  tooltip: 'My lessons',
                  icon: const Icon(Icons.assignment_turned_in_rounded,
                      color: AppColors.primaryBlue, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              onChanged: onQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search courses, subjects, skills...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textOnDark.withValues(alpha: 0.45) : AppColors.textSecondary,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          controller.clear();
                          onQuery('');
                        },
                        icon: const Icon(Icons.close_rounded, size: 20),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              style: TextStyle(
                fontSize: 14.5,
                color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.categories,
    required this.levels,
    required this.selectedCategory,
    required this.selectedLevel,
    required this.onCategory,
    required this.onLevel,
  });

  final List<String> categories;
  final List<String> levels;
  final String selectedCategory;
  final String selectedLevel;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onLevel;

  @override
  Widget build(BuildContext context) {
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
              final selected = c == selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Pill(
                  label: c,
                  selected: selected,
                  onTap: () => onCategory(c),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: levels.length,
            itemBuilder: (context, i) {
              final l = levels[i];
              final selected = l == selectedLevel;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Pill(
                  label: l,
                  small: true,
                  selected: selected,
                  onTap: () => onLevel(l),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
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
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryBlue
            : (isDark ? AppColors.bgDarkCard : AppColors.bgWhite),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? AppColors.primaryBlue
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07)),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
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
                color: selected
                    ? Colors.white
                    : (isDark ? AppColors.textOnDark : AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.index});

  final Course course;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Color(
      int.tryParse((course.color ?? '#1E88E5').replaceAll('#', 'FF')) ?? 0xFF1E88E5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/courses/${course.slug}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 148,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RemoteImage(url: course.imageUrl, memCacheWidth: 700),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                            stops: const [0.4, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: LevelChip(label: course.level),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            course.category,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Row(
                          children: [
                            const Icon(Icons.play_circle_fill_rounded,
                                color: Colors.white, size: 17),
                            const SizedBox(width: 6),
                            Text(
                              '${course.lessonsCount} lessons',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (course.duration != null)
                              Text(
                                course.duration!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (course.progressPercent > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(22),
                            ),
                            child: LinearProgressIndicator(
                              value: course.progressPercent / 100,
                              minHeight: 5,
                              backgroundColor: Colors.white.withValues(alpha: 0.25),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              course.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (course.price != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '\$${course.price!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (course.subtitle != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          course.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      Text(
                        course.description ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: isDark
                              ? AppColors.textOnDark.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (course.ageGroup != null) ...[
                            const Icon(Icons.child_care_rounded,
                                size: 15, color: AppColors.accentOrange),
                            const SizedBox(width: 5),
                            Text(
                              course.ageGroup!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textOnDark.withValues(alpha: 0.75)
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                          const Icon(Icons.verified_rounded,
                              size: 15, color: AppColors.accentGreen),
                          const SizedBox(width: 5),
                          Text(
                            'Certificate',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textOnDark.withValues(alpha: 0.75)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Enroll',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded,
                                    size: 14, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 450.ms, delay: Duration(milliseconds: (index * 60).clamp(0, 400)))
        .slide(begin: const Offset(0, 0.05));
  }
}
