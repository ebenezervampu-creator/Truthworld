import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_preferences.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_analysis_service.dart';

/// GetX controller coordinating audio theme state, accessibility fallbacks,
/// and shared audio analysis without violating the Zero setState Policy.
class AudioThemeController extends GetxController {
  AudioThemeController({required this.playerCtrl});

  final TowerPlayerController playerCtrl;
  late final AudioAnalysisService analysisService;

  final RxBool isReducedMotion = false.obs;

  @override
  void onInit() {
    super.onInit();
    analysisService = AudioAnalysisService(playerCtrl: playerCtrl);
    analysisService.onInit();
  }

  /// Resolves the active theme with intelligent fallback to Obsidian Minimalist
  /// when reduced-motion accessibility or constrained resources are active.
  AudioPlayerTheme get effectiveTheme {
    if (isReducedMotion.value) {
      return AudioPlayerTheme.obsidianMinimalist;
    }
    return TowerPlayerPreferences.globalAudioTheme.value;
  }

  void seekToSegment(SubtitleSegment segment) {
    playerCtrl.seekTo(segment.start);
  }

  @override
  void onClose() {
    analysisService.onClose();
    super.onClose();
  }
}
