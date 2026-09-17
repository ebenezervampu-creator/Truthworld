import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/domain/database_helpers.dart';
import 'package:truthworld/features/video/domain/repositories/video_repository.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_analytics_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_engagement_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/features/video/presentation/controllers/video_recommendations_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_transcript_controller.dart';
import 'package:truthworld/services/video_hydration_service.dart';
import 'package:video_player/video_player.dart';

/// Mixin handling video entity hydration, deep link resolution, route origin analysis, metadata streams, and sub-controller bindings.
mixin VideoHydrationFlowMixin on GetxController {
  Video get video;
  set video(Video v);
  Rx<Video> get rxVideo;
  VideoRepository get videoRepository;
  RxBool get rxIsLoading;
  RxBool get showThumbnail;
  RxBool get rxIsOffline;
  RxBool get isAudioOnly;
  RxString get rxErrorMessage;
  Rx<VideoClip?> get activeClip;
  Duration? get initialSeekPosition;
  set initialSeekPosition(Duration? pos);
  RxBool get navigatedFromTopic;
  RxBool get navigatedFromPlaylist;
  Rx<PlaylistModel?> get currentPlaylist;
  RxBool get isPlaylistShuffled;

  VideoEngagementController get engagementController;
  set engagementController(VideoEngagementController c);
  VideoAnalyticsController get analyticsController;
  set analyticsController(VideoAnalyticsController c);
  VideoTranscriptController get transcriptController;
  set transcriptController(VideoTranscriptController c);
  VideoRecommendationsController get recommendationsController;
  set recommendationsController(VideoRecommendationsController c);
  ChannelController get channelController;
  set channelController(ChannelController c);
  CommentsController get commentsController;
  set commentsController(CommentsController c);

  StreamSubscription? get connectivitySubscription;
  set connectivitySubscription(StreamSubscription? s);
  StreamSubscription<DocumentSnapshot>? get videoSubscription;
  set videoSubscription(StreamSubscription<DocumentSnapshot>? s);

  VideoPlayerController? get videoPlayerController;
  RxBool get videoError;
  bool get isAuthenticated;
  String get trafficSource;
  set trafficSource(String val);

  Future<void> attemptRecovery();
  Future<void> startPlaybackFlow({String? overrideUrl});
  void listenToLanguageRequests();
  Future<void> fetchAvailableResolutions();
  String detectTrafficSource();
  Future<void> resolveViewerIdentity();
  Future<void> fetchPlaylistVideos();
  Future<void> fetchFirstPlaylistVideo(String videoId);
  Future<void> fetchRecommendations();
  Future<void> fetchPlaylistForVideo();

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _channelStream;
  String? _lastChannelStreamId;

  Stream<DocumentSnapshot<Map<String, dynamic>>> getChannelStream(String channelId) {
    if (_channelStream != null && _lastChannelStreamId == channelId) {
      return _channelStream!;
    }
    _lastChannelStreamId = channelId;
    _channelStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.channels)
        .doc(channelId)
        .snapshots();
    return _channelStream!;
  }

  void setupConnectivityListener() {
    connectivitySubscription = Get.find<ConnectivityService>()
        .onConnectivityChanged
        .listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        if (rxIsOffline.value) {
          rxIsOffline.value = false;
        }
        if (videoError.value) {
          attemptRecovery();
        }
      } else {
        if (!rxIsOffline.value) {
          rxIsOffline.value = true;
        }
      }
    });
  }

  void _initializeCommentsController() {
    final tag = 'video_${video.id}';
    if (!Get.isRegistered<CommentsController>(tag: tag)) {
      commentsController = Get.put(
        CommentsController(video: video, isOffline: rxIsOffline.value),
        tag: tag,
      );
    } else {
      commentsController = Get.find<CommentsController>(tag: tag);
    }
  }

  void initializeCommentsController() => _initializeCommentsController();

  Future<void> checkUserInteractions() async {
    await engagementController.checkUserInteractions(video.id, video.channelId);
  }

  void _listenToVideoUpdates() {
    videoSubscription?.cancel();
    videoSubscription = FirebaseFirestore.instance
        .collection(FirestoreCollections.videos)
        .doc(video.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final newData = snapshot.data();
        if (newData != null) {
          final updatedVideo = Video.fromMap(newData, snapshot.id);
          if (video.chapters.length != updatedVideo.chapters.length) {
            debugPrint(
              '[VideoController] 📖 Chapters updated: ${updatedVideo.chapters.length} found',
            );
          }
          rxVideo.value = updatedVideo;
          video = updatedVideo;
          if (Get.isRegistered<TowerPlayerController>(tag: video.id)) {
            Get.find<TowerPlayerController>(tag: video.id).update();
          }
        }
      }
    }, onError: (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoController.videoUpdates');
    });
    if (Get.isRegistered<TowerPlayerController>(tag: video.id)) {
      Get.find<TowerPlayerController>(tag: video.id).update();
    } else if (Get.isRegistered<TowerPlayerController>()) {
      Get.find<TowerPlayerController>().update();
    }
  }

  void listenToVideoUpdates() => _listenToVideoUpdates();

  void continueInitialization() {
    initializeAllMetadata();
    startPlaybackFlow();
  }

  void parseAndHydrateInitialVideo() {
    final rawArgs = Get.arguments;
    final args = rawArgs is Map<String, dynamic>
        ? rawArgs
        : (rawArgs is Map ? Map<String, dynamic>.from(rawArgs) : null);
    final prevRoute = Get.previousRoute.toLowerCase();
    final currRoute = Get.currentRoute.toLowerCase();

    final isTopicOrigin =
        (args?['fromTopic'] == true) ||
        (args?['topic'] != null) ||
        prevRoute.contains('topic') ||
        currRoute.contains('topic') ||
        (args?['heroTag']?.toString().contains('topic') ?? false);

    final isPlaylistOrigin =
        (args?['fromPlaylist'] == true) ||
        (args?['playlist'] != null) ||
        prevRoute.contains('playlist') ||
        currRoute.contains('playlist') ||
        Get.parameters.containsKey('list');

    if (isTopicOrigin) {
      navigatedFromTopic.value = true;
      navigatedFromPlaylist.value = false;
      currentPlaylist.value =
          null; // Rule: "dont need playlist when From Topics a video played"
    } else if (isPlaylistOrigin) {
      navigatedFromPlaylist.value = true;
      navigatedFromTopic.value = false;
      isPlaylistShuffled.value = (args?['isShuffled'] == true);
      if (args?['playlist'] != null) {
        currentPlaylist.value = args!['playlist'] as PlaylistModel;
        fetchPlaylistVideos();
      } else if (Get.parameters.containsKey('list')) {
        final listId = Get.parameters['list']!;
        DeepLinkService.instance.loadPlaylist(listId).then((pl) {
          if (pl != null) {
            currentPlaylist.value = pl;
            fetchPlaylistVideos();
          }
        });
      }
    } else {
      navigatedFromPlaylist.value = false;
      navigatedFromTopic.value = false;
    }

    final hasClipEnd = (args?['clipEndTime'] != null) ||
        Get.parameters.containsKey('clipEnd') ||
        Get.parameters.containsKey('end') ||
        (kIsWeb &&
            (Uri.base.queryParameters.containsKey('clipEnd') ||
                Uri.base.queryParameters.containsKey('end')));
    final rawResume = args?['resumePosition'] ?? args?['initialPosition'];
    if (rawResume is Duration && rawResume > Duration.zero) {
      initialSeekPosition = rawResume;
    } else if (rawResume is int && rawResume > 0) {
      initialSeekPosition = Duration(milliseconds: rawResume);
    } else if (rawResume is double && rawResume > 0) {
      initialSeekPosition = Duration(milliseconds: rawResume.toInt());
    } else if (!hasClipEnd) {
      final timeStr = Get.parameters['t'] ??
          Get.parameters['time'] ??
          (kIsWeb
              ? (Uri.base.queryParameters['t'] ??
                  Uri.base.queryParameters['time'])
              : null) ??
          Get.parameters['start'] ??
          (kIsWeb ? Uri.base.queryParameters['start'] : null);
      final parsedTime = DeepLinkService.parseTimestamp(timeStr);
      if (parsedTime != null) {
        initialSeekPosition = parsedTime;
      }
    }
    if (args?['video'] != null) {
      final videoArg = args!['video'] as Video;
      rxVideo.value = videoArg;
      DeepLinkService.instance.cacheVideo(videoArg);
      _initLoadedVideo(args);
    } else if (currentPlaylist.value != null &&
        currentPlaylist.value!.videoIds.isNotEmpty) {
      fetchFirstPlaylistVideo(currentPlaylist.value!.videoIds.first);
      return;
    } else {
      final videoId = Get.parameters['v'] ?? Get.parameters['videoId'] ?? Get.parameters['id'];
      if (videoId != null && videoId.isNotEmpty) {
        _loadVideoFromDeepLink(videoId, args);
      } else {
        videoError.value = true;
        rxErrorMessage.value = 'Video data not found';
        rxIsLoading.value = false;
      }
    }
  }

  Future<void> _loadVideoFromDeepLink(String videoId, Map<String, dynamic>? args) async {
    rxIsLoading.value = true;
    showThumbnail.value = true;
    try {
      final offlineMeta = await getOfflineVideoMetadata(videoId);
      if (offlineMeta != null) {
        rxIsOffline.value = true;
        if (offlineMeta.isAudioOnly) {
          isAudioOnly.value = true;
        }
        final offlineVideo = Video.fromOffline(offlineMeta);
        rxVideo.value = offlineVideo;
        _initLoadedVideo(args);
        return;
      }
    } catch (_) {}
    final cached = DeepLinkService.instance.getVideoFromCache(videoId);
    if (cached != null) {
      debugPrint('[VideoController] ⚡ 0ms instant cache hit for video: $videoId');
      rxVideo.value = cached;
      _initLoadedVideo(args);
      return;
    }
    if (VideoHydrationService.hasInjectedData()) {
      final injectedData = VideoHydrationService.getInjectedData();
      if (injectedData != null) {
        final hydVideo = Video(
          id: injectedData['id'] as String? ?? videoId,
          title: injectedData['title'] as String? ?? 'Video',
          description: injectedData['description'] as String? ?? '',
          thumbnailUrl: injectedData['thumbnail'] as String? ?? '',
          videoUrl: injectedData['videoUrl'] as String?,
          hlsUrl: injectedData['hlsUrl'] as String? ?? '',
          dashUrl: injectedData['dashUrl'] as String? ?? '',
          ownerId: injectedData['creatorId'] as String? ?? 'unknown',
          channelId: injectedData['channelId'] as String? ?? (injectedData['creatorId'] as String? ?? 'unknown'),
          channelName: injectedData['creatorName'] as String? ?? 'Creator',
          category: injectedData['category'] as String? ?? 'General',
          tags: List<String>.from(injectedData['tags'] as List? ?? []),
          viewCount: injectedData['viewCount'] as int? ?? 0,
          vDurationValue: Duration(
            seconds: injectedData['duration'] as int? ?? 0,
          ),
          createdAt: Timestamp.now(),
        );
        VideoHydrationService.clearInjectedData();
        rxVideo.value = hydVideo;
        DeepLinkService.instance.cacheVideo(hydVideo);
        _initLoadedVideo(args);
        return;
      }
    }
    try {
      debugPrint('[VideoController] ⏳ Loading deep-linked video from Firestore: $videoId');
      final loadedVideo = await DeepLinkService.instance.loadVideo(videoId);
      if (loadedVideo != null) {
        rxVideo.value = loadedVideo;
        DeepLinkService.instance.cacheVideo(loadedVideo);
        _initLoadedVideo(args);
      } else {
        videoError.value = true;
        rxErrorMessage.value = 'Video not found or has been removed.';
        rxIsLoading.value = false;
      }
    } catch (e) {
      debugPrint('[VideoController] Deep link video load error: $e');
      videoError.value = true;
      rxErrorMessage.value = 'Unable to load video: $e';
      rxIsLoading.value = false;
    }
  }

  Future<void> loadVideoFromDeepLink(String videoId, Map<String, dynamic>? args) =>
      _loadVideoFromDeepLink(videoId, args);

  void _initLoadedVideo(Map<String, dynamic>? args) {
    final tag = 'video_${video.id}';
    if (!Get.isRegistered<VideoEngagementController>(tag: tag)) {
      engagementController = Get.put(VideoEngagementController(), tag: tag);
    } else {
      engagementController = Get.find<VideoEngagementController>(tag: tag);
    }

    if (!Get.isRegistered<VideoAnalyticsController>(tag: tag)) {
      analyticsController = Get.put(VideoAnalyticsController(), tag: tag);
    } else {
      analyticsController = Get.find<VideoAnalyticsController>(tag: tag);
    }
    if (args?['clip'] != null) {
      activeClip.value = args!['clip'] as VideoClip;
      debugPrint(
        '[VideoController] 🎬 Starting in Clip Mode: ${activeClip.value?.title}',
      );
    } else {
      final startStr = Get.parameters['start'] ??
          Get.parameters['clipStart'] ??
          (kIsWeb
              ? (Uri.base.queryParameters['start'] ??
                  Uri.base.queryParameters['clipStart'])
              : null);
      final endStr = Get.parameters['end'] ??
          Get.parameters['clipEnd'] ??
          (kIsWeb
              ? (Uri.base.queryParameters['end'] ??
                  Uri.base.queryParameters['clipEnd'])
              : null);
      final clipTitleParam = Get.parameters['clipTitle'] ??
          Get.parameters['title'] ??
          (kIsWeb
              ? (Uri.base.queryParameters['clipTitle'] ??
                  Uri.base.queryParameters['title'])
              : null);
      if (startStr != null && endStr != null) {
        final start = double.tryParse(startStr);
        final end = double.tryParse(endStr);
        if (start != null && end != null && end > start) {
          activeClip.value = VideoClip(
            id: Get.parameters['clipId'] ??
                (kIsWeb ? Uri.base.queryParameters['clipId'] : null) ??
                'temp_${DateTime.now().millisecondsSinceEpoch}',
            videoId: video.id,
            userId: '',
            title: clipTitleParam != null
                ? Uri.decodeComponent(clipTitleParam)
                : '${video.title} Clip',
            startTime: start,
            endTime: end,
            thumbnailUrl: video.thumbnailUrl,
            videoTitle: video.title,
            channelName: video.channelName,
            createdAt: DateTime.now(),
          );
          debugPrint(
            '[VideoController] 🎬 Starting in Clip Mode via URL parameters: ${activeClip.value?.title}',
          );
        }
      }
    }

    if (activeClip.value != null && initialSeekPosition == null) {
      initialSeekPosition = Duration(
        milliseconds: (activeClip.value!.startTime * 1000).toInt(),
      );
    }

    if (initialSeekPosition == null && VideoPlaybackHandoff.hasActivePosition(video.id)) {
      initialSeekPosition = VideoPlaybackHandoff.peekPosition(video.id);
    }
    if (VideoPlaybackHandoff.isActive(video.id) || args?['isFromMiniplayer'] == true) {
      rxIsLoading.value = false;
      showThumbnail.value = false;
    }
    startPlaybackFlow();
    Future.microtask(_initializeAllMetadata);
  }

  void initLoadedVideo(Map<String, dynamic>? args) => _initLoadedVideo(args);

  void _initializeAllMetadata() {
    final connectivity = Get.find<ConnectivityService>();
    final hasInternet = connectivity.isConnected;
    trafficSource = detectTrafficSource();
    resolveViewerIdentity();
    final tag = 'video_${video.id}';
    if (!Get.isRegistered<CommentsController>(tag: tag)) {
      commentsController = Get.put(
        CommentsController(video: video, isOffline: !hasInternet),
        tag: tag,
      );
    } else {
      final comments = Get.find<CommentsController>(tag: tag);
      if (hasInternet && comments.isOffline) {
        comments.enableOnlineMode();
      }
    }
    if (!Get.isRegistered<ChannelController>(tag: video.id)) {
      channelController = Get.put(ChannelController(), tag: video.id);
    } else {
      channelController = Get.find<ChannelController>(tag: video.id);
    }

    if (rxIsOffline.value) {
      rxIsLoading.value = false;
      return;
    }

    if (hasInternet) {
      final mediaService = VideoMediaService();
      Future.wait([
        mediaService.getLocalization(video.id),
        mediaService.getCredibility(video.id),
        mediaService.getStreaming(video.id),
      ]).then((_) {
        rxVideo.refresh();
      });

      channelController.listenSubscription(video.channelId);
      if (isAuthenticated) {
        checkUserInteractions();
      }
      fetchRecommendations();
      fetchPlaylistForVideo();
      _initializeCommentsController();
      _listenToVideoUpdates();
      listenToLanguageRequests();
    }
  }

  void initializeAllMetadata() => _initializeAllMetadata();
}
