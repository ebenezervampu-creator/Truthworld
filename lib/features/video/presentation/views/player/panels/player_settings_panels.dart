import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/player_settings_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'player_settings_widgets.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ctrl.closeSettings,
      behavior: HitTestBehavior.opaque,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          color: AppColors.bgPage.withValues(alpha: 0.5),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // absorb inner taps
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 340,
                  constraints: const BoxConstraints(maxHeight: 520),
                  decoration: BoxDecoration(
                    color: PT.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PT.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bgPage.withValues(alpha: 0.7),
                        blurRadius: 32,
                        spreadRadius: 8,
                      ),
                      BoxShadow(
                        color: PT.primary.withValues(alpha: 0.12),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Obx(() {
                      switch (ctrl.activePanel.value) {
                        case 'speed':
                          return SpeedPanel(ctrl: ctrl);
                        case 'quality':
                          return QualityPanel(ctrl: ctrl);
                        case 'subtitles':
                          return SubtitlesPanel(ctrl: ctrl);
                        case 'subtitle_settings':
                          return SubtitleSettingsPanel(ctrl: ctrl);
                        case 'subtitle_style':
                          return SubtitleStylePanel(ctrl: ctrl);
                        case 'language':
                          return LanguagePanel(ctrl: ctrl);
                        case 'audio_settings':
                          return AudioSettingsPanel(ctrl: ctrl);
                        case 'zoom':
                          return ZoomPanel(ctrl: ctrl);
                        case 'rating':
                          return RatingPanel(ctrl: ctrl);
                        case 'chapters':
                          return ChaptersPanel(ctrl: ctrl);
                        default:
                          return MainSettingsMenu(ctrl: ctrl);
                      }
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Main menu ─────────────────────────────────────────────────────────────────
