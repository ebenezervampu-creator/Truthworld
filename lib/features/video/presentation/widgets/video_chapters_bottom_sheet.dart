import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet and standalone widgets for displaying video chapters
/// with exact UI architecture adhering to AppFonts and AppThemes design guidelines.
class VideoChaptersBottomSheet extends StatelessWidget {
  const VideoChaptersBottomSheet({
    required this.video,
    super.key,
    this.videoTag,
  });

  final Video video;
  final String? videoTag;

  static void show(
    BuildContext context, {
    required Video video,
    String? videoTag,
  }) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            VideoChaptersBottomSheet(video: video, videoTag: videoTag),
      ),
    );
  }

  TowerPlayerController? _getPlayerController() {
    try {
      if (videoTag != null &&
          Get.isRegistered<TowerPlayerController>(tag: videoTag)) {
        return Get.find<TowerPlayerController>(tag: videoTag);
      }
      if (Get.isRegistered<TowerPlayerController>(tag: video.id)) {
        return Get.find<TowerPlayerController>(tag: video.id);
      }
      if (Get.isRegistered<TowerPlayerController>()) {
        return Get.find<TowerPlayerController>();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoChaptersBottomSheet.getPlayerController',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final playerCtrl = _getPlayerController();
    final chapters = video.chapters.isNotEmpty
        ? video.chapters
        : (playerCtrl?.chapters ?? const <VideoChapter>[]);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Drag Indicator Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chapters',
                      style: context.twTypography.headline.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white, // Rule: White icon
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.bgDivider),

              // Chapter List
              Expanded(
                child: chapters.isEmpty
                    ? Center(
                        child: Text(
                          'No chapters available for this video',
                          style: context.twTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: chapters.length,
                        itemBuilder: (context, index) {
                          final chapter = chapters[index];
                          return ChapterTile(
                            chapter: chapter,
                            video: video,
                            playerCtrl: playerCtrl,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Chapter Item Card following exact UI Architecture
class ChapterTile extends StatelessWidget {
  const ChapterTile({
    required this.chapter,
    required this.video,
    super.key,
    this.playerCtrl,
    this.onTapOverride,
  });

  final VideoChapter chapter;
  final Video video;
  final TowerPlayerController? playerCtrl;
  final VoidCallback? onTapOverride;

  @override
  Widget build(BuildContext context) {
    final ctrl = playerCtrl;
    if (ctrl == null) {
      return _buildContent(context, isCurrent: false);
    }
    return Obx(() {
      final isCurrent = ctrl.currentChapter.value == chapter;
      return _buildContent(context, isCurrent: isCurrent);
    });
  }

  Widget _buildContent(BuildContext context, {required bool isCurrent}) {
    final thumbUrl =
        (chapter.thumbnailUrl != null && chapter.thumbnailUrl!.isNotEmpty)
            ? chapter.thumbnailUrl!
            : video.thumbnailUrl;

    return InkWell(
      onTap: onTapOverride ??
          () {
            if (playerCtrl != null) {
              unawaited(playerCtrl!.seekTo(chapter.startTime));
            }
          },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isCurrent ? AppColors.bgSurfaceHover : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapter Thumbnail Container
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 140,
                height: 78,
                color: AppColors.bgInput,
                child: thumbUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white, // Rule: White icon
                            size: 28,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: Colors.white, // Rule: White icon
                          size: 28,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Title and Action Icons
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    chapter.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.twTypography.title.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Share Icon
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            ShareBottomSheet.show(
                              title: chapter.title,
                              url:
                                  'https://truthworld.app/watch?v=${video.id}&t=${chapter.startTime.inSeconds}',
                              thumbnailUrl:
                                  chapter.thumbnailUrl ?? video.thumbnailUrl,
                              currentPosition: chapter.startTime,
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.share_outlined,
                              color: Colors.white, // Rule: White icon
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Replay Icon
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            if (playerCtrl != null) {
                              unawaited(
                                playerCtrl!.seekTo(chapter.startTime),
                              );
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.repeat_rounded,
                              color: Colors.white, // Rule: White icon
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Timestamp Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF162A45), // Signature dark blue badge
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                chapter.formattedStartTime,
                style: const TextStyle(
                  color: Color(0xFF3EA6FF), // Signature light blue time text
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
