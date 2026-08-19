import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/saved_videos_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

void showMoreOptionsBottomSheet(
  BuildContext context,
  String videoId,
  Function(bool) rotateCallback, {
  Video? video,
}) {
  final savedVideosController = Get.isRegistered<SavedVideosController>()
      ? Get.find<SavedVideosController>()
      : Get.put(SavedVideosController(), permanent: true);

  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.textSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.flag_outlined,
              color: AppColors.textPrimary,
            ),
            title: const Text('Report'),
            onTap: () {
              Navigator.pop(context);
              Get.snackbar('Report', 'Video reported.');
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.visibility_off_outlined,
              color: AppColors.textPrimary,
            ),
            title: const Text('Not interested'),
            onTap: () {
              Navigator.pop(context);
              UserPreferencesService.to.hideVideo(videoId);
              Get.snackbar(
                'Not interested',
                "We won't show this video anymore.",
              );
            },
          ),
          Obx(() {
            final isSaved = savedVideosController.isSaved(videoId);
            return ListTile(
              leading: Icon(
                isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                color: AppColors.textPrimary,
              ),
              title: Text(isSaved ? 'Remove from saved' : 'Save video'),
              onTap: () {
                Navigator.pop(context);
                final targetVideo = video ??
                    savedVideosController.savedVideos.firstWhere(
                      (v) => v.id == videoId,
                      orElse: () => Video(
                        id: videoId,
                        title: 'Video $videoId',
                        description: '',
                        thumbnailUrl: '',
                        ownerId: '',
                        channelId: '',
                        channelName: '',
                        category: '',
                        tags: const [],
                      ),
                    );
                savedVideosController.toggleSaveVideo(targetVideo);
              },
            );
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rotate Video:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.rotate_left,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        rotateCallback(false);
                        Navigator.pop(context);
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.rotate_right,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        rotateCallback(true);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
