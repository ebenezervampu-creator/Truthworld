import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitles_mixins.dart';

export 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitle_cue_model.dart';
export 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitles_mixins.dart';

/// Professional Subtitles Management Controller
class SubtitlesController extends SubtitlesControllerBase
    with
        SubtitlesChannelVideosMixin,
        SubtitlesPlayerMixin,
        SubtitlesCuesMixin,
        SubtitlesAiMixin,
        SubtitlesStorageMixin,
        SubtitlesExportMixin {
  static String formatDurationToTimecode(Duration duration) =>
      SubtitlesControllerBase.formatDurationToTimecode(duration);

  @override
  void onInit() {
    super.onInit();
    initializeContentFilters();
    initializeContext();
  }

  @override
  void onClose() {
    cancelBaseSubscriptions();
    disposeVideoPlayer();
    super.onClose();
  }
}
