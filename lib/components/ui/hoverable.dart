import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

class HoverableController extends GetxController {
  bool isHovered = false;

  void setHovered(bool value) {
    isHovered = value;
    update();
  }
}

class Hoverable extends StatelessWidget {

  const Hoverable({
    required this.child, super.key,
    this.scaleOnHover = true,
    this.scaleFactor = 1.02,
    this.hoverColor,
    this.borderRadius,
    this.onTap,
  });
  final Widget child;
  final bool scaleOnHover;
  final double scaleFactor;
  final Color? hoverColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HoverableController>(
      init: HoverableController(),
      global: false,
      builder: (controller) {
        final defaultHoverColor =
            Theme.of(context).brightness == Brightness.dark
            ? AppColors.textPrimary.withValues(alpha: 0.05)
            : AppColors.bgPage.withValues(alpha: 0.05);

        var content = child;

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
