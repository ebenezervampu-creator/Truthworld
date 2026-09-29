import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_targeting_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

class AudienceTopicsSection extends StatelessWidget {
  const AudienceTopicsSection({
    required this.targetAllTopics,
    required this.selectedTopics,
    required this.availableTopics,
    super.key,
  });

  final RxBool targetAllTopics;
  final RxList<String> selectedTopics;
  final List<String> availableTopics;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isAllTopics = targetAllTopics.value;
      return CampaignWizardAudienceSectionCard(
        title: 'Topic & Category Interests',
        subtitle:
            'Align your campaign with specific video categories and genres.',
        icon: Icons.tag_rounded,
        isAllSelected: isAllTopics,
        allSelectedLabel: 'All Categories & Topics',
        onToggleAll: (val) {
          targetAllTopics.value = val;
          if (val) {
            selectedTopics.clear();
          }
        },
        content: isAllTopics
            ? const SizedBox.shrink()
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableTopics.map((topic) {
                  final isSelected = selectedTopics.contains(topic);
                  return FilterChip(
                    label: Text(
                      topic,
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    showCheckmark: isSelected,
                    checkmarkColor: isSelected ? Colors.black : Colors.white,
                    selectedColor: AppColors.brand,
                    backgroundColor: const Color(0xFF18181B),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.brand
                          : const Color(0xFF27272A),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        selectedTopics.add(topic);
                      } else {
                        selectedTopics.remove(topic);
                      }
                    },
                  );
                }).toList(),
              ),
      );
    });
  }
}
