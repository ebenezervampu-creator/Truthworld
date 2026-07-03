import 'package:flutter/material.dart';

/// Staggered fade-slide animation for list/grid items.
///
/// Wraps each item to create a staggered entry effect where items
/// appear one after another with a slight delay.
///
/// Usage in a `ListView.builder` or `GridView.builder`:
/// ```dart
/// itemBuilder: (context, index) {
///   return StaggeredFadeSlide(
///     index: index,
///     child: VideoGridCard(video: videos[index]),
///   );
/// }
/// ```
class StaggeredFadeSlide extends StatefulWidget {
  /// Index of this item in the list — used to calculate stagger delay.
  final int index;

  /// The child widget to animate.
  final Widget child;

  /// Delay between each item's animation start.
  final Duration staggerDelay;

  /// Duration of each item's animation.
  final Duration duration;

  /// Vertical offset in pixels for the slide-up effect.
  final double slideOffset;

  /// Maximum number of items to animate (prevents long delays for
  /// items far down the list that are likely off-screen).
  final int maxAnimatedItems;

  const StaggeredFadeSlide({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 350),
    this.slideOffset = 24.0,
    this.maxAnimatedItems = 20,
  });

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Skip animation for items beyond the max threshold
    // (they're likely scrolled off-screen, animating them wastes resources)
    final shouldAnimate = widget.index < widget.maxAnimatedItems;

    _controller = AnimationController(
      duration: shouldAnimate ? widget.duration : Duration.zero,
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, shouldAnimate ? widget.slideOffset : 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (shouldAnimate) {
      // Calculate stagger delay based on index
      final delay = widget.staggerDelay * widget.index;
      Future.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      // Instant show for items beyond threshold
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
