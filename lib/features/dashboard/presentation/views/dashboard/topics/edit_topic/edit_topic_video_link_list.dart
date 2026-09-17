import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/edit_topic/edit_topic_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Selection list displaying channel videos with checkboxes to link them to the topic.
class EditTopicVideoLinkList extends StatelessWidget {
  final EditTopicController controller;

  const EditTopicVideoLinkList({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.channelVideos.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No videos found on your channel. Upload a video first to link to topics.',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 13,
            ),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: controller.channelVideos.map((video) {
            final videoId = (video['id'] as String?) ?? '';
            final title = (video['title'] as String?) ?? '';
            final thumbnailUrl = (video['thumbnailUrl'] as String?) ?? '';
            final isSelected = controller.selectedVideoIds.contains(videoId);

            return Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                activeColor: Colors.white,
                checkColor: Colors.black,
                value: isSelected,
                title: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                secondary: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          width: 44,
                          height: 25,
                          fit: BoxFit.cover,
                          errorWidget: (c, o, s) => Container(
                            width: 44,
                            height: 25,
                            color: const Color(0xFF27272A),
                            child: const Icon(
                              Icons.video_library,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Container(
                          width: 44,
                          height: 25,
                          color: const Color(0xFF27272A),
                          child: const Icon(
                            Icons.video_library,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                ),
                onChanged: (checked) {
                  controller.toggleVideoSelection(videoId, checked ?? false);
                },
              ),
            );
          }).toList(),
        ),
      );
    });
  }
}
