import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Audience section card container with toggle-all chip.
class CampaignWizardAudienceSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isAllSelected;
  final String allSelectedLabel;
  final ValueChanged<bool> onToggleAll;
  final Widget content;

  const CampaignWizardAudienceSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isAllSelected,
    required this.allSelectedLabel,
    required this.onToggleAll,
    required this.content,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              FilterChip(
                label: Text(
                  allSelectedLabel,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 11,
                    fontWeight: isAllSelected ? FontWeight.bold : FontWeight.normal,
                    color: isAllSelected ? Colors.black : Colors.white70,
                  ),
                ),
                selected: isAllSelected,
                showCheckmark: isAllSelected,
                checkmarkColor: isAllSelected ? Colors.black : Colors.white,
                selectedColor: AppColors.brand,
                backgroundColor: const Color(0xFF27272A),
                side: BorderSide(
                  color: isAllSelected ? AppColors.brand : const Color(0xFF3F3F46),
                ),
                onSelected: onToggleAll,
              ),
            ],
          ),
          if (!isAllSelected) ...[
            const Divider(color: Color(0xFF27272A), height: 24),
            content,
          ],
        ],
      ),
    );
  }
}

/// Compact audience badge chip for summary views.
class CampaignWizardAudienceBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const CampaignWizardAudienceBadge({
    required this.icon,
    required this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3F3F46)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
