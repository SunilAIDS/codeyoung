import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/common.dart';

/// Account tab — premium profile, learning stats, achievements and settings.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to track progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final stats = ref.watch(statsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppHeader(
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            style: IconButton.styleFrom(
              foregroundColor:
                  isDark ? AppColors.textOnDark : AppColors.textSecondary,
            ),
            icon: const Icon(Icons.settings_outlined, size: 21),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(statsProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _ProfileHero(user: user),
              const SizedBox(height: 18),
              stats.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: LoadingState(label: 'Crunching your stats...'),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ErrorState(
                    compact: true,
                    message: (e is ApiException && e.isOffline)
                        ? 'The CodeYoung server is still waking up from idle.\n'
                            'It can take up to a minute — tap Try again in a moment.'
                        : "We couldn't load your progress. Please tap Try again.",
                    onRetry: () => ref.invalidate(statsProvider),
                  ),
                ),
                data: (s) => _StatsGrid(stats: s),
              ),
              const SizedBox(height: 20),
              const _PremiumCard(),
              const SizedBox(height: 20),
              stats.valueOrNull == null
                  ? const SizedBox.shrink()
                  : _Achievements(stats: stats.valueOrNull!),
              const SizedBox(height: 20),
              _MenuCard(
                children: [
                  _MenuItem(
                    icon: Icons.menu_book_rounded,
                    color: AppColors.primaryBlue,
                    label: 'My lessons',
                    subtitle: 'Continue where you left off',
                    onTap: () => context.push('/lessons'),
                  ),
                  _MenuItem(
                    icon: Icons.school_rounded,
                    color: AppColors.accentGreen,
                    label: 'Browse courses',
                    subtitle: 'All 1:1 live programmes',
                    onTap: () => context.go('/courses'),
                  ),
                  _MenuItem(
                    icon: Icons.photo_library_rounded,
                    color: AppColors.accentOrange,
                    label: 'Gallery',
                    subtitle: 'Projects and classroom moments',
                    onTap: () => context.push('/gallery'),
                  ),
                  _MenuItem(
                    icon: Icons.smart_toy_rounded,
                    color: AppColors.accentPurple,
                    label: 'AI Mentor',
                    subtitle: 'Ask anything, out loud',
                    onTap: () => context.go('/chat'),
                  ),
                  _MenuItem(
                    icon: Icons.favorite_rounded,
                    color: AppColors.accentPink,
                    label: 'About Codeyoung',
                    subtitle: 'Our story and founders',
                    onTap: () => context.go('/about'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MenuCard(
                children: [
                  _MenuItem(
                    icon: Icons.settings_rounded,
                    color: AppColors.textSecondary,
                    label: 'Settings',
                    subtitle: 'Theme, network, account',
                    onTap: () => context.push('/settings'),
                  ),
                  _MenuItem(
                    icon: Icons.logout_rounded,
                    color: AppColors.error,
                    label: 'Sign out',
                    onTap: () => _signOut(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Center(
                child: Text(
                  'CodeYoung • v1.0.0\nSmart Owl Education Pvt Ltd',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, height: 1.6, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Profile hero                                                               */
/* -------------------------------------------------------------------------- */

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'CodeYoung Learner';
    final email = user?.email ?? 'Sign in to sync progress';
    final initials = user?.initials ?? 'CY';
    final signedIn = user != null;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: signedIn ? AppGradients.primary : AppGradients.nightSky,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (signedIn ? AppColors.primaryBlue : const Color(0xFF1F2937))
                .withValues(alpha: 0.42),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -56,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            right: 60,
            bottom: -70,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (user?.isPremium == true) ...[
                              const SizedBox(width: 8),
                              const _PremiumBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            signedIn
                                ? '${user?.role == 'student' ? 'Student' : 'Member'} • Level ${user?.role == 'mentor' ? 'M' : '1'}'
                                : 'Not signed in',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: IconButton(
                      onPressed: signedIn
                          ? () => _showEditSheet(context)
                          : () => context.go('/login'),
                      tooltip: signedIn ? 'Edit profile' : 'Sign in',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(9),
                        minimumSize: const Size(36, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(signedIn ? Icons.edit_rounded : Icons.login_rounded, size: 18),
                    ),
                  ),
                ],
              ),
              if (!signedIn) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Sign in to track progress'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slide(begin: const Offset(0, 0.05));
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EditProfileSheet(),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: AppGradients.gold,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 13, color: Color(0xFF4A3200)),
          SizedBox(width: 4),
          Text(
            'PREMIUM',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF4A3200),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Stats                                                                      */
/* -------------------------------------------------------------------------- */

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(Icons.check_circle_rounded, '${stats.lessonsCompleted}',
          'Lessons done', AppColors.accentGreen),
      _StatItem(Icons.schedule_rounded, '${stats.hoursLearned}',
          'Hours learned', AppColors.primaryBlue),
      _StatItem(Icons.emoji_events_rounded, '${stats.projectsBuilt}',
          'Projects built', AppColors.accentOrange),
      _StatItem(Icons.local_fire_department_rounded, '${stats.streak}',
          'Day streak', AppColors.accentPink),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your learning',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textOnDark
                      : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accentPurple.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Level ${stats.level} • ${formatCount(stats.totalXp)} XP',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 560;
              final cols = wide ? 4 : 2;
              // Content is ~118px tall (icon chip 33 + gap 9 + value ~26 +
              // gap 1 + label ~15 + padding 28). A hard-coded ratio only
              // worked at one width and overflowed everywhere else, so derive
              // it from the real tile width instead.
              const tileHeight = 120.0;
              final tileWidth = (c.maxWidth - (cols - 1) * 12) / cols;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: tileWidth / tileHeight,
                children: items,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem(this.icon, this.value, this.label, this.color);

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
        borderRadius: BorderRadius.circular(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.22 : 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark
                  ? AppColors.textOnDark.withValues(alpha: 0.62)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Premium banner                                                             */
/* -------------------------------------------------------------------------- */

class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppGradients.gold,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF7971E).withValues(alpha: 0.42),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Color(0xFF7A4E00), size: 32),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CodeYoung Premium',
                    style: TextStyle(
                      color: Color(0xFF4A3200),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unlimited 1:1 mentor sessions, priority scheduling, detailed progress reports and certificates.',
                    style: TextStyle(
                      color: const Color(0xFF4A3200).withValues(alpha: 0.85),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => context.go('/courses'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A3200),
                foregroundColor: const Color(0xFFFFF3D6),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms, delay: 120.ms).slide(begin: const Offset(0, 0.08)),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Achievements                                                               */
/* -------------------------------------------------------------------------- */

class _Achievements extends StatelessWidget {
  const _Achievements({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = stats.achievementsList;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Achievements',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${stats.achievements}/${list.isEmpty ? 5 : list.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: list.isEmpty
                ? Center(
                    child: Text(
                      'Complete lessons to earn badges.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textOnDark.withValues(alpha: 0.6)
                            : AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final a = list[i];
                      final color = a.earned ? AppColors.accentGold : AppColors.textSecondary;
                      return Container(
                        width: 128,
                        margin: const EdgeInsets.only(right: 11),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: a.earned
                                ? AppColors.accentGold.withValues(alpha: 0.5)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05)),
                          ),
                          boxShadow: a.earned
                              ? [
                                  BoxShadow(
                                    color: AppColors.accentGold.withValues(alpha: 0.18),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: a.earned ? 0.20 : 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _iconFor(a.icon),
                                color: color,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              a.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: a.earned
                                    ? (isDark ? AppColors.textOnDark : AppColors.textPrimary)
                                    : (isDark
                                        ? AppColors.textOnDark.withValues(alpha: 0.5)
                                        : AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) => switch (name) {
        'login' => Icons.login_rounded,
        'book' => Icons.menu_book_rounded,
        'code' => Icons.code_rounded,
        'format_list_numbered' => Icons.format_list_numbered_rounded,
        'schedule' => Icons.schedule_rounded,
        'star' => Icons.star_rounded,
        _ => Icons.emoji_events_rounded,
      };
}

/* -------------------------------------------------------------------------- */
/* Menu cards                                                                 */
/* -------------------------------------------------------------------------- */

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
          borderRadius: BorderRadius.circular(22),
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
        child: Column(children: children),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.24 : 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textOnDark.withValues(alpha: 0.6)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Edit profile sheet                                                         */
/* -------------------------------------------------------------------------- */

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _bio;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showAppSnackBar(context, 'Name cannot be empty', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(
            name: _name.text.trim(),
            email: _email.text.trim(),
            bio: _bio.text.trim(),
          );
      ref.invalidate(statsProvider);
      if (mounted) {
        Navigator.pop(context);
        showAppSnackBar(context, 'Profile updated');
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, error: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save changes', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDarkSurface : AppColors.bgWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _field(_name, 'Full name', Icons.person_rounded),
            const SizedBox(height: 12),
            _field(_email, 'Email address', Icons.mail_rounded, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(_bio, 'A line about you (optional)', Icons.edit_note_rounded, maxLines: 3),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Save changes',
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkCard : AppColors.bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primaryBlue, size: 20),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 14 : 16),
        ),
        style: TextStyle(
          fontSize: 14.5,
          color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
        ),
      ),
    );
  }
}
