import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/features/community/presentation/views/upload/community_upload_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Visibility configuration section for community posts (Public, Private, Members, etc.).
class CommunityPostVisibilitySection
    extends GetView<CommunityPostUploadController> {
  const CommunityPostVisibilitySection({super.key});

  static const List<Map<String, dynamic>> _visibilityOptions = [
    {
      'key': 'Public',
      'title': 'Public',
      'desc': 'Anyone can see this post',
      'icon': Icons.public_outlined,
    },
    {
      'key': 'Private',
      'title': 'Private',
      'desc': 'Only you can see this post',
      'icon': Icons.lock_outlined,
    },
    {
      'key': 'Members',
      'title': 'Members',
      'desc': 'Only members can see this post',
      'icon': Icons.people_outline_rounded,
    },
    {
      'key': 'Subscribers only',
      'title': 'Subscribers only',
      'desc': 'Only subscribers can see this post',
      'icon': Icons.star_outline_rounded,
    },
    {
      'key': 'Made for kids',
      'title': 'Made for kids',
      'desc': 'Safe content for kids',
      'icon': Icons.sentiment_satisfied_alt_outlined,
      'hasInfo': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentVis = controller.selectedVisibility.value;

      return CommunityUploadSectionCard(
        title: '2. Visibility',
        subtitle: 'Choose who can see your post.',
        children: _visibilityOptions.map((opt) {
          final key = opt['key']! as String;
          final title = opt['title']! as String;
          final desc = opt['desc']! as String;
          final icon = opt['icon']! as IconData;
          final hasInfo = opt['hasInfo'] == true;
          final isSelected = currentVis == key;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () {
                controller.selectedVisibility.value = key;
                if (key == 'Made for kids') {
                  controller.isKidFriendly.value = true;
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : context.colors.divider,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: AppColors.textPrimary, // Always white icon
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: context.twTypography.title.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: context.twTypography.caption.copyWith(
                              fontSize: 11,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasInfo)
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.textPrimary, // White icon
                        size: 18,
                      )
                    else if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.textPrimary, // White icon
                        size: 20,
                      )
                    else
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.textTertiary,
                            width: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}
