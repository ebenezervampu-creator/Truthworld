import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Reusable Topic Metrics Display Row (Followers count & Videos count)
class TopicMetricsRow extends StatelessWidget {
  const TopicMetricsRow({
    required this.followerCount,
    required this.videoCount,
    super.key,
    this.isCompact = false,
    this.textColor,
    this.topic,
  });
  final int followerCount;
  final int videoCount;
  final bool isCompact;
  final Color? textColor;
  final Topic? topic;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor =
        textColor ??
        (isDark ? AppColors.textSecondary : const Color(0xFF4B5563));

    final followingController = topic != null
        ? (Get.isRegistered<FollowingTopicsController>()
            ? Get.find<FollowingTopicsController>()
            : Get.put(FollowingTopicsController()))
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Followers Metric
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_alt_outlined,
              size: isCompact ? 13 : 15,
              color: defaultColor,
            ),
            const SizedBox(width: 4),
            if (topic != null && followingController != null)
              Obx(() {
                final count = followingController.getFollowerCount(topic!);
                return Text(
                  '${FormatUtils.formatCount(count)} Followers',
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12.5,
                    fontWeight: FontWeight.w600,
                    color: defaultColor,
                  ),
                );
              })
            else
              Text(
                '${FormatUtils.formatCount(followerCount)} Followers',
                style: TextStyle(
                  fontSize: isCompact ? 11 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: defaultColor,
                ),
              ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '•',
            style: TextStyle(
              color: defaultColor,
              fontSize: isCompact ? 11 : 13,
            ),
          ),
        ),

        // Videos Metric
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: isCompact ? 13 : 15,
              color: defaultColor,
            ),
            const SizedBox(width: 4),
            Text(
              '${FormatUtils.formatCount(videoCount)} Videos',
              style: TextStyle(
                fontSize: isCompact ? 11 : 12.5,
                fontWeight: FontWeight.w600,
                color: defaultColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
