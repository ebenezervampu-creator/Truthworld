import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Reusable interactive studio card providing executive hover lift,
/// luminous border highlights, subtle elevation shadows, and tap-down compression.
/// Designed with 100% Zero-setState declarative reactivity and strict UI contrast compliance.
class StudioInteractiveCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final double hoverElevation;
  final EdgeInsetsGeometry? padding;
  final bool enableHover;
  final bool enablePressScale;

  const StudioInteractiveCard({
    required this.child,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.hoverBorderColor,
    this.hoverElevation = -3.0,
    this.padding,
    this.enableHover = true,
    this.enablePressScale = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(12);
    final isHovered = ValueNotifier<bool>(false);
    final isPressed = ValueNotifier<bool>(false);

    return ValueListenableBuilder<bool>(
      valueListenable: isHovered,
      builder: (context, hovered, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isPressed,
          builder: (context, pressed, _) {
            final effectiveOffset = (enableHover && hovered && !pressed)
                ? Offset(0, hoverElevation)
                : Offset.zero;
            final effectiveScale = (enablePressScale && pressed) ? 0.985 : 1.0;

            final effectiveBorder = Border.all(
              color: (hovered && enableHover)
                  ? (hoverBorderColor ??
                      AppColors.textPrimary.withValues(alpha: 0.28))
                  : (borderColor ?? AppColors.bgDivider),
              width: 1,
            );

            final effectiveShadow = (hovered && enableHover && !pressed)
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const <BoxShadow>[];

            return MouseRegion(
              cursor: onTap != null
                  ? SystemMouseCursors.click
                  : MouseCursor.defer,
              onEnter: (_) {
                if (enableHover) isHovered.value = true;
              },
              onExit: (_) {
                if (enableHover) {
                  isHovered.value = false;
                  isPressed.value = false;
                }
              },
              child: Listener(
                onPointerDown: (_) {
                  if (enablePressScale && onTap != null) isPressed.value = true;
                },
                onPointerUp: (_) {
                  if (enablePressScale) isPressed.value = false;
                },
                onPointerCancel: (_) {
                  if (enablePressScale) isPressed.value = false;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(
                    effectiveOffset.dx,
                    effectiveOffset.dy,
                    0,
                  )..scale(effectiveScale),
                  decoration: BoxDecoration(
                    color: backgroundColor ?? AppColors.bgSurface,
                    borderRadius: effectiveRadius,
                    border: effectiveBorder,
                    boxShadow: effectiveShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: effectiveRadius,
                      onTap: onTap,
                      child: Padding(
                        padding: padding ?? EdgeInsets.zero,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
