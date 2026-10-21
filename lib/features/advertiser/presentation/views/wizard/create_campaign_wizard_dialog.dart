import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/location_autocomplete_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive multi-step campaign creation wizard and checkout flow.
class CreateCampaignWizardDialog {
  const CreateCampaignWizardDialog._();

  static void show(
    BuildContext context,
    AdvertiserPortalController controller, {
    AdItem? existingCampaign,
  }) {
    showCreateCampaignWizard(
      context,
      controller,
      existingCampaign: existingCampaign,
    );
  }
}

void showCreateCampaignWizard(
  BuildContext context,
  AdvertiserPortalController controller, {
  AdItem? existingCampaign,
}) {
  final advertiserController = TextEditingController(
    text: existingCampaign?.advertiser ?? '',
  );
  final titleController = TextEditingController(
    text: existingCampaign?.title ?? '',
  );
  final descriptionController = TextEditingController(
    text: existingCampaign?.description ?? '',
  );
  final ctaTextController = TextEditingController(
    text: existingCampaign?.ctaText ?? 'Learn More',
  );
  final ctaUrlController = TextEditingController(
    text: existingCampaign?.ctaTarget ?? '',
  );
  final videoUrlController = TextEditingController(
    text: existingCampaign?.videoUrl ?? '',
  );
  final imageUrlController = TextEditingController(
    text: existingCampaign?.imageUrl ?? '',
  );
  final midrollVideoUrlController = TextEditingController(
    text: existingCampaign?.midrollVideoUrl ?? '',
  );
  final pinnedCommentController = TextEditingController(
    text: existingCampaign?.pinnedCommentText ?? '',
  );

  final adFormat = (existingCampaign?.adType ?? 'skippable').obs;
  final selectedBudget =
      (existingCampaign?.budgetTier?.toLowerCase() ?? 'startup').obs;
  final selectedGradient = 0.obs;

  final selectedVideoTitle = ''.obs;
  final selectedVideoId = (existingCampaign?.videoId ?? '').obs;
  final pickedBumperFileName = ''.obs;
  final pickedBumperMeta = ''.obs;
  final isBumperUploading = false.obs;
  final bumperUploadProgress = 0.0.obs;
  final bumperUploadStatus = ''.obs;

  final pickedMidrollFileName = ''.obs;
  final pickedMidrollMeta = ''.obs;
  final isMidrollUploading = false.obs;
  final midrollUploadProgress = 0.0.obs;
  final midrollUploadStatus = ''.obs;

  final pickedBannerFileName = ''.obs;
  final pickedBannerMeta = ''.obs;
  final isBannerUploading = false.obs;
  final bannerUploadProgress = 0.0.obs;
  final bannerUploadStatus = ''.obs;

  // Audience & Targeting State
  final targetAllAges = (existingCampaign?.targetAgeGroups == null ||
          existingCampaign!.targetAgeGroups!.isEmpty).obs;
  final selectedAgeGroups = <String>[
    if (existingCampaign?.targetAgeGroups != null)
      ...existingCampaign!.targetAgeGroups!,
  ].obs;

  final targetAllGenders = (existingCampaign?.targetGenders == null ||
          existingCampaign!.targetGenders!.isEmpty).obs;
  final selectedGenders = <String>[
    if (existingCampaign?.targetGenders != null)
      ...existingCampaign!.targetGenders!,
  ].obs;

  final targetWorldwide = (existingCampaign?.targetLocations == null ||
          existingCampaign!.targetLocations!.isEmpty ||
          existingCampaign.targetLocations!.contains('Worldwide')).obs;
  final selectedLocations = <String>[
    if (existingCampaign?.targetLocations != null)
      ...existingCampaign!.targetLocations!.where((l) => l != 'Worldwide'),
  ].obs;
  final customLocationController = TextEditingController();
  final locationAutocompleteController =
      Get.put(LocationAutocompleteController());

  final targetAllLanguages = (existingCampaign?.targetLanguages == null ||
          existingCampaign!.targetLanguages!.isEmpty).obs;
  final selectedLanguages = <String>[
    if (existingCampaign?.targetLanguages != null)
      ...existingCampaign!.targetLanguages!,
  ].obs;

  final targetAllAudiences = (existingCampaign?.targetAudiences == null ||
          existingCampaign!.targetAudiences!.isEmpty).obs;
  final selectedAudiences = <String>[
    if (existingCampaign?.targetAudiences != null)
      ...existingCampaign!.targetAudiences!,
  ].obs;
  final customAudienceController = TextEditingController();

  final targetAllTopics = (existingCampaign?.targetTopics == null ||
          existingCampaign!.targetTopics!.isEmpty).obs;
  final selectedTopics = <String>[
    if (existingCampaign?.targetTopics != null)
      ...existingCampaign!.targetTopics!,
  ].obs;

  const availableAgeGroups = [
    '18–24',
    '25–34',
    '35–44',
    '45–54',
    '55–64',
    '65+',
  ];

  const availableGenders = [
    'Male',
    'Female',
    'Non-binary / Other',
  ];

  const popularLocations = [
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Germany',
    'United Arab Emirates',
    'Singapore',
  ];

  const availableLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'de', 'name': 'German'},
    {'code': 'ta', 'name': 'Tamil'},
    {'code': 'te', 'name': 'Telugu'},
  ];

  const availableAudiences = [
    'All People / General Audience',
    'Software Engineers & IT',
    'Students & University Scholars',
    'Doctors & Healthcare Professionals',
    'Entrepreneurs & Business Owners',
    'Marketers & Advertisers',
    'Finance & Banking Professionals',
    'Teachers & Educators',
    'Content Creators & Influencers',
    'Lawyers & Legal Professionals',
    'Government & Public Sector',
    'Sales & Business Development',
    'Designers & Creative Artists',
    'Engineers & Architects',
    'Real Estate Agents & Brokers',
    'Hospitality & Tourism Workers',
    'Retail & E-Commerce Sellers',
    'Freelancers & Remote Workers',
    'Corporate Managers & Executives',
    'Homemakers & Parents',
    'Fitness Trainers & Athletes',
    'Scientists & Researchers',
    'Accountants & Tax Consultants',
    'Journalists & Media Workers',
    'Farmers & Agriculture Specialists',
    'Tradespeople & Technicians',
    'Logistics & Supply Chain Workers',
    'Security & Defense Personnel',
    'Musicians & Performing Artists',
    'Writers & Authors',
    'Human Resources (HR) & Recruiters',
  ];

  const availableTopics = AppCategories.allCategories;

  final gradientOptions = <List<Color>>[
    [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
    [const Color(0xFFEF4444), const Color(0xFFF59E0B)],
    [const Color(0xFF10B981), const Color(0xFF059669)],
    [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
    [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
  ];

  final currentStep = 1.obs;

  Get.dialog(
    Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Semantics(
        label: 'Campaign Creation Studio Dialog',
        container: true,
        namesRoute: true,
        child: Container(
          width: 860,
          height: MediaQuery.of(context).size.height * 0.86,
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF27272A)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Studio Top Header & Stepper
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF18181B),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF27272A)),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.campaign_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existingCampaign != null
                                      ? 'Edit Ad Campaign Studio'
                                      : 'Ad Campaign Creation Studio',
                                  style: const TextStyle(
                                    fontFamily: TWTypography.brandFamily,
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Industry Standard Campaign Manager & Delivery Setup',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: Get.back,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Step Stepper Indicator Chips
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 640;
                        return Obx(() {
                          final step = currentStep.value;
                          final tabs = [
                            CampaignWizardStepTab(
                              stepIndex: 1,
                              title: '1. Format & Objective',
                              icon: Icons.grid_view_rounded,
                              currentStep: step,
                              onTap: () => currentStep.value = 1,
                              isExpanded: !isCompact,
                            ),
                            const SizedBox(width: 8),
                            CampaignWizardStepTab(
                              stepIndex: 2,
                              title: '2. Creatives & Media',
                              icon: Icons.video_file_rounded,
                              currentStep: step,
                              onTap: () => currentStep.value = 2,
                              isExpanded: !isCompact,
                            ),
                            const SizedBox(width: 8),
                            CampaignWizardStepTab(
                              stepIndex: 3,
                              title: '3. Target Audience',
                              icon: Icons.people_alt_rounded,
                              currentStep: step,
                              onTap: () => currentStep.value = 3,
                              isExpanded: !isCompact,
                            ),
                            const SizedBox(width: 8),
                            CampaignWizardStepTab(
                              stepIndex: 4,
                              title: '4. Budget & Launch',
                              icon: Icons.rocket_launch_rounded,
                              currentStep: step,
                              onTap: () => currentStep.value = 4,
                              isExpanded: !isCompact,
                            ),
                          ];

                          if (isCompact) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(children: tabs),
                            );
                          }

                          return Row(children: tabs);
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Studio Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Obx(() {
                    // STEP 1: Format & Objective
                    if (currentStep.value == 1) {
                      return CampaignWizardFormatStep(
                        existingCampaign: existingCampaign,
                        adFormat: adFormat,
                      );
                    }

                    // STEP 2: Creatives & Media
                    if (currentStep.value == 2) {
                      return CampaignWizardMediaStep(
                        context: context,
                        controller: controller,
                        adFormat: adFormat,
                        advertiserController: advertiserController,
                        titleController: titleController,
                        descriptionController: descriptionController,
                        ctaTextController: ctaTextController,
                        ctaUrlController: ctaUrlController,
                        videoUrlController: videoUrlController,
                        midrollVideoUrlController: midrollVideoUrlController,
                        imageUrlController: imageUrlController,
                        pinnedCommentController: pinnedCommentController,
                        selectedVideoTitle: selectedVideoTitle,
                        selectedVideoId: selectedVideoId,
                        pickedBumperFileName: pickedBumperFileName,
                        pickedBumperMeta: pickedBumperMeta,
                        isBumperUploading: isBumperUploading,
                        bumperUploadProgress: bumperUploadProgress,
                        bumperUploadStatus: bumperUploadStatus,
                        pickedMidrollFileName: pickedMidrollFileName,
                        pickedMidrollMeta: pickedMidrollMeta,
                        isMidrollUploading: isMidrollUploading,
                        midrollUploadProgress: midrollUploadProgress,
                        midrollUploadStatus: midrollUploadStatus,
                        pickedBannerFileName: pickedBannerFileName,
                        pickedBannerMeta: pickedBannerMeta,
                        isBannerUploading: isBannerUploading,
                        bannerUploadProgress: bannerUploadProgress,
                        bannerUploadStatus: bannerUploadStatus,
                      );
                    }

                    // STEP 3: Target Audience & Demographics
                    if (currentStep.value == 3) {
                      return CampaignWizardAudienceStep(
                        existingCampaign: existingCampaign,
                        targetAllAges: targetAllAges,
                        selectedAgeGroups: selectedAgeGroups,
                        targetAllGenders: targetAllGenders,
                        selectedGenders: selectedGenders,
                        targetWorldwide: targetWorldwide,
                        selectedLocations: selectedLocations,
                        customLocationController: customLocationController,
                        locationAutocompleteController:
                            locationAutocompleteController,
                        targetAllLanguages: targetAllLanguages,
                        selectedLanguages: selectedLanguages,
                        targetAllAudiences: targetAllAudiences,
                        selectedAudiences: selectedAudiences,
                        availableAudiences: availableAudiences,
                        customAudienceController: customAudienceController,
                        targetAllTopics: targetAllTopics,
                        selectedTopics: selectedTopics,
                        availableAgeGroups: availableAgeGroups,
                        availableGenders: availableGenders,
                        popularLocations: popularLocations,
                        availableLanguages: availableLanguages,
                        availableTopics: availableTopics,
                      );
                    }

                    // STEP 4: Budget & Launch
                    return CampaignWizardBudgetStep(
                      currentStep: currentStep,
                      targetAllAges: targetAllAges,
                      selectedAgeGroups: selectedAgeGroups,
                      targetAllGenders: targetAllGenders,
                      selectedGenders: selectedGenders,
                      targetWorldwide: targetWorldwide,
                      selectedLocations: selectedLocations,
                      targetAllLanguages: targetAllLanguages,
                      selectedLanguages: selectedLanguages,
                      targetAllAudiences: targetAllAudiences,
                      selectedAudiences: selectedAudiences,
                      targetAllTopics: targetAllTopics,
                      selectedTopics: selectedTopics,
                      selectedBudget: selectedBudget,
                      adFormat: adFormat,
                      selectedGradient: selectedGradient,
                      gradientOptions: gradientOptions,
                    );
                  }),
                ),
              ),

              // Studio Footer Actions Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF18181B),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: Color(0xFF27272A)),
                  ),
                ),
                child: Obx(() {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          if (currentStep.value > 1) {
                            currentStep.value--;
                          } else {
                            Get.back();
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: Text(
                          currentStep.value > 1 ? 'Back' : 'Cancel',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27272A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                      if (currentStep.value < 4)
                        ElevatedButton.icon(
                          onPressed: () {
                            if (currentStep.value == 2) {
                              if (advertiserController.text.trim().isEmpty ||
                                  titleController.text.trim().isEmpty ||
                                  descriptionController.text.trim().isEmpty) {
                                AppSnackbar.warning(
                                  'Please fill brand name, headline, and description.',
                                );
                                return;
                              }
                              if (adFormat.value == 'homepage' &&
                                  imageUrlController.text.trim().isEmpty) {
                                AppSnackbar.warning(
                                  'Homepage Ads require an Image Banner creative. Please pick or select an image file.',
                                );
                                return;
                              }
                              if (adFormat.value == 'scroll' &&
                                  imageUrlController.text.trim().isEmpty) {
                                AppSnackbar.warning(
                                  'Scroll Ads require an Image Banner creative. Please pick or select an image file.',
                                );
                                return;
                              }
                            }
                            if (currentStep.value == 3) {
                              if (!targetAllAges.value &&
                                  selectedAgeGroups.isEmpty) {
                                AppSnackbar.warning(
                                  'Please select at least one age bracket or toggle "All Ages".',
                                );
                                return;
                              }
                              if (!targetAllGenders.value &&
                                  selectedGenders.isEmpty) {
                                AppSnackbar.warning(
                                  'Please select at least one gender or toggle "All Genders".',
                                );
                                return;
                              }
                              if (!targetWorldwide.value &&
                                  selectedLocations.isEmpty) {
                                AppSnackbar.warning(
                                  'Please add at least one location or toggle "Worldwide".',
                                );
                                return;
                              }
                              if (!targetAllAudiences.value &&
                                  selectedAudiences.isEmpty) {
                                AppSnackbar.warning(
                                  'Please select at least one targeted audience or toggle "All People / All Audiences".',
                                );
                                return;
                              }
                            }
                            currentStep.value++;
                          },
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.black,
                            size: 16,
                          ),
                          label: const Text(
                            'Next Step',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () {
                            final brand = advertiserController.text.trim();
                            final title = titleController.text.trim();
                            final desc = descriptionController.text.trim();
                            if (brand.isEmpty || title.isEmpty || desc.isEmpty) {
                              AppSnackbar.warning('Please fill brand name, title, and description.');
                              return;
                            }
                            final brandVal = ContentValidator.validate(brand, fieldName: 'Brand Name');
                            if (!brandVal.isValid) {
                              AppSnackbar.warning(brandVal.message);
                              return;
                            }
                            final titleVal = ContentValidator.validate(title, fieldName: 'Campaign Title');
                            if (!titleVal.isValid) {
                              AppSnackbar.warning(titleVal.message);
                              return;
                            }
                            final descVal = ContentValidator.validate(desc, fieldName: 'Description');
                            if (!descVal.isValid) {
                              AppSnackbar.warning(descVal.message);
                              return;
                            }
                            final ctaText = ctaTextController.text.trim();
                            if (ctaText.isNotEmpty) {
                              final ctaVal = ContentValidator.validate(ctaText, fieldName: 'CTA Button Text');
                              if (!ctaVal.isValid) {
                                AppSnackbar.warning(ctaVal.message);
                                return;
                              }
                            }
                            if (adFormat.value == 'video_sponsor' && pinnedCommentController.text.trim().isNotEmpty) {
                              final pinVal = ContentValidator.validate(pinnedCommentController.text.trim(), fieldName: 'Pinned Comment');
                              if (!pinVal.isValid) {
                                AppSnackbar.warning(pinVal.message);
                                return;
                              }
                            }

                            if (adFormat.value == 'homepage' &&
                                imageUrlController.text.trim().isEmpty) {
                              AppSnackbar.warning('Homepage Ads require an Image Banner creative.');
                              return;
                            }

                            var targetVideoUrl = videoUrlController.text.trim();
                            if (adFormat.value == 'skippable' &&
                                targetVideoUrl.isEmpty) {
                              targetVideoUrl =
                                  'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
                            }

                            if (adFormat.value == 'video_sponsor') {
                              if (targetVideoUrl.isEmpty) {
                                targetVideoUrl =
                                    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
                              }
                              if (midrollVideoUrlController.text.trim().isEmpty) {
                                midrollVideoUrlController.text =
                                    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
                              }
                              if (imageUrlController.text.trim().isEmpty) {
                                imageUrlController.text =
                                    'https://images.unsplash.com/photo-1523474253046-8cd2748b5fd2?w=500';
                              }
                              if (pinnedCommentController.text.trim().isEmpty) {
                                final brandName = advertiserController.text.trim().isNotEmpty
                                    ? advertiserController.text.trim()
                                    : (titleController.text.trim().isNotEmpty
                                        ? titleController.text.trim()
                                        : 'our sponsor');
                                pinnedCommentController.text =
                                    'Welcome viewers! Thanks for checking out $brandName. Feel free to ask us any questions here!';
                              }
                            }

                            Get.back();
                            showCampaignCheckoutDialog(
                              context,
                              controller,
                              brand: advertiserController.text.trim(),
                              title: titleController.text.trim(),
                              description: descriptionController.text.trim(),
                              ctaText: ctaTextController.text.trim(),
                              ctaTarget: ctaUrlController.text.trim().isEmpty
                                  ? 'https://google.com'
                                  : ctaUrlController.text.trim(),
                              isSkippable:
                                  adFormat.value == 'skippable' ||
                                  adFormat.value == 'video_sponsor',
                              videoUrl: targetVideoUrl.isNotEmpty
                                  ? targetVideoUrl
                                  : null,
                              imageUrl: imageUrlController.text.trim().isNotEmpty
                                  ? imageUrlController.text.trim()
                                  : null,
                              gradient:
                                  (adFormat.value != 'skippable' &&
                                      adFormat.value != 'video_sponsor')
                                  ? gradientOptions[selectedGradient.value]
                                  : null,
                              budgetTier: selectedBudget.value,
                              adType: adFormat.value,
                              videoId: selectedVideoId.value.isEmpty
                                  ? null
                                  : selectedVideoId.value,
                              midrollVideoUrl: adFormat.value == 'video_sponsor'
                                  ? midrollVideoUrlController.text.trim()
                                  : null,
                              pinnedCommentText: adFormat.value == 'video_sponsor'
                                  ? pinnedCommentController.text.trim()
                                  : null,
                              targetAgeGroups: targetAllAges.value
                                  ? null
                                  : selectedAgeGroups.toList(),
                              targetGenders: targetAllGenders.value
                                  ? null
                                  : selectedGenders.toList(),
                              targetLocations: targetWorldwide.value
                                  ? ['Worldwide']
                                  : selectedLocations.toList(),
                              targetLanguages: targetAllLanguages.value
                                  ? null
                                  : selectedLanguages.toList(),
                              targetTopics: targetAllTopics.value
                                  ? null
                                  : selectedTopics.toList(),
                              targetAudiences: targetAllAudiences.value
                                  ? null
                                  : selectedAudiences.toList(),
                              existingCampaign: existingCampaign,
                            );
                          },
                          icon: const Icon(
                            Icons.rocket_launch_rounded,
                            color: Colors.black,
                            size: 16,
                          ),
                          label: const Text(
                            'Proceed to Checkout',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
