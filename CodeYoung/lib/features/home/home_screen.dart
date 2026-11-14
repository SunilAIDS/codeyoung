import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/banner_carousel.dart';
import '../../core/widgets/common.dart';

/// First screen of the app.
///
/// Explains what Codeyoung is, introduces both co-founders with their quotes,
/// and routes into the rest of the product through premium banners and
/// content rails.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    final about = ref.watch(aboutProvider);
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: const AppHeader(),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeFeedProvider);
            ref.invalidate(aboutProvider);
            await ref.read(homeFeedProvider.future);
          },
          child: feed.when(
            loading: () => const _HomeSkeleton(),
            error: (e, _) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 40),
              child: ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(homeFeedProvider),
              ),
            ),
            data: (data) => _HomeBody(
              feed: data,
              about: about,
              userName: user?.name,
              onSeeAllCourses: () => context.go('/courses'),
              onSeeAllVideos: () => context.push('/videos'),
              onSeeAllGallery: () => context.push('/gallery'),
              onOpenCourse: (slug) => context.push('/courses/$slug'),
              onOpenVideo: (id) => context.push('/videos/$id'),
              onBanner: (b) {
                final route = b.ctaRoute;
                if (route == null) return;
                if (route.startsWith('/home') ||
                    route.startsWith('/about') ||
                    route.startsWith('/courses') ||
                    route.startsWith('/chat') ||
                    route.startsWith('/account')) {
                  context.go(route);
                } else {
                  context.push(route);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.feed,
    required this.about,
    required this.userName,
    required this.onSeeAllCourses,
    required this.onSeeAllVideos,
    required this.onSeeAllGallery,
    required this.onOpenCourse,
    required this.onOpenVideo,
    required this.onBanner,
  });

  final HomeFeed feed;
  final AsyncValue<AboutInfo> about;
  final String? userName;
  final VoidCallback onSeeAllCourses;
  final VoidCallback onSeeAllVideos;
  final VoidCallback onSeeAllGallery;
  final void Function(String slug) onOpenCourse;
  final void Function(int id) onOpenVideo;
  final void Function(PromoBanner banner) onBanner;

  @override
  Widget build(BuildContext context) {
    final founders = about.valueOrNull?.founders ?? const <Founder>[];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _GreetingBar(userName: userName),
        const SizedBox(height: 4),

        // --- Hero -------------------------------------------------------
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _HeroCard(stats: feed.stats),
        ),
        const SizedBox(height: 22),

        // --- Promo banners ---------------------------------------------
        if (feed.banners.isNotEmpty) ...[
          BannerCarousel(
            banners: feed.banners,
            onTapCta: onBanner,
          ),
          const SizedBox(height: 26),
        ],

        // --- What is Codeyoung + founders ------------------------------
        _StorySection(founders: founders, about: about),
        const SizedBox(height: 26),

        // --- Quick actions ---------------------------------------------
        const _QuickActions(),
        const SizedBox(height: 26),

        // --- Categories -------------------------------------------------
        if (feed.categories.isNotEmpty) ...[
          const SectionHeader(title: 'Explore subjects', subtitle: 'Pick a track and start today'),
          _CategoryWrap(categories: feed.categories, onSelected: onSeeAllCourses),
          const SizedBox(height: 26),
        ],

        // --- Featured courses ------------------------------------------
        if (feed.featuredCourses.isNotEmpty) ...[
          SectionHeader(
            title: 'Featured courses',
            subtitle: '1:1 live, mentor led',
            actionLabel: 'See all',
            onAction: onSeeAllCourses,
          ),
          _CourseRail(courses: feed.featuredCourses, onOpen: onOpenCourse),
          const SizedBox(height: 26),
        ],

        // --- Featured videos -------------------------------------------
        if (feed.featuredVideos.isNotEmpty) ...[
          SectionHeader(
            title: 'Watch & learn',
            subtitle: 'Free video lessons',
            actionLabel: 'See all',
            onAction: onSeeAllVideos,
          ),
          _VideoRail(videos: feed.featuredVideos, onOpen: onOpenVideo),
          const SizedBox(height: 26),
        ],

        // --- Gallery preview -------------------------------------------
        if (feed.galleryPreview.isNotEmpty) ...[
          SectionHeader(
            title: 'Life at Codeyoung',
            subtitle: 'Classrooms, projects and wins',
            actionLabel: 'Gallery',
            onAction: onSeeAllGallery,
          ),
          _GalleryRail(images: feed.galleryPreview),
          const SizedBox(height: 26),
        ],

        // --- Mentor CTA -------------------------------------------------
        const _MentorCta(),
      ],
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Greeting                                                                   */
/* -------------------------------------------------------------------------- */

class _GreetingBar extends StatelessWidget {
  const _GreetingBar({this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final firstName = (userName ?? '').trim().split(RegExp(r'\s+')).first;
    final showName = firstName.isNotEmpty && firstName != 'CodeYoung';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? AppColors.textOnDark.withValues(alpha: 0.65)
                        : AppColors.textSecondary,
                  ),
                ),
                Text(
                  showName ? firstName : 'Welcome back',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.go('/chat'),
            tooltip: 'Ask your mentor',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryBlue.withValues(alpha: isDark ? 0.28 : 0.12),
              foregroundColor: AppColors.primaryBlue,
            ),
            icon: const Icon(Icons.smart_toy_rounded, size: 22),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => context.go('/about'),
            tooltip: 'About Codeyoung',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accentGold.withValues(alpha: 0.18),
              foregroundColor: const Color(0xFFB8860B),
            ),
            icon: const Icon(Icons.favorite_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Hero                                                                       */
/* -------------------------------------------------------------------------- */

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final students = (stats['students'] as num?)?.toInt() ?? 20000;
    final parents = (stats['parents'] as num?)?.toInt() ?? 50000;
    final rating = (stats['rating'] as num?)?.toDouble() ?? 4.5;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -60,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Learn to Code.\nBuild the Future.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'One child. One mentor. Real attention. Clear progress.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _Stat(value: formatCount(students), label: 'students'),
                  _divider(),
                  _Stat(value: formatCount(parents), label: 'parents'),
                  _divider(),
                  _Stat(value: rating.toStringAsFixed(1), label: 'rating', star: true),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 550.ms).slide(begin: const Offset(0, 0.06));
  }

  Widget _divider() => Container(
        width: 1,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.white.withValues(alpha: 0.28),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.star = false});

  final String value;
  final String label;
  final bool star;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            if (star) ...[
              const SizedBox(width: 3),
              const Icon(Icons.star_rounded, color: AppColors.accentGold, size: 16),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Story + founders                                                           */
/* -------------------------------------------------------------------------- */

class _StorySection extends StatelessWidget {
  const _StorySection({required this.founders, required this.about});

  final List<Founder> founders;
  final AsyncValue<AboutInfo> about;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final company = about.valueOrNull?.company ?? const <String, dynamic>{};
    final mission = '${company['mission'] ?? ''}';
    final founded = company['founded'] ?? 2019;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'What is Codeyoung?',
          subtitle: 'Our story, in brief',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'SINCE 2019',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accentPurple.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'IIT DELHI FOUNDED',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.accentPurple,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  mission.isNotEmpty
                      ? mission
                      : 'Kids of today are the innovators of tomorrow. We empower them through effective and simplified education to unlock their learning potential.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.6,
                    color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    _MiniFact(icon: Icons.groups_rounded, label: '20K+ students', color: AppColors.primaryBlue),
                    SizedBox(width: 14),
                    _MiniFact(icon: Icons.verified_rounded, label: 'STEM accredited', color: AppColors.accentOrange),
                    SizedBox(width: 14),
                    _MiniFact(icon: Icons.public_rounded, label: 'Global', color: AppColors.accentCyan),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Founded $founded • Smart Owl Education Pvt Ltd',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.textOnDark.withValues(alpha: 0.55)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- Founders ---------------------------------------------------
        if (founders.isNotEmpty) ...[
          const SizedBox(height: 22),
          const SectionHeader(
            title: 'Meet the founders',
            subtitle: 'The vision behind Codeyoung',
          ),
          SizedBox(
            height: 262,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: founders.length,
              itemBuilder: (context, i) => _FounderCard(founder: founders[i], delay: i * 120),
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniFact extends StatelessWidget {
  const _MiniFact({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textOnDark.withValues(alpha: 0.85)
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _FounderCard extends StatelessWidget {
  const _FounderCard({required this.founder, this.delay = 0});

  final Founder founder;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 290,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: RemoteImage(
                  url: founder.photo,
                  fit: BoxFit.cover,
                  errorIcon: Icons.person_rounded,
                  memCacheWidth: 200,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      founder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      founder.role,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.school_rounded, size: 14, color: AppColors.accentOrange),
                        const SizedBox(width: 4),
                        Text(
                          founder.almaMater,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.textOnDark.withValues(alpha: 0.7)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.14 : 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, size: 20, color: AppColors.primaryBlue),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      founder.quote,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: delay.ms)
        .slide(begin: const Offset(0.12, 0));
  }
}

/* -------------------------------------------------------------------------- */
/* Quick actions                                                              */
/* -------------------------------------------------------------------------- */

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <_Action>[
      const _Action(Icons.play_circle_rounded, 'Videos', 'Free lessons', AppColors.primaryBlue, '/videos'),
      const _Action(Icons.menu_book_rounded, 'Lessons', 'Track progress', AppColors.accentGreen, '/lessons'),
      const _Action(Icons.photo_library_rounded, 'Gallery', 'Projects & more', AppColors.accentOrange, '/gallery'),
      const _Action(Icons.smart_toy_rounded, 'Mentor', 'Ask anything', AppColors.accentPurple, '/chat'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Start learning', subtitle: 'Everything in one tap'),
          LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth > 560;
              // Narrow phones: 2 columns laid out horizontally (icon + text side
              // by side). 4 tall columns at ratio 1.05 only gave ~73px of height
              // while the content needs ~90px, which triggered a RenderFlex
              // overflow. Two wide rows fit comfortably.
              final crossAxis = isWide ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxis,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 2.1 : 2.0,
                children: actions
                    .map(
                      (a) => _ActionCard(
                        action: a,
                        horizontal: true,
                        onTap: () {
                          if (a.route.startsWith('/home') ||
                              a.route.startsWith('/about') ||
                              a.route.startsWith('/courses') ||
                              a.route.startsWith('/chat') ||
                              a.route.startsWith('/account')) {
                            context.go(a.route);
                          } else {
                            context.push(a.route);
                          }
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Action {
  const _Action(this.icon, this.label, this.subtitle, this.color, this.route);

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String route;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.onTap, this.horizontal = false});

  final _Action action;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = horizontal
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _iconBox(isDark),
              const SizedBox(width: 12),
              _labels(isDark),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _iconBox(isDark),
              const SizedBox(height: 10),
              _labels(isDark, center: true),
            ],
          );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Center(child: content)),
      ),
    );
  }

  Widget _iconBox(bool isDark) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: action.color.withValues(alpha: isDark ? 0.26 : 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(action.icon, color: action.color, size: 25),
      );

  Widget _labels(bool isDark, {bool center = false}) => Column(
        crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            action.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            action.subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.textOnDark.withValues(alpha: 0.6) : AppColors.textSecondary,
            ),
          ),
        ],
      );
}

/* -------------------------------------------------------------------------- */
/* Categories                                                                 */
/* -------------------------------------------------------------------------- */

class _CategoryWrap extends StatelessWidget {
  const _CategoryWrap({required this.categories, required this.onSelected});

  final List<String> categories;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = [
      AppColors.primaryBlue,
      AppColors.accentOrange,
      AppColors.accentGreen,
      AppColors.accentPurple,
      AppColors.accentPink,
      AppColors.accentCyan,
      const Color(0xFF7B61FF),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(categories.length, (i) {
          final color = palette[i % palette.length];
          final icon = switch (categories[i].toLowerCase()) {
            'coding' => Icons.code_rounded,
            'math' => Icons.calculate_rounded,
            'english' => Icons.menu_book_rounded,
            'science' => Icons.science_rounded,
            'robotics' => Icons.smart_toy_rounded,
            _ => Icons.school_rounded,
          };
          return InkWell(
            onTap: onSelected,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 7),
                  Text(
                    categories[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Rails                                                                      */
/* -------------------------------------------------------------------------- */

class _CourseRail extends StatelessWidget {
  const _CourseRail({required this.courses, required this.onOpen});

  final List<Course> courses;
  final void Function(String slug) onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 236,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: courses.length,
        itemBuilder: (context, i) {
          final c = courses[i];
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final color = Color(int.tryParse((c.color ?? '#1E88E5').replaceAll('#', 'FF')) ??
              0xFF1E88E5);

          return Container(
            width: 244,
            margin: const EdgeInsets.only(right: 14),
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
                onTap: () => onOpen(c.slug),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 116,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RemoteImage(url: c.imageUrl, memCacheWidth: 520),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            top: 10,
                            child: LevelChip(label: c.level),
                          ),
                          if (c.progressPercent > 0)
                            Positioned(
                              left: 10,
                              right: 10,
                              bottom: 9,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: c.progressPercent / 100,
                                  minHeight: 5,
                                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.subtitle ?? c.description ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: isDark
                                  ? AppColors.textOnDark.withValues(alpha: 0.65)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Icon(Icons.play_circle_fill_rounded, size: 15, color: color),
                              const SizedBox(width: 5),
                              Text(
                                '${c.lessonsCount} lessons',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textOnDark.withValues(alpha: 0.75)
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              if (c.price != null)
                                Text(
                                  '\$${c.price!.toStringAsFixed(0)}/class',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accentGreen,
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
          );
        },
      ),
    );
  }
}

class _VideoRail extends StatelessWidget {
  const _VideoRail({required this.videos, required this.onOpen});

  final List<VideoItem> videos;
  final void Function(int id) onOpen;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      // Image (116) + padding (24) + 2-line title (~35) + gap (5) + chip row (~24)
      // + a little breathing room. Was 178, which overflowed on 2-line titles.
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: videos.length,
        itemBuilder: (context, i) {
          final v = videos[i];
          return Container(
            width: 236,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
              borderRadius: BorderRadius.circular(20),
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
                onTap: () => onOpen(v.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 116,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RemoteImage(url: v.thumb, memCacheWidth: 520),
                          const Center(
                            child: _PlayBadge(),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                v.duration ?? '',
                                style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              LevelChip(label: v.category),
                              const Spacer(),
                              Text(
                                v.viewsLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.textOnDark.withValues(alpha: 0.6)
                                      : AppColors.textSecondary,
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
          );
        },
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
    );
  }
}

class _GalleryRail extends StatelessWidget {
  const _GalleryRail({required this.images});

  final List<GalleryImage> images;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: images.length,
        itemBuilder: (context, i) {
          final img = images[i];
          return Container(
            width: 178,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RemoteImage(url: img.url, memCacheWidth: 420),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 20, 10, 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withValues(alpha: 0.82), Colors.transparent],
                      ),
                    ),
                    child: Text(
                      img.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Mentor CTA                                                                 */
/* -------------------------------------------------------------------------- */

class _MentorCta extends StatelessWidget {
  const _MentorCta();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppGradients.grape,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8E2DE2).withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ask your AI mentor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live internet answers, read aloud in your voice.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => context.go('/chat'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6A11CB),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('Open', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Loading skeleton                                                           */
/* -------------------------------------------------------------------------- */

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.bgDarkCard : const Color(0xFFE9EEF6);
    final highlight = isDark ? const Color(0xFF2A2A42) : const Color(0xFFF5F8FD);

    Widget box(double h, double w, {double radius = 18}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, highlight, base],
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        box(34, 160, radius: 10),
        const SizedBox(height: 16),
        box(210, double.infinity, radius: 26),
        const SizedBox(height: 22),
        box(190, double.infinity),
        const SizedBox(height: 22),
        box(24, 180, radius: 8),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: box(104, 0, radius: 20)),
          const SizedBox(width: 12),
          Expanded(child: box(104, 0, radius: 20)),
          const SizedBox(width: 12),
          Expanded(child: box(104, 0, radius: 20)),
        ]),
      ],
    );
  }
}
