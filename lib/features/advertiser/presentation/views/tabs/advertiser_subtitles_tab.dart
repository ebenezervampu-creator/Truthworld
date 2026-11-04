import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/subtitles/advertiser_subtitles_editor.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/subtitles/advertiser_subtitles_sidebar.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/advertiser/presentation/views/tabs/subtitles/subtitles_tab_barrel.dart';

/// Tab allowing advertisers to select campaigns, manage multilingual subtitle tracks,
/// and fine-tune cue timings and translation pipelines.
class AdvertiserSubtitlesTab extends StatelessWidget {
  const AdvertiserSubtitlesTab({
    required this.controller,
    super.key,
  });

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLarge = constraints.maxWidth >= 800;

        Widget buildSidebar() {
          return Obx(() {
            final currentUid = AuthService.to.uid;
            final skippableCampaigns = AdService.to.customCampaigns
                .where((ad) =>
                    ad.userId == currentUid &&
                    (ad.isSkippableAd ||
                        (ad.videoUrl != null && ad.videoUrl!.isNotEmpty) ||
                        (ad.midrollVideoUrl != null &&
                            ad.midrollVideoUrl!.isNotEmpty) ||
                        (ad.resolutions != null && ad.resolutions!.isNotEmpty)))
                .toList();
            return AdvertiserSubtitlesSidebar(
              controller: controller,
              campaigns: skippableCampaigns,
            );
          });
        }

        final editor = AdvertiserSubtitlesEditor(controller: controller);

        if (isLarge) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 300, child: buildSidebar()),
              const VerticalDivider(color: AppColors.bgSurface, width: 1),
              Expanded(child: editor),
            ],
          );
        }

        return Obx(() {
          if (controller.selectedAdForSubtitles.value == null) {
            return buildSidebar();
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                color: AppColors.appBarSurface,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        controller.selectedAdForSubtitles.value = null;
                      },
                    ),
                    const Text(
                      'Back to Ads List',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: editor),
            ],
          );
        });
      },
    );
  }
}
