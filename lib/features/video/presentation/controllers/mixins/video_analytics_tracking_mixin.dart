import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/algorithm/user_signal_tracker.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/features/analytics/data/services/viewer_identity_service.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:video_player/video_player.dart';

/// Mixin handling traffic source attribution, watch time tracking, 24h qualified views, and history synchronization.
mixin VideoAnalyticsTrackingMixin on GetxController {
  Video get video;
  Rx<VideoClip?> get activeClip;
  Stopwatch get watchStopwatch;
  int get lastPingWatchSeconds;
  set lastPingWatchSeconds(int val);
  bool get isVpcInitialized;
  VideoPlayerController? get videoPlayerController;
  RxBool get isSubscribed;
  String get trafficSource;
  set trafficSource(String val);
  String get viewerHash;
  set viewerHash(String val);
  MainController get mainController;
  bool get isAlreadyWatched;
  set isAlreadyWatched(bool val);

  bool get isAlreadyWatchedVideo {
    if (isAlreadyWatched) return true;
    final dur = video.durationSeconds > 0
        ? video.durationSeconds
        : (videoPlayerController?.value.duration.inSeconds ?? 0);
    if (Get.isRegistered<WatchHistoryService>() &&
        WatchHistoryService.to.isVideoFullyWatched(video.id, totalDuration: dur)) {
      isAlreadyWatched = true;
      return true;
    }
    return false;
  }

  String detectTrafficSource() {
    if (activeClip.value != null) {
      return 'clip';
    }

    final args = Get.arguments as Map<String, dynamic>? ?? {};

    if (args.containsKey('source')) {
      final source = args['source'] as String? ?? 'direct';
      return normalizeTrafficSource(source);
    }

    if (args.containsKey('referrer')) {
      final referrer = args['referrer'] as String? ?? '';
      return classifyExternalReferrer(referrer);
    }

    final previousRoute = Get.previousRoute;
    if (previousRoute.contains('search')) return 'search';
    if (previousRoute.contains('channel')) return 'channel_page';
    if (previousRoute.contains('home')) return 'home_feed';
    if (previousRoute.contains('shorts')) return 'shorts_feed';
    if (previousRoute.contains('trending')) return 'trending';
    if (previousRoute.contains('library') ||
        previousRoute.contains('history')) {
      return 'library';
    }
    if (previousRoute.contains('playlist')) return 'playlist';
    if (previousRoute.contains('notifications')) return 'notifications';

    return 'direct';
  }

  String normalizeTrafficSource(String source) {
    const mapping = {
      'clip': 'clip',
      'suggested': 'suggested',
      'search': 'search',
      'direct': 'direct',
      'external': 'other_external',
      'channel_page': 'channel_page',
      'shorts_feed': 'shorts_feed',
      'home_feed': 'home_feed',
      'home': 'home_feed',
      'trending': 'trending',
      'playlist': 'playlist',
      'end_screen': 'end_screen',
      'notifications': 'notifications',
      'library': 'library',
    };
    return mapping[source] ?? source;
  }

  String classifyExternalReferrer(String referrer) {
    final lower = referrer.toLowerCase();
    if (lower.contains('whatsapp') || lower.contains('wa.me')) {
      return 'whatsapp';
    }
    if (lower.contains('instagram') || lower.contains('ig.me')) {
      return 'instagram';
    }
    if (lower.contains('twitter') ||
        lower.contains('t.co') ||
        lower.contains('x.com')) {
      return 'twitter';
    }
    if (lower.contains('facebook') || lower.contains('fb.')) return 'facebook';
    if (lower.contains('telegram') || lower.contains('t.me')) return 'telegram';
    if (lower.contains('embed')) return 'embed';
    return 'direct_link';
  }

  void flushRemainingWatchTime() {
    if (!AuthService.to.isAuthenticated.value || AuthService.to.uid.isEmpty) {
      // Unsigned / guest user: Do not credit watch time to channel/video.
      // Guest watch limit is tracked exclusively by GuestPlaybackLimitService.
      return;
    }
    final currentWatchSeconds = watchStopwatch.elapsed.inSeconds;
    final delta = currentWatchSeconds - lastPingWatchSeconds;
    if (delta > 0 && isVpcInitialized && videoPlayerController != null) {
      final totalDuration = videoPlayerController!.value.duration.inSeconds > 0
          ? videoPlayerController!.value.duration.inSeconds
          : video.durationSeconds;
      lastPingWatchSeconds = currentWatchSeconds;
      if (isAlreadyWatchedVideo) {
        return; // Never count watch time again for already watched video!
      }
      pingWatchEvent('watch_ping', currentWatchSeconds, totalDuration, delta);
    }
  }

  Future<void> pingWatchEvent(
    String eventType,
    int position,
    int duration,
    int deltaSeconds,
  ) async {
    if (!AuthService.to.isAuthenticated.value || AuthService.to.uid.isEmpty) return;
    if (isAlreadyWatchedVideo) return; // Never record watch time for re-watching!
    final totalDur = duration > 0
        ? duration
        : (video.durationSeconds > 0
            ? video.durationSeconds
            : (videoPlayerController?.value.duration.inSeconds ?? 0));

    var effectiveDelta = deltaSeconds;
    if (effectiveDelta > 0 && totalDur > 0 && Get.isRegistered<WatchHistoryService>()) {
      final cumWatch = WatchHistoryService.to.getCumulativeWatchSeconds(video.id);
      final remainingAllowed = math.max(0, totalDur - cumWatch);
      effectiveDelta = math.min(effectiveDelta, remainingAllowed);
      if (effectiveDelta > 0) {
        WatchHistoryService.to.addCumulativeWatchSeconds(video.id, effectiveDelta, totalDur);
      }
    }

    if (effectiveDelta <= 0 && eventType == 'watch_ping') return;
    final isSub = isSubscribed.value;

    mainController.trackWatchEvent(
      videoId: video.id,
      channelId: video.channelId,
      eventType: eventType,
      position: position,
      duration: totalDur,
      watchTimeSecondsDelta: effectiveDelta,
      isSubscriber: isSub,
      isNotSubscriber: !isSub,
      trafficSource: trafficSource,
      viewerHash: viewerHash.isNotEmpty ? viewerHash : null,
    );
  }

  bool canCountQualifiedView() {
    if (!AuthService.to.isAuthenticated.value || AuthService.to.uid.isEmpty) {
      // Unsigned / guest viewers NEVER count as qualified views
      return false;
    }
    try {
      final storage = GetStorage();
      final identifier = AuthService.to.uid;
      final key = 'qv_${video.id}_$identifier';
      final lastTimestamp = storage.read<int>(key);
      if (lastTimestamp == null) return true;
      final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
      return DateTime.now().difference(lastTime).inHours >= 24;
    } catch (e) {
      return true;
    }
  }

  void markQualifiedViewTimestamp() {
    if (!AuthService.to.isAuthenticated.value || AuthService.to.uid.isEmpty) return;
    try {
      final storage = GetStorage();
      final identifier = AuthService.to.uid;
      final key = 'qv_${video.id}_$identifier';
      storage.write(key, DateTime.now().millisecondsSinceEpoch);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoAnalyticsTrackingMixin.markQualifiedViewTimestamp',
      );
    }
  }

  Future<void> fireMilestoneEvent(
    String eventType,
    int position,
    int duration,
  ) async {
    if (!AuthService.to.isAuthenticated.value || AuthService.to.uid.isEmpty) return;
    final isSub = isSubscribed.value;

    String? dedupKey;
    if (eventType == 'qualified_view' && viewerHash.isNotEmpty) {
      try {
        final identityService = Get.find<ViewerIdentityService>();
        dedupKey = await identityService.generateDedupKey(video.id);
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'VideoAnalyticsTrackingMixin.generateDedupKey',
        );
      }
    }

    final currentWatch = watchStopwatch.elapsed.inSeconds;
    final rawDelta = isAlreadyWatchedVideo ? 0 : (currentWatch - lastPingWatchSeconds);
    if (rawDelta > 0) {
      lastPingWatchSeconds = currentWatch;
    }

    final totalDur = duration > 0
        ? duration
        : (video.durationSeconds > 0
            ? video.durationSeconds
            : (videoPlayerController?.value.duration.inSeconds ?? 0));

    var effectiveDelta = rawDelta > 0 ? rawDelta : 0;
    if (effectiveDelta > 0 && totalDur > 0 && Get.isRegistered<WatchHistoryService>()) {
      final cumWatch = WatchHistoryService.to.getCumulativeWatchSeconds(video.id);
      final remainingAllowed = math.max(0, totalDur - cumWatch);
      effectiveDelta = math.min(effectiveDelta, remainingAllowed);
      if (effectiveDelta > 0) {
        WatchHistoryService.to.addCumulativeWatchSeconds(video.id, effectiveDelta, totalDur);
      }
    }

    if (totalDur <= 0) return;

    mainController.trackWatchEvent(
      videoId: video.id,
      channelId: video.channelId,
      eventType: eventType,
      position: position,
      duration: totalDur,
      watchTimeSecondsDelta: effectiveDelta,
      isSubscriber: isSub,
      isNotSubscriber: !isSub,
      trafficSource: trafficSource,
      viewerHash: viewerHash.isNotEmpty ? viewerHash : null,
      dedupKey: dedupKey,
    );
  }

  Future<void> resolveViewerIdentity() async {
    try {
      final identityService = Get.find<ViewerIdentityService>();
      viewerHash = await identityService.getViewerIdentity();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoAnalyticsTrackingMixin.resolveViewerIdentity',
      );
      viewerHash = AuthService.to.uid.isNotEmpty ? AuthService.to.uid : '';
    }
  }

  Future<void> syncWatchHistory(
    int currentWatchSeconds,
    int totalDuration,
  ) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) return;

    try {
      final storage = GetStorage();
      final isPaused = storage.read<bool>('watch_history_paused') ?? false;
      if (isPaused) {
        debugPrint('[VideoController] Watch history sync skipped (Paused)');
        return;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoAnalyticsTrackingMixin.checkHistoryPaused',
      );
    }

    try {
      final cumWatch = Get.isRegistered<WatchHistoryService>()
          ? WatchHistoryService.to.getCumulativeWatchSeconds(video.id)
          : currentWatchSeconds;
      final effectiveWatch = math.max(currentWatchSeconds, cumWatch);
      final effectiveDuration = totalDuration > 0
          ? totalDuration
          : (video.durationSeconds > 0
              ? video.durationSeconds
              : video.durationValue.inSeconds);

      final percentage = effectiveDuration > 0
          ? ((effectiveWatch / effectiveDuration) * 100).clamp(0, 100)
          : 0;

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('watch_history')
          .doc(video.id)
          .set({
            'videoId': video.id,
            'channelId': video.channelId,
            'channelName': video.channelName,
            'channelImage': video.channelImage,
            'title': video.title,
            'thumbnailUrl': video.thumbnailUrl,
            'duration': video.duration,
            'durationMs': video.durationValue.inMilliseconds > 0
                ? video.durationValue.inMilliseconds
                : effectiveDuration * 1000,
            'views': video.views,
            'likeCount': video.likeCount,
            'category': video.category,
            'tags': video.tags,
            'description': video.description,
            'videoUrl': video.originalUrl,
            'ownerId': video.ownerId,
            'watchedAt': FieldValue.serverTimestamp(),
            'watchedDuration': effectiveWatch,
            'watchPercentage': percentage,
            'isCompleted': percentage >= 90.0,
            'lastPosition':
                videoPlayerController?.value.position.inSeconds ?? 0,
            'videoDuration': effectiveDuration,
          }, SetOptions(merge: true));

      // Only mark video as watched in recommendation profile if user actually watched >= 80%
      if (percentage >= 80 && Get.isRegistered<UserInterestProfileService>()) {
        Get.find<UserInterestProfileService>().markVideoWatched(
          video.id,
          category: video.category,
          topics: video.topics,
        );
      }

      if (Get.isRegistered<UserSignalTracker>()) {
        Get.find<UserSignalTracker>().trackWatch(
          videoId: video.id,
          category: video.category,
          topics: video.topics,
          channelId: video.channelId,
          durationSec: effectiveWatch,
          completion: (percentage / 100.0).clamp(0.0, 1.0),
          isFactChecked: video.isFactChecked || video.hasAiCredibility,
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoAnalyticsTrackingMixin.syncWatchHistory',
      );
    }
  }

}
