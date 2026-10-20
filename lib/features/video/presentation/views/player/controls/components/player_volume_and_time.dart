import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_controls_buttons.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/widgets/video_chapters_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

class VolumeControl extends StatelessWidget {
  const VolumeControl({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => MouseRegion(
        onEnter: (_) => ctrl.volumeSliderVis.value = true,
        onExit: (_) => ctrl.volumeSliderVis.value = false,
        child: Row(
          children: [
            IconBtn(icon: ctrl.volumeIcon, onTap: ctrl.toggleMute),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: ctrl.volumeSliderVis.value
                  ? SizedBox(
                      width: 80,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: PT.primary,
                          inactiveTrackColor: AppColors.textDisabled,
                          thumbColor: PT.primary,
                          overlayColor: PT.primary.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: ctrl.volume.value,
                          onChanged: ctrl.setVolume,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class TimeDisplay extends StatelessWidget {
  const TimeDisplay({
    required this.ctrl,
    this.showChapters = true,
    super.key,
  });
  final TowerPlayerController ctrl;
  final bool showChapters;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _openChapters(BuildContext context) {
    if (ctrl.chapters.isEmpty) return;
    final isMobile =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS ||
        MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      VideoController? vc;
      try {
        if (ctrl.tag != null &&
            Get.isRegistered<VideoController>(tag: ctrl.tag)) {
          vc = Get.find<VideoController>(tag: ctrl.tag);
        } else if (Get.isRegistered<VideoController>()) {
          vc = Get.find<VideoController>();
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'PlayerControls.showChapters.findVideo',
        );
      }
      final video = vc?.video ??
          Video(
            id: ctrl.tag ?? '',
            title: '',
            description: '',
            videoUrl: '',
            thumbnailUrl: '',
            ownerId: '',
            channelId: '',
            channelName: '',
            category: '',
            tags: const [],
            chapters: ctrl.chapters.toList(),
          );
      VideoChaptersBottomSheet.show(
        context,
        video: video,
        videoTag: ctrl.tag,
      );
      return;
    }
    ctrl.activePanel.value = 'chapters';
    ctrl.settingsOpen.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final currentChapter = ctrl.currentChapter.value;
        final hasChapters = ctrl.chapters.isNotEmpty;
        final chapterTitle = showChapters
            ? (currentChapter?.title ?? (hasChapters ? 'Chapters' : null))
            : null;

        return Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: hasChapters ? () => _openChapters(context) : null,
            borderRadius: BorderRadius.circular(4),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${_fmt(ctrl.vv.position)} / ${_fmt(ctrl.vv.duration)}',
                    style: TS.time,
                  ),
                  if (chapterTitle != null) ...[
                    TextSpan(
                      text: ' • ',
                      style: TextStyle(
                        color: AppColors.textPrimary.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    TextSpan(
                      text: chapterTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(left: 2),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
