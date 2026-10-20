import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/audio_theme_panel.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/chapters_panel.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/language_panel.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/quality_panel.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/speed_zoom_panels.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/subtitle_style_panel.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/subtitles_panel.dart';
import 'package:truthworld/theme/app_theme.dart';

class MobileSettingsBottomSheet extends StatelessWidget {
  const MobileSettingsBottomSheet({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  static void show(BuildContext context, TowerPlayerController ctrl) {
    Get.bottomSheet(
      MobileSettingsBottomSheet(ctrl: ctrl),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enterBottomSheetDuration: const Duration(milliseconds: 250),
      exitBottomSheetDuration: const Duration(milliseconds: 150),
    ).then((_) {
      // Reset state when closed
      ctrl.activePanel.value = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: const Color(
            0xFF1E1E1E,
          ), // Premium dark theme matching screenshot
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Obx(() {
              Widget content;
              switch (ctrl.activePanel.value) {
                case 'speed':
                  content = SpeedPanel(ctrl: ctrl);
                case 'quality':
                  content = QualityPanel(ctrl: ctrl);
                case 'chapters':
                  content = SizedBox(
                    height: 480,
                    child: ChaptersPanel(ctrl: ctrl),
                  );
                case 'subtitles':
                  content = SizedBox(
                    height: 450,
                    child: SubtitlesPanel(ctrl: ctrl),
                  );
                case 'subtitle_settings':
                  content = SizedBox(
                    height: 480,
                    child: SubtitleSettingsPanel(ctrl: ctrl),
                  );
                case 'subtitle_style':
                  content = SizedBox(
                    height: 500,
                    child: SubtitleStylePanel(ctrl: ctrl),
                  );
                case 'language':
                  content = SizedBox(
                    height: 450,
                    child: LanguagePanel(ctrl: ctrl),
                  );
                case 'audio_settings':
                  content = SizedBox(
                    height: 480,
                    child: AudioSettingsPanel(ctrl: ctrl),
                  );
                case 'audio_theme':
                  content = SizedBox(
                    height: 480,
                    child: AudioThemePanel(ctrl: ctrl),
                  );
                case 'zoom':
                  content = ZoomPanel(ctrl: ctrl);
                case 'more':
                  content = MorePanel(ctrl: ctrl);
                case 'sleep_timer':
                  content = SleepTimerPanel(ctrl: ctrl);
                default:
                  content = MobileMainSettingsMenu(ctrl: ctrl);
              }

              return AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: content,
              );
            }),
          ),
        ),
      ),
    );
  }
}

class MobileMainSettingsMenu extends StatelessWidget {
  const MobileMainSettingsMenu({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle at top center of bottom sheet
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Obx(
            () => MobileSettingsTile(
              icon: Icons.tune_rounded,
              title: 'Quality',
              value: ctrl.abr.isAutoMode.value
                  ? 'Auto (${ctrl.currentQualityLabel})'
                  : ctrl.currentQualityLabel,
              onTap: () => ctrl.activePanel.value = 'quality',
            ),
          ),
          Obx(
            () => MobileSettingsTile(
              icon: Icons.play_circle_outline_rounded,
              title: 'Playback speed',
              value: ctrl.playbackSpeed.value == 1.0
                  ? 'Normal'
                  : '${ctrl.playbackSpeed.value}x',
              onTap: () => ctrl.activePanel.value = 'speed',
            ),
          ),
          Obx(
            () => MobileSettingsTile(
              icon: Icons.closed_caption_rounded,
              title: 'Captions',
              value: ctrl.subtitlesEnabled.value
                  ? ctrl.activeSubLang.value
                  : 'Off',
              onTap: () => ctrl.activePanel.value = 'subtitles',
            ),
          ),
          Obx(
            () => MobileSettingsTile(
              icon: Icons.settings_voice_rounded,
              title: 'Audio Track',
              value: ctrl.activeAudioLang.value,
              onTap: () => ctrl.activePanel.value = 'language',
            ),
          ),
          Obx(
            () => MobileSettingsTile(
              icon: Icons.zoom_in_rounded,
              title: 'Zoom',
              value: ctrl.zoomLabel,
              onTap: () => ctrl.activePanel.value = 'zoom',
            ),
          ),
          Obx(
            () => ctrl.chapters.isNotEmpty
                ? MobileSettingsTile(
                    icon: Icons.list_alt_rounded,
                    title: 'Chapters',
                    value: ctrl.currentChapter.value?.title ??
                        '${ctrl.chapters.length} chapters',
                    onTap: () => ctrl.activePanel.value = 'chapters',
                  )
                : const SizedBox.shrink(),
          ),
          MobileSettingsTile(
            icon: Icons.settings_outlined,
            title: 'More',
            value: '',
            onTap: () => ctrl.activePanel.value = 'more',
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class MobileSettingsTile extends StatelessWidget {
  const MobileSettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 22),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  title,
                  style: TS.body.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (value.isNotEmpty)
                Flexible(
                  child: Text(
                    value,
                    style: TS.bodySm.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textPrimary.withValues(alpha: 0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileToggleTile extends StatelessWidget {
  const MobileToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 22),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  title,
                  style: TS.body.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.textPrimary,
                activeTrackColor: PT.primary,
                inactiveThumbColor: AppColors.textTertiary,
                inactiveTrackColor: AppColors.bgDivider,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MorePanel extends StatelessWidget {
  const MorePanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeader(
          title: 'More',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        const PlayerDivider(),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => MobileToggleTile(
                    icon: Icons.repeat_rounded,
                    title: 'Loop video',
                    value: ctrl.isLooping.value,
                    onChanged: (v) => ctrl.toggleLoop(),
                  ),
                ),
                Obx(
                  () => MobileToggleTile(
                    icon: Icons.music_note_rounded,
                    title: 'Audio Only Mode',
                    value: ctrl.isAudioOnly.value,
                    onChanged: (v) => ctrl.toggleAudioOnly(),
                  ),
                ),
                Obx(() {
                  if (!ctrl.isAudioOnly.value) return const SizedBox.shrink();
                  return MobileSettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Audio Theme',
                    value: TowerPlayerPreferences.globalAudioTheme.value.displayName,
                    onTap: () => ctrl.activePanel.value = 'audio_theme',
                  );
                }),
                Obx(
                  () => MobileToggleTile(
                    icon: Icons.playlist_play_rounded,
                    title: 'Autoplay Next',
                    value: ctrl.isAutoplay.value,
                    onChanged: (v) => ctrl.toggleAutoplay(),
                  ),
                ),
                Obx(
                  () => MobileToggleTile(
                    icon: Icons.analytics_outlined,
                    title: 'Stats for Nerds',
                    value: ctrl.showStatsForNerds.value,
                    onChanged: (v) => ctrl.showStatsForNerds.toggle(),
                  ),
                ),
                Obx(
                  () => MobileToggleTile(
                    icon: Icons.view_sidebar_rounded,
                    title: 'Fullscreen Action Bar',
                    value: ctrl.showFullscreenActionsDock.value,
                    onChanged: (v) => ctrl.showFullscreenActionsDock.toggle(),
                  ),
                ),
                Obx(
                  () => MobileToggleTile(
                    icon: Icons.aspect_ratio_rounded,
                    title: 'Zoom to Fill',
                    value: ctrl.isZoomToFill.value,
                    onChanged: (v) => ctrl.toggleZoomToFill(),
                  ),
                ),
                Obx(
                  () => MobileSettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Lock screen',
                    value: ctrl.lockController.isLocked.value
                        ? 'Locked'
                        : 'Off',
                    onTap: () {
                      ctrl.closeSettings();
                      ctrl.lockController.lock();
                    },
                  ),
                ),
                Obx(() {
                  final isActive = ctrl.isSleepTimerActive.value;
                  final isAtEnd = ctrl.isSleepTimerAtEndOfVideo.value;
                  final rem = ctrl.sleepTimerRemainingSeconds.value;
                  var valueText = 'Off';
                  if (isActive) {
                    if (isAtEnd) {
                      valueText = 'End of video';
                    } else {
                      final mins = rem ~/ 60;
                      final secs = rem % 60;
                      valueText =
                          '$mins:${secs.toString().padLeft(2, '0')} left';
                    }
                  }
                  return MobileSettingsTile(
                    icon: Icons.nights_stay_rounded,
                    title: 'Sleep timer',
                    value: valueText,
                    onTap: () => ctrl.activePanel.value = 'sleep_timer',
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
