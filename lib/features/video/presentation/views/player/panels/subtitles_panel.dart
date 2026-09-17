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
          actionIcon: Icons.tune_rounded,
          onAction: () => ctrl.activePanel.value = 'subtitle_style',
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Obx(
                  () => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.closed_caption_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Subtitles',
                          style: TS.body.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: ctrl.subtitlesEnabled.value,
                          onChanged: (v) => ctrl.setSubtitles(enabled: v),
                          activeThumbColor: PT.primary,
                          activeTrackColor: PT.primary.withValues(alpha: 0.4),
                          inactiveThumbColor: AppColors.textTertiary,
                          inactiveTrackColor: AppColors.bgDivider,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),
                ),
                const PlayerDivider(),
                SettingsTile(
                  icon: Icons.tune_rounded,
                  title: 'Subtitle Appearance & Style',
                  value: 'Customize',
                  onTap: () => ctrl.activePanel.value = 'subtitle_style',
                ),
                const PlayerDivider(),
                Obx(() {
                  if (ctrl.subtitleTracks.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No subtitles available',
                          style: TS.bodySm,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: ctrl.subtitleTracks
                        .map(
                          (t) => SelectTile(
                            label: t.label,
                            badge: t.langCode.toUpperCase(),
                            selected:
                                ctrl.subtitlesEnabled.value &&
                                ctrl.activeSubLang.value == t.label,
                            dimmed: !ctrl.subtitlesEnabled.value,
                            onTap: ctrl.subtitlesEnabled.value
                                ? () => ctrl.setSubtitles(
                                      enabled: true,
                                      track: t,
                                    )
                                : null,
                          ),
                        )
                        .toList(),
                  );
                }),
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
