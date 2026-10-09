import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Centralized watch-session playback queue service.
///
/// Tracks the history of videos watched in the current session so that:
/// - If the current video is the first video of the session, there are no back videos.
/// - When tapping Next Video, the current video is pushed onto [previousStack].
/// - When tapping Back Video, the previous video is popped and played, and the current video
///   moves onto [forwardStack].
/// - All next/back navigation operates strictly when autoplay mode is enabled.
class VideoPlaybackQueueService extends GetxService {
  static VideoPlaybackQueueService get to =>
      Get.isRegistered<VideoPlaybackQueueService>()
          ? Get.find<VideoPlaybackQueueService>()
          : Get.put(VideoPlaybackQueueService(), permanent: true);

  final RxList<Video> previousStack = <Video>[].obs;
  final RxList<Video> forwardStack = <Video>[].obs;
  final Rx<Video?> currentVideo = Rx<Video?>(null);

  bool _isInternalNavigation = false;

  /// Called whenever a video begins playback.
  /// If the navigation originated internally (Next or Back tap), the previous session history
  /// is preserved. If the video was opened fresh (e.g. tapped from Home, Feed, Search),
  /// the session history is cleared so that the new video acts as the "first video".
  void onVideoLoaded(Video video) {
    if (_isInternalNavigation) {
      _isInternalNavigation = false;
      currentVideo.value = video;
      debugPrint('[VideoPlaybackQueueService] Session continued: ${video.id} (history: ${previousStack.length})');
    } else {
      if (currentVideo.value?.id != video.id) {
        clearSession();
        currentVideo.value = video;
        debugPrint('[VideoPlaybackQueueService] New session started: ${video.id}');
      }
    }
  }

  /// Whether a previous video exists in the current session.
  bool get hasPreviousVideo => previousStack.isNotEmpty;

  /// Whether a forward video exists in the current session (e.g. after tapping back).
  bool get hasForwardVideo => forwardStack.isNotEmpty;

  /// The most recent previous video in the stack.
  Video? get previousVideo => previousStack.isNotEmpty ? previousStack.last : null;

  /// The next video in the forward stack.
  Video? get nextForwardVideo => forwardStack.isNotEmpty ? forwardStack.last : null;

  /// Pops the previous video to play it, pushing current video to [forwardStack].
  Video? popPreviousVideo() {
    if (previousStack.isEmpty) return null;
    if (currentVideo.value != null) {
      forwardStack.add(currentVideo.value!);
    }
    _isInternalNavigation = true;
    return previousStack.removeLast();
  }

  /// Prepares to navigate forward to [nextVideo], pushing current video onto [previousStack].
  void pushCurrentForNext(Video nextVideo) {
    if (currentVideo.value != null) {
      previousStack.add(currentVideo.value!);
    }
    if (forwardStack.isNotEmpty && forwardStack.last.id == nextVideo.id) {
      forwardStack.removeLast();
    }
    _isInternalNavigation = true;
  }

  /// Clears the watch session history (resets to initial first video state).
  void clearSession() {
    previousStack.clear();
    forwardStack.clear();
    currentVideo.value = null;
    _isInternalNavigation = false;
  }

  /// Fallback query to fetch a candidate next public video from Firestore
  /// when recommendations list is empty or still fetching.
  Future<Video?> fetchFallbackNextVideo(String currentVideoId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .where('status', whereIn: const ['ready', 'published'])
          .limit(15)
          .get();

      for (final doc in snap.docs) {
        if (doc.id != currentVideoId && !previousStack.any((v) => v.id == doc.id)) {
          final vid = Video.fromDocumentSnapshot(doc);
          if (VideoVisibilityPolicy.canViewVideo(vid)) {
            return vid;
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoPlaybackQueueService.fetchFallbackNextVideo',
      );
    }
    return null;
  }
}
