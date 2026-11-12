import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

/// Manages truth report metrics, badges, and verification state for TowerPlayer.
mixin TowerPlayerTruthReportMixin on GetxController {
  VideoController? get videoController;

  int? get truthReportScore => null;

  bool get isAnalyzingTruth =>
      videoController?.isLoadingFactCheck.value == true;

  String get truthReportBadgeText {
    if (isAnalyzingTruth) return 'Analyzing…';
    final score = truthReportScore;
    if (score != null) return 'Truth Report $score';
    final isFactChecked = videoController?.video.isFactChecked == true;
    if (isFactChecked) return 'Truth Report ✓';
    return 'Truth Report';
  }
}
