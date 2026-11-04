import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_targeting_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

class AudienceGenderSection extends StatelessWidget {
  const AudienceGenderSection({
    required this.targetAllGenders,
    required this.selectedGenders,
    required this.availableGenders,
    super.key,
  });

  final RxBool targetAllGenders;
  final RxList<String> selectedGenders;
  final List<String> availableGenders;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isAllSelected = targetAllGenders.value;
      return CampaignWizardAudienceSectionCard(
        title: 'Gender Demographics',
        subtitle:
            'Target viewers based on user-specified gender identity.',
        icon: Icons.wc_rounded,
        isAllSelected: isAllSelected,
        allSelectedLabel: 'All Genders (Recommended)',
        onToggleAll: (val) {
          targetAllGenders.value = val;
          if (val) {
            selectedGenders.clear();
          }
        },
        content: isAllSelected
            ? const SizedBox.shrink()
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableGenders.map((gender) {
                  final isSelected = selectedGenders.contains(gender);
                  return FilterChip(
                    label: Text(
                      gender,
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
                    backgroundColor: AppColors.bgPage,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.brand
                          : AppColors.bgSurface,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        selectedGenders.add(gender);
                      } else {
                        selectedGenders.remove(gender);
                      }
                    },
                  );
                }).toList(),
              ),
      );
    });
  }
}
