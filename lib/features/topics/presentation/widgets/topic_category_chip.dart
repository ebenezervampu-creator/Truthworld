import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Reusable Topic Category Capsule Chip Widget
class TopicCategoryChip extends StatelessWidget {

  const TopicCategoryChip({
    required this.category, super.key,
    this.isCompact = false,
  });
  final String category;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (category.trim().isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 9,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.textPrimary.withValues(alpha: 0.12)
            : AppColors.bgPage.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? AppColors.textPrimary.withValues(alpha: 0.15)
              : AppColors.bgPage.withValues(alpha: 0.1),
          width: 0.8,
        ),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: isCompact ? 9.5 : 11,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.textPrimary : const Color(0xFF1F2937),
        ),
      ),
    );
  }
}
