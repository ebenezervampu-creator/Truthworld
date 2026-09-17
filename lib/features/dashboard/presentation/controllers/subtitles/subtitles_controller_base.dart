import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitle_cue_model.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

/// Base state and properties for SubtitlesController
abstract class SubtitlesControllerBase extends BaseController
    with ContentValidationMixin {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  static const String subtitlesTag = 'SubtitlesController';

  // Active channel context
  final RxString channelId = ''.obs;

  // Video list state
  final RxList<Video> videos = <Video>[].obs;
  final RxList<Video> filteredVideos = <Video>[].obs;
  final RxString searchQuery = ''.obs;
  StreamSubscription<QuerySnapshot>? videosSubscription;
  StreamSubscription<QuerySnapshot>? channelVideosSubscription;
  final Map<String, Video> ownerVideosMap = {};
  final Map<String, Video> channelVideosMap = {};

  // Selected video and subtitle preview state
  final Rxn<Video> selectedVideo = Rxn<Video>();
  final RxList<String> availableLanguages = <String>[].obs;
  final RxString selectedLanguage = ''.obs;
  final RxList<SubtitleCue> currentCues = <SubtitleCue>[].obs;
  final RxBool isSaving = false.obs;
  final RxBool hasUnsavedChanges = false.obs;
  final RxBool isUploadingFile = false.obs;

  // Video Player Preview & Sync
  VideoPlayerController? videoPlayerController;
  final RxBool isVideoPlayerInitialized = false.obs;
  final RxBool isVideoPlaying = false.obs;
  final Rx<Duration> currentVideoPosition = Duration.zero.obs;
  final Rx<Duration> videoDuration = Duration.zero.obs;
  final RxBool showVideoPreview = false.obs;
  final RxInt activeCueIndex = (-1).obs;

  // Truthworld AI Generation & Status
  final RxBool isGeneratingAI = false.obs;
  final RxInt aiJobProgress = 0.obs;
  final RxString aiJobStatus = ''.obs;
  StreamSubscription<DocumentSnapshot>? aiJobSubscription;

  // Cues Search & Filtering
  final RxString searchQueryInCues = ''.obs;
  List<SubtitleCue> get filteredCues {
    if (searchQueryInCues.value.trim().isEmpty) {
      return currentCues;
    }
    final q = searchQueryInCues.value.toLowerCase().trim();
    return currentCues.where((c) {
      return c.text.toLowerCase().contains(q) ||
          c.startTime.contains(q) ||
          c.endTime.contains(q);
    }).toList();
  }

  // Language requests states
  final RxList<LanguageRequest> languageRequests = <LanguageRequest>[].obs;
  final RxBool isLoadingRequests = false.obs;
  final RxBool showRequestsPanel = false.obs;
  StreamSubscription<QuerySnapshot>? requestsSubscription;

  // Abstract cross-mixin contracts
  Future<void> parseCuesForLanguage(String langCode, String? urlOrData);
  Future<void> initVideoPlayer(Video video);
  void disposeVideoPlayer();

  static String formatDurationToTimecode(Duration duration) {
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String shiftTimeString(String timeStr, int offsetMs) {
    try {
      final parts = timeStr.split(':');
      var h = 0;
      var m = 0;
      var s = 0;
      var ms = 0;
      if (parts.length >= 3) {
        h = int.parse(parts[0]);
        m = int.parse(parts[1]);
        final sParts = parts[2].split('.');
        s = int.parse(sParts[0]);
        ms = sParts.length > 1
            ? int.parse(sParts[1].padRight(3, '0').substring(0, 3))
            : 0;
      } else if (parts.length == 2) {
        m = int.parse(parts[0]);
        final sParts = parts[1].split('.');
        s = int.parse(sParts[0]);
        ms = sParts.length > 1
            ? int.parse(sParts[1].padRight(3, '0').substring(0, 3))
            : 0;
      }

      var totalMs =
          Duration(
            hours: h,
            minutes: m,
            seconds: s,
            milliseconds: ms,
          ).inMilliseconds +
          offsetMs;
      if (totalMs < 0) totalMs = 0;
      final updated = Duration(milliseconds: totalMs);

      String twoDigits(int n) => n.toString().padLeft(2, '0');
      String threeDigits(int n) => n.toString().padLeft(3, '0');
      return '${twoDigits(updated.inHours)}:${twoDigits(updated.inMinutes.remainder(60))}:${twoDigits(updated.inSeconds.remainder(60))}.${threeDigits(updated.inMilliseconds.remainder(1000))}';
    } catch (_) {
      return timeStr;
    }
  }

  String getLanguageName(String code) {
    final found = supportedLanguages.firstWhereOrNull((l) => l.code == code);
    if (found != null) return found.name;
    return code.length <= 3 ? code.toUpperCase() : code;
  }

  void cancelBaseSubscriptions() {
    videosSubscription?.cancel();
    channelVideosSubscription?.cancel();
    requestsSubscription?.cancel();
    aiJobSubscription?.cancel();
  }
}
