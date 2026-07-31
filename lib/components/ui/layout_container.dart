import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class LayoutContainer extends StatelessWidget {
  const LayoutContainer({
    required this.child,
    super.key,
    this.maxWidth = 1400,
    this.padding,
    this.alignment = Alignment.center,
    this.height,
  });
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        height: height,
        constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
        padding:
            padding ??
            EdgeInsets.symmetric(horizontal: _getResponsivePadding(context)),
        child: child,
      ),
    );
  }

  double _getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return AppTheme.spacing.lg;
    if (width >= 768) return AppTheme.spacing.md;
    return AppTheme.spacing.sm;
  }
}

/// ContentSection: Standardized section wrapper with consistent spacing
///
/// Used for:
/// - Grouping related content
/// - Consistent vertical spacing between sections
/// - Semantic structure
class ContentSection extends StatelessWidget {
  const ContentSection({
    required this.child,
    super.key,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.withBorder = false,
    this.semanticLabel,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double? borderRadius;
  final bool withBorder;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: padding ?? EdgeInsets.all(AppTheme.spacing.md),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppTheme.colors.surface,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppTheme.radius.lg,
          ),
          border: withBorder
              ? Border.all(
                  color: AppTheme.colors.border.withValues(alpha: 0.3),
                )
              : null,
        ),
        child: child,
      ),
    );
  }
}
