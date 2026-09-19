import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/painters/channel_banner_painters.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/branding/channel_branding_banner_preview_content.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/branding/channel_branding_moderation_badge.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Banner dropzone component handling upload, upload progress, multi-device preview,
/// and safe area guides.
class ChannelBrandingBannerDropzone extends StatelessWidget {
  const ChannelBrandingBannerDropzone({
    required this.controller,
    required this.isDarkMode,
    required this.bannerPreviewMode,
    required this.showBannerSafeArea,
    super.key,
  });

  final ChannelController controller;
  final bool isDarkMode;
  final RxInt bannerPreviewMode;
  final RxBool showBannerSafeArea;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bannerData = controller.bannerImageData.value;
      final bannerUrl = controller.bannerUrl.value;
      final hasBanner = bannerData != null || bannerUrl.isNotEmpty;
      final currentMode = bannerPreviewMode.value;
      final showGuides = showBannerSafeArea.value;
      final isUploading = controller.isUploadingBanner.value;
      final status = controller.bannerStatus.value;
      final reason = controller.bannerStatusReason.value;

      if (!hasBanner) {
        return GestureDetector(
          onTap: isUploading ? null : () => controller.pickImage(true),
          child: CustomPaint(
            painter: DashedBorderPainter(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isUploading)
                    Column(
                      children: [
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Uploading Banner (${(controller.bannerUploadProgress.value * 100).toStringAsFixed(0)}%)...',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    const Icon(
                      Icons.cloud_upload_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Upload Channel Banner',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Recommended: 2560 x 1440 px (16:9 canvas, Max 6MB)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'YouTube Standard: Safe area ensures your logo & text look great across TV, Desktop, and Mobile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }

      // Banner Selected - Render YouTube-standard multi-device preview card
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status == 'REJECTED'
                ? const Color(0xFFEF4444)
                : const Color(0xFF27272A),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Controls Bar: Device Selector + Guide Toggle
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F23),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2E2E32)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPreviewChip(
                          icon: Icons.tv,
                          label: 'All (16:9)',
                          isSelected: currentMode == 0,
                          onTap: () => bannerPreviewMode.value = 0,
                        ),
                        _buildPreviewChip(
                          icon: Icons.desktop_windows,
                          label: 'Desktop',
                          isSelected: currentMode == 1,
                          onTap: () => bannerPreviewMode.value = 1,
                        ),
                        _buildPreviewChip(
                          icon: Icons.smartphone,
                          label: 'Mobile',
                          isSelected: currentMode == 2,
                          onTap: () => bannerPreviewMode.value = 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (status.isNotEmpty) ...[
                      Flexible(
                        child: ChannelBrandingModerationBadge(
                          status: status,
                          reason: reason,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    InkWell(
                      onTap: () =>
                          showBannerSafeArea.value = !showBannerSafeArea.value,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: showGuides
                              ? const Color(0xFF2E2E32)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: showGuides
                                ? Colors.white70
                                : const Color(0xFF3F3F46),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.grid_on,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Safe Area Guides',
                              style: TextStyle(
                                fontSize: 11,
                                color: showGuides
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: showGuides
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Banner Preview Display Area
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: ChannelBrandingBannerPreviewContent(
                  bannerData: bannerData,
                  bannerUrl: bannerUrl,
                  mode: currentMode,
                  showGuides: showGuides,
                  controller: controller,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Actions & Info Footer
            Row(
              children: [
                Expanded(
                  child: Text(
                    status == 'REJECTED'
                        ? 'Image Rejected: $reason. Please change this banner.'
                        : (currentMode == 0
                            ? 'Full 16:9 canvas (2560 x 1440). Complete widescreen banner artwork.'
                            : (currentMode == 1
                                ? 'Desktop view. Complete 16:9 banner displayed across computer screens.'
                                : 'Mobile view. Complete 16:9 banner displayed across mobile smartphones.')),
                    style: TextStyle(
                      fontSize: 11,
                      color: status == 'REJECTED'
                          ? const Color(0xFFEF4444)
                          : AppColors.textTertiary,
                      fontWeight: status == 'REJECTED'
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => controller.pickImage(true),
                  icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                  label: const Text(
                    'Change',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF27272A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove Banner',
                  onPressed: () {
                    controller.bannerImageData.value = null;
                    controller.bannerUrl.value = '';
                    controller.bannerFileId.value = '';
                    controller.bannerStatus.value = '';
                    controller.bannerStatusReason.value = '';
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                  splashRadius: 18,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPreviewChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3F3F46) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
