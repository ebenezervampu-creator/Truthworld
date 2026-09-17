import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_rejection_banner.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_options.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Step 1: Placement & Format selection.
class CampaignWizardFormatStep extends StatelessWidget {
  final AdItem? existingCampaign;
  final RxString adFormat;

  const CampaignWizardFormatStep({
    required this.existingCampaign,
    required this.adFormat,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSponsor = adFormat.value == 'video_sponsor';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampaignRejectionBanner(existingCampaign: existingCampaign),
          const Text(
            'Select Campaign Placement & Format',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose where your campaign creatives will be served across Truthworld platforms.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              CampaignWizardFormatOption(
                label: 'Video Sponsor Ads',
                value: 'video_sponsor',
                isSelected: adFormat.value == 'video_sponsor',
                onTap: () => adFormat.value = 'video_sponsor',
                icon: Icons.stars_rounded,
                isPopular: true,
              ),
              CampaignWizardFormatOption(
                label: 'Skippable Video',
                value: 'skippable',
                isSelected: adFormat.value == 'skippable',
                onTap: () => adFormat.value = 'skippable',
                icon: Icons.play_circle_filled_rounded,
              ),
              CampaignWizardFormatOption(
                label: 'Homepage Banner',
                value: 'homepage',
                isSelected: adFormat.value == 'homepage',
                onTap: () => adFormat.value = 'homepage',
                icon: Icons.aspect_ratio_rounded,
              ),
              CampaignWizardFormatOption(
                label: 'Scroll Feed Banner',
                value: 'scroll',
                isSelected: adFormat.value == 'scroll',
                onTap: () => adFormat.value = 'scroll',
                icon: Icons.dynamic_feed_rounded,
              ),
              CampaignWizardFormatOption(
                label: 'Comment Box Banner',
                value: 'comment',
                isSelected: adFormat.value == 'comment',
                onTap: () => adFormat.value = 'comment',
                icon: Icons.comment_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isSponsor) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.5),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Combined 4-in-1 Video Sponsor Suite (POPULAR)',
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. 5-Sec Pre-Roll Sponsor Bumper (Plays BEFORE main video starts: "This video is brought to you by [Brand]")\n'
                    '2. 7-Minute Skippable Mid-roll Video Ad\n'
                    '3. Recommended Videos Promoted Feed Banner\n'
                    '4. Interactive Sponsored Pinned Comment below video',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}
