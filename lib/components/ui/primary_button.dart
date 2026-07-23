import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

enum ButtonVariant { primary, secondary, icon, danger, ghost }

enum ButtonSize { small, medium, large }

/// PrimaryButton: Standardized button component with multiple variants
///
/// Features:
/// - Multiple size variants (small, medium, large)
/// - Multiple style variants (primary, secondary, danger, ghost, icon)
/// - Loading state with spinner
/// - Full-width support
/// - Icon + text support
/// - Semantic accessibility
/// - Token-based styling
@immutable
class PrimaryButton extends StatelessWidget {

  const PrimaryButton({
    required this.label, super.key,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.isDisabled = false,
    this.tooltipMessage,
  });
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final bool isDisabled;
  final String? tooltipMessage;

  @override
  Widget build(BuildContext context) {
    // Icon-only variant handled separately
    if (variant == ButtonVariant.icon && icon != null) {
      return Semantics(
        button: true,
        enabled: onPressed != null && !isLoading && !isDisabled,
        label: label,
        child: Tooltip(
          message: tooltipMessage ?? label,
          child: IconButton(
            onPressed: (isLoading || isDisabled) ? null : onPressed,
            icon: _buildIconContent(),
            padding: EdgeInsets.all(_getIconPadding()),
            tooltip: tooltipMessage ?? label,
            color: _getIconColor(),
            hoverColor: AppTheme.colors.surface.withValues(alpha: 0.8),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading && !isDisabled,
      label: label,
      onTap: (isLoading || isDisabled) ? null : onPressed,
      child: _buildButton(context),
    );
  }

  Widget _buildButton(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading && !isDisabled;
    final style = _getButtonStyle();

    final child = isLoading
        ? SizedBox(
            width: _getIconSize(),
            height: _getIconSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_getLoadingIndicatorColor()),
            ),
          )
        : _buildButtonContent();

    final actionButton = ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: style,
      child: child,
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: actionButton);
    }

    return actionButton;
  }

  Widget _buildButtonContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: _getIconSize()),
          SizedBox(width: AppTheme.spacing.xs),
        ],
        Text(label, style: AppTheme.typography.label, semanticsLabel: label),
      ],
    );
  }

  Widget _buildIconContent() {
    return isLoading
        ? SizedBox(
            width: _getIconSize(),
            height: _getIconSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_getLoadingIndicatorColor()),
            ),
          )
        : Icon(icon);
  }

  ButtonStyle _getButtonStyle() {
    final padding = switch (size) {
      ButtonSize.small => AppTheme.components.buttonPaddingSmall,
      ButtonSize.medium => AppTheme.components.buttonPaddingMedium,
      ButtonSize.large => AppTheme.components.buttonPaddingLarge,
    };

    final height = switch (size) {
      ButtonSize.small => 32.0,
      ButtonSize.medium => 40.0,
      ButtonSize.large => 48.0,
    };

    final backgroundColor = switch (variant) {
      ButtonVariant.primary => AppTheme.colors.primary,
      ButtonVariant.secondary => Colors.transparent,
      ButtonVariant.danger => AppTheme.colors.error,
      ButtonVariant.ghost => Colors.transparent,
      ButtonVariant.icon => Colors.transparent,
    };

    final foregroundColor = switch (variant) {
      ButtonVariant.primary => AppTheme.colors.textPrimary,
      ButtonVariant.secondary => AppTheme.colors.primary,
      ButtonVariant.danger => AppTheme.colors.textPrimary,
      ButtonVariant.ghost => AppTheme.colors.textSecondary,
      ButtonVariant.icon => AppTheme.colors.textSecondary,
    };

    final borderColor = switch (variant) {
      ButtonVariant.secondary => AppTheme.colors.primary,
      ButtonVariant.ghost => Colors.transparent,
      _ => null,
    };

    final baseStyle =
        ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: EdgeInsets.symmetric(horizontal: padding * 1.5, vertical: padding),
          minimumSize: Size(0, height),
          fixedSize: isFullWidth ? Size.fromHeight(height) : null,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radius.circularMd,
          ),
          elevation: 0,
          side: borderColor != null
              ? BorderSide(color: borderColor, width: 1.5)
              : BorderSide.none,
          disabledBackgroundColor: AppTheme.colors.surface.withValues(
            alpha: 0.5,
          ),
          disabledForegroundColor: AppTheme.colors.textTertiary,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.hovered)) {
              return foregroundColor.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.pressed)) {
              return foregroundColor.withValues(alpha: 0.12);
            }
            return null;
          }),
        );

    return baseStyle;
  }

  double _getIconSize() {
    return switch (size) {
      ButtonSize.small => AppTheme.sizes.iconSm,
      ButtonSize.medium => AppTheme.sizes.iconMd,
      ButtonSize.large => AppTheme.sizes.iconLg,
    };
  }

  double _getIconPadding() {
    return switch (size) {
      ButtonSize.small => AppTheme.spacing.xs,
      ButtonSize.medium => AppTheme.spacing.sm,
      ButtonSize.large => AppTheme.spacing.md,
    };
  }

  Color _getIconColor() {
    return switch (variant) {
      ButtonVariant.icon => AppTheme.colors.textSecondary,
      ButtonVariant.primary => AppTheme.colors.primary,
      ButtonVariant.danger => AppTheme.colors.error,
      _ => AppTheme.colors.textSecondary,
    };
  }

  Color _getLoadingIndicatorColor() {
    return switch (variant) {
      ButtonVariant.primary ||
      ButtonVariant.danger => AppTheme.colors.textPrimary,
      _ => AppTheme.colors.primary,
    };
  }
}





