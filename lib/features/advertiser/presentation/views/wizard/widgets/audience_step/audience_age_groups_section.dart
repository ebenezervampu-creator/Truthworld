import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_targeting_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

class AudienceAgeGroupsSection extends StatelessWidget {
  const AudienceAgeGroupsSection({
    required this.targetAllAges,
    required this.selectedAgeGroups,
    required this.availableAgeGroups,
    super.key,
  });

  final RxBool targetAllAges;
  final RxList<String> selectedAgeGroups;
  final List<String> availableAgeGroups;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isAllSelected = targetAllAges.value;
      return CampaignWizardAudienceSectionCard(
        title: 'Audience Age Groups',
        subtitle:
            'Select specific age brackets or reach all ages across Truthworld.',
        icon: Icons.calendar_today_rounded,
        isAllSelected: isAllSelected,
        allSelectedLabel: 'All Ages (Broad Reach)',
        onToggleAll: (val) {
          targetAllAges.value = val;
          if (val) {
            selectedAgeGroups.clear();
          }
        },
        content: isAllSelected
            ? const SizedBox.shrink()
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableAgeGroups.map((ageGrp) {
                  final isSelected = selectedAgeGroups.contains(ageGrp);
                  return FilterChip(
                    label: Text(
                      ageGrp,
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
                        selectedAgeGroups.add(ageGrp);
                      } else {
                        selectedAgeGroups.remove(ageGrp);
                      }
                    },
                  );
                }).toList(),
              ),
      );
    });
  }
}
