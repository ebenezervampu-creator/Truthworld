import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/mobile_friendly_video_player.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section 2: Video File Selection, Preview Player, and Upload Progress
class CreateContentVideoFileSection extends StatelessWidget {
  const CreateContentVideoFileSection({
    required this.uploadController,
    super.key,
  });

  final UploadController uploadController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pickedVideo = uploadController.pickedVideo.value;
      final videoUrl = uploadController.videoUrl.value;
      final isUploading = uploadController.isUploading.value;
      final progressPercent = uploadController.uploadProgressPercent;
      final playerCtrl = uploadController.videoPlayerController;
      final resumedDraft = uploadController.resumedVideoDraft.value;
      final hasVideo =
          pickedVideo != null || videoUrl.isNotEmpty || resumedDraft != null;
      final videoName = pickedVideo?.name ??
          (resumedDraft?.title.isNotEmpty == true
              ? resumedDraft!.title
              : 'Video File Ready');

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '2. Video File',
                  style: context.themeTypography.title.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: uploadController.pickVideo,
                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                  label: Text(
                    hasVideo ? 'Change video' : 'Select video',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasVideo)
              InkWell(
                onTap: uploadController.pickVideo,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F11),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_upload_outlined,
                          color: Colors.white, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Select video to upload',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Click or drag video file to upload (MP4, MOV, MKV, WEBM)',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    if (playerCtrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: MobileFriendlyVideoPlayer(
                            controller: playerCtrl,
                            showControls: true,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.movie_creation_outlined,
                                color: Colors.white, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'Video Uploaded & Ready',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.video_library,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  videoName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isUploading)
                                  Text(
                                    'Uploading: $progressPercent',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.7),
                                        fontSize: 11),
                                  )
                                else
                                  Text(
                                    hasVideo ? 'Video attached and ready' : '',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.6),
                                        fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isUploading)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: uploadController.uploadProgress.value,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.1),
                            color: Colors.white,
                            minHeight: 4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// Section 1: Thumbnail Image Selection and 16:9 Aspect Ratio Preview
class CreateContentThumbnailSection extends StatelessWidget {
  const CreateContentThumbnailSection({
    required this.uploadController,
    super.key,
  });

  final UploadController uploadController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pickedImage = uploadController.pickedImage.value;
      final thumbnailUrl = uploadController.thumbnailUrl.value;

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
              '1. Thumbnail',
              style: context.themeTypography.title.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose or upload a 16:9 thumbnail for your video',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            if (pickedImage != null &&
                ((kIsWeb && pickedImage.bytes != null) ||
                    (pickedImage.path != null &&
                        pickedImage.path!.isNotEmpty) ||
                    pickedImage.bytes != null))
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (kIsWeb && pickedImage.bytes != null)
                        ? Image.memory(pickedImage.bytes!, fit: BoxFit.cover)
                        : (pickedImage.path != null
                            ? Image.file(io.File(pickedImage.path!),
                                fit: BoxFit.cover)
                            : (pickedImage.bytes != null
                                ? Image.memory(pickedImage.bytes!,
                                    fit: BoxFit.cover)
                                : const SizedBox.shrink())),
                  ),
                ),
              )
            else if (thumbnailUrl.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (ctx, url, err) => const ColoredBox(
                        color: Color(0xFF0F0F11),
                        child: Icon(Icons.image, color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ),
              ),
            InkWell(
              onTap: () => uploadController.pickImage(forCommunity: false),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.file_upload_outlined,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickedImage != null || thumbnailUrl.isNotEmpty
                                ? 'Change Thumbnail'
                                : 'Upload custom image',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          Text(
                            '16:9 Aspect Ratio (1280x720). Max 2MB. PNG, JPG or WEBP.',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
