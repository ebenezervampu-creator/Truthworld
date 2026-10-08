import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Bottom sheet to search and pick videos from a channel to add to a playlist.
class VideoPickerSheet extends StatelessWidget {
  const VideoPickerSheet({
    required this.channelId,
    required this.targetList,
    this.onUpdated,
    super.key,
  });

  final String channelId;
  final RxList<Video> targetList;
  final void Function(List<Video>)? onUpdated;

  static Future<void> show(
    BuildContext context, {
    required String channelId,
    required RxList<Video> targetList,
    void Function(List<Video>)? onUpdated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.bgDivider),
      ),
      builder: (_) => VideoPickerSheet(
        channelId: channelId,
        targetList: targetList,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlaylistsManagementController>();
    final searchFilter = ''.obs;
    final allChannelVideos = <Video>[].obs;
    final isLoading = true.obs;
    final tempSelected = List<Video>.from(targetList).obs;

    controller.fetchChannelVideos(channelId).then((vids) {
      allChannelVideos.assignAll(vids);
      isLoading.value = false;
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Channel Videos',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFamily: TWTypography.brandFamily,
                ),
              ),
              Row(
                children: [
                  Obx(() {
                    if (allChannelVideos.isEmpty) return const SizedBox.shrink();
                    final isAllSelected =
                        tempSelected.length == allChannelVideos.length;
                    return TextButton(
                      onPressed: () {
                        if (isAllSelected) {
                          tempSelected.clear();
                        } else {
                          tempSelected.assignAll(allChannelVideos);
                        }
                      },
                      child: Text(
                        isAllSelected ? 'Deselect All' : 'Select All',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontFamily: TWTypography.uiFamily,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (val) => searchFilter.value = val.trim().toLowerCase(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontFamily: TWTypography.uiFamily,
            ),
            decoration: InputDecoration(
              hintText: 'Search channel videos...',
              hintStyle: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
                fontFamily: TWTypography.uiFamily,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
              filled: true,
              fillColor: AppColors.bgPage,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.bgDivider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.bgDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() {
              if (isLoading.value) {
                return Shimmer.fromColors(
                  baseColor: const Color(0xFF1E1E1E),
                  highlightColor: AppColors.bgSurfaceHover,
                  child: ListView.separated(
                    itemCount: 6,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, _) => Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                );
              }

              final query = searchFilter.value;
              final displayList = query.isEmpty
                  ? allChannelVideos
                  : allChannelVideos
                      .where((v) =>
                          v.title.toLowerCase().contains(query) ||
                          v.description.toLowerCase().contains(query))
                      .toList();

              if (displayList.isEmpty) {
                return const Center(
                  child: Text(
                    'No channel videos found.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: TWTypography.uiFamily,
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: displayList.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final video = displayList[index];

                  return Obx(() {
                    final isSelected =
                        tempSelected.any((v) => v.id == video.id);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (isSelected) {
                            tempSelected.removeWhere((v) => v.id == video.id);
                          } else {
                            tempSelected.add(video);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.bgSurfaceHover
                                : AppColors.bgPage,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.textSecondary
                                  : AppColors.bgDivider,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(
                                  width: 56,
                                  height: 32,
                                  child: video.thumbnailUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: video.thumbnailUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) =>
                                              const ColoredBox(
                                            color: AppColors.bgSurfaceHover,
                                            child: Icon(
                                              Icons.movie,
                                              color: AppColors.textPrimary,
                                              size: 16,
                                            ),
                                          ),
                                        )
                                      : const ColoredBox(
                                          color: AppColors.bgSurfaceHover,
                                          child: Icon(
                                            Icons.movie,
                                            color: AppColors.textPrimary,
                                            size: 16,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      video.title,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: TWTypography.uiFamily,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      video.duration.isNotEmpty
                                          ? video.duration
                                          : '${video.views} views',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                        fontFamily: TWTypography.uiFamily,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.textPrimary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.bgDivider,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.black,
                                        size: 16,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                targetList.assignAll(tempSelected);
                onUpdated?.call(tempSelected);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Obx(() {
                return Text(
                  'Done (${tempSelected.length} selected)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: TWTypography.uiFamily,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
