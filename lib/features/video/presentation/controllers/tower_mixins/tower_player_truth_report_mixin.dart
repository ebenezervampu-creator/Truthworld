import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

/// Manages truth report metrics, badges, and verification state for TowerPlayer.
mixin TowerPlayerTruthReportMixin on GetxController {
  VideoController? get videoController;

  int? get truthReportScore {
    final score = videoController?.video.trustScore;
    if (score != null && score > 0) {
      return score > 5.0 ? score.toInt() : (score * 20).toInt();
    }
    final rawScore = videoController?.factCheckData['trustScore'];
    if (rawScore is num && rawScore > 0) {
      return rawScore > 5.0 ? rawScore.toInt() : (rawScore * 20).toInt();
    }
    return null;
  }

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
