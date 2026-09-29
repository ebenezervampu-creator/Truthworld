import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class DoubleTapRipple extends StatefulWidget {
  const DoubleTapRipple({
    required this.isLeft,
    this.seconds = 10,
    super.key,
  });

  final bool isLeft;
  final int seconds;

  @override
  State<DoubleTapRipple> createState() => _DoubleTapRippleState();
}

class _DoubleTapRippleState extends State<DoubleTapRipple>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat();
  }

  @override
  void didUpdateWidget(DoubleTapRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_animCtrl.isAnimating) {
      _animCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLeft = widget.isLeft;
    final seconds = widget.seconds;

    return Positioned(
      top: 0,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.45,
      child: RepaintBoundary(
        child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipPath(
            clipper: _SeekRippleClipper(isLeft: isLeft),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated 3-chevron wave pulse
                    AnimatedBuilder(
                      animation: _animCtrl,
                      builder: (context, child) {
                        final progress = _animCtrl.value;

                        double getArrowOpacity(int index) {
                          final offset = index * 0.22;
                          final localProgress = (progress - offset) % 1.0;
                          if (localProgress < 0.0) return 0.2;
                          if (localProgress <= 0.35) {
                            return 0.2 + (0.8 * (localProgress / 0.35));
                          } else if (localProgress <= 0.7) {
                            return 1.0 - (0.8 * ((localProgress - 0.35) / 0.35));
                          }
                          return 0.2;
                        }

                        final arrowIcons = List.generate(3, (index) {
                          // For left: wave travels from inner (index 2) to outer (index 0)
                          // For right: wave travels from inner (index 0) to outer (index 2)
                          final arrowIdx = isLeft ? (2 - index) : index;
                          final opacity = getArrowOpacity(arrowIdx);

                          return Opacity(
                            opacity: opacity.clamp(0.2, 1.0),
                            child: Icon(
                              isLeft
                                  ? Icons.arrow_left_rounded
                                  : Icons.arrow_right_rounded,
                              color: AppColors.textPrimary,
                              size: 40,
                            ),
                          );
                        });

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: arrowIcons,
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    // Accumulated seconds text with smooth pop/scale transition
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: child,
                      ),
                      child: Text(
                        '$seconds seconds',
                        key: ValueKey<int>(seconds),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
}

class _SeekRippleClipper extends CustomClipper<Path> {
  _SeekRippleClipper({required this.isLeft});
  final bool isLeft;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (isLeft) {
      // Parabolic curved arc towards the center right
      path.moveTo(0, 0);
      path.lineTo(size.width * 0.72, 0);
      path.quadraticBezierTo(
        size.width * 1.12,
        size.height / 2,
        size.width * 0.72,
        size.height,
      );
      path.lineTo(0, size.height);
      path.close();
    } else {
      // Parabolic curved arc towards the center left
      path.moveTo(size.width, 0);
      path.lineTo(size.width * 0.28, 0);
      path.quadraticBezierTo(
        -size.width * 0.12,
        size.height / 2,
        size.width * 0.28,
        size.height,
      );
      path.lineTo(size.width, size.height);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(_SeekRippleClipper oldClipper) =>
      oldClipper.isLeft != isLeft;
}

// ─────────────────────────────────────────────────────────────────────────────
// SEEK PREVIEW TOOLTIP
// ─────────────────────────────────────────────────────────────────────────────
