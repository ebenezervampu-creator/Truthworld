import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_targeting_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

class AudienceCategoriesSection extends StatelessWidget {
  const AudienceCategoriesSection({
    required this.targetAllAudiences,
    required this.selectedAudiences,
    required this.availableAudiences,
    required this.customAudienceController,
    super.key,
  });

  final RxBool targetAllAudiences;
  final RxList<String> selectedAudiences;
  final List<String> availableAudiences;
  final TextEditingController customAudienceController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isAllAudiences = targetAllAudiences.value;
      return CampaignWizardAudienceSectionCard(
        title: 'Targeted Audience Categories',
        subtitle:
            'Reach audiences by professional domain, lifestyle or general interest.',
        icon: Icons.groups_rounded,
        isAllSelected: isAllAudiences,
        allSelectedLabel: 'All Audiences & Communities',
        onToggleAll: (val) {
          targetAllAudiences.value = val;
          if (val) {
            selectedAudiences.clear();
          }
        },
        content: isAllAudiences
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableAudiences.map((aud) {
                      final isSelected = selectedAudiences.contains(aud);
                      return FilterChip(
                        label: Text(
                          aud,
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
                            selectedAudiences.add(aud);
                          } else {
                            selectedAudiences.remove(aud);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customAudienceController,
                          maxLength: 50,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: TruthworldTextInputFormatters.withLimit(50),
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add custom audience tag...',
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
                            fillColor: AppColors.bgPage,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.bgSurface,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.bgSurface,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.white38,
                              ),
                            ),
                          ),
                          onSubmitted: (val) {
                            final trimmed = val.trim();
                            if (trimmed.isNotEmpty) {
                              final valRes = ContentValidator.validate(
                                trimmed,
                                fieldName: 'Audience',
                              );
                              if (!valRes.isValid) {
                                AppSnackbar.warning(valRes.message);
                                return;
                              }
                              if (!selectedAudiences.contains(trimmed)) {
                                selectedAudiences.add(trimmed);
                                customAudienceController.clear();
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          final trimmed =
                              customAudienceController.text.trim();
                          if (trimmed.isNotEmpty) {
                            final valRes = ContentValidator.validate(
                              trimmed,
                              fieldName: 'Audience',
                            );
                            if (!valRes.isValid) {
                              AppSnackbar.warning(valRes.message);
                              return;
                            }
                            if (!selectedAudiences.contains(trimmed)) {
                              selectedAudiences.add(trimmed);
                              customAudienceController.clear();
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
                          backgroundColor: AppColors.bgSurface,
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
                  if (selectedAudiences.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selectedAudiences.map((aud) {
                        return Chip(
                          label: Text(
                            aud,
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
                          onDeleted: () => selectedAudiences.remove(aud),
                          backgroundColor: AppColors.bgSurface,
                          padding: const EdgeInsets.all(4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
      );
    });
  }
}
