import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HoverableController extends GetxController {
  bool isHovered = false;

  void setHovered(bool value) {
    isHovered = value;
    update();
  }
}

class Hoverable extends StatelessWidget {
  final Widget child;
  final bool scaleOnHover;
  final double scaleFactor;
  final Color? hoverColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const Hoverable({
    super.key,
    required this.child,
    this.scaleOnHover = true,
    this.scaleFactor = 1.02,
    this.hoverColor,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HoverableController>(
      init: HoverableController(),
      global: false,
      builder: (controller) {
        final defaultHoverColor =
            Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05);

        Widget content = child;

        if (scaleOnHover) {
          content = AnimatedScale(
            scale: controller.isHovered ? scaleFactor : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: content,
          );
        }

        if (hoverColor != null || !scaleOnHover) {
          content = AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: controller.isHovered
                  ? (hoverColor ?? defaultHoverColor)
                  : Colors.transparent,
              borderRadius: borderRadius ?? BorderRadius.circular(8),
            ),
            child: content,
          );
        }

        return MouseRegion(
          onEnter: (_) => controller.setHovered(true),
          onExit: (_) => controller.setHovered(false),
          cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
          child: GestureDetector(onTap: onTap, child: content),
        );
      },
    );
  }
}
