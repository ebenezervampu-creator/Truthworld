import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/components/ui/rive/rive_interaction_widgets.dart';
import 'package:truthworld/theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// Industry Standard Micro-Interaction Animations for Truthworld
///
/// Guidelines:
/// 1. Animations trigger ONLY on direct user action (taps/clicks).
/// 2. Performance: 0 external package dependencies, using lightweight Flutter
///    AnimationControllers and CustomPainters for 60/120 FPS performance.
/// 3. Like: Elastic scale pop + radial particle burst.
/// 4. Dislike: Tactile tilt / press shift (subdued).
/// 5. Subscribe: Color morph + scale pop + bell icon pulse.
/// 6. Follow Topic: 180° icon spin morph (+ to ✓) + chip scale pop.
/// ---------------------------------------------------------------------------

/// Radial particle burst painter for Like animation
class _ParticleBurstPainter extends CustomPainter {
  _ParticleBurstPainter({
    required this.progress,
    required this.color,
  }) : particleCount = 7;
  final double progress; // 0.0 to 1.0
  final Color color;
  final int particleCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.9;
    final minRadius = math.min(size.width, size.height) * 0.45;

    // Expand distance with easeOut
    final currentDistance =
        minRadius +
        (maxRadius - minRadius) * Curves.easeOut.transform(progress);

    // Opacity fades near the end of progress
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final particleRadius = (2.5 * (1.0 - progress * 0.5)).clamp(0.5, 3.5);

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final angleStep = (2 * math.pi) / particleCount;

    for (var i = 0; i < particleCount; i++) {
      final angle = i * angleStep - (math.pi / 2);
      final dx = center.dx + math.cos(angle) * currentDistance;
      final dy = center.dy + math.sin(angle) * currentDistance;
      canvas.drawCircle(Offset(dx, dy), particleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Professional Animated Like Button
class AnimatedLikeButton extends StatefulWidget {
  const AnimatedLikeButton({
    required this.isLiked,
    required this.onTap,
    super.key,
    this.icon,
    this.activeIcon,
    this.size = 22,
    this.activeColor,
    this.inactiveColor,
    this.enableParticles = true,
    this.useRive = false,
    this.child,
  });
  final bool isLiked;
  final VoidCallback onTap;
  final IconData? icon;
  final IconData? activeIcon;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool enableParticles;
  final bool useRive;
  final Widget? child;

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _particleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.35,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.35,
          end: 1,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
    ]).animate(_scaleController);
  }

  @override
  void didUpdateWidget(covariant AnimatedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked) {
      if (widget.isLiked) {
        _scaleController.forward(from: 0);
        if (widget.enableParticles) {
          _particleController.forward(from: 0);
        }
      } else {
        _scaleController.reverse(from: 0.5);
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useRive) {
      return TruthworldRiveLikeButton(
        isLiked: widget.isLiked,
        onTap: widget.onTap,
        size: widget.size,
        activeColor: widget.activeColor,
        inactiveColor: widget.inactiveColor,
      );
    }

    final activeColor = widget.activeColor ?? AppColors.brand;
    final inactiveColor = widget.inactiveColor ?? AppColors.textPrimary;

    final defaultIcon = widget.isLiked
        ? (widget.activeIcon ?? Icons.thumb_up_rounded)
        : (widget.icon ?? Icons.thumb_up_outlined);

    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: activeColor.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedBuilder(
          animation: _particleController,
          builder: (context, child) {
            return CustomPaint(
              foregroundPainter: widget.enableParticles
                  ? _ParticleBurstPainter(
                      progress: _particleController.value,
                      color: activeColor,
                    )
                  : null,
              child: child,
            );
          },
          child: ScaleTransition(
            scale: _scaleAnimation,
            child:
                widget.child ??
                Icon(
                  defaultIcon,
                  size: widget.size,
                  color: widget.isLiked ? activeColor : inactiveColor,
                ),
          ),
        ),
      ),
    );
  }
}

/// Professional Animated Dislike Button
class AnimatedDislikeButton extends StatefulWidget {
  const AnimatedDislikeButton({
    required this.isDisliked,
    required this.onTap,
    super.key,
    this.icon,
    this.activeIcon,
    this.size = 22,
    this.activeColor,
    this.inactiveColor,
    this.child,
  });
  final bool isDisliked;
  final VoidCallback onTap;
  final IconData? icon;
  final IconData? activeIcon;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final Widget? child;

  @override
  State<AnimatedDislikeButton> createState() => _AnimatedDislikeButtonState();
}

class _AnimatedDislikeButtonState extends State<AnimatedDislikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _tiltAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );

    _tiltAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -0.18,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.18,
          end: 0.08,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.08,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0.88),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant AnimatedDislikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDisliked != oldWidget.isDisliked && widget.isDisliked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? AppColors.textPrimary;
    final inactiveColor = widget.inactiveColor ?? AppColors.textPrimary;

    final defaultIcon = widget.isDisliked
        ? (widget.activeIcon ?? Icons.thumb_down_rounded)
        : (widget.icon ?? Icons.thumb_down_outlined);

    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: inactiveColor.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _tiltAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child:
                    widget.child ??
                    Icon(
                      defaultIcon,
                      size: widget.size,
                      color: widget.isDisliked ? activeColor : inactiveColor,
                    ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Professional Animated Channel Subscribe Button
class AnimatedSubscribeButton extends StatefulWidget {
  const AnimatedSubscribeButton({
    required this.isSubscribed,
    required this.onPressed,
    super.key,
    this.subscribedText = 'Subscribed',
    this.unsubscribedText = 'Subscribe',
    this.notificationsEnabled = false,
    this.notificationOption = 'all',
    this.onNotificationTap,
    this.compact = false,
  });
  final bool isSubscribed;
  final VoidCallback onPressed;
  final String subscribedText;
  final String unsubscribedText;
  final bool notificationsEnabled;
  final String notificationOption;
  final VoidCallback? onNotificationTap;
  final bool compact;

  @override
  State<AnimatedSubscribeButton> createState() =>
      _AnimatedSubscribeButtonState();
}

class _AnimatedSubscribeButtonState extends State<AnimatedSubscribeButton>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _bellController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _bellSwingAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _bellController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_scaleController);

    _bellSwingAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -0.22,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.22,
          end: 0.22,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.22,
          end: 0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 35,
      ),
    ]).animate(_bellController);
  }

  @override
  void didUpdateWidget(covariant AnimatedSubscribeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSubscribed != oldWidget.isSubscribed && widget.isSubscribed) {
      _scaleController.forward(from: 0);
      _bellController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _bellController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (widget.isSubscribed && widget.onNotificationTap != null) {
      widget.onNotificationTap!();
    } else {
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSub = widget.isSubscribed;
    final bgColor = isSub
        ? AppColors.bgSurfaceContainerHighest
        : AppColors.textPrimary;
    final fgColor = isSub ? AppColors.textPrimary : AppColors.bgPage;

    final padding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 9);

    final fontSize = widget.compact ? 12.0 : 13.0;

    IconData bellIcon;
    if (widget.notificationOption == 'none' || !widget.notificationsEnabled) {
      bellIcon = Icons.notifications_off_rounded;
    } else if (widget.notificationOption == 'personalized') {
      bellIcon = Icons.notifications_outlined;
    } else {
      bellIcon = Icons.notifications_active_rounded;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: isSub
              ? Border.all(color: AppColors.textPrimary.withValues(alpha: 0.15))
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: isSub
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.unsubscribedText,
                          style: TextStyle(
                            color: fgColor,
                            fontWeight: FontWeight.bold,
                            fontSize: fontSize,
                          ),
                        ),
                      ],
                    ),
                    secondChild: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _bellSwingAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _bellSwingAnimation.value,
                              child: Icon(
                                bellIcon,
                                size: fontSize + 3,
                                color: fgColor,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.subscribedText,
                          style: TextStyle(
                            color: fgColor,
                            fontWeight: FontWeight.w600,
                            fontSize: fontSize,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: fontSize + 3,
                          color: fgColor,
                        ),
                      ],
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

/// Professional Animated Follow Topic Chip / Button
class AnimatedFollowTopicButton extends StatefulWidget {
  const AnimatedFollowTopicButton({
    required this.isFollowed,
    required this.onPressed,
    super.key,
    this.topicName,
    this.compact = false,
  });
  final bool isFollowed;
  final VoidCallback onPressed;
  final String? topicName;
  final bool compact;

  @override
  State<AnimatedFollowTopicButton> createState() =>
      _AnimatedFollowTopicButtonState();
}

class _AnimatedFollowTopicButtonState extends State<AnimatedFollowTopicButton>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _rotateController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.09,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.09,
          end: 1,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_scaleController);

    _rotateAnimation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeOutBack),
    );

    if (widget.isFollowed) {
      _rotateController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedFollowTopicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFollowed != oldWidget.isFollowed) {
      _scaleController.forward(from: 0);
      if (widget.isFollowed) {
        _rotateController.forward(from: 0);
      } else {
        _rotateController.reverse(from: 1);
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final isFollowed = widget.isFollowed;
    final bgColor = isFollowed
        ? AppColors.textPrimary.withValues(alpha: 0.12)
        : AppColors.textPrimary;
    final fgColor = isFollowed ? AppColors.textPrimary : AppColors.bgPage;

    final padding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 9);

    final fontSize = widget.compact ? 12.0 : 13.0;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: isFollowed
              ? Border.all(color: AppColors.textPrimary.withValues(alpha: 0.18))
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _rotateAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotateAnimation.value,
                        child: Icon(
                          isFollowed ? Icons.check_rounded : Icons.add_rounded,
                          size: fontSize + 3,
                          color: fgColor,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize,
                    ),
                    child: Text(isFollowed ? 'Following' : 'Follow'),
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
