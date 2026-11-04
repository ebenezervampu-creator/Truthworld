import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Professional Holographic Shimmer Sweep Animated Credibility Verification Button.
///
/// Implements a high-precision periodic specular light beam sweep across the capsule,
/// accompanied by a synchronized micro-gleam and star sparkle on the verified shield.
///
/// Designed strictly to TruthWorld engineering standards:
/// - 60/120 FPS hardware acceleration via CustomPainter & AnimatedBuilder
/// - Zero calls to [setState]
/// - Strict dark-mode high contrast (WCAG AAA compliant)
/// - Clean ticker disposal and automatic TickerMode pausing
class AnimatedCredibilityButton extends StatefulWidget {
  const AnimatedCredibilityButton({
    required this.onTap,
    this.label = 'AI Check',
    this.tooltip = 'Truth & Credibility Check',
    this.icon = Icons.verified_rounded,
    this.score,
    super.key,
  });

  final VoidCallback onTap;
  final String label;
  final String tooltip;
  final IconData icon;
  final double? score;

  @override
  State<AnimatedCredibilityButton> createState() =>
      _AnimatedCredibilityButtonState();
}

class _AnimatedCredibilityButtonState extends State<AnimatedCredibilityButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _sweepAnimation;
  late final Animation<double> _iconPulseAnimation;
  late final Animation<double> _sparkleAnimation;

  // Tactile press state managed without setState via ValueNotifier
  final ValueNotifier<bool> _isPressed = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    // 3.6 second loop: ~1.1s active beam sweep + ~2.5s calm resting phase
    _animController = AnimationController(
      duration: const Duration(milliseconds: 3600),
      vsync: this,
    );

    // Active sweep runs across the first 35% of the total period (0.0 to 0.35)
    _sweepAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeInOutCubic),
    );

    // Subtle scale pop on the verified icon when beam passes over it (0.12 to 0.28)
    _iconPulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.12, 0.28),
      ),
    );

    // Subtle specular star sparkle glint at peak passage (0.18 to 0.26)
    _sparkleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.18, 0.26),
      ),
    );

    _animController.repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    _isPressed.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _isPressed.value = true;
  }

  void _handleTapUp(TapUpDetails _) {
    _isPressed.value = false;
  }

  void _handleTapCancel() {
    _isPressed.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final hasLabel = widget.label.isNotEmpty;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: ValueListenableBuilder<bool>(
        valueListenable: _isPressed,
        builder: (context, isPressed, child) {
          return AnimatedScale(
            scale: isPressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _isPressed.value = false;
              // Smoothly dispatch tap on next frame so tactile spring release renders without thread contention
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onTap();
              });
            },
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            borderRadius: BorderRadius.circular(24),
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                final sweepProgress = _sweepAnimation.value;
                final isSweepActive = _animController.value <= 0.35;
                final activeSweepProgress = isSweepActive ? sweepProgress : -1.0;

                return CustomPaint(
                  painter: _HolographicShimmerPainter(
                    sweepProgress: activeSweepProgress,
                    radius: 24,
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: hasLabel ? 14 : 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: isSweepActive ? 0.22 : 0.10,
                        ),
                      ),
                      boxShadow: isSweepActive
                          ? const [
                              BoxShadow(
                                color: Color(0x3000E5FF),
                                blurRadius: 10,
                                spreadRadius: 0.5,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Shield icon with synchronized pulse and sparkle
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            ScaleTransition(
                              scale: _iconPulseAnimation,
                              child: Icon(
                                widget.icon,
                                size: 20,
                                color: isSweepActive
                                    ? const Color(0xFFE0F7FA) // Luminous cyan-tinted white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            // Micro 4-point sparkle star on badge corner
                            if (isSweepActive && _sparkleAnimation.value > 0.05)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Opacity(
                                  opacity: _sparkleAnimation.value.clamp(0.0, 1.0),
                                  child: CustomPaint(
                                    size: const Size(8, 8),
                                    painter: _SparkleStarPainter(
                                      progress: _sparkleAnimation.value,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (hasLabel) ...[
                          const SizedBox(width: 8),
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                              color: isSweepActive
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// High-performance painter rendering the angled holographic specular light beam
/// and border gleam across the button capsule without allocating new layers.
class _HolographicShimmerPainter extends CustomPainter {
  const _HolographicShimmerPainter({
    required this.sweepProgress,
    required this.radius,
  });

  final double sweepProgress; // -1.0 when inactive, 0.0 -> 1.0 during active sweep
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (sweepProgress < 0.0 || sweepProgress > 1.0) return;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    canvas.save();
    canvas.clipRRect(rrect);

    // Calculate light beam center position across width
    // Sweeps from -40% to +140% of capsule width for seamless entrance/exit
    final totalSpan = size.width + size.height * 0.8;
    final currentX = -size.height * 0.4 + totalSpan * sweepProgress;
    final beamWidth = math.max(36.0, size.width * 0.45);

    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-0.6, -1.0),
        end: const Alignment(0.6, 1.0),
        colors: [
          Colors.transparent,
          const Color(0x1500E5FF), // Subtle holographic cyan
          Colors.white.withValues(alpha: 0.38), // Crisp specular core
          const Color(0x207C4DFF), // Subtle iridescent violet
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(currentX, size.height / 2),
          width: beamWidth,
          height: size.height * 1.6,
        ),
      )
      ..blendMode = BlendMode.screen;

    // Draw the specular beam across the clipped capsule
    canvas.drawRect(Offset.zero & size, beamPaint);

    // Draw localized border sheen highlight along capsule perimeter
    final borderSheenPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (currentX / size.width) * 2.0 - 1.0,
          0.0,
        ),
        radius: 0.6,
        colors: [
          Colors.white.withValues(alpha: 0.75),
          const Color(0x4000E5FF),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..blendMode = BlendMode.screen;

    canvas.drawRRect(rrect, borderSheenPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HolographicShimmerPainter oldDelegate) {
    return oldDelegate.sweepProgress != sweepProgress;
  }
}

/// Micro 4-point diamond star sparkle painter for the shield icon.
class _SparkleStarPainter extends CustomPainter {
  const _SparkleStarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final armLength = (size.width / 2) * progress;
    final armWidth = (size.width * 0.18) * progress;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(center.dx, center.dy - armLength)
      ..quadraticBezierTo(
        center.dx + armWidth,
        center.dy - armWidth,
        center.dx + armLength,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + armWidth,
        center.dy + armWidth,
        center.dx,
        center.dy + armLength,
      )
      ..quadraticBezierTo(
        center.dx - armWidth,
        center.dy + armWidth,
        center.dx - armLength,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - armWidth,
        center.dy - armWidth,
        center.dx,
        center.dy - armLength,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkleStarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
