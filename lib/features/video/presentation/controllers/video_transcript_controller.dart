import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/isolate_compute_utils.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

/// Sub-controller responsible for fetching, downloading, parsing, and caching
/// video transcripts, subtitle segments, and AI moderation summaries.
class VideoTranscriptController extends BaseController {
  final RxBool isTranscriptVisible = false.obs;
  final RxList<SubtitleSegment> transcriptSegments = <SubtitleSegment>[].obs;
  final RxBool isLoadingTranscript = false.obs;
  final RxBool hasAttemptedTranscriptFetch = false.obs;

  final RxBool isSummaryVisible = false.obs;
  final RxString moderationSummary = ''.obs;
  final RxBool isLoadingSummary = false.obs;

  final ScrollController transcriptScrollController = ScrollController();
  final RxInt activeSegmentIndex = (-1).obs;
  final RxBool autoScrollEnabled = true.obs;
  DateTime _lastAutoScroll = DateTime(2000);
  String? currentVideoId;

  /// In-memory cache of parsed transcripts by videoId to eliminate redundant network round-trips
  static final Map<String, List<SubtitleSegment>> _transcriptCache = {};

  final Map<int, GlobalKey> _segmentKeys = <int, GlobalKey>{};
  Timer? _autoResumeTimer;

  GlobalKey getSegmentKey(int index) {
    return _segmentKeys.putIfAbsent(
      index,
      () => GlobalKey(debugLabel: 'transcript_seg_$index'),
    );
  }

  void onUserScrolled() {
    autoScrollEnabled.value = false;
    _autoResumeTimer?.cancel();
    _autoResumeTimer = Timer(const Duration(milliseconds: 3500), () {
      if (isClosed) return;
      resumeAutoScroll();
    });
  }

  void onUserScrollEnded() {
    if (!autoScrollEnabled.value) {
      _autoResumeTimer?.cancel();
      _autoResumeTimer = Timer(const Duration(milliseconds: 3500), () {
        if (isClosed) return;
        resumeAutoScroll();
      });
    }
  }

  void resumeAutoScroll() {
    _autoResumeTimer?.cancel();
    _autoResumeTimer = null;
    autoScrollEnabled.value = true;
    if (isTranscriptVisible.value && activeSegmentIndex.value != -1) {
      scrollToSegmentIndex(activeSegmentIndex.value, animate: true);
    }
  }

  void resetForVideo(String newVideoId) {
    if (currentVideoId != newVideoId) {
      currentVideoId = newVideoId;
      _autoResumeTimer?.cancel();
      _autoResumeTimer = null;
      _segmentKeys.clear();
      transcriptSegments.clear();
      activeSegmentIndex.value = -1;
      autoScrollEnabled.value = true;
      isTranscriptVisible.value = false;
      hasAttemptedTranscriptFetch.value = false;
      moderationSummary.value = '';
    }
  }

  void toggleTranscriptVisibility() {
    isTranscriptVisible.value = !isTranscriptVisible.value;
  }

  void toggleSummaryVisibility() {
    isSummaryVisible.value = !isSummaryVisible.value;
  }

  /// Locates the exact segment index where the video is currently playing.
  /// 1. Tests if [pos] falls within [start, end] of any segment.
  /// 2. If [pos] is in a gap between lines or paused, selects the latest line spoken before [pos].
  /// 3. Falls back safely to 0 if before start.
  int findSegmentIndexForPosition(Duration pos) {
    if (transcriptSegments.isEmpty) return -1;

    // 1. Exact match within segment bounds
    for (var i = 0; i < transcriptSegments.length; i++) {
      final s = transcriptSegments[i];
      if (pos >= s.start && pos <= s.end) {
        return i;
      }
    }

    // 2. Nearest segment that started at or before pos (handles pauses & gaps)
    for (var i = transcriptSegments.length - 1; i >= 0; i--) {
      if (transcriptSegments[i].start <= pos) {
        return i;
      }
    }

    // 3. pos is before the first segment starts
    return 0;
  }

  /// Synchronizes the transcript display to the current playback position.
  /// When [forceScroll] is true, scrolls the list immediately to the matching segment.
  void syncToCurrentPosition(Duration pos, {bool forceScroll = false}) {
    if (transcriptSegments.isEmpty) return;
    final idx = findSegmentIndexForPosition(pos);
    if (idx == -1) return;

    final changed = (idx != activeSegmentIndex.value);
    activeSegmentIndex.value = idx;

    if (changed || forceScroll) {
      if (isTranscriptVisible.value || forceScroll) {
        scrollToSegmentIndex(idx, animate: !forceScroll);
      }
    }
  }

  void updateActiveSegment(SubtitleSegment? seg, {Duration? currentPos}) {
    if (seg != null) {
      final idx = transcriptSegments.indexOf(seg);
      if (idx != -1) {
        if (idx != activeSegmentIndex.value) {
          activeSegmentIndex.value = idx;
          if (autoScrollEnabled.value && isTranscriptVisible.value) {
            _smoothScrollToIndex(idx);
          }
        }
        return;
      }
    }
    // Handle gap or pause between dialogue lines by using current playback pos
    if (currentPos != null && transcriptSegments.isNotEmpty) {
      final idx = findSegmentIndexForPosition(currentPos);
      if (idx != -1 && idx != activeSegmentIndex.value) {
        activeSegmentIndex.value = idx;
        if (autoScrollEnabled.value && isTranscriptVisible.value) {
          _smoothScrollToIndex(idx);
        }
      }
    }
  }

  /// Scrolls to [targetIndex] so that the active segment moves near the top of the container,
  /// causing previous dialogue lines to scroll off/disappear while upcoming lines remain visible.
  void scrollToSegmentIndex(int targetIndex, {bool animate = false}) {
    if (targetIndex < 0 || targetIndex >= transcriptSegments.length) return;
    if (!transcriptScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isClosed || !transcriptScrollController.hasClients) return;
        scrollToSegmentIndex(targetIndex, animate: animate);
      });
      return;
    }

    // 1. Direct alignment using the segment's GlobalKey if rendered
    final key = _segmentKeys[targetIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.04, // Aligns active line near the top (previous lines disappear)
        duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
      return;
    }

    // 2. If the item is not yet rendered by the lazy sliver, scroll to estimated offset
    final pos = transcriptScrollController.position;
    final maxScroll = pos.maxScrollExtent;
    final estimatedOffset = (targetIndex * 42.0).clamp(0.0, maxScroll);

    if ((pos.pixels - estimatedOffset).abs() > 2.0) {
      if (animate && (pos.pixels - estimatedOffset).abs() < 400.0) {
        transcriptScrollController.animateTo(
          estimatedOffset,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        transcriptScrollController.jumpTo(estimatedOffset);
      }
    }

    // 3. Post-frame refinement once the sliver has built the requested tile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed || !transcriptScrollController.hasClients) return;
      final renderedKey = _segmentKeys[targetIndex];
      if (renderedKey?.currentContext != null) {
        Scrollable.ensureVisible(
          renderedKey!.currentContext!,
          alignment: 0.04,
          duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _smoothScrollToIndex(int index) {
    final now = DateTime.now();
    if (now.difference(_lastAutoScroll).inMilliseconds < 150) return;
    _lastAutoScroll = now;

    scrollToSegmentIndex(index, animate: true);
  }

  /// Proactively finds, downloads, and parses the transcript/subtitles for [video].
  Future<void> loadTranscriptForVideo(
    Video video, {
    String? defaultSubtitleUrl,
    bool forceRefresh = false,
  }) async {
    final playerCtrl = TowerPlayerController.getForTagOrActive(video.id);

    // Invalidate transcript if video ID changed to prevent displaying wrong video's transcript
    if (currentVideoId != null && currentVideoId != video.id) {
      transcriptSegments.clear();
      activeSegmentIndex.value = -1;
      hasAttemptedTranscriptFetch.value = false;
      moderationSummary.value = '';
    }
    currentVideoId = video.id;

    // 0. Fast-path memory cache checks
    if (forceRefresh) {
      _transcriptCache.remove(video.id);
    } else if (_transcriptCache.containsKey(video.id)) {
      final cachedSegs = _transcriptCache[video.id]!;
      if (cachedSegs.isNotEmpty) {
        transcriptSegments.assignAll(cachedSegs);
        if (playerCtrl != null) {
          playerCtrl.subtitleSegments.assignAll(cachedSegs);
          playerCtrl.startSubtitleSyncTimer();
          playerCtrl.syncActiveSubtitle();
        }
        if (isTranscriptVisible.value) {
          final currentPos = playerCtrl?.videoPlayerController.value.position ?? Duration.zero;
          syncToCurrentPosition(currentPos, forceScroll: true);
        }
      }
      isLoadingTranscript.value = false;
      playerCtrl?.isLoadingSubtitles.value = false;
      hasAttemptedTranscriptFetch.value = true;
      return;
    }

    if (transcriptSegments.isNotEmpty) {
      if (playerCtrl != null && playerCtrl.subtitleSegments.isEmpty) {
        playerCtrl.subtitleSegments.assignAll(transcriptSegments);
        playerCtrl.startSubtitleSyncTimer();
        playerCtrl.syncActiveSubtitle();
      }
      if (isTranscriptVisible.value) {
        final currentPos = playerCtrl?.videoPlayerController.value.position ?? Duration.zero;
        syncToCurrentPosition(currentPos, forceScroll: true);
      }
      return;
    }
    if (playerCtrl != null && playerCtrl.subtitleSegments.isNotEmpty) {
      transcriptSegments.assignAll(playerCtrl.subtitleSegments);
      if (isTranscriptVisible.value) {
        final currentPos = playerCtrl.videoPlayerController.value.position;
        syncToCurrentPosition(currentPos, forceScroll: true);
      }
      return;
    }

    if (isLoadingTranscript.value) return;
    if (!forceRefresh && hasAttemptedTranscriptFetch.value) return;

    isLoadingTranscript.value = true;
    playerCtrl?.isLoadingSubtitles.value = true;
    try {
      void applySegments(List<SubtitleSegment> segs) {
        _transcriptCache[video.id] = List<SubtitleSegment>.from(segs);
        transcriptSegments.assignAll(segs);
        playerCtrl?.subtitleSegments.assignAll(segs);
        playerCtrl?.startSubtitleSyncTimer();
        playerCtrl?.syncActiveSubtitle();
        if (isTranscriptVisible.value) {
          final currentPos = playerCtrl?.videoPlayerController.value.position ?? Duration.zero;
          syncToCurrentPosition(currentPos, forceScroll: true);
        }
      }

      // 1. Resolve preferred language (active track selection > video native language > en)
      final videoLangRaw = video.language.trim().toLowerCase();
      final videoLangCode = normalizeLanguageCode(video.language);
      final videoLangObj = supportedLanguages.firstWhereOrNull((l) => l.code == videoLangCode);
      final videoLangName = videoLangObj?.name.toLowerCase() ?? '';

      final activeTrackRaw = playerCtrl?.activeSubLang.value.trim().toLowerCase() ?? '';
      final isTrackActive = activeTrackRaw.isNotEmpty &&
          activeTrackRaw != 'off' &&
          activeTrackRaw != 'auto';
      final activeTrackCode = isTrackActive ? normalizeLanguageCode(activeTrackRaw) : '';
      final activeTrackObj = isTrackActive
          ? supportedLanguages.firstWhereOrNull((l) => l.code == activeTrackCode)
          : null;
      final activeTrackName = activeTrackObj?.name.toLowerCase() ?? '';

      String? findMatchingUrlInMap(Map? map) {
        if (map == null || map.isEmpty) return null;

        String? extractUrl(dynamic val) {
          if (val == null) return null;
          if (val is String && val.trim().isNotEmpty) return val.trim();
          if (val is Map) {
            final u = (val['url'] ?? val['srtPath'] ?? val['vttPath'] ?? val['subtitleUrl'])?.toString();
            if (u != null && u.trim().isNotEmpty) return u.trim();
          }
          final s = val.toString().trim();
          return s.isNotEmpty ? s : null;
        }

        // 1. If explicit user track selection (e.g. 'Telugu', 'te')
        if (isTrackActive) {
          final direct = extractUrl(map[activeTrackRaw]) ??
              (activeTrackCode.isNotEmpty ? extractUrl(map[activeTrackCode]) : null) ??
              (activeTrackName.isNotEmpty ? extractUrl(map[activeTrackName]) : null);
          if (direct != null) return direct;
        }

        // 2. Video native language (e.g. 'te', 'telugu')
        if (videoLangCode.isNotEmpty) {
          final native = extractUrl(map[videoLangCode]) ??
              (videoLangRaw.isNotEmpty ? extractUrl(map[videoLangRaw]) : null) ??
              (videoLangName.isNotEmpty ? extractUrl(map[videoLangName]) : null);
          if (native != null) return native;
        }

        // 3. Fallback to English
        final en = extractUrl(map['en']) ?? extractUrl(map['english']);
        if (en != null) return en;

        // 4. Fallback to first available entry
        return extractUrl(map.values.first);
      }

      var candidateUrl = findMatchingUrlInMap(video.mediaSubtitles) ??
          (video.transcriptionUrl.isNotEmpty ? video.transcriptionUrl : null) ??
          defaultSubtitleUrl;

      // 2. If null, fetch from localization subcollection
      if (candidateUrl == null || candidateUrl.isEmpty) {
        final loc = await VideoMediaService().getLocalization(video.id);
        if (loc.subtitles.isNotEmpty) {
          candidateUrl = findMatchingUrlInMap(loc.subtitles);
        }
      }

      String? retrievedJobId;
      // 3. If still null, check root video document in Firestore
      if (candidateUrl == null || candidateUrl.isEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(video.id)
            .get();
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          retrievedJobId = (data['jobId'] as String?)?.trim();
          final media = data['media'] as Map<String, dynamic>?;
          candidateUrl = (media?['transcriptionUrl'] as String?) ??
              (data['transcriptionUrl'] as String?) ??
              (data['transcriptUrl'] as String?);
          if (candidateUrl == null || candidateUrl.isEmpty) {
            final subs = (media?['subtitles'] ?? data['subtitles']) as Map?;
            if (subs != null && subs.isNotEmpty) {
              candidateUrl = findMatchingUrlInMap(subs);
            }
          }
        }
      }

      // 4. If candidate URL found, fetch and parse
      if (candidateUrl != null && candidateUrl.isNotEmpty) {
        final isTranscriptJson = candidateUrl.endsWith('.json') ||
            candidateUrl.contains('/transcripts/');
        if (!isTranscriptJson && playerCtrl != null) {
          await playerCtrl.fetchAndParseSubtitles(candidateUrl);
          if (playerCtrl.subtitleSegments.isNotEmpty) {
            applySegments(playerCtrl.subtitleSegments);
            return;
          }
        }
        final segs = await downloadAndParseTranscript(candidateUrl);
        if (segs.isNotEmpty) {
          applySegments(segs);
          return;
        }
      }

      // 4.5 Check Firestore transcripts collection directly for video.id (authenticated users only)
      if (FirebaseAuth.instance.currentUser != null) {
        try {
          final directTranscriptSnap = await FirebaseFirestore.instance
              .collection('transcripts')
              .doc(video.id)
              .get();
          if (directTranscriptSnap.exists && directTranscriptSnap.data() != null) {
            final tData = directTranscriptSnap.data()!;
            if (tData['utterances'] != null || tData['segments'] != null || tData['words'] != null) {
              final segs = await parseTranscriptContent(jsonEncode(tData));
              if (segs.isNotEmpty) {
                applySegments(segs);
                return;
              }
            }
          }
        } catch (_) {}

        // 4.6 Check Firestore transcripts collection for jobId (if present)
        if (retrievedJobId != null && retrievedJobId.isNotEmpty && retrievedJobId != video.id) {
          try {
            final jobTranscriptSnap = await FirebaseFirestore.instance
                .collection('transcripts')
                .doc(retrievedJobId)
                .get();
            if (jobTranscriptSnap.exists && jobTranscriptSnap.data() != null) {
              final jData = jobTranscriptSnap.data()!;
              if (jData['utterances'] != null || jData['segments'] != null || jData['words'] != null) {
                final segs = await parseTranscriptContent(jsonEncode(jData));
                if (segs.isNotEmpty) {
                  applySegments(segs);
                  return;
                }
              }
            }
          } catch (_) {}
        }
      }

      // 5. Canonical fallback probe into Cloud Storage if Firestore URL metadata was absent
      final probePaths = <String>[
        'transcripts/${video.id}/full.json',
        if (videoLangCode.isNotEmpty && videoLangCode != 'en') ...[
          'subtitles/${video.id}/$videoLangCode.vtt',
          'subtitles/${video.id}/$videoLangCode.srt',
          if (videoLangRaw.isNotEmpty && videoLangRaw != videoLangCode) ...[
            'subtitles/${video.id}/$videoLangRaw.vtt',
            'subtitles/${video.id}/$videoLangRaw.srt',
          ],
        ],
        'subtitles/${video.id}/en.vtt',
        'subtitles/${video.id}/en.srt',
        if (retrievedJobId != null && retrievedJobId.isNotEmpty && retrievedJobId != video.id) ...[
          'transcripts/$retrievedJobId/full.json',
          if (videoLangCode.isNotEmpty && videoLangCode != 'en') ...[
            'subtitles/$retrievedJobId/$videoLangCode.vtt',
            'subtitles/$retrievedJobId/$videoLangCode.srt',
            if (videoLangRaw.isNotEmpty && videoLangRaw != videoLangCode) ...[
              'subtitles/$retrievedJobId/$videoLangRaw.vtt',
              'subtitles/$retrievedJobId/$videoLangRaw.srt',
            ],
          ],
          'subtitles/$retrievedJobId/en.vtt',
          'subtitles/$retrievedJobId/en.srt',
        ],
      ];

      // Parallel probe across candidate storage paths with tight timeout to eliminate sequential waterfall
      final probeFutures = probePaths.map((p) async {
        try {
          final data = await StorageUtils.getDataWithTimeout(
            FirebaseStorage.instance.ref(p),
            timeout: const Duration(milliseconds: 1500),
          );
          if (data != null && data.isNotEmpty) {
            return MapEntry<String, Uint8List>(p, data);
          }
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('unauthorized') ||
              errStr.contains('permission-denied')) {
            debugPrint('[VideoTranscriptController] Storage probe unauthorized for $p');
          }
        }
        return null;
      });

      final probeResults = await Future.wait(probeFutures);
      for (final res in probeResults) {
        if (res != null) {
          final content = utf8.decode(res.value, allowMalformed: true);
          final segs = await parseTranscriptContent(content);
          if (segs.isNotEmpty) {
            applySegments(segs);
            debugPrint('[VideoTranscriptController] ✅ Found transcript via storage probe: ${res.key}');
            return;
          }
        }
      }

      // No transcript found for this video. Cache empty list so subsequent
      // calls never re-probe network or Firestore unnecessarily.
      _transcriptCache[video.id] = const [];
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoTranscriptController.loadTranscript',
      );
    } finally {
      isLoadingTranscript.value = false;
      playerCtrl?.isLoadingSubtitles.value = false;
      hasAttemptedTranscriptFetch.value = true;
    }
  }

  Future<List<SubtitleSegment>> downloadAndParseTranscript(String url) async {
    try {
      String? content;
      try {
        final resolvedUrl = StorageUtils.getFastDownloadUrl(url);
        final headers = await StorageUtils.getMediaHeaders();
        final response = await AppHttpClient.get(
          Uri.parse(resolvedUrl),
          headers: headers,
        );
        if (response.statusCode == 200) {
          content = utf8.decode(response.bodyBytes, allowMalformed: true);
        }
      } catch (e) {
        logger.warning(
          'Transcript HTTP fast download failed or skipped: $e',
          tag: 'VideoTranscriptController.downloadHttpTranscript',
        );
      }

      if (content == null || content.isEmpty) {
        try {
          final ref = StorageUtils.getStorageRef(url);
          if (ref != null) {
            final data = await StorageUtils.getDataWithTimeout(ref);
            if (data != null && data.isNotEmpty) {
              content = utf8.decode(data, allowMalformed: true);
            }
          }
        } catch (_) {}
      }

      if (content != null && content.isNotEmpty) {
        return await parseTranscriptContent(content);
      }
    } catch (e, stackTrace) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('unauthorized') ||
          errStr.contains('permission-denied') ||
          errStr.contains('object-not-found')) {
        logger.warning(
          'Transcript download unavailable: $e',
          tag: 'VideoTranscriptController.downloadAndParseTranscript',
        );
      } else {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'VideoTranscriptController.downloadAndParseTranscript',
        );
      }
    }
    return [];
  }

  Future<List<SubtitleSegment>> parseTranscriptContent(String content) {
    return IsolateComputeUtils.parseSubtitlesAsync(content);
  }

  /// Fetches the AI Summary from moderation.summary in the video document or credibility cache.
  /// If the summary is missing, invalid, or a verbatim transcript snippet, invokes Cloud Function
  /// `getVideoAiSummary` to synthesize a genuine AI summary on demand.
  Future<void> fetchSummary(Video video) async {
    final videoLang = video.language;
    if (UserFeedbackSanitizer.isValidVideoSummary(
      moderationSummary.value,
      transcriptSegments: transcriptSegments,
      targetLanguage: videoLang,
    )) {
      return;
    }
    isLoadingSummary.value = true;
    try {
      // 1. Direct check on video.moderationSummary from Video model
      if (UserFeedbackSanitizer.isValidVideoSummary(
        video.moderationSummary,
        transcriptSegments: transcriptSegments,
        targetLanguage: videoLang,
      )) {
        moderationSummary.value = video.moderationSummary;
        isLoadingSummary.value = false;
        return;
      }

      // 2. Check VideoMediaService credibility cache
      final credibility = await VideoMediaService().getCredibility(video.id);
      if (UserFeedbackSanitizer.isValidVideoSummary(
        credibility.summary,
        transcriptSegments: transcriptSegments,
        targetLanguage: videoLang,
      )) {
        moderationSummary.value = credibility.summary;
        isLoadingSummary.value = false;
        return;
      }

      // 3. Fallback: Fetch directly from videos/{videoId} document in Firestore
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final mod = data['moderation'] as Map<String, dynamic>?;
        final modSummary = (mod?['summary'] as String?)?.trim() ?? '';
        final directModSummary = (data['moderationSummary'] as String?)?.trim() ?? '';
        final topSummary = (data['summary'] as String?)?.trim() ?? '';

        var candidate = '';
        if (UserFeedbackSanitizer.isValidVideoSummary(
          modSummary,
          transcriptSegments: transcriptSegments,
          targetLanguage: videoLang,
        )) {
          candidate = modSummary;
        } else if (UserFeedbackSanitizer.isValidVideoSummary(
          directModSummary,
          transcriptSegments: transcriptSegments,
          targetLanguage: videoLang,
        )) {
          candidate = directModSummary;
        } else if (UserFeedbackSanitizer.isValidVideoSummary(
          topSummary,
          transcriptSegments: transcriptSegments,
          targetLanguage: videoLang,
        )) {
          candidate = topSummary;
        }

        if (candidate.isNotEmpty) {
          moderationSummary.value = candidate;
          isLoadingSummary.value = false;
          return;
        }
      }

      // 4. Synthesize genuine AI summary on demand via Cloud Function
      try {
        final callable = FirebaseFunctions.instanceFor(region: AppConfig.credibilityFunctionsRegion)
            .httpsCallable('getVideoAiSummary');
        final result = await callable.call<Map<String, dynamic>>({
          'videoId': video.id,
        });
        final genSummary = (result.data['summary'] as String?)?.trim() ?? '';
        if (UserFeedbackSanitizer.isValidVideoSummary(
          genSummary,
          transcriptSegments: transcriptSegments,
          targetLanguage: videoLang,
        )) {
          moderationSummary.value = genSummary;
          return;
        }
      } catch (callErr, stack) {
        ErrorHandler.log(
          callErr,
          stackTrace: stack,
          tag: 'VideoTranscriptController.getVideoAiSummary',
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoTranscriptController.fetchSummary',
      );
    } finally {
      isLoadingSummary.value = false;
    }
  }

  @override
  void onClose() {
    _autoResumeTimer?.cancel();
    _segmentKeys.clear();
    transcriptScrollController.dispose();
    super.onClose();
  }
}
