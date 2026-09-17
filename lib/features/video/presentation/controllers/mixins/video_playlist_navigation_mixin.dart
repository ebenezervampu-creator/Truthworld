import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playlist_controller.dart';
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        processVideoCompletion();
      });
    } else if (!isAtEnd) {
      _hasHandledCompletion = false;
    }
  }

  /// Backward-compatible alias.
  void _handleVideoCompletion(VideoPlayerValue value) =>
      handleVideoCompletion(value);

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

  /// Backward-compatible alias.
  void _processVideoCompletion() => processVideoCompletion();

  void autoplayNextVideo() {
    if (recommendedVideos.isEmpty) {
      debugPrint('[VideoController] No recommended videos for autoplay');
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
    Get.offNamed(
      '/watch?v=${nextVideo.id}',
      arguments: {
        'video': nextVideo,
        'playlist': currentPlaylist.value,
      },
    );
  }

  /// Backward-compatible alias.
  void _autoplayNextVideo() => autoplayNextVideo();

  void playNext() {
    if (playlistVideos.isNotEmpty &&
        currentPlaylistIndex.value < playlistVideos.length - 1) {
      playNextVideo();
      return;
    }
    autoplayNextVideo();
  }

  void playPrevious() {
    if (playlistVideos.isNotEmpty && currentPlaylistIndex.value > 0) {
      videoPlaylistController.playPreviousPlaylistVideo();
      return;
    }

    if (recommendedVideos.isEmpty) return;

    final currentIndex =
        recommendedVideos.indexWhere((v) => v.id == video.id);
    Video? prevVideo;
    if (currentIndex > 0) {
      prevVideo = recommendedVideos[currentIndex - 1];
    } else if (currentIndex == -1 && recommendedVideos.isNotEmpty) {
      prevVideo = recommendedVideos.first;
    }

    if (prevVideo != null && prevVideo.id != video.id) {
      debugPrint('[VideoController] Playing previous video: ${prevVideo.id}');
      Get.offNamed(
        '/watch?v=${prevVideo.id}',
        arguments: {
          'video': prevVideo,
          'playlist': currentPlaylist.value,
        },
      );
    }
  }

  void toggleAudioOnly() {
    if (Get.isRegistered<TowerPlayerController>(tag: video.id)) {
      Get.find<TowerPlayerController>(tag: video.id).toggleAudioOnly();
    } else if (Get.isRegistered<TowerPlayerController>()) {
      Get.find<TowerPlayerController>().toggleAudioOnly();
    } else {
      isAudioOnly.value = !isAudioOnly.value;
    }
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
            .get();
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
          .get();
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

  /// Backward-compatible alias.
  Future<void> _fetchFirstPlaylistVideo(String videoId) =>
      fetchFirstPlaylistVideo(videoId);

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

    initializeVideoPlayer(overrideUrl: nextVideo.videoUrl);
    fetchRecommendations();
    checkUserInteractions();
    channelController.listenSubscription(nextVideo.channelId);
  }
}
