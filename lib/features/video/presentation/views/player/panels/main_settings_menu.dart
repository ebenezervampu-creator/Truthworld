import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';
import 'package:truthworld/theme/app_theme.dart';

class MainSettingsMenu extends StatelessWidget {
  const MainSettingsMenu({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: 'Settings',
            onBack: null,
            onClose: ctrl.closeSettings,
          ),

          // ── Category: Playback ───────────────────────────────────────────────
          const _CategoryHeader('Playback'),
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
              icon: Icons.slow_motion_video_rounded,
              title: 'Playback Speed',
              value: ctrl.playbackSpeed.value == 1.0
                  ? 'Normal'
                  : '${ctrl.playbackSpeed.value}×',
              onTap: () => ctrl.activePanel.value = 'speed',
            ),
          ),
          SettingsTile(
            icon: Icons.picture_in_picture_alt_rounded,
            title: 'Picture-in-Picture',
            value: 'Pop out player',
            onTap: () {
              ctrl.closeSettings();
              ctrl.togglePiP();
            },
          ),

          const PlayerDivider(),

          // ── Category: Audio & Localization ────────────────────────────────────
          const _CategoryHeader('Audio & Localization'),
          Obx(
            () => SettingsTile(
              icon: Icons.translate_rounded,
              title: 'Audio',
              value: ctrl.activeAudioLang.value,
              onTap: () => ctrl.activePanel.value = 'language',
            ),
          ),
          Obx(
            () => ToggleTile(
              icon: Icons.music_note_rounded,
              title: 'Audio-only Mode',
              value: ctrl.isAudioOnly.value,
              onChanged: (_) => ctrl.toggleAudioOnly(),
            ),
          ),
          Obx(() {
            if (!ctrl.isAudioOnly.value) return const SizedBox.shrink();
            return SettingsTile(
              icon: Icons.palette_outlined,
              title: 'Audio Theme',
              value: TowerPlayerPreferences.globalAudioTheme.value.displayName,
              onTap: () => ctrl.activePanel.value = 'audio_theme',
            );
          }),

          const PlayerDivider(),

          // ── Category: Subtitles ──────────────────────────────────────────────
          const _CategoryHeader('Subtitles'),
          Obx(
            () => SettingsTile(
              icon: Icons.closed_caption_rounded,
              title: 'Subtitles',
              value: ctrl.subtitlesEnabled.value
                  ? ctrl.activeSubLang.value
                  : 'Off',
              onTap: () => ctrl.activePanel.value = 'subtitles',
            ),
          ),

          const PlayerDivider(),

          // ── Category: Playback Statistics & Advanced ──────────────────────────
          const _CategoryHeader('Playback Statistics & Advanced'),
          Obx(
            () => ToggleTile(
              icon: Icons.analytics_outlined,
              title: 'Playback Statistics',
              value: ctrl.showStatsForNerds.value,
              onChanged: (_) => ctrl.showStatsForNerds.toggle(),
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
          Obx(
            () => ToggleTile(
              icon: Icons.repeat_rounded,
              title: 'Loop Video',
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
