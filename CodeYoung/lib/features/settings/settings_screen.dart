import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/common.dart';


/// Wrapper used by the router so the route name stays `/settings`.
class SettingsScreenShell extends ConsumerWidget {
  const SettingsScreenShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SettingsScreen();
  }
}

/// Settings — appearance, voice, network diagnostics, account actions.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoSpeak = true;
  String _networkStatus = 'Checking...';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkBackend();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final stored = prefs.getString('theme_mode') ?? 'system';
      _themeMode = switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _autoSpeak = prefs.getBool('auto_speak') ?? true;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'theme_mode',
      mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
              ? 'dark'
              : 'system',
    );
  }

  Future<void> _setAutoSpeak(bool value) async {
    setState(() => _autoSpeak = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_speak', value);
  }

  Future<void> _checkBackend() async {
    setState(() {
      _checking = true;
      _networkStatus = 'Checking...';
    });
    try {
      final api = ref.read(apiServiceProvider);
      final json = await api.getJson('/health');
      final status = '${json['status'] ?? ''}';
      setState(() {
        _networkStatus = status == 'ok'
            ? 'Connected (port ${AppConfig.apiBase.split(':').last})'
            : 'Unexpected response';
      });
    } catch (e) {
      setState(() => _networkStatus = 'Offline — start the backend');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to track progress.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: const AppHeader(showBack: true, subtitle: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 36),
        children: [
          // --- Appearance ---------------------------------------------
          _Card(
            title: 'Appearance',
            icon: Icons.palette_rounded,
            color: AppColors.accentPurple,
            children: [
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded, size: 18)),
                  ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto_rounded, size: 18)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded, size: 18)),
                ],
                selected: {_themeMode},
                onSelectionChanged: (s) => _setThemeMode(s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // --- Mentor voice -------------------------------------------
          _Card(
            title: 'Mentor voice',
            icon: Icons.record_voice_over_rounded,
            color: AppColors.accentGreen,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _autoSpeak,
                activeThumbColor: AppColors.primaryBlue,
                title: const Text('Read answers aloud', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'The mentor speaks every reply using Python text-to-speech.',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: isDark ? AppColors.textOnDark.withValues(alpha: 0.65) : AppColors.textSecondary),
                ),
                onChanged: _setAutoSpeak,
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => context.go('/chat'),
                icon: const Icon(Icons.chat_rounded, size: 17),
                label: const Text('Open mentor'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.4)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // --- Connection ---------------------------------------------
          _Card(
            title: 'Connection',
            icon: Icons.wifi_rounded,
            color: AppColors.primaryBlue,
            children: [
              _Row(
                label: 'API server',
                value: AppConfig.apiBase,
                mono: true,
              ),
              const SizedBox(height: 8),
              _Row(
                label: 'Mentor service',
                value: AppConfig.chatBase,
                mono: true,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_networkStatus.startsWith('Connected')
                          ? AppColors.accentGreen
                          : AppColors.accentOrange)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (_networkStatus.startsWith('Connected')
                            ? AppColors.accentGreen
                            : AppColors.accentOrange)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _networkStatus.startsWith('Connected')
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
                            size: 18,
                            color: _networkStatus.startsWith('Connected')
                                ? AppColors.accentGreen
                                : AppColors.accentOrange,
                          ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _networkStatus,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _checking ? null : _checkBackend,
                      tooltip: 'Re-check',
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // --- Account -------------------------------------------------
          _Card(
            title: 'Account',
            icon: Icons.person_rounded,
            color: AppColors.accentOrange,
            children: [
              _Row(label: 'Signed in as', value: user?.email ?? 'Not signed in'),
              const SizedBox(height: 12),
              if (user != null)
                OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded, size: 17),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.45)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'Sign in',
                    icon: Icons.login_rounded,
                    height: 46,
                    onPressed: () => context.go('/login'),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // --- About ---------------------------------------------------
          _Card(
            title: 'About',
            icon: Icons.info_rounded,
            color: AppColors.accentCyan,
            children: [
              const _Row(label: 'App version', value: '1.0.0'),
              const SizedBox(height: 8),
              const _Row(label: 'Built with', value: 'Flutter • Node.js • Python'),
              const SizedBox(height: 8),
              const _Row(label: 'Data layer', value: 'SQLite (node:sqlite)'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  _LinkPill(
                    label: 'Website',
                    icon: Icons.language_rounded,
                    onTap: () => _open('https://www.codeyoung.com'),
                  ),
                  _LinkPill(
                    label: 'Email support',
                    icon: Icons.mail_rounded,
                    onTap: () => _open('mailto:support@codeyoung.com'),
                  ),
                  _LinkPill(
                    label: 'Call us',
                    icon: Icons.phone_rounded,
                    onTap: () => _open('tel:+918884459977'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 22),
          Center(
            child: Text(
              'Smart Owl Education Pvt Ltd\nCIN U80904KA2020PTC132006',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.7,
                color: isDark ? AppColors.textOnDark.withValues(alpha: 0.5) : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/* -------------------------------------------------------------------------- */

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.24 : 0.14),
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
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? AppColors.textOnDark.withValues(alpha: 0.7) : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              fontFamily: mono ? 'monospace' : null,
              color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkPill extends StatelessWidget {
  const _LinkPill({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.18 : 0.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primaryBlue),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
