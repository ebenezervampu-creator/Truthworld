import 'dart:async';

import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/presentation/controllers/claim_stream_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

mixin TowerPlayerEngagementMixin on GetxController {
  // Host controller dependencies
  VideoPlayerController get videoPlayerController;
  VideoController? get videoController;
  PlaybackSource get activePlayback;
  VideoPlayerValue get vv;
  String? get tag;
  @override
  bool get isClosed;
  Future<void> seekTo(Duration pos);
  void showToast(String msg);
  RxBool get showCommentsPopup;
  RxBool get showTranscriptPopup;
  RxBool get showFactCheckPopup;
  RxBool get subtitlesEnabled;

  // ── Chapters ──────────────────────────────────────────────
  final RxList<VideoChapter> chapters = <VideoChapter>[].obs;
  final Rx<VideoChapter?> currentChapter = Rx<VideoChapter?>(null);

  VideoChapter? binarySearchChapter(Duration pos) {
    if (chapters.isEmpty) return null;
    var lo = 0;
    var hi = chapters.length - 1;
    var result = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (chapters[mid].startTime <= pos) {
        result = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return result >= 0 ? chapters[result] : null;
  }

  // ── Fact-Check & Claims ───────────────────────────────────
  final Rxn<ClaimResult> activeClaim = Rxn<ClaimResult>();
  final RxBool showFactOverlay = true.obs;
  final RxBool isFactCheckAutoPlay = true.obs;
  final RxBool isFactOverlayExpanded = false.obs;
  final Set<String> _dismissedClaimKeys = <String>{};
  Timer? _factOverlayAutoDismissTimer;
  DateTime? _lastClaimSwitchTime;

  void toggleFactOverlayExpanded() {
    isFactOverlayExpanded.toggle();
    if (isFactOverlayExpanded.value) {
      _factOverlayAutoDismissTimer?.cancel();
    } else if (activeClaim.value != null) {
      _startFactOverlayAutoDismiss(const Duration(seconds: 4));
    }
  }

  void _startFactOverlayAutoDismiss([Duration duration = const Duration(seconds: 7)]) {
    _factOverlayAutoDismissTimer?.cancel();
    _factOverlayAutoDismissTimer = Timer(duration, () {
      if (!isFactOverlayExpanded.value && activeClaim.value != null) {
        activeClaim.value = null;
      }
    });
  }

  void dismissActiveClaim() {
    final cur = activeClaim.value;
    if (cur != null) {
      final key = '${cur.start}_${cur.text}';
      _dismissedClaimKeys.add(key);
    }
    _factOverlayAutoDismissTimer?.cancel();
    activeClaim.value = null;
    isFactOverlayExpanded.value = false;
  }

  void stopFactOverlayTimers() {
    _factOverlayAutoDismissTimer?.cancel();
    _factOverlayAutoDismissTimer = null;
  }

  List<ClaimResult> get availableClaims {
    // 1. If video has completed fact-checking with keyClaims in uiReport, prioritize final report
    final uiClaims = videoController?.video.uiReport?.keyClaims;
    if (uiClaims != null && uiClaims.isNotEmpty && videoController?.video.isFactChecked == true) {
      return uiClaims;
    }

    // 2. Check for live progressive claims streaming from ClaimStreamController
    final vId = videoController?.video.id;
    if (vId != null && vId.isNotEmpty) {
      final tag = 'claim_stream_$vId';
      if (Get.isRegistered<ClaimStreamController>(tag: tag)) {
        final streamCtrl = Get.find<ClaimStreamController>(tag: tag);
        if (streamCtrl.claims.isNotEmpty) {
          return streamCtrl.claims;
        }
      }
    }

    // 3. Fallback to existing uiReport or raw factCheckData
    if (uiClaims != null && uiClaims.isNotEmpty) return uiClaims;
    final rawClaims = videoController?.factCheckData['claims'] ??
        videoController?.factCheckData['uiReport']?['keyClaims'];
    if (rawClaims is List && rawClaims.isNotEmpty) {
      return rawClaims
          .map((c) => ClaimResult.fromMap(
                Map<String, dynamic>.from(
                  c is Map ? c : {'text': c.toString()},
                ),
              ))
          .toList();
    }
    return const [];
  }

  /// Claims sorted chronologically by timestamp (for Chapter mode)
  List<ClaimResult> get timestampedClaims {
    final list = List<ClaimResult>.from(availableClaims);
    list.sort((a, b) => (a.start ?? 0.0).compareTo(b.start ?? 0.0));
    return list;
  }

  void playClaim(ClaimResult claim) {
    seekTo(claim.startDuration);
    videoPlayerController.play();
    showFactOverlay.value = true;
    final key = '${claim.start}_${claim.text}';
    _dismissedClaimKeys.remove(key);
    activeClaim.value = claim;
    isFactOverlayExpanded.value = false;
    _lastClaimSwitchTime = DateTime.now();
    _startFactOverlayAutoDismiss(const Duration(seconds: 7));
    showToast('Playing claim: ${claim.verdict.replaceAll("_", " ")}');
  }

  void playNextClaim() {
    final claims = availableClaims;
    if (claims.isEmpty) return;
    final posSec = vv.position.inMilliseconds / 1000.0;
    for (final claim in claims) {
      if (claim.start != null && claim.start! > posSec + 1.0) {
        playClaim(claim);
        return;
      }
    }
    if (claims.first.start != null) {
      playClaim(claims.first);
    }
  }

  void playPreviousClaim() {
    final claims = availableClaims;
    if (claims.isEmpty) return;
    final posSec = vv.position.inMilliseconds / 1000.0;
    for (var i = claims.length - 1; i >= 0; i--) {
      final claim = claims[i];
      if (claim.start != null && claim.start! < posSec - 2.0) {
        playClaim(claim);
        return;
      }
    }
  }

  void toggleFactCheckAutoPlay() {
    isFactCheckAutoPlay.toggle();
    if (isFactCheckAutoPlay.value) {
      showFactOverlay.value = true;
      if (!vv.isPlaying) {
        videoPlayerController.play();
      }
      showToast('Fact-check live sync enabled');
    } else {
      showToast('Fact-check live sync paused');
    }
  }

  void syncActiveClaim(Duration pos) {
    if (!isFactCheckAutoPlay.value || !showFactOverlay.value) {
      return;
    }
    ClaimResult? nextActiveClaim;
    try {
      final claims = availableClaims;
      if (claims.isNotEmpty) {
        final posSec = pos.inMilliseconds / 1000.0;
        for (final claim in claims) {
          if (claim.start != null) {
            final key = '${claim.start}_${claim.text}';
            if (_dismissedClaimKeys.contains(key)) continue;

            final s = claim.start!;
            final e = claim.end ?? (s + 8.0);
            if (posSec >= s && posSec <= e) {
              nextActiveClaim = claim;
              break;
            }
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerEngagementMixin.syncActiveClaim',
      );
    }
    if (activeClaim.value != nextActiveClaim) {
      // Debounce rapid automatic switching (at least 1.5s display time)
      final now = DateTime.now();
      if (nextActiveClaim != null && _lastClaimSwitchTime != null && activeClaim.value != null) {
        if (now.difference(_lastClaimSwitchTime!).inMilliseconds < 1500) {
          return;
        }
      }
      _lastClaimSwitchTime = now;
      activeClaim.value = nextActiveClaim;
      isFactOverlayExpanded.value = false;
      if (nextActiveClaim != null) {
        _startFactOverlayAutoDismiss(const Duration(seconds: 7));
      } else {
        _factOverlayAutoDismissTimer?.cancel();
      }
    }
  }

  // ── Comments & Transcripts Autoplay ───────────────────────
  final RxBool isCommentsAutoPlay = false.obs;
  final RxBool isTranscriptAutoPlay = false.obs;
  final Rxn<Comment> currentAutoPlayComment = Rxn<Comment>();
  final RxInt activeAutoPlayCommentIndex = 0.obs;
  Timer? commentsAutoPlayTimer;

  void toggleCommentsAutoPlay() {
    isCommentsAutoPlay.toggle();
    if (isCommentsAutoPlay.value) {
      showCommentsPopup.value = false;
      startCommentsAutoPlay();
    } else {
      stopCommentsAutoPlay();
    }
  }

  void startCommentsAutoPlay() {
    stopCommentsAutoPlay();
    updateAutoPlayComment();
    commentsAutoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      updateAutoPlayComment();
    });
  }

  void stopCommentsAutoPlay() {
    commentsAutoPlayTimer?.cancel();
    commentsAutoPlayTimer = null;
    currentAutoPlayComment.value = null;
  }

  void updateAutoPlayComment() {
    try {
      final t = 'video_$tag';
      if (Get.isRegistered<CommentsController>(tag: t)) {
        final cc = Get.find<CommentsController>(tag: t);
        if (cc.comments.isNotEmpty) {
          final nextIdx =
              (activeAutoPlayCommentIndex.value + 1) % cc.comments.length;
          activeAutoPlayCommentIndex.value = nextIdx;
          currentAutoPlayComment.value = cc.comments[nextIdx];
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerEngagementMixin.updateAutoPlayComment',
      );
    }
  }

  void toggleTranscriptAutoPlay() {
    isTranscriptAutoPlay.toggle();
    if (isTranscriptAutoPlay.value) {
      showTranscriptPopup.value = false;
      subtitlesEnabled.value = true;
    }
  }

  // ── Content Metadata ──────────────────────────────────────
  ContentMetadata contentMeta = const ContentMetadata(
    genre: 'Action · Drama',
    releaseYear: '2024',
    duration: '2h 14m',
    director: 'N/A',
    cast: 'N/A',
    advisories: ['Violence', 'Strong Language'],
  );
}
