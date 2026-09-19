import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Left sidebar showing video campaigns eligible for subtitles and batch AI translation.
class AdvertiserSubtitlesSidebar extends StatelessWidget {
  const AdvertiserSubtitlesSidebar({
    required this.controller,
    required this.campaigns,
    super.key,
  });

  final AdvertiserPortalController controller;
  final List<AdItem> campaigns;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0F0F0F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Select Video Ad to Translate',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: Obx(
                () => OutlinedButton.icon(
                  onPressed: controller.isGeneratingAllVideoAdsAI.value
                      ? null
                      : controller.generateAllVideoAdsAI,
                  icon: controller.isGeneratingAllVideoAdsAI.value
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 16,
                        ),
                  label: Text(
                    controller.isGeneratingAllVideoAdsAI.value
                        ? 'Queueing Batch AI...'
                        : 'Generate AI for All Video Ads',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3F3F46)),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF27272A), height: 1),
          Expanded(
            child: campaigns.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No video campaigns available. Subtitles can only be added to Skippable Video ads.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: campaigns.length,
                    itemBuilder: (context, index) {
                      final ad = campaigns[index];
                      return Obx(() {
                        final isSelected =
                            controller.selectedAdForSubtitles.value?.id ==
                                ad.id;
                        return AdvertiserSubtitlesCampaignItem(
                          ad: ad,
                          isSelected: isSelected,
                          onTap: () {
                            controller.selectedAdForSubtitles.value = ad;
                            controller.selectedLanguageForSubtitles.value =
                                'en';
                            controller.loadCuesForAd(ad, 'en');
                          },
                        );
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Individual selectable campaign item in the subtitles sidebar.
class AdvertiserSubtitlesCampaignItem extends StatelessWidget {
  const AdvertiserSubtitlesCampaignItem({
    required this.ad,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final AdItem ad;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final langCount = (ad.subtitles ?? {}).length;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.brand.withValues(alpha: 0.12)
            : Colors.transparent,
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFF27272A),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 50,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ad.gradientColors,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Icon(
                Icons.play_circle_filled_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          title: Text(
            ad.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            '$langCount Language track${langCount == 1 ? "" : "s"}',
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
