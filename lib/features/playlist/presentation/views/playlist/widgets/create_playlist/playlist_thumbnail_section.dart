import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/playlist/presentation/controllers/create_playlist_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Step 5: Playlist Thumbnail Selection Section.
class PlaylistThumbnailSection extends StatelessWidget {
  const PlaylistThumbnailSection({
    required this.controller,
    required this.isDesktop,
    this.fromUpload = false,
    super.key,
  });

  final CreatePlaylistController controller;
  final bool isDesktop;
  final bool fromUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '5. Playlist Thumbnail',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a thumbnail for your playlist',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Option 1: Selected Video Thumbnail
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Obx(() {
                  final useCustom = controller.useCustomThumbnail.value;
                  final selectedIdx = controller.selectedThumbnailIndex.value;
                  final videos = controller.selectedVideos;

                  return InkWell(
                    onTap: () => controller.setUseCustomThumbnail(false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F11),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !useCustom
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.1),
                          width: !useCustom ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: !useCustom
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: !useCustom
                                    ? Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Use thumbnail from selected video',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              'Choose from your selected videos',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // List of video thumbnails
                          if (videos.isEmpty)
                            Text(
                              fromUpload
                                  ? 'Will use the thumbnail from your uploading video (or choose a custom image)'
                                  : 'Select videos first',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            SizedBox(
                              height: 64,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: videos.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, i) {
                                  final isSelected =
                                      !useCustom && selectedIdx == i;
                                  final v = videos[i];

                                  return GestureDetector(
                                    onTap: () =>
                                        controller.setSelectedThumbnailIndex(i),
                                    child: Container(
                                      width: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            CachedNetworkImage(
                                              imageUrl: v.thumbnailUrl,
                                              fit: BoxFit.cover,
                                            ),
                                            Positioned(
                                              right: 4,
                                              bottom: 4,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 3,
                                                  vertical: 1,
                                                ),
                                                color: Colors.black.withValues(
                                                  alpha: 0.8,
                                                ),
                                                child: Text(
                                                  v.duration,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              if (!isDesktop)
                const SizedBox(height: 12)
              else
                const SizedBox(width: 16),

              // Option 2: Upload Custom Image
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Obx(() {
                  final useCustom = controller.useCustomThumbnail.value;
                  final customBytes = controller.customImageBytes.value;
                  final customName = controller.customImageName.value;

                  return InkWell(
                    onTap: () {
                      controller.setUseCustomThumbnail(true);
                      controller.pickCustomImage();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F11),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: useCustom
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.1),
                          width: useCustom ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: useCustom
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: useCustom
                                    ? Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Upload custom image',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              'Pick an image from your device',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Dropzone / Upload Box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                if (customBytes != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.memory(
                                      customBytes,
                                      height: 50,
                                      width: 90,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    customName ?? 'Custom Image',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(
                                    Icons.file_upload_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Upload image',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'PNG, JPG or WEBP. Max 5MB.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
