import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_input_field.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Checkout and payment dialog for finalizing ad campaign launch.
void showCampaignCheckoutDialog(
  BuildContext context,
  AdvertiserPortalController controller, {
  required String brand,
  required String title,
  required String description,
  required String ctaText,
  required String ctaTarget,
  required bool isSkippable,
  required String budgetTier,
  required String adType,
  String? videoUrl,
  String? imageUrl,
  List<Color>? gradient,
  String? videoId,
  String? midrollVideoUrl,
  String? pinnedCommentText,
  List<String>? targetAgeGroups,
  List<String>? targetGenders,
  List<String>? targetLocations,
  List<String>? targetLanguages,
  List<String>? targetTopics,
  List<String>? targetAudiences,
  AdItem? existingCampaign,
}) {
  final progressStep = 0.obs;
  final checkoutSuccess = false.obs;

  final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
      CurrencyLocalizationService.to.isIndianUser;
  final currency = isIndian ? 'INR' : 'USD';
  final currencySymbol = isIndian ? '₹' : r'$';

  var cost = isIndian ? 2000.0 : 25.0;
  if (budgetTier == 'startup') cost = isIndian ? 500.0 : 10.0;
  if (budgetTier == 'growth') cost = isIndian ? 5000.0 : 50.0;
  if (budgetTier == 'enterprise') cost = isIndian ? 15000.0 : 150.0;

  final audienceParts = <String>[];
  if (targetAgeGroups != null && targetAgeGroups.isNotEmpty) {
    audienceParts.add('Ages: ${targetAgeGroups.join(', ')}');
  } else {
    audienceParts.add('All Ages');
  }
  if (targetGenders != null && targetGenders.isNotEmpty) {
    audienceParts.add('Gender: ${targetGenders.join(', ')}');
  } else {
    audienceParts.add('All Genders');
  }
  if (targetLocations != null && targetLocations.isNotEmpty) {
    audienceParts.add(targetLocations.join(', '));
  } else {
    audienceParts.add('Worldwide');
  }
  if (targetAudiences != null && targetAudiences.isNotEmpty) {
    audienceParts.add('Audience: ${targetAudiences.join(', ')}');
  } else {
    audienceParts.add('All People / All Audiences');
  }
  final audienceSummaryText = audienceParts.join(' • ');

  Get.dialog(
    Dialog(
      backgroundColor: Colors.transparent,
      child: Semantics(
        label: 'Payment Dialog',
        container: true,
        namesRoute: true,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: Obx(() {
            if (progressStep.value > 0) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  if (!checkoutSuccess.value) ...[
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Submitting campaign for moderation...',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 64,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Campaign Created Successfully!',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your advertisement has been submitted for moderation. Once approved by our Verification System, it will go live.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: Get.back,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(140, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Campaign Checkout',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF27272A), height: 20),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ad Campaign (${budgetTier.toUpperCase()})',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '$currencySymbol${cost.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Audience Summary Pill in Checkout
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Audience Targeting',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textTertiary,
                                fontSize: 9,
                              ),
                            ),
                            Text(
                              audienceSummaryText,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Cashfree Gateway Summary Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F23),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2E2E33)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isIndian
                                  ? 'Cashfree Payment Gateway'
                                  : 'Cashfree Global Payment Gateway',
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${CashfreeCountrySupport.getPaymentMethodsSummary(currency == "INR" ? "IN" : "US")} • 100% Secure',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: progressStep.value > 0
                      ? null
                      : () async {
                          try {
                            if (existingCampaign != null) {
                              progressStep.value = 1;
                              final ad = existingCampaign.copyWith(
                                advertiser: brand,
                                title: title,
                                description: description,
                                imageUrl: imageUrl ?? '',
                                ctaText: ctaText,
                                ctaTarget: ctaTarget,
                                gradientColors:
                                    gradient ??
                                    existingCampaign.gradientColors,
                                isSkippableAd: isSkippable,
                                videoUrl: videoUrl,
                                budgetTier: budgetTier.toUpperCase(),
                                budgetAmount: cost,
                                adType: adType,
                                status: 'underReview',
                                videoId: (videoId ?? '').isNotEmpty
                                    ? videoId
                                    : existingCampaign.videoId,
                                midrollVideoUrl: midrollVideoUrl,
                                pinnedCommentText: pinnedCommentText,
                                targetAgeGroups: targetAgeGroups,
                                targetGenders: targetGenders,
                                targetLocations: targetLocations,
                                targetLanguages: targetLanguages,
                                targetTopics: targetTopics,
                                targetAudiences: targetAudiences,
                              );

                              final success =
                                  await AdService.to.updateCampaign(ad);
                              if (success) {
                                checkoutSuccess.value = true;
                              } else {
                                progressStep.value = 0;
                                AppSnackbar.error(
                                  'Unable to update campaign. Please try again.',
                                );
                              }
                              return;
                            }

                            // Launch Cashfree Payment for new campaign
                            final campaignId =
                                'camp_${DateTime.now().millisecondsSinceEpoch}';

                            final paymentResult =
                                await CashfreePaymentService.to.startPayment(
                              amount: cost,
                              currency: currency,
                              purpose: 'advertiser_campaign',
                              orderNote: 'Campaign: $title',
                              metadata: {
                                'campaignId': campaignId,
                                'campaignTitle': title,
                                'advertiser': brand,
                              },
                            );

                            if (!paymentResult.success) {
                              if (paymentResult.errorMessage != null &&
                                  !paymentResult.errorMessage!
                                      .toLowerCase()
                                      .contains('cancel')) {
                                AppSnackbar.error(paymentResult.errorMessage!);
                              }
                              return;
                            }

                            progressStep.value = 1;

                            final ad = AdItem(
                              id: campaignId,
                              userId:
                                  (Get.isRegistered<AuthService>() &&
                                          AuthService.to.uid.isNotEmpty)
                                      ? AuthService.to.uid
                                      : 'advertiser',
                              advertiser: brand,
                              title: title,
                              description: description,
                              imageUrl: imageUrl ?? '',
                              ctaText: ctaText,
                              ctaTarget: ctaTarget,
                              gradientColors:
                                  gradient ??
                                  [
                                    const Color(0xFFEF4444),
                                    const Color(0xFFF59E0B),
                                  ],
                              isSkippableAd: isSkippable,
                              videoUrl: videoUrl,
                              budgetTier: budgetTier.toUpperCase(),
                              budgetAmount: cost,
                              adType: adType,
                              status: 'underReview',
                              videoId: videoId,
                              midrollVideoUrl: midrollVideoUrl,
                              pinnedCommentText: pinnedCommentText,
                              targetAgeGroups: targetAgeGroups,
                              targetGenders: targetGenders,
                              targetLocations: targetLocations,
                              targetLanguages: targetLanguages,
                              targetTopics: targetTopics,
                              targetAudiences: targetAudiences,
                            );

                            final success = await AdService.to.createCampaign(
                              ad,
                            );
                            if (success) {
                              checkoutSuccess.value = true;
                            } else {
                              progressStep.value = 0;
                              AppSnackbar.error(
                                'Unable to register campaign. Please try again.',
                              );
                            }
                          } catch (e) {
                            progressStep.value = 0;
                            ErrorHandler.log(e);
                            AppSnackbar.error(
                              'Unable to complete checkout. Please try again.',
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    existingCampaign != null
                        ? 'Save & Resubmit Campaign'
                        : 'Pay $currencySymbol${cost.toStringAsFixed(0)} with Cashfree',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    ),
    barrierDismissible: false,
  );
}


/// Backward-compatible alias.
void showCheckoutDialog(
  BuildContext context,
  AdvertiserPortalController controller, {
  required String brand,
  required String title,
  required String description,
  required String ctaText,
  required String ctaTarget,
  required bool isSkippable,
  required String budgetTier,
  required String adType,
  String? videoUrl,
  String? imageUrl,
  List<Color>? gradient,
  String? videoId,
  String? midrollVideoUrl,
  String? pinnedCommentText,
  List<String>? targetAgeGroups,
  List<String>? targetGenders,
  List<String>? targetLocations,
  List<String>? targetLanguages,
  List<String>? targetTopics,
  List<String>? targetAudiences,
  AdItem? existingCampaign,
}) => showCampaignCheckoutDialog(
  context,
  controller,
  brand: brand,
  title: title,
  description: description,
  ctaText: ctaText,
  ctaTarget: ctaTarget,
  isSkippable: isSkippable,
  budgetTier: budgetTier,
  adType: adType,
  videoUrl: videoUrl,
  imageUrl: imageUrl,
  gradient: gradient,
  videoId: videoId,
  midrollVideoUrl: midrollVideoUrl,
  pinnedCommentText: pinnedCommentText,
  targetAgeGroups: targetAgeGroups,
  targetGenders: targetGenders,
  targetLocations: targetLocations,
  targetLanguages: targetLanguages,
  targetTopics: targetTopics,
  targetAudiences: targetAudiences,
  existingCampaign: existingCampaign,
);

Widget _buildInputField(
  String label,
  TextEditingController controller,
  String hint,
) {
  return AdvertiserInputField(
    label: label,
    controller: controller,
    hint: hint,
  );
}
