import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/painters/channel_banner_painters.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/branding/channel_branding_moderation_badge.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Avatar dropzone component for channel avatar image selection, moderation status, and actions.
class ChannelBrandingAvatarDropzone extends StatelessWidget {
  const ChannelBrandingAvatarDropzone({
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final ChannelController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
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
                  ChannelBrandingModerationBadge(
                    status: status,
                    reason: reason,
                  ),
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
}
