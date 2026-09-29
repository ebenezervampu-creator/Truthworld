import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_targeting_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

class AudienceLanguagesSection extends StatelessWidget {
  const AudienceLanguagesSection({
    required this.targetAllLanguages,
    required this.selectedLanguages,
    required this.availableLanguages,
    super.key,
  });

  final RxBool targetAllLanguages;
  final RxList<String> selectedLanguages;
  final List<Map<String, String>> availableLanguages;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isAllLanguages = targetAllLanguages.value;
      return CampaignWizardAudienceSectionCard(
        title: 'Target Languages',
        subtitle: 'Serve ads to viewers who speak specific languages.',
        icon: Icons.translate_rounded,
        isAllSelected: isAllLanguages,
        allSelectedLabel: 'All Languages',
        onToggleAll: (val) {
          targetAllLanguages.value = val;
          if (val) {
            selectedLanguages.clear();
          }
        },
        content: isAllLanguages
            ? const SizedBox.shrink()
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableLanguages.map((lang) {
                  final code = lang['code']!;
                  final name = lang['name']!;
                  final isSelected = selectedLanguages.contains(code);
                  return FilterChip(
                    label: Text(
                      name,
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
                        selectedLanguages.add(code);
                      } else {
                        selectedLanguages.remove(code);
                      }
                    },
                  );
                }).toList(),
              ),
      );
    });
  }
}
