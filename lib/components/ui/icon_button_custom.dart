import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

enum IconButtonSize { small, medium, large }

enum IconButtonVariant { primary, secondary, danger, ghost }

/// IconButtonCustom: Standardized icon button with multiple variants
///
/// Provides:
/// - Multiple size variants (small, medium, large)
/// - Multiple style variants (primary, secondary, danger, ghost)
/// - Loading state support
/// - Accessibility with semantic labels
/// - Consistent hover/active states
class IconButtonCustom extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final IconButtonSize size;
  final IconButtonVariant variant;
  final bool isLoading;
  final String? tooltip;
  final Color? color;
  final double? iconSize;

  const IconButtonCustom({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = IconButtonSize.medium,
    this.variant = IconButtonVariant.primary,
    this.isLoading = false,
    this.tooltip,
    this.color,
    this.iconSize,
  });

  double _getPadding() {
    switch (size) {
      case IconButtonSize.small:
        return AppTheme.spacing.xs;
      case IconButtonSize.medium:
        return AppTheme.spacing.sm;
      case IconButtonSize.large:
        return AppTheme.spacing.md;
    }
  }

  double _getIconSize() {
    return iconSize ??
        switch (size) {
          IconButtonSize.small => AppTheme.sizes.iconSm,
          IconButtonSize.medium => AppTheme.sizes.iconMd,
          IconButtonSize.large => AppTheme.sizes.iconLg,
        };
  }

  Color _getColor() {
    if (color != null) return color!;

    return switch (variant) {
      IconButtonVariant.primary => AppTheme.colors.primary,
      IconButtonVariant.secondary => AppTheme.colors.textSecondary,
      IconButtonVariant.danger => AppTheme.colors.error,
      IconButtonVariant.ghost => AppTheme.colors.textSecondary,
    };
  }

  Color? _getBackgroundColor() {
    return switch (variant) {
      IconButtonVariant.primary => Colors.transparent,
      IconButtonVariant.secondary => Colors.transparent,
      IconButtonVariant.danger => Colors.transparent,
      IconButtonVariant.ghost => Colors.transparent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final RxBool isPressed = false.obs;

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: tooltip ?? 'Action button',
      child: Tooltip(
        message: tooltip ?? '',
        child: Obx(() {
          return AnimatedContainer(
            duration: AppTheme.animations.fast,
            decoration: BoxDecoration(
              color: _getBackgroundColor(),
              borderRadius: BorderRadius.circular(AppTheme.radius.md),
            ),
            child: MouseRegion(
              onEnter: (_) => isPressed.value = true,
              onExit: (_) => isPressed.value = false,
              cursor: onPressed != null && !isLoading
                  ? SystemMouseCursors.click
                  : MouseCursor.defer,
              child: InkWell(
                onTapDown: (_) => isPressed.value = true,
                onTapUp: (_) => isPressed.value = false,
                onTapCancel: () => isPressed.value = false,
                onTap: onPressed,
                child: Padding(
                  padding: EdgeInsets.all(_getPadding()),
                  child: AnimatedOpacity(
                    opacity: isLoading ? 0.6 : 1.0,
                    duration: AppTheme.animations.fast,
                    child: isLoading
                        ? SizedBox(
                            width: _getIconSize(),
                            height: _getIconSize(),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(_getColor()),
                            ),
                          )
                        : Icon(
                            icon,
                            size: _getIconSize(),
                            color: isPressed.value
                                ? _getColor().withValues(alpha: 0.7)
                                : _getColor(),
                          ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}





