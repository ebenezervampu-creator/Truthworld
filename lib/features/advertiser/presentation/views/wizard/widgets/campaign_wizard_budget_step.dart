import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_options.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_targeting_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Step 4: Budget tier, fallback gradient, and review launch overview.
class CampaignWizardBudgetStep extends StatelessWidget {
  final RxInt currentStep;
  final RxBool targetAllAges;
  final RxList<String> selectedAgeGroups;
  final RxBool targetAllGenders;
  final RxList<String> selectedGenders;
  final RxBool targetWorldwide;
  final RxList<String> selectedLocations;
  final RxBool targetAllLanguages;
  final RxList<String> selectedLanguages;
  final RxBool targetAllAudiences;
  final RxList<String> selectedAudiences;
  final RxBool targetAllTopics;
  final RxList<String> selectedTopics;
  final RxString selectedBudget;
  final RxString adFormat;
  final RxInt selectedGradient;
  final List<List<Color>> gradientOptions;

  const CampaignWizardBudgetStep({
    required this.currentStep,
    required this.targetAllAges,
    required this.selectedAgeGroups,
    required this.targetAllGenders,
    required this.selectedGenders,
    required this.targetWorldwide,
    required this.selectedLocations,
    required this.targetAllLanguages,
    required this.selectedLanguages,
    required this.targetAllAudiences,
    required this.selectedAudiences,
    required this.targetAllTopics,
    required this.selectedTopics,
    required this.selectedBudget,
    required this.adFormat,
    required this.selectedGradient,
    required this.gradientOptions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSkippable = adFormat.value == 'skippable';
      final isSponsor = adFormat.value == 'video_sponsor';
      final isScroll = adFormat.value == 'scroll';
      final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
          CurrencyLocalizationService.to.isIndianUser;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audience Summary Review Card
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF27272A),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.people_alt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Target Audience Overview',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => currentStep.value = 3,
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      label: const Text(
                        'Edit Targeting',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CampaignWizardAudienceBadge(
                      icon: Icons.calendar_today_rounded,
                      label: targetAllAges.value
                          ? 'All Ages'
                          : 'Ages: ${selectedAgeGroups.join(', ')}',
                    ),
                    CampaignWizardAudienceBadge(
                      icon: Icons.wc_rounded,
                      label: targetAllGenders.value
                          ? 'All Genders'
                          : 'Gender: ${selectedGenders.join(', ')}',
                    ),
                    CampaignWizardAudienceBadge(
                      icon: Icons.public_rounded,
                      label: targetWorldwide.value
                          ? 'Worldwide'
                          : 'Locations: ${selectedLocations.join(', ')}',
                    ),
                    if (!targetAllLanguages.value && selectedLanguages.isNotEmpty)
                      CampaignWizardAudienceBadge(
                        icon: Icons.translate_rounded,
                        label: 'Languages: ${selectedLanguages.join(', ')}',
                      ),
                    if (!targetAllAudiences.value && selectedAudiences.isNotEmpty)
                      CampaignWizardAudienceBadge(
                        icon: Icons.groups_rounded,
                        label: 'Audience: ${selectedAudiences.join(', ')}',
                      )
                    else if (targetAllAudiences.value)
                      const CampaignWizardAudienceBadge(
                        icon: Icons.groups_rounded,
                        label: 'All People / All Audiences',
                      ),
                    if (!targetAllTopics.value && selectedTopics.isNotEmpty)
                      CampaignWizardAudienceBadge(
                        icon: Icons.tag_rounded,
                        label: 'Topics: ${selectedTopics.join(', ')}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Text(
            'Select Campaign Budget & Delivery Plan',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              CampaignWizardBudgetOption(
                tierName: 'Bootstrap Package',
                cost: isIndian ? '₹500' : r'$10',
                subtitle: 'Estimated 2,500 impressions',
                value: 'startup',
                isSelected: selectedBudget.value == 'startup',
                onTap: () => selectedBudget.value = 'startup',
              ),
              const SizedBox(height: 8),
              CampaignWizardBudgetOption(
                tierName: 'Starter Pack',
                cost: isIndian ? '₹2,000' : r'$25',
                subtitle: 'Estimated 10,000 impressions',
                value: 'starter',
                isSelected: selectedBudget.value == 'starter',
                onTap: () => selectedBudget.value = 'starter',
              ),
              const SizedBox(height: 8),
              CampaignWizardBudgetOption(
                tierName: 'Growth Booster',
                cost: isIndian ? '₹5,000' : r'$50',
                subtitle: 'Estimated 35,000 impressions',
                value: 'growth',
                isSelected: selectedBudget.value == 'growth',
                onTap: () => selectedBudget.value = 'growth',
              ),
              const SizedBox(height: 8),
              CampaignWizardBudgetOption(
                tierName: 'Enterprise Scale',
                cost: isIndian ? '₹15,000' : r'$150',
                subtitle: 'Estimated 120,000 impressions',
                value: 'enterprise',
                isSelected: selectedBudget.value == 'enterprise',
                onTap: () => selectedBudget.value = 'enterprise',
              ),
            ],
          ),
          if (!isSkippable && !isSponsor && !isScroll) ...[
            const SizedBox(height: 24),
            const Text(
              'Select Fallback / Banner Theme',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: gradientOptions.length,
                itemBuilder: (context, idx) {
                  final colors = gradientOptions[idx];
                  return GestureDetector(
                    onTap: () => selectedGradient.value = idx,
                    child: Container(
                      width: 45,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedGradient.value == idx
                              ? AppColors.brand
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      );
    });
  }
}
