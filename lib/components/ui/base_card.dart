import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// BaseCard: Reusable card component with consistent styling
///
/// Provides:
/// - Consistent dark theme styling
/// - Elevation/shadow support
/// - Border, padding, and radius tokens
/// - Optional hover/tap effects
/// - Semantic accessibility support
class BaseCard extends StatelessWidget {
  const BaseCard({
    required this.child,
    super.key,
    this.onTap,
    this.onDoubleTap,
    this.enableHoverEffect = true,
    this.padding,
    this.border,
    this.backgroundColor,
    this.shadows,
    this.borderRadius,
    this.semanticLabel,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool enableHoverEffect;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;
  final Color? backgroundColor;
  final List<BoxShadow>? shadows;
  final double? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isInteractive = onTap != null || onDoubleTap != null;

    return Semantics(
      container: true,
      button: isInteractive,
      label: semanticLabel,
      enabled: isInteractive,
      child: AnimatedContainer(
        duration: AppTheme.animations.normal,
        curve: AppTheme.animations.easeOutCubic,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppTheme.colors.surface,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppTheme.radius.lg,
          ),
          border:
              border ??
              Border.all(
                color: AppTheme.colors.border.withValues(alpha: 0.3),
              ),
          boxShadow: shadows ?? AppTheme.shadows.elevationMd,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppTheme.radius.lg,
          ),
          child: InkWell(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            borderRadius: BorderRadius.circular(
              borderRadius ?? AppTheme.radius.lg,
            ),
            hoverColor: enableHoverEffect
                ? AppTheme.colors.surface.withValues(alpha: 0.8)
                : Colors.transparent,
            splashColor: enableHoverEffect
                ? AppTheme.colors.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            child: Padding(
              padding:
                  padding ?? EdgeInsets.all(AppTheme.components.cardPadding),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
