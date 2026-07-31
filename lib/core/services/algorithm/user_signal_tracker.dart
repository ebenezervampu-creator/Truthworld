import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/session_interest_tracker.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';

/// Tracks all user interactions for the Truthworld Algorithm.
///
/// Dual-write pattern:
/// 1. Updates local UserInterestProfile immediately (instant reactivity)
/// 2. Sends signal to server trackActivity() in background (persistent storage)
/// 3. Records session event in SessionInterestTracker (session awareness)
class UserSignalTracker extends GetxService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );
  final List<Map<String, dynamic>> _buffer = <Map<String, dynamic>>[];
  Timer? _flushTimer;

  UserInterestProfileService get _profileService =>
      Get.find<UserInterestProfileService>();
  SessionInterestTracker get _sessionTracker =>
      Get.find<SessionInterestTracker>();

  @override
  void onInit() {
    super.onInit();
    _startFlushTimer();
  }

  @override
  void onClose() {
    _flushTimer?.cancel();
    unawaited(flush());
    super.onClose();
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 10), (_) => flush());
  }

  /// Track video watch (when > 20 seconds)
  Future<void> trackWatch({
    required String videoId,
    required String category,
    required List<String> topics,
    required String channelId,
    required int durationSec,
    required double completion,
  }) async {
    if (durationSec <= 20) return;

    _profileService.onVideoWatched(videoId, category, topics, completion);
    _sessionTracker.trackSessionEvent('watch', {
      'videoId': videoId,
      'category': category,
      'topics': topics,
    });

    _queueSignal(
      category,
      'watch',
      durationSec: durationSec,
      channelId: channelId,
      videoId: videoId,
    );
  }

  /// Track video like
  Future<void> trackLike({
    required String videoId,
    required String category,
    required List<String> topics,
    required String channelId,
  }) async {
    _profileService.onVideoLiked(videoId, category);
    _sessionTracker.trackSessionEvent('like', {
      'videoId': videoId,
      'category': category,
      'topics': topics,
    });
    _queueSignal(category, 'like', channelId: channelId, videoId: videoId);
  }

  /// Track video dislike
  Future<void> trackDislike({
    required String videoId,
    required String category,
  }) async {
    _profileService.onVideoDisliked(videoId, category);
    _sessionTracker.trackSessionEvent('dislike', {
      'videoId': videoId,
      'category': category,
    });
    _queueSignal(category, 'dislike', videoId: videoId);
  }

  /// Track topic follow
  Future<void> trackFollowTopic({
    required String topicSlug,
    required String category,
  }) async {
    _profileService.onTopicFollowed(topicSlug);
    _sessionTracker.trackSessionEvent('follow_topic', {
      'topicSlug': topicSlug,
      'category': category,
    });
    _queueSignal(category, 'follow_topic', topicSlug: topicSlug);
  }

  /// Track channel subscribe
  Future<void> trackSubscribe({
    required String channelId,
    required String category,
  }) async {
    _profileService.onChannelSubscribed(channelId);
    _sessionTracker.trackSessionEvent('subscribe', {
      'channelId': channelId,
      'category': category,
    });
    _queueSignal(category, 'subscribe', channelId: channelId);
  }

  /// Track search query
  Future<void> trackSearch({required String query}) async {
    _sessionTracker.trackSessionEvent('search', {'query': query});
    _queueSignal('general', 'search', topicSlug: query);
  }

  /// Track video click (impression → click)
  Future<void> trackClick({
    required String videoId,
    required String category,
    required List<String> topics,
    required String channelId,
    required RecommendationSurface source,
  }) async {
    _sessionTracker.trackSessionEvent('click', {
      'videoId': videoId,
      'category': category,
      'source': source.toString(),
    });
    _queueSignal(category, 'click', channelId: channelId, videoId: videoId);
  }

  /// Track skip (scrolled past without clicking)
  Future<void> trackSkip({
    required String videoId,
    required String category,
  }) async {
    _sessionTracker.trackSessionEvent('skip', {
      'videoId': videoId,
      'category': category,
    });
    _queueSignal(category, 'skip', videoId: videoId);
  }

  /// Track early exit (watched < 5 seconds then left)
  Future<void> trackEarlyExit({
    required String videoId,
    required String category,
    required List<String> topics,
  }) async {
    _sessionTracker.trackSessionEvent('early_exit', {
      'videoId': videoId,
      'category': category,
    });
    _queueSignal(category, 'early_exit', videoId: videoId);
  }

  /// Track not interested
  Future<void> trackNotInterested({required String videoId}) async {
    _profileService.onVideoNotInterested(videoId);
    _sessionTracker.trackSessionEvent('not_interested', {'videoId': videoId});
    _queueSignal('general', 'not_interested', videoId: videoId);
  }

  void _queueSignal(
    String category,
    String type, {
    int? durationSec,
    String? topicSlug,
    String? channelId,
    String? videoId,
  }) {
    _buffer.add({
      'type': type,
      'category': category,
      if (durationSec != null) 'durationSec': durationSec,
      if (topicSlug != null) 'topicSlug': topicSlug,
      if (channelId != null) 'channelId': channelId,
      if (videoId != null) 'videoId': videoId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    if (_buffer.length >= 10) {
      unawaited(flush());
    }
  }

  /// Flush queued signals to server in a single batch
  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _buffer.clear();
      return;
    }

    final eventsToFlush = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    try {
      final callable = _functions.httpsCallable('trackActivity');
      await callable.call({
        'events': eventsToFlush,
      });
    } catch (e) {
      debugPrint('[UserSignalTracker] Batched tracking failed: $e');
    }
  }
}
