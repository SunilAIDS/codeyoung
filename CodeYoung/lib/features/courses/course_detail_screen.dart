import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/common.dart';

/// Single course: hero, description, objectives and the full lesson list.
class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(courseDetailProvider(slug));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Column(
        children: [
          const AppHeader(showBack: true, subtitle: 'Course'),
          Expanded(
            child: detail.when(
              loading: () => const LoadingState(label: 'Loading course...'),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(courseDetailProvider(slug)),
              ),
              data: (course) {
                final color = Color(
                  int.tryParse((course.color ?? '#1E88E5').replaceAll('#', 'FF')) ??
                      0xFF1E88E5,
                );

                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 250,
                      pinned: true,
                      stretch: true,
                      automaticallyImplyLeading: false,
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      RemoteImage(url: course.imageUrl, memCacheWidth: 900),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.72),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                LevelChip(label: course.level),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
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
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              course.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1.15,
                              ),
                            ),
                            if (course.subtitle != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                course.subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Facts grid -------------------------------------
                      Row(
                        children: [
                          _Fact(
                            icon: Icons.menu_book_rounded,
                            value: '${course.lessonsCount}',
                            label: 'Lessons',
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 10),
                          _Fact(
                            icon: Icons.schedule_rounded,
                            value: course.duration ?? '—',
                            label: 'Duration',
                            color: AppColors.accentOrange,
                          ),
                          const SizedBox(width: 10),
                          _Fact(
                            icon: Icons.child_care_rounded,
                            value: course.ageGroup ?? 'All',
                            label: 'Ages',
                            color: AppColors.accentPurple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // --- Progress ---------------------------------------
                      if (course.lessonsCount > 0) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
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
                                  Text(
                                    'Your progress',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.textOnDark
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${course.completedCount}/${course.lessonsCount} done',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: course.lessonsCount > 0
                                      ? course.completedCount / course.lessonsCount
                                      : 0,
                                  minHeight: 9,
                                  backgroundColor: AppColors.primaryBlue
                                      .withValues(alpha: 0.14),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(color),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${course.progressPercent}% complete — keep going!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textOnDark.withValues(alpha: 0.65)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // --- Description ------------------------------------
                      if (course.description != null &&
                          course.description!.isNotEmpty) ...[
                        Text(
                          'About this course',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          course.description!,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.65,
                            color: isDark
                                ? AppColors.textOnDark.withValues(alpha: 0.8)
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // --- What you'll learn ------------------------------
                      const _LearnCard(),
                      const SizedBox(height: 18),

                      // --- Lessons ----------------------------------------
                      Row(
                        children: [
                          Text(
                            'Lessons',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${course.lessons.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (course.lessons.isNotEmpty)
                            TextButton(
                              onPressed: () => context.push('/lessons'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryBlue,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Track all',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              if (course.lessons.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: EmptyState(
                      icon: Icons.menu_book_rounded,
                      title: 'Lessons coming soon',
                      subtitle: 'We are finalising the syllabus for this course.',
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _LessonRow(
                      index: i,
                      lesson: course.lessons[i],
                      color: color,
                    ),
                    childCount: course.lessons.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: detail.valueOrNull == null
          ? null
          : _EnrollBar(
              price: detail.valueOrNull!.price,
              color: colorFor(detail.valueOrNull!.color),
              onEnroll: () {
                showAppSnackBar(
                  context,
                  'Great choice! Our team will reach out to schedule your FREE trial class.',
                );
              },
            ),
    );
  }

  Color colorFor(String? hex) => Color(
        int.tryParse((hex ?? '#1E88E5').replaceAll('#', 'FF')) ?? 0xFF1E88E5,
      );
}

/* -------------------------------------------------------------------------- */

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.textOnDark.withValues(alpha: 0.6)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearnCard extends StatelessWidget {
  const _LearnCard();

  static const bullets = [
    'Core concepts explained with worked examples',
    'Guided, hands-on practice after every topic',
    'A mini-project that applies what you learned',
    'One-to-one feedback from an experienced mentor',
    'A certificate when you complete the course',
  ];

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
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What you'll learn",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 13, color: AppColors.accentGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
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

/* -------------------------------------------------------------------------- */

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.index,
    required this.lesson,
    required this.color,
  });

  final int index;
  final dynamic lesson;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = lesson.completed == true;
    final percent = (lesson.percent as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: completed
                ? AppColors.accentGreen.withValues(alpha: 0.4)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/lessons/${lesson.id}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: completed
                          ? AppColors.accentGreen.withValues(alpha: 0.16)
                          : color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: completed
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.accentGreen, size: 22)
                        : Text(
                            '${index + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 42 / 16,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '${lesson.duration ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textOnDark.withValues(alpha: 0.6)
                                    : AppColors.textSecondary,
                              ),
                            ),
                            if (lesson.hasVideo == true) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.play_circle_fill_rounded,
                                  size: 13, color: AppColors.primaryBlue),
                              const SizedBox(width: 4),
                              Text(
                                lesson.videoType == 'youtube' ? 'Video' : 'Clip',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (percent > 0 && !completed) ...[
                          const SizedBox(height: 8),
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
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark
                        ? AppColors.textOnDark.withValues(alpha: 0.45)
                        : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms, delay: Duration(milliseconds: (index * 45).clamp(0, 350)));
  }
}

/* -------------------------------------------------------------------------- */

class _EnrollBar extends StatelessWidget {
  const _EnrollBar({required this.price, required this.color, required this.onEnroll});

  final double? price;
  final Color color;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkSurface : AppColors.bgWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  price != null ? '\$${price!.toStringAsFixed(0)}' : 'Free',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                  ),
                ),
                Text(
                  price != null ? 'per class · free trial first' : 'book a trial',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.textOnDark.withValues(alpha: 0.6)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GradientButton(
                label: 'Book FREE trial',
                icon: Icons.event_available_rounded,
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [color, color.withValues(alpha: 0.75)],
                ),
                height: 50,
                onPressed: onEnroll,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
