import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog allowing advertiser to select from authentic channel videos.
void showCampaignVideosPicker(
  BuildContext context,
  AdvertiserPortalController controller, {
  required Function(Map<String, dynamic>) onSelected,
}) {
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
            color: AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.bgSurface),
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
              const Divider(color: AppColors.bgSurface),
              const SizedBox(height: 8),
              const Text(
                'Pick a published video from your channel for this advertising campaign.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  final videos = controller.channelVideos;

                  if (controller.isLoadingVideos.value) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (videos.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.video_library_outlined,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No Channel Videos Found',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Please publish a video to your channel first, or select "Pick from Device" in the campaign wizard to upload a custom video file directly.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: Get.back,
                            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 16),
                            label: const Text(
                              'Return to Wizard',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final video = videos[index];
                      final title = video['title']?.toString() ?? 'Untitled Video';
                      final description = video['description']?.toString() ?? '';
                      final thumbnailUrl = video['thumbnailUrl']?.toString() ?? '';

                      return Card(
                        color: AppColors.bgInput,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppColors.bgSurface),
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 60,
                              height: 36,
                              color: AppColors.bgPage,
                              child: thumbnailUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: thumbnailUrl,
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
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: description.isNotEmpty
                              ? Text(
                                  description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
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

/// Guides advertiser to upload their authentic brand banner.
void showCampaignImagePicker(
  BuildContext context, {
  required Function(String) onSelectedUrl,
}) {
  AppSnackbar.info('Please select your authentic brand banner using "Pick from Device".');
}

/// Backward-compatible alias.
void showImagePicker(
  BuildContext context, {
  required Function(String) onSelectedUrl,
}) => showCampaignImagePicker(context, onSelectedUrl: onSelectedUrl);
