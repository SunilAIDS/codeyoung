import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/common.dart';

/// About Us tab — full company story, both founders, advantages, awards.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final about = ref.watch(aboutProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: const AppHeader(),
      body: SafeArea(
        top: false,
        child: about.when(
          loading: () => const LoadingState(label: 'Loading our story...'),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(aboutProvider)),
          data: (info) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(aboutProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _Header(info: info),
                _MissionCard(info: info),
                _FoundersSection(founders: info.founders),
                _JourneySection(info: info),
                _AdvantagesSection(advantages: info.advantages),
                _AwardsSection(awards: info.awards),
                _SubjectsSection(subjects: info.subjects),
                _ContactSection(info: info),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */

class _Header extends StatelessWidget {
  const _Header({required this.info});

  final AboutInfo info;

  @override
  Widget build(BuildContext context) {
    final company = info.company;
    final name = '${company['name'] ?? 'Codeyoung'}';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
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
            right: -50,
            top: -60,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogo(height: 40, dark: false),
              const SizedBox(height: 18),
              const Text(
                'Our story',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$name is an online learning platform built for kids — 1:1 live classes with mentors who make hard things feel simple.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _pill(Icons.calendar_today_rounded, 'Est. ${company['founded'] ?? 2019}'),
                  const SizedBox(width: 8),
                  _pill(Icons.public_rounded, 'Global'),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slide(begin: const Offset(0, 0.05));
  }

  Widget _pill(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.info});

  final AboutInfo info;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mission = '${info.company['mission'] ?? ''}';
    final story = '${info.company['story'] ?? ''}';

    return _SectionCard(
      title: 'Why we exist',
      icon: Icons.favorite_rounded,
      color: AppColors.accentPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mission.isNotEmpty) ...[
            Text(
              mission,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.65,
                color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (story.isNotEmpty)
            Text(
              story,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: isDark
                    ? AppColors.textOnDark.withValues(alpha: 0.78)
                    : AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _FoundersSection extends StatelessWidget {
  const _FoundersSection({required this.founders});

  final List<Founder> founders;

  @override
  Widget build(BuildContext context) {
    if (founders.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          const SectionHeader(
            title: 'Meet the founders',
            subtitle: 'Behind the vision',
          ),
          ...founders.map((f) => _FounderDetailCard(founder: f)),
        ],
      ),
    );
  }
}

class _FounderDetailCard extends StatelessWidget {
  const _FounderDetailCard({required this.founder});

  final Founder founder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
        borderRadius: BorderRadius.circular(24),
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
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: RemoteImage(
                  url: founder.photo,
                  fit: BoxFit.cover,
                  errorIcon: Icons.person_rounded,
                  memCacheWidth: 260,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      founder.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      founder.role,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.school_rounded, size: 14, color: AppColors.accentOrange),
                              const SizedBox(width: 5),
                              Text(
                                founder.almaMater,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentOrange,
                                ),
                              ),
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
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.14 : 0.07),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, size: 24, color: AppColors.primaryBlue),
                const SizedBox(height: 8),
                Text(
                  founder.quote,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms).slide(begin: const Offset(0, 0.06));
  }
}

class _JourneySection extends StatelessWidget {
  const _JourneySection({required this.info});

  final AboutInfo info;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const stats = {
      'students': 20000,
      'parents': 50000,
      'countries': 10,
      'mentors': 500,
    };

    return _SectionCard(
      title: 'The journey',
      icon: Icons.route_rounded,
      color: AppColors.accentCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Codeyoung started out in late 2019, and we have come a long way since then. We keep growing, serving parents the best we can and being a pivotal part of their kids’ adventure of learning and growth.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: [
              _JourneyStat(value: formatCount(stats['students']!), label: 'Students enrolled', color: AppColors.primaryBlue),
              _JourneyStat(value: formatCount(stats['parents']!), label: 'Happy parents', color: AppColors.accentGreen),
              _JourneyStat(value: '${stats['countries']}+', label: 'Countries', color: AppColors.accentOrange),
              _JourneyStat(value: formatCount(stats['mentors']!), label: 'Expert mentors', color: AppColors.accentPurple),
            ],
          ),
        ],
      ),
    );
  }
}

class _JourneyStat extends StatelessWidget {
  const _JourneyStat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.textOnDark.withValues(alpha: 0.75) : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvantagesSection extends StatelessWidget {
  const _AdvantagesSection({required this.advantages});

  final List<Map<String, dynamic>> advantages;

  @override
  Widget build(BuildContext context) {
    if (advantages.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final palette = [AppColors.primaryBlue, AppColors.accentGreen, AppColors.accentOrange];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'The proven advantage',
            subtitle: 'Why 1:1 learning wins',
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
              borderRadius: BorderRadius.circular(24),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.psychology_rounded, color: AppColors.accentPurple, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Bloom's 2 Sigma: a 1:1 tutored student outperforms 98% of peers",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...advantages.asMap().entries.map((entry) {
                  final a = entry.value;
                  final color = palette[entry.key % palette.length];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_iconFor('${a['icon']}'), color: color, size: 21),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${a['title']}',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${a['description']}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: isDark
                                      ? AppColors.textOnDark.withValues(alpha: 0.7)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) => switch (name) {
        'videocam' => Icons.videocam_rounded,
        'trending_up' => Icons.trending_up_rounded,
        'feedback' => Icons.feedback_rounded,
        _ => Icons.check_circle_rounded,
      };
}

class _AwardsSection extends StatelessWidget {
  const _AwardsSection({required this.awards});

  final List<Map<String, dynamic>> awards;

  @override
  Widget build(BuildContext context) {
    if (awards.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SectionCard(
      title: 'Rewards & recognition',
      icon: Icons.emoji_events_rounded,
      color: AppColors.accentGold,
      child: Column(
        children: awards.map((a) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: isDark ? 0.14 : 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech_rounded, color: AppColors.accentGold, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${a['title']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (a['year'] != null)
                  Text(
                    '${a['year']}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentGold,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SubjectsSection extends StatelessWidget {
  const _SubjectsSection({required this.subjects});

  final List<String> subjects;

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'What we teach', subtitle: 'Six subjects, one mentor model'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: subjects.map((s) {
              final icon = switch (s.toLowerCase()) {
                'coding' => Icons.code_rounded,
                'math' => Icons.calculate_rounded,
                'english' => Icons.menu_book_rounded,
                'science' => Icons.science_rounded,
                'robotics' => Icons.smart_toy_rounded,
                'financial literacy' => Icons.savings_rounded,
                _ => Icons.school_rounded,
              };
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 7),
                    Text(
                      s,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.info});

  final AboutInfo info;

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = info.company;
    final email = '${company['email'] ?? 'support@codeyoung.com'}';
    final phone = '${company['phone'] ?? ''}';
    final legal = '${company['legalName'] ?? ''}';
    final cin = '${company['cin'] ?? ''}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Get in touch', subtitle: 'We reply within a day'),
          Row(
            children: [
              Expanded(
                child: _ContactTile(
                  icon: Icons.mail_rounded,
                  label: 'Email',
                  value: email,
                  color: AppColors.primaryBlue,
                  onTap: () => _open('mailto:$email'),
                ),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _ContactTile(
                    icon: Icons.phone_rounded,
                    label: 'Call',
                    value: phone,
                    color: AppColors.accentGreen,
                    onTap: () => _open('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: 'Book a FREE trial class',
              icon: Icons.event_available_rounded,
              gradient: AppGradients.grape,
              onPressed: () => context.go('/courses'),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              [
                if (legal.isNotEmpty) legal,
                if (cin.isNotEmpty) 'CIN: $cin',
                'All rights reserved.',
              ].join('\n'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.6,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textOnDark.withValues(alpha: 0.5)
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.textOnDark.withValues(alpha: 0.6) : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          SectionHeader(title: title),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
              borderRadius: BorderRadius.circular(24),
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
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
