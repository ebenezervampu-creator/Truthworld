import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_analysis_service.dart';

/// Contract for all TruthWorld Audio Theme stages.
/// Enforces StatelessWidget (Zero setState Policy) and unified consumption
/// of the shared AudioAnalysisService.
abstract class AudioThemeStage extends StatelessWidget {
  const AudioThemeStage({
    required this.ctrl,
    required this.analysisService,
    this.video,
    super.key,
  });

  final TowerPlayerController ctrl;
  final AudioAnalysisService analysisService;
  final Video? video;
}
