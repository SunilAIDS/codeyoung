import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Auto-advancing hero carousel for the promotional banners served by the API.
///
/// Each slide has a gradient, an optional illustration (bundled asset or
/// network URL), a badge and a CTA. Supports tap-through and swipe.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.banners,
    this.height = 210,
    this.onTapCta,
    this.autoPlay = true,
  });

  final List<PromoBanner> banners;
  final double height;
  final void Function(PromoBanner banner)? onTapCta;
  final bool autoPlay;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    if (widget.autoPlay && widget.banners.length > 1) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _BannerCard(
                banner: widget.banners[i],
                onTap: () {
                  final b = widget.banners[i];
                  if (widget.onTapCta != null) {
                    widget.onTapCta!(b);
                  } else if (b.ctaRoute != null) {
                    // Fall back to deep-linking through the router overlay.
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(b.ctaLabel ?? b.title)),
                    );
                  }
                },
              ),
            ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: 250.ms,
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryBlue : AppColors.primaryBlue.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.onTap});

  final PromoBanner banner;
  final VoidCallback onTap;

  Gradient get _gradient {
    final spec = banner.gradient;
    if (spec != null && spec.contains(',')) {
      // Spec format: "linear-gradient(135deg,#1E88E5 0%,#1565C0 55%,#0D47A1 100%)"
      final colors = RegExp(r'#[0-9A-Fa-f]{6}')
          .allMatches(spec)
          .map((m) => Color(int.parse('FF${m.group(0)!.substring(1)}', radix: 16)))
          .toList();
      if (colors.length >= 2) {
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.length > 3 ? [colors.first, colors[1], colors.last] : colors,
        );
      }
    }
    return AppGradients.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Decorative illustration, right-aligned and partially faded so
              // the copy always stays legible.
              Positioned(
                right: -10,
                top: 0,
                bottom: 0,
                width: 165,
                child: Opacity(
                  opacity: 0.34,
                  child: RemoteImage(
                    url: banner.imageUrl,
                    fit: BoxFit.contain,
                    errorIcon: Icons.auto_awesome,
                  ),
                ),
              ),
              // Legibility scrim.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.30),
                        Colors.black.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 150, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (banner.badge != null && banner.badge!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          banner.badge!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: Color(0xFF4A3200),
                          ),
                        ),
                      ),
                    const SizedBox(height: 9),
                    Text(
                      banner.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.5,
                        height: 1.22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (banner.subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        banner.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            banner.ctaLabel ?? 'Explore',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1565C0)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slide(begin: const Offset(0, 0.08));
  }
}

/// Compact horizontal banner used inside list scroll views.
class InlineBanner extends StatelessWidget {
  const InlineBanner({super.key, required this.banner, this.onTap});

  final PromoBanner banner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: AppGradients.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  banner.subtitle ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primaryBlue),
        ],
      ),
    );
  }
}
