import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

  class DraftVideoCard extends StatelessWidget {
  const DraftVideoCard({
    required this.video,
    required this.controller,
    super.key,
  });

  final Video video;
  final VideoManagementController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          debugPrint('🎬 Direct draft resume tapped for video: ${video.id}');
          Get.toNamed(
            '/upload/video',
            arguments: {'video': video, 'videoId': video.id, 'draft': video},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 96,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.bgInput,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: video.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(
                            Icons.drafts_outlined,
                            color: Colors.white,
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.drafts_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'DRAFT',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFFF59E0B),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      video.title.isNotEmpty ? video.title : 'Untitled Draft',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.videoTitleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'edit') {
                    Get.toNamed(
                      '/upload/video',
                      arguments: {'video': video, 'videoId': video.id, 'draft': video},
                    );
                  } else if (value == 'delete') {
                    controller.deleteVideo(video);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Resume / Edit Upload'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text('Delete Draft'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


}

  class ScheduledVideoCard extends StatelessWidget {
  const ScheduledVideoCard({
    required this.video,
    required this.controller,
    super.key,
  });

  final Video video;
  final VideoManagementController controller;

  @override
  Widget build(BuildContext context) {
    final scheduledText = DateFormat('MMM dd, yyyy · hh:mm a')
        .format(video.uploadedAt.toDate());

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 96,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.bgInput,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: video.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(
                          Icons.schedule_rounded,
                          color: Colors.white,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.schedule_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF6366F1)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: Color(0xFF818CF8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'SCHEDULED: $scheduledText',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFF818CF8),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    video.title.isNotEmpty ? video.title : 'Scheduled Video',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.videoTitleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'publish') {
                  controller.updateVideo(video.id, {
                    'status': 'published',
                    'visibility': 'public',
                  });
                } else if (value == 'delete') {
                  controller.deleteVideo(video);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'publish',
                  child: Row(
                    children: [
                      Icon(Icons.publish_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Publish Now'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text('Delete Scheduled Video'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


}
