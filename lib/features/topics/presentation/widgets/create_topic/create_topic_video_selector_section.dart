import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic/create_topic_theme_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section 8: Add Videos to Topic
Widget buildSection8AddVideos(
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
        Row(
          children: [
            buildCreateTopicSectionTitle(context, '8. Add Videos'),
            const SizedBox(width: 6),
            if (!isFromUpload)
              const Text(
                '* (Required)',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Text(
                '(Optional)',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isFromUpload
              ? 'The video you are currently uploading will be automatically added to this topic upon publishing.'
              : 'At least 1 video is required to create a topic.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),

        // Select Videos Button
        OutlinedButton.icon(
          onPressed: () => openCreateTopicVideoSelectorModal(context, controller, channelVideosFuture),
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
          label: Obx(() {
            final count = controller.selectedVideoIds.length;
            return Text(
              count > 0
                  ? 'Select videos ($count)'
                  : (isFromUpload ? 'Add more videos (Optional)' : 'Select videos'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          }),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),

        const SizedBox(height: 12),

        // Selected Video Cards List
        FutureBuilder<List<Map<String, dynamic>>>(
          future: channelVideosFuture,
          builder: (context, snapshot) {
            final videos = snapshot.data ?? [];
            return Obx(() {
              final selectedIds = controller.selectedVideoIds.toList();
              final selectedVideos = videos.where((v) => selectedIds.contains(v['id'])).toList();

              if (selectedVideos.isEmpty) {
                if (isFromUpload) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F11),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current uploading video will be added',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Your current video is already staged and will be linked to this topic once you publish.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F11),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'No videos selected yet. (At least 1 video required)',
                      style: TextStyle(color: const Color(0xFFF59E0B).withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: selectedVideos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final v = selectedVideos[index];
                      final thumb = v['thumbnailUrl'] ?? '';
                      final title = v['title'] ?? 'Untitled Video';

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F11),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 56,
                                height: 38,
                                color: const Color(0xFF1E1E24),
                                child: thumb.isNotEmpty
                                    ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover, errorWidget: (_, _, _) => const Icon(Icons.movie, size: 16, color: Colors.white))
                                    : const Icon(Icons.movie, size: 16, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                              onPressed: () {
                                controller.selectedVideoIds.remove(v['id']);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${selectedVideos.length} videos selected',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
                    ),
                  ),
                ],
              );
            });
          },
        ),
      ],
    ),
  );
}

/// Modal bottom sheet for selecting videos into a topic
void openCreateTopicVideoSelectorModal(
  BuildContext context,
  CreateTopicController controller,
  Future<List<Map<String, dynamic>>> channelVideosFuture,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF161618),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Videos for Topic',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: channelVideosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                final videos = snapshot.data ?? [];
                if (videos.isEmpty) {
                  return const Text('No channel videos available.', style: TextStyle(color: Colors.white54));
                }
                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: videos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final v = videos[index];
                      final id = v['id'] as String;
                      final thumb = v['thumbnailUrl'] as String? ?? '';
                      final title = v['title'] as String? ?? 'Untitled Video';

                      return Obx(() {
                        final isSelected = controller.selectedVideoIds.contains(id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) {
                            controller.toggleVideoSelection(id, thumb);
                          },
                          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          secondary: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: thumb.isNotEmpty
                                ? CachedNetworkImage(imageUrl: thumb, width: 48, height: 32, fit: BoxFit.cover, errorWidget: (_, _, _) => const Icon(Icons.movie, color: Colors.white))
                                : const Icon(Icons.movie, color: Colors.white),
                          ),
                          activeColor: Colors.white,
                          checkColor: Colors.black,
                        );
                      });
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    },
  );
}
