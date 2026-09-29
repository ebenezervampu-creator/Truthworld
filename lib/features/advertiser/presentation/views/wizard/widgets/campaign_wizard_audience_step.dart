import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/location_autocomplete_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/audience_step/audience_age_groups_section.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/audience_step/audience_categories_section.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/audience_step/audience_gender_section.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/audience_step/audience_languages_section.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/audience_step/audience_locations_section.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/audience_step/audience_reach_counter.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/audience_step/audience_topics_section.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_rejection_banner.dart';
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
  final LocationAutocompleteController? locationAutocompleteController;
  final RxBool targetAllLanguages;
  final RxList<String> selectedLanguages;
  final RxBool targetAllAudiences;
  final RxList<String> selectedAudiences;
  final List<String> availableAudiences;
  final TextEditingController customAudienceController;
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
    required this.targetAllAudiences,
    required this.selectedAudiences,
    required this.availableAudiences,
    required this.customAudienceController,
    required this.targetAllTopics,
    required this.selectedTopics,
    required this.availableAgeGroups,
    required this.availableGenders,
    required this.popularLocations,
    required this.availableLanguages,
    required this.availableTopics,
    this.locationAutocompleteController,
    super.key,
  });

  LocationAutocompleteController get _locController =>
      locationAutocompleteController ??
      (Get.isRegistered<LocationAutocompleteController>()
          ? Get.find<LocationAutocompleteController>()
          : Get.put(LocationAutocompleteController()));

  @override
  Widget build(BuildContext context) {
    final locController = _locController;

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
            AudienceReachCounter(
              targetAllAges: targetAllAges,
              targetAllGenders: targetAllGenders,
              targetWorldwide: targetWorldwide,
              targetAllAudiences: targetAllAudiences,
              selectedAgeGroups: selectedAgeGroups,
              selectedLocations: selectedLocations,
              selectedAudiences: selectedAudiences,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 1. AGE GROUPS SECTION
        AudienceAgeGroupsSection(
          targetAllAges: targetAllAges,
          selectedAgeGroups: selectedAgeGroups,
          availableAgeGroups: availableAgeGroups,
        ),
        const SizedBox(height: 16),

        // 2. GENDER SECTION
        AudienceGenderSection(
          targetAllGenders: targetAllGenders,
          selectedGenders: selectedGenders,
          availableGenders: availableGenders,
        ),
        const SizedBox(height: 16),

        // 3. LOCATION & GEOGRAPHY SECTION
        AudienceLocationsSection(
          targetWorldwide: targetWorldwide,
          selectedLocations: selectedLocations,
          popularLocations: popularLocations,
          customLocationController: customLocationController,
          locController: locController,
        ),
        const SizedBox(height: 16),

        // 4. LANGUAGES SECTION
        AudienceLanguagesSection(
          targetAllLanguages: targetAllLanguages,
          selectedLanguages: selectedLanguages,
          availableLanguages: availableLanguages,
        ),
        const SizedBox(height: 16),

        // 5. TARGETED AUDIENCE & PROFESSIONS SECTION
        AudienceCategoriesSection(
          targetAllAudiences: targetAllAudiences,
          selectedAudiences: selectedAudiences,
          availableAudiences: availableAudiences,
          customAudienceController: customAudienceController,
        ),
        const SizedBox(height: 16),

        // 6. TOPIC INTERESTS SECTION
        AudienceTopicsSection(
          targetAllTopics: targetAllTopics,
          selectedTopics: selectedTopics,
          availableTopics: availableTopics,
        ),
      ],
    );
  }
}
