import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/painters/channel_banner_painters.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_input_fields.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelWizardBrandingCard extends StatelessWidget {
  final ChannelController controller;
  final bool isDarkMode;

  ChannelWizardBrandingCard({
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

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
          _buildBannerDropzone(isDarkMode),
          const SizedBox(height: 20),
          // Channel Avatar
          const ChannelWizardFieldLabel('Channel Avatar', isRequired: true),
          const SizedBox(height: 8),
          _buildAvatarDropzone(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildModerationStatusBadge(String status, String reason) {
    if (status.isEmpty) return const SizedBox.shrink();

    final isPending = status == 'PENDING';
    final isApproved = status == 'APPROVED';
    final isRejected = status == 'REJECTED';
    final isFlagged = status == 'FLAGGED';

    final Color badgeBg;
    final Color borderColor;
    final Color textColor;
    final IconData iconData;
    final String label;

    if (isPending) {
      badgeBg = const Color(0xFF1E293B);
      borderColor = const Color(0xFF38BDF8).withValues(alpha: 0.4);
      textColor = const Color(0xFF38BDF8);
      iconData = Icons.hourglass_top_rounded;
      label = 'Verifying...';
    } else if (isApproved) {
      badgeBg = const Color(0xFF064E3B);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
      textColor = const Color(0xFF34D399);
      iconData = Icons.verified_rounded;
      label = 'Verified';
    } else if (isRejected) {
      badgeBg = const Color(0xFF450A0A);
      borderColor = const Color(0xFFEF4444).withValues(alpha: 0.4);
      textColor = const Color(0xFFF87171);
      iconData = Icons.error_outline_rounded;
      label = reason.isNotEmpty ? 'Rejected: $reason' : 'Image Rejected';
    } else if (isFlagged) {
      badgeBg = const Color(0xFF451A03);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.4);
      textColor = const Color(0xFFFBBF24);
      iconData = Icons.warning_amber_rounded;
      label = reason.isNotEmpty ? 'Flagged: $reason' : 'Flagged for Review';
    } else {
      badgeBg = const Color(0xFF064E3B);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
      textColor = const Color(0xFF34D399);
      iconData = Icons.check_circle_outline_rounded;
      label = 'Verified';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPending)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Icon(iconData, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerDropzone(bool isDarkMode) {
    return Obx(() {
      final bannerData = controller.bannerImageData.value;
      final bannerUrl = controller.bannerUrl.value;
      final hasBanner = bannerData != null || bannerUrl.isNotEmpty;
      final currentMode = _bannerPreviewMode.value;
      final showGuides = _showBannerSafeArea.value;
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
                // Horizontally scrollable chip row to guarantee zero overflow on mobile & web-mobile
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
                        _buildBannerPreviewChip(
                          icon: Icons.tv,
                          label: 'All (16:9)',
                          isSelected: currentMode == 0,
                          onTap: () => _bannerPreviewMode.value = 0,
                        ),
                        _buildBannerPreviewChip(
                          icon: Icons.desktop_windows,
                          label: 'Desktop',
                          isSelected: currentMode == 1,
                          onTap: () => _bannerPreviewMode.value = 1,
                        ),
                        _buildBannerPreviewChip(
                          icon: Icons.smartphone,
                          label: 'Mobile',
                          isSelected: currentMode == 2,
                          onTap: () => _bannerPreviewMode.value = 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Status Badge & Safe Area Toggle Button
                Row(
                  children: [
                    if (status.isNotEmpty) ...[
                      Flexible(
                        child: _buildModerationStatusBadge(status, reason),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    InkWell(
                      onTap: () => _showBannerSafeArea.value =
                          !_showBannerSafeArea.value,
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
                child: _buildBannerPreviewContent(
                  bannerData: bannerData,
                  bannerUrl: bannerUrl,
                  mode: currentMode,
                  showGuides: showGuides,
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

  Widget _buildBannerPreviewChip({
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

  Widget _buildBannerPreviewContent({
    required ImageData? bannerData,
    required String bannerUrl,
    required int mode,
    required bool showGuides,
  }) {
    final imageWidget = bannerData != null
        ? Image.memory(bannerData.bytes, fit: BoxFit.cover)
        : CachedNetworkImage(
            imageUrl: bannerUrl,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => const ColoredBox(
              color: Color(0xFF212121),
              child: Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          );

    if (mode == 1) {
      // Desktop View: Render in a sleek Desktop Browser Window Mockup
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2E2E32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mini Desktop Browser Window Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF202024),
                borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121214),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'truthworld.com/@${controller.customUrl.text.isNotEmpty ? controller.customUrl.text : "channel"}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Desktop Banner: Full 16:9 Canvas (Zero Cropping)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageWidget,
                  if (showGuides)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: YouTubeBannerSafeAreaPainter(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Miniature Channel Header preview bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF27272A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipOval(
                      child: controller.avatarImageData.value != null
                          ? Image.memory(
                              controller.avatarImageData.value!.bytes,
                              fit: BoxFit.cover,
                            )
                          : (controller.avatarUrl.value.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: controller.avatarUrl.value,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 13,
                                    color: Colors.white,
                                  )),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          controller.channelName.text.isNotEmpty
                              ? controller.channelName.text
                              : 'Channel Name',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@${controller.customUrl.text.isNotEmpty ? controller.customUrl.text : "handle"} • Desktop Display',
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (mode == 2) {
      // Mobile View: Render in a sleek Smartphone Mockup with true 1546x423 center crop
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2E2E32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Phone Status Bar Mockup
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF202024),
                borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '9:41',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi, size: 9, color: Colors.white70),
                      SizedBox(width: 4),
                      Icon(Icons.battery_full, size: 9, color: Colors.white70),
                    ],
                  ),
                ],
              ),
            ),
            // Mobile Banner: Full 16:9 Canvas (Zero Cropping)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageWidget,
                  if (showGuides)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: YouTubeBannerSafeAreaPainter(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Miniature Channel Header preview bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF27272A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipOval(
                      child: controller.avatarImageData.value != null
                          ? Image.memory(
                              controller.avatarImageData.value!.bytes,
                              fit: BoxFit.cover,
                            )
                          : (controller.avatarUrl.value.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: controller.avatarUrl.value,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.white,
                                  )),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          controller.channelName.text.isNotEmpty
                              ? controller.channelName.text
                              : 'Channel Name',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@${controller.customUrl.text.isNotEmpty ? controller.customUrl.text : "handle"} • Mobile Display',
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Default Mode 0: Full 16:9 View (2560 x 1440)
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          if (showGuides)
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: YouTubeBannerSafeAreaPainter(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarDropzone(bool isDarkMode) {
    return Obx(() {
      final avatarData = controller.avatarImageData.value;
      final avatarUrl = controller.avatarUrl.value;
      final hasAvatar = avatarData != null || avatarUrl.isNotEmpty;
      final isUploading = controller.isUploadingAvatar.value;
      final status = controller.avatarStatus.value;
      final reason = controller.avatarStatusReason.value;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: isUploading ? null : () => controller.pickImage(false),
            child: CustomPaint(
              painter: DashedBorderPainter(
                color: status == 'REJECTED'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF3F3F3F),
                borderRadius: 50,
              ),
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFF121212),
                  shape: BoxShape.circle,
                ),
                child: isUploading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(controller.avatarUploadProgress.value * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : (hasAvatar
                          ? ClipOval(
                              child: avatarData != null
                                  ? Image.memory(
                                      avatarData.bytes,
                                      fit: BoxFit.cover,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: avatarUrl,
                                      fit: BoxFit.cover,
                                    ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: Colors.white,
                                size: 32,
                              ),
                            )),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: isUploading ? null : () => controller.pickImage(false),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasAvatar
                            ? 'Channel Avatar'
                            : 'Drag & drop avatar here\nor click to upload',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Recommended 800 x 800 px (Max 2MB)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildModerationStatusBadge(status, reason),
                ],
                if (hasAvatar) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => controller.pickImage(false),
                        icon: const Icon(
                          Icons.edit,
                          size: 13,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Change',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF27272A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Remove Avatar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          controller.avatarImageData.value = null;
                          controller.avatarUrl.value = '';
                          controller.avatarFileId.value = '';
                          controller.avatarStatus.value = '';
                          controller.avatarStatusReason.value = '';
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  // ========================================================================
  // CARD 2: CHANNEL DETAILS
  // ========================================================================
}
