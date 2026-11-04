import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';
import 'package:truthworld/features/video/presentation/widgets/audio_themes_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Panel allowing users to select their preferred music visualizer theme for Audio-Only mode.
class AudioThemePanel extends StatelessWidget {
  const AudioThemePanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeader(
          title: 'Audio Themes',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        const PlayerDivider(),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Obx(() {
              final activeTheme = TowerPlayerPreferences.globalAudioTheme.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: Text(
                      'Select visual styling for audio-only mode:',
                      style: TS.bodySm.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  ...AudioPlayerTheme.values.map((theme) {
                    final isSelected = activeTheme == theme;
                    return AudioThemeTile(
                      theme: theme,
                      isSelected: isSelected,
                      onTap: () {
                        TowerPlayerPreferences.globalAudioThemeValue = theme;
                        ctrl.showToast('Theme set: ${theme.displayName}');
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
