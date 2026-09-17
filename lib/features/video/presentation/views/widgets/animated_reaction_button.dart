import 'package:flutter/material.dart';

class AnimatedReactionButton extends StatefulWidget {
  const AnimatedReactionButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    required this.borderRadius,
    super.key,
    this.label,
  });

  final IconData icon;
  final String? label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  State<AnimatedReactionButton> createState() => AnimatedReactionButtonState();
}

class AnimatedReactionButtonState extends State<AnimatedReactionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.4,
          end: 1,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant AnimatedReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive && widget.isActive) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLabel = widget.label != null && widget.label!.isNotEmpty;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: widget.borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.isActive
                    ? widget.activeColor
                    : widget.inactiveColor,
              ),
            ),
            if (hasLabel) ...[
              const SizedBox(width: 6),
              Text(
                widget.label!,
                style: TextStyle(
                  color: widget.isActive
                      ? widget.activeColor
                      : widget.inactiveColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
