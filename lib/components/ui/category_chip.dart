import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? unselectedColor;

  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
    this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBgColor = selectedColor ?? AppColors.brand;
    final unselectedBgColor = unselectedColor ?? AppColors.bgSurface;

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
            color: isSelected ? Colors.transparent : AppColors.bgDivider,
            width: 1.0,
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
                ? AppColors.brand.withValues(alpha: 0.9)
                : AppColors.textPrimary.withValues(alpha: 0.05),
            splashColor: isSelected
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.brand.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space8,
              ),
              child: Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: AppTheme.labelLarge,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
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






