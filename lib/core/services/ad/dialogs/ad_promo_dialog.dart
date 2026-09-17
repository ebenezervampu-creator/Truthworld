import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/services/ad/models/ad_item.dart';
import 'package:truthworld/theme/app_theme.dart';

void showAdPromoDialogModal({
  required BuildContext context,
  required AdItem ad,
  VoidCallback? onRecordClick,
  Future<void> Function(AdItem ad)? onLaunchCtaUrl,
}) {
    if (onRecordClick != null) { onRecordClick(); }
    if (ad.ctaTarget == '/premium') {
      Get.toNamed('/premium');
      return;
    }

    final isSimulatingVisit = false.obs;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Semantics(
          label: 'Advertisement Dialog',
          container: true,
          namesRoute: true,
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161616).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.bgPage.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dialog Header Sponsor Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'SPONSORED',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Ad Visual Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: ad.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Backdrop effect or fallback icon
                        Center(
                          child: Icon(
                            ad.fallbackIcon ?? Icons.ads_click_rounded,
                            size: 72,
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Text(
                            ad.advertiser,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: AppColors.bgPage.withValues(
                                    alpha: 0.6,
                                  ),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title and Description
                Text(
                  ad.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ad.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Action Loader or Buttons
                Obx(() {
                  if (isSimulatingVisit.value) {
                    return Column(
                      children: [
                        Shimmer.fromColors(
                          baseColor: AppColors.error.withValues(alpha: 0.3),
                          highlightColor: AppColors.error,
                          child: const LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Opening sponsored page securely...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      // Primary Visit Button
                      ElevatedButton(
                        onPressed: () async {
                          isSimulatingVisit.value = true;
                          if (onLaunchCtaUrl != null) { await onLaunchCtaUrl(ad); }
                          isSimulatingVisit.value = false;
                          if (Get.isDialogOpen ?? false) {
                            Get.back();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: AppColors.bgPage,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          ad.ctaText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Bypass/Remove Ads Option
                      TextButton(
                        onPressed: () {
                          Get.back();
                          Get.toNamed('/premium');
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        child: const Text(
                          'Remove Ads (Get Premium)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
