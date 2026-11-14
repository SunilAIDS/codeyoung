import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// Brand splash — shows the official logo while the session is restored.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _status = 'Warming up your classroom...';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Minimum brand exposure so the logo is actually seen.
    final timer = Future.delayed(const Duration(milliseconds: 1600));

    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('onboarded') ?? false;
      if (!seen) {
        await prefs.setBool('onboarded', true);
        setState(() => _status = 'Preparing your first lesson...');
      } else {
        setState(() => _status = 'Syncing your progress...');
      }
    } catch (_) {
      // Preferences unavailable — continue anyway.
    }

    // Wait for the auth controller to restore any stored token.
    final auth = ref.read(authProvider.notifier);
    var waited = 0;
    while (!ref.read(sessionReadyProvider) && waited < 4000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited += 100;
      if (!mounted) return;
    }
    // Ignore unused local; auth is read for side-effect initialisation.
    // ignore: unused_local_variable
    final _ = auth;

    await timer;
    if (!mounted) return;

    // Guests land straight on the home page — sign-in is optional and can be
    // triggered from the Account tab at any time.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgWhite,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppGradients.nightSky
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFEFF5FF), Color(0xFFFFFFFF)],
                ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.25),
                      blurRadius: 44,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: const AppLogo(height: 62, dark: false),
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(
                    begin: const Offset(0.86, 0.86),
                    end: const Offset(1, 1),
                    duration: 700.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 28),
              Text(
                'CodeYoung',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ).animate().fadeIn(delay: 220.ms, duration: 500.ms),
              const SizedBox(height: 8),
              Text(
                'Learn • Create • Innovate',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textOnDark.withValues(alpha: 0.7)
                      : AppColors.primaryBlue,
                ),
              ).animate().fadeIn(delay: 340.ms, duration: 500.ms),
              const SizedBox(height: 46),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ).animate(onPlay: (c) => c.repeat()).fadeIn(delay: 500.ms),
              const SizedBox(height: 14),
              Text(
                _status,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? AppColors.textOnDark.withValues(alpha: 0.6)
                      : AppColors.textSecondary,
                ),
              ).animate().fadeIn(delay: 550.ms),
            ],
          ),
        ),
      ),
    );
  }
}
