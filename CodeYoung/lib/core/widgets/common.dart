import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

/* -------------------------------------------------------------------------- */
/* Brand                                                                      */
/* -------------------------------------------------------------------------- */

/// The official CodeYoung logo pulled from codeyoung.com.
///
/// Falls back to the app icon mark if the asset is missing so the brand never
/// renders as a broken image.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 40, this.fit = BoxFit.contain, this.dark});

  final double height;
  final BoxFit fit;
  final bool? dark;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      'assets/images/primary_logo.png',
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _FallbackMark(height: height, isDark: isDark),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.height, required this.isDark});

  final double height;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final size = height;
    return Container(
      width: size * 1.9,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.code, size: size * 0.5, color: Colors.white),
          SizedBox(width: size * 0.12),
          Text(
            AppConfig.appName,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.44,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Images                                                                     */
/* -------------------------------------------------------------------------- */

/// Network image with shimmer placeholder, error fallback and optional
/// corner radius — used everywhere so thumbnails always render something.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.errorIcon = Icons.image_outlined,
    this.errorLabel,
    this.memCacheWidth,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  final IconData errorIcon;
  final String? errorLabel;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF232338), const Color(0xFF1B1B2C)]
              : [const Color(0xFFEDF1F7), const Color(0xFFE2E8F2)],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );

    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF26263D), const Color(0xFF1E1E30)]
              : [const Color(0xFFE8EEF7), const Color(0xFFDCE5F2)],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(errorIcon, size: (height != null && height! < 90) ? 26 : 40, color: AppColors.primaryBlue),
          if (errorLabel != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                errorLabel!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textOnDark : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final src = (url ?? '').trim();
    if (src.isEmpty || src == 'null') return fallback;

    // Local asset (banners ship with the app so the home screen always looks
    // right even before the network responds).
    if (!src.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/$src',
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: src,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Layout                                                                     */
/* -------------------------------------------------------------------------- */

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.textOnDark.withValues(alpha: 0.65)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios, size: 11),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* States                                                                     */
/* -------------------------------------------------------------------------- */

/// Friendly error card with a retry affordance.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry, this.compact = false});

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, size: 42, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(
              'Oops, something went wrong',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: isDark ? AppColors.textOnDark.withValues(alpha: 0.7) : AppColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Neutral empty state used by list screens with no matches.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 46, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? AppColors.textOnDark.withValues(alpha: 0.7) : AppColors.textSecondary,
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (label != null) ...[
            const SizedBox(height: 16),
            Text(
              label!,
              style: TextStyle(
                fontSize: 13.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textOnDark.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Chips / pills                                                             */
/* -------------------------------------------------------------------------- */

class LevelChip extends StatelessWidget {
  const LevelChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  Color get _color {
    switch (label.toLowerCase()) {
      case 'beginner':
        return AppColors.accentGreen;
      case 'intermediate':
        return AppColors.accentOrange;
      case 'advanced':
        return AppColors.accentPurple;
      default:
        return color ?? AppColors.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: c,
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Buttons                                                                    */
/* -------------------------------------------------------------------------- */

/// Full-width gradient CTA used on hero and detail screens.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient,
    this.loading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient? gradient;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return AnimatedOpacity(
      duration: 200.ms,
      opacity: enabled ? 1 : 0.55,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: gradient ?? AppGradients.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: enabled ? 0.35 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 19),
                          const SizedBox(width: 9),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Misc                                                                       */
/* -------------------------------------------------------------------------- */

String formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
  return '$n';
}

void showAppSnackBar(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : const Color(0xFF2B2B3D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
}
