import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/video_chapters_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Expandable chapters section displaying timestamp segments and active marker.
class VideoChaptersSection extends StatelessWidget {
  const VideoChaptersSection({
    required this.controller,
    this.videoTag,
    super.key,
  });

  final VideoController controller;
  final String? videoTag;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chapters = controller.video.chapters;
      if (chapters.isEmpty) return const SizedBox.shrink();

      final playerCtrl = Get.isRegistered<TowerPlayerController>(tag: videoTag)
          ? Get.find<TowerPlayerController>(tag: videoTag)
          : (Get.isRegistered<TowerPlayerController>()
              ? Get.find<TowerPlayerController>()
              : null);

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.bgDivider.withValues(alpha: 0.5),
          ),
        ),
        child: ExpansionTile(
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          title: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => VideoChaptersBottomSheet.show(
                context,
                video: controller.video,
                videoTag: videoTag,
              ),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.bookmarks_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Chapters',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF162A45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        chapters.length.toString(),
                        style: const TextStyle(
                          color: AppColors.textLink,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (playerCtrl != null)
                  Obx(() {
                    final current = playerCtrl.currentChapter.value;
                    if (current == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Current: ${current.localizedTitle()}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          childrenPadding: EdgeInsets.zero,
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chapters.length,
              padding: const EdgeInsets.only(bottom: 8),
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                return ChapterTile(
                  chapter: chapter,
                  video: controller.video,
                  playerCtrl: playerCtrl,
                  index: index,
                );
              },
            ),
          ],
        ),
      );
    });
  }
}
