import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// Persistent shell hosting the five primary tabs.
///
/// Home / About / Courses / Chat / Account keep their scroll position and
/// state because the branches are held in an indexed stack.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const tabs = [
    _Tab(icon: Icons.home_rounded, activeIcon: Icons.home, label: 'Home'),
    _Tab(icon: Icons.info_outline_rounded, activeIcon: Icons.info_rounded, label: 'About'),
    _Tab(icon: Icons.school_outlined, activeIcon: Icons.school_rounded, label: 'Courses'),
    _Tab(icon: Icons.forum_outlined, activeIcon: Icons.forum_rounded, label: 'Mentor'),
    _Tab(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final index = shell.currentIndex;

    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDarkSurface : AppColors.bgWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(tabs.length, (i) {
                final tab = tabs[i];
                final selected = i == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => shell.goBranch(
                      i,
                      // Return to the branch root so back doesn't replay a
                      // long stack of detail routes.
                      initialLocation: i == shell.currentIndex,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: 220.ms,
                          curve: Curves.easeOut,
                          padding: EdgeInsets.symmetric(
                            horizontal: selected ? 16 : 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryBlue.withValues(alpha: isDark ? 0.28 : 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(
                            selected ? tab.activeIcon : tab.icon,
                            size: 22,
                            color: selected
                                ? AppColors.primaryBlue
                                : (isDark
                                    ? AppColors.textOnDark.withValues(alpha: 0.6)
                                    : AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? AppColors.primaryBlue
                                : (isDark
                                    ? AppColors.textOnDark.withValues(alpha: 0.6)
                                    : AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab({required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}
