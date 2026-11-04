import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single step indicator tab in the campaign wizard dialog.
class CampaignWizardStepTab extends StatelessWidget {
  final int stepIndex;
  final String title;
  final IconData icon;
  final int currentStep;
  final VoidCallback onTap;

  final bool isExpanded;

  const CampaignWizardStepTab({
    required this.stepIndex,
    required this.title,
    required this.icon,
    required this.currentStep,
    required this.onTap,
    this.isExpanded = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentStep == stepIndex;
    final isDone = currentStep > stepIndex;
    final content = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.brand.withValues(alpha: 0.12)
              : isDone
              ? AppColors.bgPage
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.brand
                : isDone
                ? AppColors.bgSurface
                : AppColors.bgSurface,
          ),
        ),
        child: Row(
          mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDone ? Icons.check_circle_rounded : icon,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            if (isExpanded)
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: isActive
                        ? AppColors.brand
                        : isDone
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isActive || isDone
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Text(
                title,
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: isActive
                    ? AppColors.brand
                    : isDone
                    ? Colors.white
                    : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isActive || isDone
                    ? FontWeight.bold
                    : FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
    );

    return isExpanded ? Expanded(child: content) : content;
  }
}
