import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog allowing advertiser to select from channel videos or high-quality presets.
void showCampaignVideosPicker(
  BuildContext context,
  AdvertiserPortalController controller, {
  required Function(Map<String, dynamic>) onSelected,
}) {
  final presetVideos = [
    {
      'id': 'preset_bumper',
      'title': '5-Sec Pre-Roll Bumper Sample (Butterfly HD)',
      'description': 'Short 5-second video sample for sponsor intro bumper',
      'videoUrl': 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1523474253046-8cd2748b5fd2?w=500',
    },
    {
      'id': 'preset_midroll',
      'title': '7-Min Mid-roll Video Sample (Bee HD)',
      'description': 'Detailed product video for 7-minute skippable mid-roll ad',
      'videoUrl': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=500',
    },
  ];

  Get.dialog(
    Dialog(
      backgroundColor: Colors.transparent,
      child: Semantics(
        label: 'Select Video Dialog',
        container: true,
        namesRoute: true,
        child: Container(
          width: 500,
          height: 480,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Video Creative',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: Get.back,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF27272A)),
              const SizedBox(height: 8),
              const Text(
                'Pick from your channel videos or select a high-quality video preset.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  final allVideos = [
                    ...presetVideos,
                    ...controller.channelVideos,
                  ];

                  return ListView.builder(
                    itemCount: allVideos.length,
                    itemBuilder: (context, index) {
                      final video = allVideos[index];
                      final isPreset = video['id'].toString().startsWith('preset');
                      return Card(
                        color: const Color(0xFF121212),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFF27272A)),
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 60,
                              height: 36,
                              color: const Color(0xFF18181B),
                              child: (video['thumbnailUrl']?.toString().isNotEmpty ?? false)
                                  ? CachedNetworkImage(
                                      imageUrl: video['thumbnailUrl'],
                                      fit: BoxFit.cover,
                                      placeholder: (c, u) => const Icon(
                                        Icons.video_library_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      errorWidget: (c, u, o) => const Icon(
                                        Icons.video_library_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.video_library_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  video['title'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (isPreset)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF27272A),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Preset',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            video['description'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          onTap: () {
                            onSelected(video);
                            Get.back();
                          },
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


/// Backward-compatible alias.
void showChannelVideosPicker(
  BuildContext context,
  AdvertiserPortalController controller, {
  required Function(Map<String, dynamic>) onSelected,
}) => showCampaignVideosPicker(context, controller, onSelected: onSelected);

/// Modal dialog allowing advertiser to pick a banner image from sample presets.
void showCampaignImagePicker(
  BuildContext context, {
  required Function(String) onSelectedUrl,
}) {
  final sampleImages = [
    {
      'name': 'Tech & Gadgets Banner',
      'url': 'https://images.unsplash.com/photo-1523474253046-8cd2748b5fd2?w=500',
    },
    {
      'name': 'Mobile & App Showcase Banner',
      'url': 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=500',
    },
    {
      'name': 'Brand Promotion Banner',
      'url': 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=500',
    },
  ];

  Get.dialog(
    Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        height: 400,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pick Sponsor Banner Image',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: Get.back,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xFF27272A)),
            const SizedBox(height: 8),
            const Text(
              'Select a brand image from sample presets for the recommended videos list.',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: sampleImages.length,
                itemBuilder: (context, idx) {
                  final item = sampleImages[idx];
                  return Card(
                    color: const Color(0xFF121212),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF27272A)),
                    ),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: item['url']!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        item['name']!,
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      onTap: () {
                        onSelectedUrl(item['url']!);
                        Get.back();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


/// Backward-compatible alias.
void showImagePicker(
  BuildContext context, {
  required Function(String) onSelectedUrl,
}) => showCampaignImagePicker(context, onSelectedUrl: onSelectedUrl);
