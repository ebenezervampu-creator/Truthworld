import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/branding/channel_branding_barrel.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_input_fields.dart';

export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/branding/channel_branding_barrel.dart';

/// Card 1: Channel Branding Card (Banner and Avatar setup)
class ChannelWizardBrandingCard extends StatelessWidget {
  ChannelWizardBrandingCard({
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final ChannelController controller;
  final bool isDarkMode;

  final RxInt _bannerPreviewMode = 0.obs;
  final RxBool _showBannerSafeArea = false.obs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Channel Branding',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Channel Banner
          const ChannelWizardFieldLabel('Channel Banner', isRequired: true),
          const SizedBox(height: 8),
          ChannelBrandingBannerDropzone(
            controller: controller,
            isDarkMode: isDarkMode,
            bannerPreviewMode: _bannerPreviewMode,
            showBannerSafeArea: _showBannerSafeArea,
          ),
          const SizedBox(height: 20),
          // Channel Avatar
          const ChannelWizardFieldLabel('Channel Avatar', isRequired: true),
          const SizedBox(height: 8),
          ChannelBrandingAvatarDropzone(
            controller: controller,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }
}
