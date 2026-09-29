import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic/create_topic_theme_helpers.dart';

/// Section 9: Topic Image / Thumbnail Configuration
Widget buildSection9TopicImage(
  BuildContext context,
  CreateTopicController controller,
  Future<List<Map<String, dynamic>>> channelVideosFuture, {
  bool isFromUpload = false,
}) {
  return buildCreateTopicCardContainer(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCreateTopicSectionTitle(context, '9. Topic Image'),
        const SizedBox(height: 4),
        Text(
          'Choose a thumbnail for your topic',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;

            final optionA = Obx(() {
              final isVideoThumb = controller.thumbnailSource.value == 'video';
              return InkWell(
                onTap: () => controller.thumbnailSource.value = 'video',
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isVideoThumb ? const Color(0xFF1F1F24) : const Color(0xFF0F0F11),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isVideoThumb ? Colors.white : Colors.white.withValues(alpha: 0.12),
                      width: isVideoThumb ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Radio<String>(
                            value: 'video',
                            groupValue: controller.thumbnailSource.value,
                            onChanged: (val) => controller.thumbnailSource.value = val!,
                            activeColor: Colors.white,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Use thumbnail from selected video', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text(
                                  'Choose from your selected videos',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Video Thumbnail Row Picker
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: channelVideosFuture,
                        builder: (context, snapshot) {
                          final videos = snapshot.data ?? [];
                          return Obx(() {
                            final selectedIds = controller.selectedVideoIds.toList();
                            final selectedVideos = videos.where((v) => selectedIds.contains(v['id'])).toList();

                            if (selectedVideos.isEmpty) {
                              return Text(
                                isFromUpload
                                    ? 'Will use the thumbnail from your uploading video (or choose a custom image).'
                                    : 'Select videos in section 8 first.',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                              );
                            }

                            return SizedBox(
                              height: 60,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: selectedVideos.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final v = selectedVideos[index];
                                  final thumb = v['thumbnailUrl'] ?? '';
                                  final isChosen = controller.chosenVideoThumbnailUrl.value == thumb;

                                  return InkWell(
                                    onTap: () => controller.chosenVideoThumbnailUrl.value = thumb,
                                    child: Container(
                                      width: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isChosen ? Colors.white : Colors.white.withValues(alpha: 0.12),
                                          width: isChosen ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: thumb.isNotEmpty
                                            ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover, errorWidget: (_, _, _) => const Icon(Icons.movie, size: 20, color: Colors.white))
                                            : const Icon(Icons.movie, size: 20, color: Colors.white),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            });

            final optionB = Obx(() {
              final isCustom = controller.thumbnailSource.value == 'custom';
              return InkWell(
                onTap: () => controller.thumbnailSource.value = 'custom',
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCustom ? const Color(0xFF1F1F24) : const Color(0xFF0F0F11),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCustom ? Colors.white : Colors.white.withValues(alpha: 0.12),
                      width: isCustom ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Radio<String>(
                            value: 'custom',
                            groupValue: controller.thumbnailSource.value,
                            onChanged: (val) => controller.thumbnailSource.value = val!,
                            activeColor: Colors.white,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Upload custom image', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text(
                                  'Pick an image from your device',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Upload Box
                      InkWell(
                        onTap: controller.pickCustomThumbnail,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161618),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Column(
                            children: [
                              if (controller.pickedCustomImageBytes.value != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(controller.pickedCustomImageBytes.value!, height: 80, fit: BoxFit.cover),
                                ),
                                const SizedBox(height: 8),
                              ] else ...[
                                const Icon(Icons.upload_rounded, color: Colors.white, size: 24),
                                const SizedBox(height: 6),
                              ],
                              const Text('Upload image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text(
                                'PNG, JPG or WEBP. Max 5MB.',
                                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            });

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: optionA),
                  const SizedBox(width: 16),
                  Expanded(child: optionB),
                ],
              );
            }

            return Column(
              children: [
                optionA,
                const SizedBox(height: 14),
                optionB,
              ],
            );
          },
        ),

        const SizedBox(height: 10),
        Text(
          'Recommended size: 1280x720 (16:9). Max size: 5MB.',
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
        ),
      ],
    ),
  );
}
