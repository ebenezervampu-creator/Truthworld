import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/language_requests.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';
import 'package:truthworld/features/video/presentation/widgets/language_preferences_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubtitlesPanel extends StatelessWidget {
  const SubtitlesPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanelHeader(
          title: 'Subtitles / CC',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
          actionIcon: Icons.settings_outlined,
          onAction: () => ctrl.activePanel.value = 'subtitle_settings',
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Obx(() {
              if (ctrl.subtitleTracks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 48,
                    horizontal: 24,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.closed_caption_disabled_rounded,
                          size: 36,
                          color: AppColors.textTertiary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No subtitles available',
                          style: TS.bodySm,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  const SizedBox(height: 6),
                  ...ctrl.subtitleTracks.map((t) {
                    final isSelected = ctrl.subtitlesEnabled.value &&
                        ctrl.activeSubLang.value == t.label;
                    return SelectTile(
                      label: t.label,
                      badge: t.langCode.toUpperCase(),
                      selected: isSelected,
                      onTap: () {
                        if (isSelected) {
                          ctrl.setSubtitles(enabled: false);
                        } else {
                          ctrl.setSubtitles(
                            enabled: true,
                            track: t,
                          );
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class SubtitleSettingsPanel extends StatelessWidget {
  const SubtitleSettingsPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanelHeader(
          title: 'Subtitle Settings',
          onBack: () => ctrl.activePanel.value = 'subtitles',
          onClose: null,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.tune_rounded,
                  title: 'Subtitle Appearance & Style',
                  value: 'Customize',
                  onTap: () => ctrl.activePanel.value = 'subtitle_style',
                ),
                const PlayerDivider(),
                Obx(
                  () => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sync_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sync Timing Offset',
                              style: TS.body.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              ctrl.subtitleOffsetMs.value == 0
                                  ? 'Exact (0ms)'
                                  : '${ctrl.subtitleOffsetMs.value > 0 ? "+" : ""}${ctrl.subtitleOffsetMs.value}ms',
                              style: TS.bodySm.copyWith(
                                color: ctrl.subtitleOffsetMs.value != 0
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          iconSize: 20,
                          color: AppColors.textPrimary,
                          tooltip: 'Delay -100ms',
                          onPressed: () => ctrl.adjustSubtitleOffset(-100),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          iconSize: 18,
                          color: AppColors.textSecondary,
                          tooltip: 'Reset offset',
                          onPressed: ctrl.subtitleOffsetMs.value != 0
                              ? ctrl.resetSubtitleOffset
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          iconSize: 20,
                          color: AppColors.textPrimary,
                          tooltip: 'Advance +100ms',
                          onPressed: () => ctrl.adjustSubtitleOffset(100),
                        ),
                      ],
                    ),
                  ),
                ),
                const PlayerDivider(),
                ConfigureLanguagesButton(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const LanguagePreferencesDialog(),
                  ),
                ),
                const PlayerDivider(),
                RequestLanguageButton(
                  type: 'subtitle',
                  onTap: () => ctrl.showRequestDialog(context, 'subtitle'),
                ),
                const PlayerDivider(),
                LanguageRequestsList(type: 'subtitle', tag: ctrl.tag),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
