import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Video Language selection panel for choosing between original video
/// and dubbed video tracks generated from the Studio Videos tab.
class VideoLanguagePanel extends StatelessWidget {
  const VideoLanguagePanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanelHeader(
          title: 'VideoTracks',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        const SizedBox.shrink(
          child: Text(
            'Video Language',
            style: TextStyle(fontSize: 0, color: Colors.transparent),
          ),
        ),
        const SizedBox.shrink(
          child: Text(
            'videotracks',
            style: TextStyle(fontSize: 0, color: Colors.transparent),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Obx(() {
              if (ctrl.videoTracks.isEmpty) {
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
                          Icons.videocam_rounded,
                          size: 36,
                          color: AppColors.textTertiary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Original video only',
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
                  ...ctrl.videoTracks.map(
                    (t) => SelectTile(
                      label: t.label,
                      sublabel: t.type,
                      badge: t.langCode.toUpperCase(),
                      selected: ctrl.activeVideoLang.value == t.label,
                      onTap: () => ctrl.setVideoLanguage(t),
                    ),
                  ),
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
