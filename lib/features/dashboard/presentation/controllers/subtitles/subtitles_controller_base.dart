import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitle_cue_model.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

export 'package:truthworld/features/video/data/models/ai_features.dart' show normalizeLanguageCode;

/// Base state and properties for SubtitlesController
abstract class SubtitlesControllerBase extends BaseController
    with ContentValidationMixin {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  static const String subtitlesTag = 'SubtitlesController';

  // Active channel context
  final RxString channelId = ''.obs;
  final Rx<SpendableBalance?> spendableBalance = Rx<SpendableBalance?>(null);
  final Rx<Channel?> currentChannel = Rx<Channel?>(null);

  Future<void> refreshSpendableBalance() async {
    try {
      final currentUser = auth.currentUser;
      if (currentUser == null) return;
      final targetChanId = channelId.value.isNotEmpty
          ? channelId.value
          : (selectedVideo.value?.channelId.isNotEmpty == true
              ? selectedVideo.value!.channelId
              : currentUser.uid);
      if (targetChanId.isEmpty) return;

      final chanDoc = await firestore
          .collection(FirestoreCollections.channels)
          .doc(targetChanId)
          .get();
      if (chanDoc.exists && chanDoc.data() != null) {
        final chan = Channel.fromMap(chanDoc.data()!, chanDoc.id);
        safeStateAction(() {
          currentChannel.value = chan;
        });
        final bal = await ChannelWalletService().getSpendableBalanceForChannelId(chan.id);
        safeStateAction(() {
          spendableBalance.value = bal;
        });
      }
    } catch (e) {
      logger.warning('Could not refresh spendable balance: $e', tag: subtitlesTag);
    }
  }

  // Video list state
  final RxList<Video> videos = <Video>[].obs;
  final RxList<Video> filteredVideos = <Video>[].obs;
  final RxString searchQuery = ''.obs;
  StreamSubscription<QuerySnapshot>? videosSubscription;
  StreamSubscription<QuerySnapshot>? channelVideosSubscription;
  final Map<String, Video> ownerVideosMap = {};
  final Map<String, Video> channelVideosMap = {};

  // UI Navigation, Tabs & Preview States
  final RxInt selectedMainTab = 0.obs; // 0 = Subtitles, 1 = Transcripts
  final RxBool isCcEnabled = true.obs;
  final RxDouble cueZoomScale = 1.0.obs;
  final RxBool isCuesSearchExpanded = false.obs;
  final RxSet<String> selectedCueIds = <String>{}.obs;

  void toggleCc() => isCcEnabled.toggle();
  void toggleCuesSearch() => isCuesSearchExpanded.toggle();

  // Selected video and subtitle preview state
  final Rxn<Video> selectedVideo = Rxn<Video>();
  final RxList<String> availableLanguages = <String>[].obs;
  final RxString selectedLanguage = ''.obs;
  final RxList<SubtitleCue> currentCues = <SubtitleCue>[].obs;
  final RxBool isSaving = false.obs;
  final RxBool hasUnsavedChanges = false.obs;
  final RxBool isUploadingFile = false.obs;

  // Undo / Redo History Stacks
  final RxList<List<SubtitleCue>> undoStack = <List<SubtitleCue>>[].obs;
  final RxList<List<SubtitleCue>> redoStack = <List<SubtitleCue>>[].obs;
  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  void recordSnapshot() {
    final snapshot = currentCues
        .map((c) => SubtitleCue(
              id: c.id,
              startTime: c.startTime,
              endTime: c.endTime,
              text: c.text,
            ))
        .toList();
    undoStack.add(snapshot);
    if (undoStack.length > 50) {
      undoStack.removeAt(0);
    }
    redoStack.clear();
  }

  void undo() {
    if (undoStack.isEmpty) return;
    final currentSnapshot = currentCues
        .map((c) => SubtitleCue(
              id: c.id,
              startTime: c.startTime,
              endTime: c.endTime,
              text: c.text,
            ))
        .toList();
    redoStack.add(currentSnapshot);
    final previous = undoStack.removeLast();
    currentCues.assignAll(previous);
    hasUnsavedChanges.value = true;
    currentCues.refresh();
  }

  void redo() {
    if (redoStack.isEmpty) return;
    final currentSnapshot = currentCues
        .map((c) => SubtitleCue(
              id: c.id,
              startTime: c.startTime,
              endTime: c.endTime,
              text: c.text,
            ))
        .toList();
    undoStack.add(currentSnapshot);
    final next = redoStack.removeLast();
    currentCues.assignAll(next);
    hasUnsavedChanges.value = true;
    currentCues.refresh();
  }

  bool hasPublishedSubtitles(String code) {
    final video = selectedVideo.value;
    if (video == null) return false;
    final subs = video.mediaSubtitles;
    final normCode = normalizeLanguageCode(code);
    final isBaseTrack = normCode == normalizeLanguageCode(video.language.isNotEmpty ? video.language : 'en');
    if ((subs.containsKey(code) && (subs[code]?.isNotEmpty ?? false)) ||
        (subs.containsKey(normCode) && (subs[normCode]?.isNotEmpty ?? false)) ||
        (subs.containsKey(video.language) && (subs[video.language]?.isNotEmpty ?? false) && isBaseTrack)) {
      return true;
    }

    final resolved = resolveSubtitleUrlForLanguage(video, code);
    if (resolved != null && resolved.trim().isNotEmpty) {
      return true;
    }

    if (isBaseTrack) {
      if (video.transcriptionUrl.isNotEmpty) return true;
      if (selectedLanguage.value == code && currentCues.isNotEmpty) return true;
    }

    return false;
  }

  bool get hasAnyPublishedSubtitles {
    final video = selectedVideo.value;
    if (video == null) return false;
    return video.mediaSubtitles.values.any((s) => s.isNotEmpty) ||
        video.transcriptionUrl.isNotEmpty ||
        hasPublishedSubtitles(video.language);
  }

  List<String> get availableLanguagesWithSubtitles {
    final video = selectedVideo.value;
    if (video == null) return [];
    final res = <String>[];
    for (final k in video.mediaSubtitles.keys) {
      final code = normalizeLanguageCode(k);
      final val = video.mediaSubtitles[k];
      if (val != null && val.isNotEmpty && !res.contains(code)) {
        res.add(code);
      }
    }
    final baseLang = normalizeLanguageCode(video.language.isNotEmpty ? video.language : 'en');
    if (!res.contains(baseLang) && hasPublishedSubtitles(baseLang)) {
      res.add(baseLang);
    }
    return res;
  }

  SubtitleTrackStatus getLanguageStatus(String code) {
    if (hasPublishedSubtitles(code)) {
      return SubtitleTrackStatus.published;
    }
    if (isLanguageFailed(code)) {
      return SubtitleTrackStatus.failed;
    }
    if (isLanguageGenerating(code)) {
      return SubtitleTrackStatus.generating;
    }
    final normCode = normalizeLanguageCode(code);
    if ((selectedLanguage.value == code && currentCues.isNotEmpty) ||
        availableLanguages.contains(code) ||
        availableLanguages.contains(normCode)) {
      return SubtitleTrackStatus.draft;
    }
    return SubtitleTrackStatus.notAdded;
  }

  bool isLanguageGenerating(String code) {
    final clean = code.trim().toLowerCase();
    final norm = normalizeLanguageCode(clean);
    if (generatingSubtitleLanguages.contains(clean) || generatingSubtitleLanguages.contains(norm)) {
      return true;
    }
    final prog = subtitleProgress[clean] ?? subtitleProgress[norm];
    if (prog != null && prog.isGenerating && !prog.isFailed) {
      return true;
    }
    final status = aiLanguageStatuses[clean] ?? aiLanguageStatuses[norm];
    if (status != null) {
      final s = status.toLowerCase();
      if (s == 'generating' || s == 'translating' || s == 'transcribing' || s == 'aligning' || s == 'queued') {
        return true;
      }
    }
    if (isGeneratingAI.value && (aiTargetLanguages.contains(clean) || aiTargetLanguages.contains(norm))) {
      return true;
    }
    return false;
  }

  bool isLanguageFailed(String code) {
    final clean = code.trim().toLowerCase();
    final norm = normalizeLanguageCode(clean);
    if (hasPublishedSubtitles(clean)) {
      return false;
    }
    if (failedSubtitleLanguages.contains(clean) || failedSubtitleLanguages.contains(norm)) {
      return true;
    }
    final prog = subtitleProgress[clean] ?? subtitleProgress[norm];
    if (prog != null && prog.isFailed) {
      return true;
    }
    final status = (aiLanguageStatuses[clean] ?? aiLanguageStatuses[norm])?.toLowerCase();
    return status == 'failed';
  }

  SubtitleTrackProgressState? getSubtitleProgress(String code) {
    final clean = code.trim().toLowerCase();
    final norm = normalizeLanguageCode(clean);
    return subtitleProgress[clean] ?? subtitleProgress[norm];
  }

  List<String> get displayLanguages {
    final list = <String>[...availableLanguages];
    final video = selectedVideo.value;
    if (video != null) {
      for (final l in video.languages) {
        final code = l.toLowerCase();
        if (!list.contains(code)) {
          list.add(code);
        }
      }
    }
    for (final l in ['en', 'te', 'hi', 'ta', 'kn']) {
      if (!list.contains(l)) {
        list.add(l);
      }
    }
    return list;
  }

  /// Returns only languages configured or available for the current selected video.
  List<String> get configuredLanguages {
    final list = <String>[];
    final video = selectedVideo.value;
    final baseLang = normalizeLanguageCode(video?.language ?? 'en');
    list.add(baseLang);
    if (!list.contains('en')) list.add('en');
    if (video != null) {
      for (final k in video.mediaSubtitles.keys) {
        final code = normalizeLanguageCode(k);
        if (!list.contains(code)) list.add(code);
      }
      for (final l in video.languages) {
        final code = normalizeLanguageCode(l);
        if (!list.contains(code)) list.add(code);
      }
    }
    for (final l in availableLanguages) {
      final code = normalizeLanguageCode(l);
      if (!list.contains(code)) list.add(code);
    }
    return list;
  }

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
  final RxList<String> aiTargetLanguages = <String>[].obs;
  final RxMap<String, String> aiLanguageStatuses = <String, String>{}.obs;
  final RxSet<String> generatingSubtitleLanguages = <String>{}.obs;
  final RxSet<String> failedSubtitleLanguages = <String>{}.obs;
  final RxMap<String, SubtitleTrackProgressState> subtitleProgress =
      <String, SubtitleTrackProgressState>{}.obs;
  final RxInt aiQueuePosition = 1.obs;
  final RxInt aiQueueTotal = 1.obs;
  final RxString aiCurrentStageName = 'Speech Extraction & Transcription'.obs;
  final RxInt aiElapsedSeconds = 0.obs;
  final RxBool isAiJobPaused = false.obs;
  final RxBool isCancellingAI = false.obs;
  final RxBool isPausingAI = false.obs;
  final RxBool isRegeneratingAI = false.obs;
  StreamSubscription<DocumentSnapshot>? aiJobSubscription;
  StreamSubscription<DocumentSnapshot>? aiVideoSubscription;
  StreamSubscription<DocumentSnapshot>? aiLocSubscription;
  StreamSubscription<QuerySnapshot>? aiQueueSubscription;
  Timer? aiElapsedTimer;

  Future<void> checkAndResumeAIJob(String videoId) async {}
  Future<void> cancelAIJob() async {}
  Future<void> togglePauseAIJob() async {}
  Future<void> regenerateAIJob() async {}
  Future<void> retrySubtitleGeneration(String langCode) async {}

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
  String? resolveSubtitleUrlForLanguage(Video video, String langCode);

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

  String getLanguageName(String code, {bool includeNative = false}) {
    final clean = code.trim().toLowerCase();
    final normalized = normalizeLanguageCode(clean);
    final found = supportedLanguages.firstWhereOrNull(
      (l) => l.code == normalized || l.code == clean || l.name.toLowerCase() == clean,
    );
    if (found != null) {
      if (includeNative && found.nativeName.isNotEmpty && found.nativeName != found.name) {
        return '${found.name} (${found.nativeName})';
      }
      return found.name;
    }
    return clean.length <= 3 ? clean.toUpperCase() : clean;
  }

  void cancelBaseSubscriptions() {
    videosSubscription?.cancel();
    channelVideosSubscription?.cancel();
    requestsSubscription?.cancel();
    aiJobSubscription?.cancel();
    aiVideoSubscription?.cancel();
    aiLocSubscription?.cancel();
    aiQueueSubscription?.cancel();
    aiElapsedTimer?.cancel();
  }
}
