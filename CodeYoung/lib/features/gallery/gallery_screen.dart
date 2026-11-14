import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/common.dart';

/// Gallery tab — masonry grid of project/classroom images with a full-screen
/// pinch-to-zoom viewer.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(galleryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: const AppHeader(showBack: true),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gallery',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Projects, classrooms and wins',
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
                      onPressed: () => context.go('/account'),
                      tooltip: 'Your account',
                      icon: const Icon(Icons.person_rounded,
                          color: AppColors.primaryBlue, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: gallery.when(
                loading: () => const LoadingState(label: 'Loading gallery...'),
                error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(galleryProvider),
                ),
                data: (all) {
                  final categories = <String>{'All', ...all.map((g) => g.category)}.toList();
                  final filtered = _category == 'All'
                      ? all
                      : all.where((g) => g.category == _category).toList();

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
                            final selected = c == _category;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AnimatedContainer(
                                duration: 220.ms,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primaryBlue
                                      : (isDark
                                          ? AppColors.bgDarkCard
                                          : AppColors.bgWhite),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primaryBlue
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : Colors.black.withValues(alpha: 0.07)),
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => setState(() => _category = c),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 15, vertical: 9),
                                      child: Text(
                                        c,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight:
                                              selected ? FontWeight.w700 : FontWeight.w600,
                                          color: selected
                                              ? Colors.white
                                              : (isDark
                                                  ? AppColors.textOnDark
                                                  : AppColors.textPrimary),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async => ref.invalidate(galleryProvider),
                          child: filtered.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 60),
                                    EmptyState(
                                      icon: Icons.photo_library_outlined,
                                      title: 'Nothing here yet',
                                      subtitle: 'Try another category.',
                                    ),
                                  ],
                                )
                              : _MasonryGrid(
                                  images: filtered,
                                  onOpen: (index) => _openViewer(context, filtered, index),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, List<dynamic> images, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _ImageViewer(images: images, initial: index),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Masonry grid                                                               */
/* -------------------------------------------------------------------------- */

class _MasonryGrid extends StatelessWidget {
  const _MasonryGrid({required this.images, required this.onOpen});

  final List<dynamic> images;
  final void Function(int index) onOpen;

  @override
  Widget build(BuildContext context) {
    // Two balanced columns, distributing by estimated aspect ratio so the
    // layout stays stable while images stream in.
    final columns = <List<dynamic>>[[], []];
    final heights = [0.0, 0.0];

    for (var i = 0; i < images.length; i++) {
      final shortest = heights[0] <= heights[1] ? 0 : 1;
      columns[shortest].add(images[i]);
      // Alternate a tall/short rhythm for a lively masonry feel.
      heights[shortest] += i.isEven ? 1.35 : 1.0;
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < 2; c++)
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < columns[c].length; i++)
                      _GalleryTile(
                        image: columns[c][i],
                        index: images.indexOf(columns[c][i]),
                        onTap: () =>
                            onOpen(images.indexOf(columns[c][i])),
                        tall: i.isEven,
                      ),
                  ],
                ),
              ),
            if (columns[0].isNotEmpty && columns[1].isNotEmpty)
              const SizedBox(width: 12)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.image,
    required this.index,
    required this.onTap,
    required this.tall,
  });

  final dynamic image;
  final int index;
  final VoidCallback onTap;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final height = tall ? 218.0 : 158.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Hero(
          tag: 'gallery-${image.id}',
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RemoteImage(url: image.url, memCacheWidth: 460),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(11, 26, 11, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${image.title}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${image.category}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  right: 8,
                  top: 8,
                  child: _ZoomHint(),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 420.ms, delay: Duration(milliseconds: (index * 45).clamp(0, 400)))
        .scale(begin: const Offset(0.97, 0.97));
  }
}

class _ZoomHint extends StatelessWidget {
  const _ZoomHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 15),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Full-screen viewer                                                        */
/* -------------------------------------------------------------------------- */

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.images, required this.initial});

  final List<dynamic> images;
  final int initial;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _pageController;
  late int _index;
  bool _showInfo = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initial;
    _pageController = PageController(initialPage: widget.initial);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.images[_index];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showInfo = !_showInfo),
            child: PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              builder: (context, i) {
                final img = widget.images[i];
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider('${img.url}'),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2.5,
                  heroAttributes: PhotoViewHeroAttributes(tag: 'gallery-${img.id}'),
                );
              },
              loadingBuilder: (_, __) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              backgroundDecoration:
                  const BoxDecoration(color: Colors.transparent),
            ),
          ),

          // Top chrome
          AnimatedPositioned(
            duration: 260.ms,
            top: _showInfo ? 0 : -110,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 26),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${image.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_index + 1} of ${widget.images.length} • ${image.category}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in_rounded,
                              color: Colors.white, size: 15),
                          SizedBox(width: 5),
                          Text(
                            'Pinch to zoom',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom description
          AnimatedPositioned(
            duration: 260.ms,
            bottom: _showInfo ? 0 : -140,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 18,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.82),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (image.description != null)
                      Text(
                        '${image.description}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _NavBtn(
                          icon: Icons.arrow_back_ios_new_rounded,
                          enabled: _index > 0,
                          onTap: () {
                            if (_index > 0) {
                              _pageController.previousPage(
                                duration: 300.ms,
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        _NavBtn(
                          icon: Icons.arrow_forward_ios_rounded,
                          enabled: _index < widget.images.length - 1,
                          onTap: () {
                            if (_index < widget.images.length - 1) {
                              _pageController.nextPage(
                                duration: 300.ms,
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        ),
                        const Spacer(),
                        Text(
                          'Tap to hide',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: 200.ms,
      opacity: enabled ? 1 : 0.35,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
