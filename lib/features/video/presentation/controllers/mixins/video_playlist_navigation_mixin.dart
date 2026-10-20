import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playlist_controller.dart';
import 'package:truthworld/features/video/presentation/services/video_playback_queue_service.dart';
import 'package:video_player/video_player.dart';

/// Mixin handling playlist traversal, video completion handling, and autoplay navigation.
mixin VideoPlaylistNavigationMixin on GetxController {
  Video get video;
  Rx<Video> get rxVideo;
  RxBool get isAutoplay;
  VideoPlayerController? get videoPlayerController;
  Stopwatch get watchStopwatch;
  RxList<Video> get playlistVideos;
  RxInt get currentPlaylistIndex;
  Rx<PlaylistModel?> get currentPlaylist;
  RxList<Video> get recommendedVideos;
  VideoPlaylistController get videoPlaylistController;
  RxBool get rxIsLoading;
  RxBool get videoError;
  RxString get rxErrorMessage;
  ChannelController get channelController;
  CommentsController get commentsController;
  set commentsController(CommentsController ctrl);
  RxBool get isAudioOnly;
  RxBool get navigatedFromPlaylist;
  bool get isAlreadyWatched;
  set isAlreadyWatched(bool val);
  String? get tag;

  void flushRemainingWatchTime();
  Future<void> syncWatchHistory(int currentWatchSeconds, int totalDuration);
  void continueInitialization();
  Future<void> initializeVideoPlayer({String? overrideUrl});
  Future<void> fetchRecommendations();
  Future<void> checkUserInteractions();

  bool _hasHandledCompletion = false;

  void handleVideoCompletion(VideoPlayerValue value) {
    if (!value.isInitialized || value.duration == Duration.zero) return;

    final isAtEnd =
        value.position >= value.duration - const Duration(milliseconds: 500);

    if (isAtEnd && value.isPlaying) {
      if (_hasHandledCompletion) return;
      _hasHandledCompletion = true;

      // Transparent watch completion: Only grant genuine full completion if user
      // ACTUALLY watched >= 85% of duration (never when dragged to end in a swap).
      final totalDuration = value.duration.inSeconds;
      final actualWatched = watchStopwatch.elapsed.inSeconds;
      final isGenuineFullWatch = totalDuration > 0 && actualWatched >= (totalDuration * 0.85);

      if (isGenuineFullWatch) {
        isAlreadyWatched = true;
        if (Get.isRegistered<WatchHistoryService>()) {
          WatchHistoryService.to.markVideoFullyWatched(video.id);
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        processVideoCompletion();
      });
    } else if (!isAtEnd) {
      _hasHandledCompletion = false;
    }
  }

  void processVideoCompletion() {
    final towerPlayerController =
        Get.isRegistered<TowerPlayerController>(tag: video.id)
            ? Get.find<TowerPlayerController>(tag: video.id)
            : null;

    final shouldLoop = towerPlayerController?.isLooping.value ?? false;
    final shouldAutoplayNext =
        towerPlayerController?.isAutoplay.value ?? isAutoplay.value;

    final totalDuration = videoPlayerController?.value.duration.inSeconds ?? 0;
    flushRemainingWatchTime();
    syncWatchHistory(watchStopwatch.elapsed.inSeconds, totalDuration);

    if (shouldLoop) {
      debugPrint('[VideoController] Looping video: ${video.id}');
      videoPlayerController?.seekTo(Duration.zero);
      videoPlayerController?.play();
      _hasHandledCompletion = false;
      return;
    }

    if (playlistVideos.isNotEmpty) {
      playNextVideo();
    } else if (shouldAutoplayNext) {
      autoplayNextVideo();
    }
  }

  void autoplayNextVideo() {
    if (!isAutoplay.value) return;

    if (recommendedVideos.isEmpty) {
      VideoPlaybackQueueService.to.fetchFallbackNextVideo(video.id).then((fallback) {
        if (fallback != null && fallback.id != video.id) {
          VideoPlaybackQueueService.to.pushCurrentForNext(fallback);
          Get.offNamed(
            '/watch?v=${fallback.id}',
            arguments: {
              'video': fallback,
              'playlist': currentPlaylist.value,
              'isAudioOnly': false,
            },
          );
        }
      });
      return;
    }

    final nextVideo = recommendedVideos.firstWhere(
      (v) => v.id != video.id,
      orElse: () => recommendedVideos.first,
    );

    if (nextVideo.id == video.id) {
      debugPrint('[VideoController] No different video found for autoplay');
      return;
    }

    debugPrint('[VideoController] Autoplaying next video: ${nextVideo.id}');
    VideoPlaybackQueueService.to.pushCurrentForNext(nextVideo);
    Get.offNamed(
      '/watch?v=${nextVideo.id}',
      arguments: {
        'video': nextVideo,
        'playlist': currentPlaylist.value,
        'isAudioOnly': false,
      },
    );
  }

  void playNext() {
    if (!isAutoplay.value) return;

    if (playlistVideos.isNotEmpty &&
        currentPlaylistIndex.value < playlistVideos.length - 1) {
      final next = playlistVideos[currentPlaylistIndex.value + 1];
      VideoPlaybackQueueService.to.pushCurrentForNext(next);
      playNextVideo();
      return;
    }
    if (VideoPlaybackQueueService.to.hasForwardVideo) {
      final next = VideoPlaybackQueueService.to.nextForwardVideo;
      if (next != null) {
        VideoPlaybackQueueService.to.pushCurrentForNext(next);
        Get.offNamed(
          '/watch?v=${next.id}',
          arguments: {
            'video': next,
            'playlist': currentPlaylist.value,
            'isAudioOnly': false,
          },
        );
        return;
      }
    }
    autoplayNextVideo();
  }

  void playPrevious() {
    if (!isAutoplay.value) return;

    if (playlistVideos.isNotEmpty && currentPlaylistIndex.value > 0) {
      videoPlaylistController.playPreviousPlaylistVideo();
      return;
    }

    if (!VideoPlaybackQueueService.to.hasPreviousVideo) {
      // First video of the session: no back video!
      return;
    }

    final prevVideo = VideoPlaybackQueueService.to.popPreviousVideo();
    if (prevVideo != null && prevVideo.id != video.id) {
      debugPrint('[VideoController] Playing previous video: ${prevVideo.id}');
      Get.offNamed(
        '/watch?v=${prevVideo.id}',
        arguments: {
          'video': prevVideo,
          'playlist': currentPlaylist.value,
          'isAudioOnly': false,
        },
      );
    }
  }

  TowerPlayerController? get towerPlayerController {
    if (tag != null &&
        tag!.isNotEmpty &&
        Get.isRegistered<TowerPlayerController>(tag: tag)) {
      return Get.find<TowerPlayerController>(tag: tag);
    }
    final strippedTag = tag?.replaceFirst('video_', '');
    if (strippedTag != null &&
        strippedTag.isNotEmpty &&
        Get.isRegistered<TowerPlayerController>(tag: strippedTag)) {
      return Get.find<TowerPlayerController>(tag: strippedTag);
    }
    final prefixedTag = 'video_${tag ?? ''}';
    if (prefixedTag.isNotEmpty &&
        Get.isRegistered<TowerPlayerController>(tag: prefixedTag)) {
      return Get.find<TowerPlayerController>(tag: prefixedTag);
    }
    if (video.id.isNotEmpty &&
        Get.isRegistered<TowerPlayerController>(tag: video.id)) {
      return Get.find<TowerPlayerController>(tag: video.id);
    }
    if (Get.isRegistered<TowerPlayerController>()) {
      return Get.find<TowerPlayerController>();
    }
    return TowerPlayerController.getForTagOrActive(
      tag ?? (video.id.isNotEmpty ? video.id : null),
    );
  }

  void setAudioOnly(bool enabled) {
    isAudioOnly.value = enabled;
    TowerPlayerController.globalAudioOnly = enabled;
    if (Get.arguments is Map) {
      (Get.arguments as Map)['isAudioOnly'] = enabled;
    }
    final tpc = towerPlayerController;
    if (tpc != null) {
      tpc.isAudioOnly.value = enabled;
      tpc.setAudioOnly(enabled);
    }
    debugPrint('[VideoController] Audio only mode set to: $enabled');
  }

  void toggleAudioOnly() {
    setAudioOnly(!isAudioOnly.value);
    debugPrint('[VideoController] Audio only mode: ${isAudioOnly.value}');
  }

  Future<void> fetchPlaylistForVideo() async {
    if (!navigatedFromPlaylist.value || video.id.isEmpty) return;
    try {
      if (currentPlaylist.value == null) {
        final snap = await FirebaseFirestore.instance
            .collection('public_playlists')
            .where('videoIds', arrayContains: video.id)
            .limit(1)
            .getCacheFirst();
        if (snap.docs.isNotEmpty) {
          currentPlaylist.value = PlaylistModel.fromDocumentSnapshot(
            snap.docs.first,
          );
        }
      }
      if (currentPlaylist.value != null && playlistVideos.isEmpty) {
        await fetchPlaylistVideos();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoPlaylistNavigationMixin.loadPlaylistFromVideo',
      );
    }
  }

  Future<void> fetchFirstPlaylistVideo(String videoId) async {
    rxIsLoading.value = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .getCacheFirst();
      if (doc.exists) {
        rxVideo.value = Video.fromDocumentSnapshot(doc);
        continueInitialization();
        fetchPlaylistVideos();
      } else {
        videoError.value = true;
        rxErrorMessage.value = 'First video of playlist not found.';
      }
    } catch (e) {
      ErrorHandler.log(e);
      videoError.value = true;
      rxErrorMessage.value =
          'Unable to load first video of playlist. Please try again.';
    } finally {
      rxIsLoading.value = false;
    }
  }

  Future<void> fetchPlaylistVideos() async {
    await videoPlaylistController.fetchPlaylistVideos();
  }

  void playNextVideo() {
    videoPlaylistController.playNextPlaylistVideo();
  }

  void playPlaylistVideoAtIndex(int index) {
    videoPlaylistController.playPlaylistVideoAtIndex(index);
  }

  void handleVideoTransition(Video nextVideo) {
    Get.delete<CommentsController>(tag: 'video_${nextVideo.id}', force: true);
    commentsController = Get.put(
      CommentsController(video: nextVideo),
      tag: 'video_${nextVideo.id}',
    );

    isAudioOnly.value = false;
    TowerPlayerController.globalAudioOnly = false;
    if (Get.arguments is Map) {
      (Get.arguments as Map)['isAudioOnly'] = false;
    }
    if (Get.isRegistered<TowerPlayerController>(tag: nextVideo.id)) {
      Get.find<TowerPlayerController>(tag: nextVideo.id).setAudioOnly(false);
    }

    initializeVideoPlayer(overrideUrl: nextVideo.videoUrl);
    fetchRecommendations();
    checkUserInteractions();
    if (nextVideo.channelId.trim().isNotEmpty) {
      channelController.listenSubscription(nextVideo.channelId);
    }
  }
}
