import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/features/community/presentation/views/upload/community_upload_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Reusable toggle row for post configuration options.
class CommunityOptionToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const CommunityOptionToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: context.twTypography.title.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: context.twTypography.caption.copyWith(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: context.colors.surfaceContainerHigh,
          inactiveThumbColor: context.colors.textTertiary,
          inactiveTrackColor: context.colors.surfaceContainer,
        ),
      ],
    );
  }
}

/// Additional post options section (Made for kids, Allow comments, Pin this post).
class CommunityPostAdditionalOptions
    extends GetView<CommunityPostUploadController> {
  const CommunityPostAdditionalOptions({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return CommunityUploadSectionCard(
        title: '3. Additional Options',
        subtitle: 'More settings for your post.',
        children: [
          // Made for kids
          CommunityOptionToggleRow(
            title: 'Made for kids',
            subtitle: 'Mark this post as made for kids content',
            value: controller.isKidFriendly.value,
            onChanged: (val) => controller.isKidFriendly.value = val,
          ),
          const SizedBox(height: 14),

          // Allow comments
          CommunityOptionToggleRow(
            title: 'Allow comments',
            subtitle: 'Let others comment on this post',
            value: controller.isCommentsEnabled.value,
            onChanged: (val) => controller.isCommentsEnabled.value = val,
          ),
          const SizedBox(height: 14),

          // Pin this post
          CommunityOptionToggleRow(
            title: 'Pin this post',
            subtitle: 'Pin to the top of community feed',
            value: controller.isPinnedPost.value,
            onChanged: (val) => controller.isPinnedPost.value = val,
          ),
        ],
      );
    });
  }
}
