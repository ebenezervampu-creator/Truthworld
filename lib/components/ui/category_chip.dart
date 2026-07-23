import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// CategoryChip: Reusable, optimized chip component
///
/// Features:
/// - Selected/unselected states with smooth transitions
/// - Crimson Noir token-based styling
/// - Accessibility support
/// - Performance optimized with @immutable
@immutable
class CategoryChip extends StatelessWidget {

  const CategoryChip({
    required this.label, required this.isSelected, required this.onTap, super.key,
    this.selectedColor,
    this.unselectedColor,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.twColors;
    final typography = context.twTypography;

    final selectedBgColor = selectedColor ?? colors.brand;
    final unselectedBgColor = unselectedColor ?? colors.surface;

    return Semantics(
      button: true,
      enabled: true,
      label: '$label ${isSelected ? "selected" : ""}',
      selected: isSelected,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.animDuration,
        curve: AppTheme.animCurveEaseOut,
        margin: const EdgeInsets.only(right: AppTheme.space8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : unselectedBgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: isSelected ? Colors.transparent : colors.divider,
          ),
          boxShadow: isSelected ? AppTheme.elevationSmall : [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            hoverColor: isSelected
                ? colors.brand.withValues(alpha: 0.9)
                : colors.textPrimary.withValues(alpha: 0.05),
            splashColor: isSelected
                ? colors.textPrimary.withValues(alpha: 0.1)
                : colors.brand.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space8,
              ),
              child: Text(
                label,
                style: typography.label.copyWith(
                  color: isSelected
                      ? colors.textPrimary
                      : colors.textSecondary,
                  letterSpacing: 0.1,
                ),
                semanticsLabel: label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}






