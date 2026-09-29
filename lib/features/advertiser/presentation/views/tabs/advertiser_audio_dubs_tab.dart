import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/audio_dubs/audio_dubs_campaigns_sidebar.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/audio_dubs/audio_dubs_manager_area.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Audio dubbing and voice cloning management tab for Advertiser Studio.
class AdvertiserAudioDubsTab extends StatelessWidget {
  const AdvertiserAudioDubsTab({
    required this.controller,
    super.key,
  });

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final skippableCampaigns = AdService.to.customCampaigns
          .where((ad) =>
              ad.userId == AuthService.to.uid &&
              (ad.isSkippableAd ||
                  (ad.videoUrl != null && ad.videoUrl!.isNotEmpty) ||
                  (ad.midrollVideoUrl != null &&
                      ad.midrollVideoUrl!.isNotEmpty) ||
                  (ad.resolutions != null && ad.resolutions!.isNotEmpty)))
          .toList();

      return LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = constraints.maxWidth >= 800;
          final listWidget = AudioDubsCampaignsSidebar(
            controller: controller,
            campaigns: skippableCampaigns,
          );
          final managerWidget = AudioDubsManagerArea(controller: controller);

          if (isLarge) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 300, child: listWidget),
                const VerticalDivider(color: Color(0xFF27272A), width: 1),
                Expanded(child: managerWidget),
              ],
            );
          } else {
            return controller.selectedAdForAudio.value == null
                ? listWidget
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: const Color(0xFF161618),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                controller.selectedAdForAudio.value = null;
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
                      Expanded(child: managerWidget),
                    ],
                  );
          }
        },
      );
    });
  }
}
