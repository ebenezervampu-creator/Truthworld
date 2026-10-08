import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/edit_topic/edit_topic_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Thumbnail picker for topics supporting video-derived thumbnails and custom cropped uploads.
class EditTopicThumbnailSelector extends StatelessWidget {
  final EditTopicController controller;

  const EditTopicThumbnailSelector({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgDivider),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => controller.thumbnailSource.value = 'video',
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: controller.thumbnailSource.value == 'video'
                            ? AppColors.bgSurfaceHover
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Use Video Thumbnail',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: controller.thumbnailSource.value == 'video'
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => controller.thumbnailSource.value = 'custom',
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: controller.thumbnailSource.value == 'custom'
                            ? AppColors.bgSurfaceHover
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Upload Custom',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: controller.thumbnailSource.value == 'custom'
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Custom Upload View
          if (controller.thumbnailSource.value == 'custom') ...[
            GestureDetector(
              onTap: () => controller.pickCustomImage(context),
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                clipBehavior: Clip.antiAlias,
                child: controller.pickedCustomImageBytes.value != null
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: Image.memory(
                              controller.pickedCustomImageBytes.value!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: controller.removeCustomImage,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xB3000000),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : (controller.currentThumbnailUrl.value != null &&
                            controller.currentThumbnailUrl.value!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: controller.currentThumbnailUrl.value!,
                            fit: BoxFit.cover,
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 32,
                                color: Colors.white,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to upload a custom topic thumbnail',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          )),
              ),
            ),
          ] else ...[
            // Video-Derived Thumbnail Selector
            if (controller.selectedVideoIds.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Link at least one video below to use its thumbnail.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else ...[
              const Text(
                "Select which video's thumbnail to use:",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: controller.channelVideos
                      .where(
                        (v) => controller.selectedVideoIds.contains(v['id']),
                      )
                      .map((v) {
                        final videoUrl = (v['thumbnailUrl'] as String?) ?? '';
                        final isSelected =
                            controller.chosenVideoThumbnailUrl.value == videoUrl;
                        return GestureDetector(
                          onTap: () => controller.selectVideoThumbnail(videoUrl),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 130,
                            height: 75,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.brand
                                    : AppColors.bgDivider,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: videoUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: videoUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (c, o, s) => Container(
                                            color: const Color(0xFF1E1E1E),
                                          ),
                                        )
                                      : Container(
                                          color: const Color(0xFF1E1E1E),
                                        ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: AppColors.brand,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.black,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    color: Colors.black.withValues(
                                      alpha: 0.7,
                                    ),
                                    child: Text(
                                      (v['title'] as String?) ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
            ],
          ],
        ],
      );
    });
  }
}
