import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_rejection_banner.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_targeting_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Step 3: Audience & Demographics targeting configuration.
class CampaignWizardAudienceStep extends StatelessWidget {
  final AdItem? existingCampaign;
  final RxBool targetAllAges;
  final RxList<String> selectedAgeGroups;
  final RxBool targetAllGenders;
  final RxList<String> selectedGenders;
  final RxBool targetWorldwide;
  final RxList<String> selectedLocations;
  final TextEditingController customLocationController;
  final RxBool targetAllLanguages;
  final RxList<String> selectedLanguages;
  final RxBool targetAllTopics;
  final RxList<String> selectedTopics;
  final List<String> availableAgeGroups;
  final List<String> availableGenders;
  final List<String> popularLocations;
  final List<Map<String, String>> availableLanguages;
  final List<String> availableTopics;

  const CampaignWizardAudienceStep({
    required this.existingCampaign,
    required this.targetAllAges,
    required this.selectedAgeGroups,
    required this.targetAllGenders,
    required this.selectedGenders,
    required this.targetWorldwide,
    required this.selectedLocations,
    required this.customLocationController,
    required this.targetAllLanguages,
    required this.selectedLanguages,
    required this.targetAllTopics,
    required this.selectedTopics,
    required this.availableAgeGroups,
    required this.availableGenders,
    required this.popularLocations,
    required this.availableLanguages,
    required this.availableTopics,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampaignRejectionBanner(existingCampaign: existingCampaign),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Target Audience & Demographics',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Define who sees your ad based on age groups, gender, geography, and interests.',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              // Estimated Reach Counter
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF27272A),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.track_changes_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated Reach',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          (targetAllAges.value &&
                                  targetAllGenders.value &&
                                  targetWorldwide.value)
                              ? '250K+ Viewers'
                              : '${(50 + (selectedAgeGroups.length * 15) + (selectedLocations.length * 20)).clamp(20, 240)}K Viewers',
                          style: const TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. AGE GROUPS SECTION
          CampaignWizardAudienceSectionCard(
            title: 'Audience Age Groups',
            subtitle:
                'Select specific age brackets or reach all ages across Truthworld.',
            icon: Icons.calendar_today_rounded,
            isAllSelected: targetAllAges.value,
            allSelectedLabel: 'All Ages (Broad Reach)',
            onToggleAll: (val) {
              targetAllAges.value = val;
              if (val) {
                selectedAgeGroups.clear();
              }
            },
            content: targetAllAges.value
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
          ),
          const SizedBox(height: 16),

          // 2. GENDER SECTION
          CampaignWizardAudienceSectionCard(
            title: 'Gender Demographics',
            subtitle:
                'Target viewers based on user-specified gender identity.',
            icon: Icons.wc_rounded,
            isAllSelected: targetAllGenders.value,
            allSelectedLabel: 'All Genders (Recommended)',
            onToggleAll: (val) {
              targetAllGenders.value = val;
              if (val) {
                selectedGenders.clear();
              }
            },
            content: targetAllGenders.value
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
                        backgroundColor: const Color(0xFF18181B),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.brand
                              : const Color(0xFF27272A),
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
          ),
          const SizedBox(height: 16),

          // 3. LOCATION & GEOGRAPHY SECTION
          CampaignWizardAudienceSectionCard(
            title: 'Locations & Geography',
            subtitle:
                'Target global audiences or specific countries and cities.',
            icon: Icons.public_rounded,
            isAllSelected: targetWorldwide.value,
            allSelectedLabel: 'Worldwide / All Locations',
            onToggleAll: (val) {
              targetWorldwide.value = val;
              if (val) {
                selectedLocations.clear();
              }
            },
            content: targetWorldwide.value
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Popular Countries:',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: popularLocations.map((loc) {
                          final isSelected = selectedLocations.contains(loc);
                          return FilterChip(
                            label: Text(
                              loc,
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
                                selectedLocations.add(loc);
                              } else {
                                selectedLocations.remove(loc);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customLocationController,
                              inputFormatters:
                                  TruthworldTextInputFormatters.standard,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter city, state or country...',
                                hintStyle: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF18181B),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF27272A),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF27272A),
                                  ),
                                ),
                              ),
                              onSubmitted: (val) {
                                final trimmed = val.trim();
                                if (trimmed.isNotEmpty) {
                                  final locVal = ContentValidator.validate(
                                    trimmed,
                                    checkEnglishOnly: false,
                                    fieldName: 'Location',
                                  );
                                  if (!locVal.isValid) {
                                    AppSnackbar.warning(locVal.message);
                                    return;
                                  }
                                  if (!selectedLocations.contains(trimmed)) {
                                    selectedLocations.add(trimmed);
                                    customLocationController.clear();
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              final trimmed =
                                  customLocationController.text.trim();
                              if (trimmed.isNotEmpty) {
                                final locVal = ContentValidator.validate(
                                  trimmed,
                                  checkEnglishOnly: false,
                                  fieldName: 'Location',
                                );
                                if (!locVal.isValid) {
                                  AppSnackbar.warning(locVal.message);
                                  return;
                                }
                                if (!selectedLocations.contains(trimmed)) {
                                  selectedLocations.add(trimmed);
                                  customLocationController.clear();
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: const Text(
                              'Add',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27272A),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (selectedLocations.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: selectedLocations.map((loc) {
                            return Chip(
                              label: Text(
                                loc,
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              deleteIcon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              onDeleted: () => selectedLocations.remove(loc),
                              backgroundColor: const Color(0xFF27272A),
                              padding: const EdgeInsets.all(4),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // 4. LANGUAGES SECTION
          CampaignWizardAudienceSectionCard(
            title: 'Target Languages',
            subtitle: 'Serve ads to viewers who speak specific languages.',
            icon: Icons.translate_rounded,
            isAllSelected: targetAllLanguages.value,
            allSelectedLabel: 'All Languages',
            onToggleAll: (val) {
              targetAllLanguages.value = val;
              if (val) {
                selectedLanguages.clear();
              }
            },
            content: targetAllLanguages.value
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
          ),
          const SizedBox(height: 16),

          // 5. TOPIC INTERESTS SECTION
          CampaignWizardAudienceSectionCard(
            title: 'Topic & Category Interests',
            subtitle:
                'Align your campaign with specific video categories and genres.',
            icon: Icons.tag_rounded,
            isAllSelected: targetAllTopics.value,
            allSelectedLabel: 'All Categories & Topics',
            onToggleAll: (val) {
              targetAllTopics.value = val;
              if (val) {
                selectedTopics.clear();
              }
            },
            content: targetAllTopics.value
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
          ),
        ],
      );
    });
  }
}
