import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 3D Animated Flip Coin Widget for Truthworld "The Other Side" feature.
///
/// When tapped:
/// - Plays a smooth 3D 180-degree flip animation
/// - Toggles between "My Side / Truth" (Front) and "The Other Side / Opposite" (Back)
/// - Triggers callback and updates state
///
/// ICON COLOR RULE: Always uses white/textPrimary for icons (never brand color).
class FlipCoinWidget extends StatefulWidget {
  final bool isFlipped;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;
  final bool showLabel;

  const FlipCoinWidget({
    super.key,
    required this.isFlipped,
    required this.onTap,
    this.size = 36.0,
    this.tooltip,
    this.showLabel = false,
  });

  @override
  State<FlipCoinWidget> createState() => _FlipCoinWidgetState();
}

class _FlipCoinWidgetState extends State<FlipCoinWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );

    if (widget.isFlipped) {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(FlipCoinWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final defaultTooltip = widget.isFlipped
        ? '🪙 Showing The Other Side (Tap to flip back)'
        : '🪙 Flip Coin to see The Other Side (Opposite perspective)';

    return Tooltip(
      message: widget.tooltip ?? defaultTooltip,
      child: GestureDetector(
        onTap: _handleTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final angle = _animation.value * pi;
                  final isFront = angle < (pi / 2);

                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002) // 3D Perspective
                      ..rotateY(angle),
                    alignment: Alignment.center,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isFront
                              ? [
                                  const Color(0xFFFFD700), // Gold top-left
                                  const Color(0xFFB8860B), // Gold bottom-right
                                ]
                              : [
                                  const Color(
                                    0xFF9C27B0,
                                  ), // Purple top-left (Flip side)
                                  const Color(
                                    0xFF4A148C,
                                  ), // Dark Purple bottom-right
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isFront
                                        ? const Color(0xFFFFD700)
                                        : const Color(0xFF9C27B0))
                                    .withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Transform(
                          // Counter-rotate back side text so it isn't mirrored
                          transform: isFront
                              ? Matrix4.identity()
                              : (Matrix4.identity()..rotateY(pi)),
                          alignment: Alignment.center,
                          child: Icon(
                            isFront
                                ? Icons.monetization_on_rounded
                                : Icons.published_with_changes_rounded,
                            // RULE ENFORCEMENT: Icon is ALWAYS white
                            color: Colors.white,
                            size: widget.size * 0.6,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (widget.showLabel) ...[
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isFlipped
                        ? const Color(0xFF9C27B0).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isFlipped
                          ? const Color(0xFF9C27B0)
                          : Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.isFlipped ? 'Opposite Side' : 'Flip Perspective',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: widget.isFlipped
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
