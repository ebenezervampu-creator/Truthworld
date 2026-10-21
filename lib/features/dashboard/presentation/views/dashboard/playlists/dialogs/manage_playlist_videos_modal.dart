import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/dialogs/video_picker_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet to view, reorder, and remove/add videos within a playlist.
class ManagePlaylistVideosModal extends StatelessWidget {
  const ManagePlaylistVideosModal({
    required this.playlist,
    required this.channelId,
    super.key,
  });

  final PlaylistModel playlist;
  final String channelId;

  static Future<void> show(
    BuildContext context, {
    required PlaylistModel playlist,
    required String channelId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.bgDivider),
      ),
      builder: (_) => ManagePlaylistVideosModal(
        playlist: playlist,
        channelId: channelId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlaylistsManagementController>();
    final rxVideoIds = List<String>.from(playlist.videoIds).obs;
    final rxLoadedVideos = <Video>[].obs;
    final isLoadingVideos = true.obs;
    final isSaving = false.obs;

    // Load rich video models
    controller.fetchVideosByIds(playlist.videoIds).then((videos) {
      rxLoadedVideos.assignAll(videos);
      isLoadingVideos.value = false;
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Videos — ${playlist.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFamily: TWTypography.brandFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Drag handles to reorder videos, or add more from your channel.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFamily: TWTypography.uiFamily,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Toolbar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Obx(() {
                return Text(
                  '${rxVideoIds.length} videos in playlist',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: TWTypography.uiFamily,
                  ),
                );
              }),
              ElevatedButton.icon(
                onPressed: () => VideoPickerSheet.show(
                  context,
                  channelId: channelId,
                  targetList: rxLoadedVideos,
                  onUpdated: (selected) {
                    rxVideoIds.assignAll(selected.map((v) => v.id));
                  },
                ),
                icon: const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
                label: const Text(
                  'Add Channel Videos',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: TWTypography.uiFamily,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgSurfaceHover,
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.bgDivider),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reorderable Video List
          Expanded(
            child: Obx(() {
              if (isLoadingVideos.value && rxLoadedVideos.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: StudioLoadingIndicator(
                      message: 'Loading playlist videos...',
                      isFullScreen: false,
                    ),
                  ),
                );
              }

              if (rxLoadedVideos.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        size: 48,
                        color: AppColors.textPrimary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No videos in this playlist yet.',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: TWTypography.brandFamily,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Click "+ Add Channel Videos" to select videos.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontFamily: TWTypography.uiFamily,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: rxLoadedVideos.length,
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final animValue = Curves.easeInOut.transform(animation.value);
                      final elevation = lerpDouble(0, 8, animValue)!;
                      final scale = lerpDouble(1, 1.02, animValue)!;
                      return Transform.scale(
                        scale: scale,
                        child: Material(
                          elevation: elevation,
                          color: Colors.transparent,
                          shadowColor: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                            ),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: child,
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = rxLoadedVideos.removeAt(oldIndex);
                  rxLoadedVideos.insert(newIndex, item);
                  rxVideoIds.assignAll(rxLoadedVideos.map((v) => v.id));
                },
                itemBuilder: (context, index) {
                  final video = rxLoadedVideos[index];
                  return Container(
                    key: ValueKey(video.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.bgDivider),
                    ),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurfaceHover,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.drag_indicator_rounded,
                                color: AppColors.textPrimary,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: TWTypography.uiFamily,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 72,
                            height: 42,
                            child: video.thumbnailUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: video.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => Container(
                                      color: AppColors.bgSurfaceHover,
                                    ),
                                  )
                                : Container(
                                    color: AppColors.bgSurfaceHover,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.title,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: TWTypography.uiFamily,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${video.views} views • ${timeago.format(video.createdAt.toDate())}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontFamily: TWTypography.uiFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove from playlist',
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                          onPressed: () {
                            rxLoadedVideos.removeAt(index);
                            rxVideoIds.assignAll(
                              rxLoadedVideos.map((v) => v.id),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
          const SizedBox(height: 16),

          // Save Actions
          SizedBox(
            width: double.infinity,
            child: Obx(() {
              return ElevatedButton(
                onPressed: isSaving.value
                    ? null
                    : () async {
                        isSaving.value = true;
                        final success =
                            await controller.updatePlaylistVideos(
                          playlist: playlist,
                          videoIds: rxVideoIds.toList(),
                        );
                        isSaving.value = false;
                        if (success && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: isSaving.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Save Order & Changes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black,
                          fontFamily: TWTypography.uiFamily,
                        ),
                      ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
