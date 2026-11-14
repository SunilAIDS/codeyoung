import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Reveals [text] one character at a time.
///
/// Every glyph gets its own fade + rise with a staggered delay, so the CodeYoung
/// wordmark "types itself in" each time a screen is pushed. Characters occupy
/// their final width from the first frame (only opacity/offset animate), which
/// keeps the header perfectly still while it plays.
class LetterRevealText extends StatefulWidget {
  const LetterRevealText({
    super.key,
    required this.text,
    this.style,
    this.stagger = 55,
    this.duration = 420,
    this.curve = Curves.easeOutCubic,
    this.riseOffset = 8,
  });

  final String text;
  final TextStyle? style;

  /// Delay added per character, in milliseconds.
  final int stagger;

  /// Fade/rise duration for a single character, in milliseconds.
  final int duration;
  final Curve curve;
  final double riseOffset;

  @override
  State<LetterRevealText> createState() => _LetterRevealTextState();
}

class _LetterRevealTextState extends State<LetterRevealText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration)
      ..forward();
  }

  int get _count => widget.text.isEmpty ? 1 : widget.text.length;

  Duration get _totalDuration => Duration(
        milliseconds:
            widget.duration + widget.stagger * (_count - 1),
      );

  /// Local0..1 eased progress for character [index], matching a
  /// `Interval(i * stagger, i * stagger + duration)` on [_controller].
  double _progress(int index) {
    final totalMs = widget.duration + widget.stagger * (_count - 1);
    if (totalMs <= 0) return 1;
    final start = (index * widget.stagger) / totalMs;
    final end = (start + widget.duration / totalMs).clamp(0.0, 1.0);
    if (end <= start) return 1;
    final raw = ((_controller.value - start) / (end - start)).clamp(0.0, 1.0);
    return widget.curve.transform(raw);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chars = widget.text.split('');

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < chars.length; i++)
              if (chars[i] == ' ')
                Text(' ', style: widget.style)
              else
                Builder(
                  builder: (context) {
                    final p = _progress(i);
                    return Opacity(
                      opacity: p,
                      child: Transform.translate(
                        offset: Offset(0, widget.riseOffset * (1 - p)),
                        child: Text(chars[i], style: widget.style),
                      ),
                    );
                  },
                ),
          ],
        );
      },
    );
  }
}

/// The common top bar shown on **every** screen.
///
/// The CodeYoung wordmark is always optically centred: it lives in a [Center]
/// while the back button and trailing actions are absolutely positioned, so
/// adding or removing them can never shift the title sideways.
///
/// Use as `appBar:` — [Scaffold] asks for [preferredSize] and keeps the status
/// bar inset outside the widget, so the content is wrapped in a bottom-free
/// [SafeArea] exactly like the stock [AppBar].
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.title = 'CodeYoung',
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.elevated = true,
    this.height = 56,
  });

  /// Wordmark shown centred on every screen.
  final String title;

  /// Optional small caption under the wordmark (screen name), for pushed pages.
  final String? subtitle;

  /// Shows the leading back arrow. Tab screens leave this `false`.
  final bool showBack;

  /// Defaults to `context.pop()` when [showBack] is set.
  final VoidCallback? onBack;

  /// Trailing widgets (kept clear of the centred title).
  final List<Widget>? actions;

  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Draws a hairline under the bar.
  final bool elevated;

  final double height;

  /// Wordmark line + optional caption line.
  double get _contentHeight => subtitle == null ? height : height + 18;

  @override
  Size get preferredSize => Size.fromHeight(_contentHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ??
        (isDark ? AppColors.bgDark : AppColors.bgLight);
    final fg = foregroundColor ??
        (isDark ? AppColors.textOnDark : AppColors.textPrimary);

    final wordmarkStyle = TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.1,
      color: fg,
    );

    return Material(
      color: bg,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _contentHeight,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Centred wordmark + optional caption.
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 76),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LetterRevealText(text: title, style: wordmarkStyle),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                            color: fg.withValues(alpha: 0.60),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Leading slot — absolutely positioned so it cannot push the
              // centred wordmark off axis.
              if (showBack)
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      onPressed: onBack ?? () => context.pop(),
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded, size: 22),
                      color: fg,
                      style: IconButton.styleFrom(
                        foregroundColor: fg,
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.all(10),
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),

              // Trailing slot.
              if (actions != null && actions!.isNotEmpty)
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!,
                    ),
                  ),
                ),

              if (elevated)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
