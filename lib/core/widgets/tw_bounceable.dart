import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Tactile bounce interaction widget with spring feedback and zero setState.
/// Uses GetX reactive primitives and [AnimatedScale] for buttery smooth 60/120fps physics.
class TWBounceable extends StatelessWidget {
  TWBounceable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.96,
    this.duration = const Duration(milliseconds: 100),
    this.reverseDuration = const Duration(milliseconds: 160),
    this.curve = Curves.easeOutCubic,
    this.enabled = true,
    this.enableHaptics = true,
    this.hitTestBehavior = HitTestBehavior.opaque,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final Duration duration;
  final Duration reverseDuration;
  final Curve curve;
  final bool enabled;
  final bool enableHaptics;
  final HitTestBehavior hitTestBehavior;

  final RxBool _isPressed = false.obs;

  void _handleTapDown(TapDownDetails details) {
    if (!enabled || onTap == null) return;
    _isPressed.value = true;
    if (enableHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!enabled) return;
    _isPressed.value = false;
  }

  void _handleTapCancel() {
    if (!enabled) return;
    _isPressed.value = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled || (onTap == null && onLongPress == null)) {
      return child;
    }

    return GestureDetector(
      behavior: hitTestBehavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Obx(
        () => AnimatedScale(
          scale: _isPressed.value ? scaleFactor : 1.0,
          duration: _isPressed.value ? duration : reverseDuration,
          curve: curve,
          child: child,
        ),
      ),
    );
  }
}
