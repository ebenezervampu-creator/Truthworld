import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';

class MainSettingsMenu extends StatelessWidget {
  const MainSettingsMenu({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            title: 'Settings',
            onBack: null,
            onClose: ctrl.closeSettings,
          ),
          Obx(
            () => SettingsTile(
              icon: Icons.slow_motion_video_rounded,
              title: 'Playback Speed',
              value: ctrl.playbackSpeed.value == 1.0
                  ? 'Normal'
                  : '${ctrl.playbackSpeed.value}×',
              onTap: () => ctrl.activePanel.value = 'speed',
            ),
          ),
          Obx(
            () => SettingsTile(
              icon: Icons.tune_rounded,
              title: 'Quality',
              value: ctrl.currentQualityLabel,
              badge: ctrl.abr.isAutoMode.value ? 'AUTO' : null,
              onTap: () => ctrl.activePanel.value = 'quality',
            ),
          ),
          Obx(
            () => SettingsTile(
              icon: Icons.closed_caption_rounded,
              title: 'Subtitles / CC',
              value: ctrl.subtitlesEnabled.value
                  ? ctrl.activeSubLang.value
                  : 'Off',
              onTap: () => ctrl.activePanel.value = 'subtitles',
            ),
          ),
          Obx(
            () => SettingsTile(
              icon: Icons.translate_rounded,
              title: 'Audio Language',
              value: ctrl.activeAudioLang.value,
              onTap: () => ctrl.activePanel.value = 'language',
            ),
          ),
          Obx(
            () => ctrl.chapters.isNotEmpty
                ? SettingsTile(
                    icon: Icons.list_alt_rounded,
                    title: 'Chapters',
                    value: ctrl.currentChapter.value?.title ?? 'None',
                    onTap: () => ctrl.activePanel.value = 'chapters',
                  )
                : const SizedBox.shrink(),
          ),
          SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Content Details',
            value: ctrl.contentMeta.rating,
            onTap: () => ctrl.activePanel.value = 'rating',
          ),
          const PlayerDivider(),
          Obx(
            () => ToggleTile(
              icon: Icons.repeat_rounded,
              title: 'Loop',
              value: ctrl.isLooping.value,
              onChanged: (_) => ctrl.toggleLoop(),
            ),
          ),
          Obx(
            () => ToggleTile(
              icon: Icons.playlist_play_rounded,
              title: 'Autoplay Next',
              value: ctrl.isAutoplay.value,
              onChanged: (_) => ctrl.toggleAutoplay(),
            ),
          ),
          Obx(
            () => ToggleTile(
              icon: Icons.music_note_rounded,
              title: 'Audio Only Mode',
              value: ctrl.isAudioOnly.value,
              onChanged: (_) => ctrl.toggleAudioOnly(),
            ),
          ),
          Obx(
            () => ToggleTile(
              icon: Icons.analytics_outlined,
              title: 'Stats for Nerds',
              value: ctrl.showStatsForNerds.value,
              onChanged: (_) => ctrl.showStatsForNerds.toggle(),
            ),
          ),
          Obx(
            () => ToggleTile(
              icon: Icons.view_sidebar_rounded,
              title: 'Fullscreen Action Bar',
              value: ctrl.showFullscreenActionsDock.value,
              onChanged: (_) => ctrl.showFullscreenActionsDock.toggle(),
            ),
          ),
          Obx(
            () => SettingsTile(
              icon: Icons.zoom_in_rounded,
              title: 'Zoom',
              value: ctrl.zoomLabel,
              onTap: () => ctrl.activePanel.value = 'zoom',
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
