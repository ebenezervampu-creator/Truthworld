import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/analytics/data/services/viewer_identity_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/data/repositories/firestore_video_repository.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/domain/database_helpers.dart';
import 'package:truthworld/features/video/domain/repositories/video_repository.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_birate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_analytics_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_engagement_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playlist_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart'
    hide LanguageRequest;
import 'package:truthworld/features/video/presentation/views/player/tower_custom_player.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check_report_widget.dart';
import 'package:truthworld/services/video_hydration_service.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

class VideoController extends BaseController with GetTickerProviderStateMixin {
  VideoController({VideoRepository? videoRepository})
      : _videoRepository = videoRepository ?? FirestoreVideoRepository();

  final VideoRepository _videoRepository;

  Future<void> fetchVideoById(String id) async {
    final result = await _videoRepository.getVideoById(id);
    result.when(
      success: (data) => _video.value = data,
      failure: (err) => setError(err.displayMessage),
    );
  }

  final Rx<Video> _video = Video.empty().obs;
  Video get video => _video.value;
  Rx<Video> get rxVideo => _video;

  late VideoEngagementController engagementController;
  late VideoAnalyticsController analyticsController;

  int get likeCount => mainController.videoLikes[video.id] ?? video.likeCount;
  int get dislikeCount =>
      mainController.videoDislikes[video.id] ?? video.dislikeCount;

  void reloadRecommendationsForFlip() {
    fetchRecommendations();
  }

  RxList<LanguageRequest> get languageRequests =>
      engagementController.languageRequests;
  RxBool get isLoadingLanguageRequests =>
      engagementController.isLoadingLanguageRequests;
  StreamSubscription<QuerySnapshot>? _languageRequestsSubscription;

  late VideoPlaylistController videoPlaylistController;

  // Playlist Support (Delegated)
  Rx<PlaylistModel?> get currentPlaylist => videoPlaylistController.currentPlaylist;
  RxList<Video> get playlistVideos => videoPlaylistController.playlistVideos;
  RxInt get currentPlaylistIndex => videoPlaylistController.currentPlaylistIndex;
  RxBool get isPlaylistLooping => videoPlaylistController.isPlaylistLooping;
  RxBool get isPlaylistShuffled => videoPlaylistController.isPlaylistShuffled;
  RxBool get showPlaylistDrawer => videoPlaylistController.showPlaylistDrawer;

  // Computed: Check if previous/next video is available
  // First check playlist, then check recommendations
  bool get hasPreviousVideo =>
      (playlistVideos.isNotEmpty && currentPlaylistIndex.value > 0) ||
      recommendedVideos.indexWhere((v) => v.id == video.id) > 0;
  bool get hasNextVideo =>
      (playlistVideos.isNotEmpty &&
          currentPlaylistIndex.value < playlistVideos.length - 1) ||
      (recommendedVideos.indexWhere((v) => v.id == video.id) <
              recommendedVideos.length - 1 &&
          recommendedVideos.isNotEmpty);

  // Clips Support
  final Rx<VideoClip?> activeClip = Rx<VideoClip?>(null);
  Duration? _initialSeekPosition;

  // State variables
  final RxBool isDownloading = false.obs;
  final RxDouble downloadProgress = 0.0.obs;
  RxBool get isSubscribed => engagementController.isSubscribed;
  RxBool get isLiked => engagementController.isLiked;
  RxBool get isDisliked => engagementController.isDisliked;
  final RxBool isExpanded = false.obs;
  final RxBool isTranscriptVisible = false.obs;
  final RxList<SubtitleSegment> transcriptSegments = <SubtitleSegment>[].obs;
  final RxBool isLoadingTranscript = false.obs;
  final RxBool isSummaryVisible = false.obs;
  final RxString moderationSummary = ''.obs;
  final RxBool isLoadingSummary = false.obs;
  final RxBool rxIsLoading = true.obs;
  RxBool get isLoadingRx => rxIsLoading;
  @override
  bool get isLoading => rxIsLoading.value || super.isLoading;

  final RxBool videoError = false.obs;
  final RxBool showThumbnail = true.obs;
  final RxBool isAutoplay = true.obs;
  final RxBool isPlayingRx = false.obs;
  final RxBool navigatedFromPlaylist = false.obs;
  final RxBool navigatedFromTopic = false.obs;
  RxBool get isAutoplayEnabled => isAutoplay; // Alias for UI consistency

  final RxString rxErrorMessage = ''.obs;
  RxString get errorMessageRx => rxErrorMessage;
  @override
  String get errorMessage => rxErrorMessage.value.isNotEmpty
      ? rxErrorMessage.value
      : super.errorMessage;

  final RxInt selectedIndex = 0.obs;
  final RxBool isFullScreen = false.obs;
  final RxInt mobileTabIndex = 0.obs;
  final RxInt desktopTabIndex = 0.obs;
  final RxBool isActivePage = true.obs;

  // Quality & Resolutions
  final RxList<VideoResolutionV2> availableResolutions =
      <VideoResolutionV2>[].obs;
  final Rx<VideoResolutionV2?> currentResolution = Rx<VideoResolutionV2?>(null);
  final RxList<SubtitleTrack> availableSubtitles = <SubtitleTrack>[].obs;
  final RxList<AudioTrack> availableAudioTracks = <AudioTrack>[].obs;
  final RxBool isAudioOnly = false.obs;

  // Analytics & View Tracking
  final Stopwatch _watchStopwatch = Stopwatch();
  bool _hasCountedQualifiedView = false;
  int _lastReportedWatchTime = 0;
  int _lastPingWatchSeconds = 0;
  final RxBool isSwitchingResolution = false.obs;
  final RxBool isAutoSwitching = false.obs;

  final RxBool rxIsOffline = false.obs;
  RxBool get isOfflineRx => rxIsOffline;
  @override
  bool get isOffline => rxIsOffline.value || super.isOffline;
  String? _offlineBlobUrl;
  StreamSubscription? _connectivitySubscription;

  // Milestone tracking — only fire each milestone once per session
  final Set<String> _firedMilestones = {};
  static const _milestoneThresholds = [25, 50, 75, 100];
  static const int _watchPingIntervalSeconds = 20; // Cost-effective heartbeat interval
  static const int _watchHistoryIntervalSeconds = 15; // Periodic history sync interval

  // Traffic source for this viewing session
  String _trafficSource = 'direct';

  // Viewer identity (for anonymous dedup)
  String _viewerHash = '';

  // Total watch time for this session (seconds)
  int get watchTimeSeconds => analyticsController.watchTimeSeconds;

  // Recommendations Cache
  final RxList<Video> recommendedVideos = <Video>[].obs;
  final RxList<CommunityPostModel> communityPosts = <CommunityPostModel>[].obs;
  final RxList<Video> moreFromChannel = <Video>[].obs;
  final RxBool isLoadingRecommendations = true.obs;
  final RxString selectedRecommendationFilter = 'All'.obs;
  final RxInt recommendationActiveTab = 0.obs;

  List<dynamic> get recommendedItems {
    final displayVideos = filteredRecommendedVideos;
    final isFlipped = (selectedRecommendationFilter.value == 'Flip Coin') ||
        (Get.isRegistered<FlipCoinService>() &&
            Get.find<FlipCoinService>().isVideoFlipped(video.id));
    if (isFlipped) {
      return List<dynamic>.from(displayVideos);
    }

    final mixed = <dynamic>[];
    var videoIndex = 0;
    var postIndex = 0;
    var topicIndex = 0;

    while (videoIndex < displayVideos.length ||
        postIndex < communityPosts.length ||
        topicIndex < videoTopicsList.length) {
      for (var i = 0; i < 3 && videoIndex < displayVideos.length; i++) {
        mixed.add(displayVideos[videoIndex++]);
      }
      if (topicIndex < videoTopicsList.length) {
        mixed.add(videoTopicsList[topicIndex++]);
      }
      if (postIndex < communityPosts.length) {
        mixed.add(communityPosts[postIndex++]);
      }
    }
    return mixed;
  }

  // Topics and Playlists recommendation tabs state
  final RxList<Topic> videoTopicsList = <Topic>[].obs;
  final RxList<PlaylistModel> videoPlaylistsList = <PlaylistModel>[].obs;
  final RxMap<String, List<Video>> topicVideosCache =
      <String, List<Video>>{}.obs;
  final RxMap<String, List<Video>> playlistVideosCache =
      <String, List<Video>>{}.obs;

  List<String> get recommendationFilters {
    final list = ['All', 'Flip Coin'];

    // 1. Topics tab (ONLY if navigated from Topics page)
    if (navigatedFromTopic.value) {
      for (final topic in videoTopicsList) {
        final name = 'Topic: ${topic.title}';
        if (!list.contains(name) && !list.contains(topic.title)) {
          list.add(name);
        }
      }
    }

    // 2. Channel tab
    if (video.channelName.isNotEmpty) {
      list.add('From ${video.channelName}');
    }

    // 3. Tags / Category
    if (video.tags.isNotEmpty) {
      for (final t in video.tags.take(3)) {
        if (!list.contains(t)) list.add(t);
      }
    } else if (video.category.isNotEmpty && !list.contains(video.category)) {
      list.add(video.category);
    }

    return list;
  }

  List<Video> get filteredRecommendedVideos {
    final filter = selectedRecommendationFilter.value;
    if (filter == 'All' || filter == 'Flip Coin') {
      return recommendedVideos;
    }

    // Check if filter is a Playlist tab
    if (filter.startsWith('Playlist: ')) {
      final plName = filter.replaceFirst('Playlist: ', '');
      if (currentPlaylist.value != null &&
          currentPlaylist.value!.playlistName == plName) {
        if (playlistVideos.isNotEmpty) return playlistVideos;
      }
      final matchedPlaylist = videoPlaylistsList.firstWhereOrNull(
        (p) => p.playlistName == plName,
      );
      if (matchedPlaylist != null) {
        return playlistVideosCache[matchedPlaylist.id] ?? [];
      }
    }

    final matchedPlaylistDirect = videoPlaylistsList.firstWhereOrNull(
      (p) => p.playlistName == filter,
    );
    if (matchedPlaylistDirect != null) {
      return playlistVideosCache[matchedPlaylistDirect.id] ?? [];
    }

    // Check if filter is a Topic tab
    if (filter.startsWith('Topic: ')) {
      final topicTitle = filter.replaceFirst('Topic: ', '');
      final matchedTopic = videoTopicsList.firstWhereOrNull(
        (t) => t.title == topicTitle,
      );
      if (matchedTopic != null) {
        return topicVideosCache[matchedTopic.id] ?? [];
      }
    }

    final matchedTopicDirect = videoTopicsList.firstWhereOrNull(
      (t) => t.title == filter,
    );
    if (matchedTopicDirect != null) {
      return topicVideosCache[matchedTopicDirect.id] ?? [];
    }

    if (filter == 'From ${video.channelName}') {
      return moreFromChannel;
    }

    final filterLower = filter.toLowerCase();
    return recommendedVideos.where((v) {
      final titleLower = v.title.toLowerCase();
      final descLower = v.description.toLowerCase();
      final tagMatch = v.tags.any((t) => t.toLowerCase() == filterLower);
      final categoryMatch = v.category.toLowerCase() == filterLower;
      return titleLower.contains(filterLower) ||
          descLower.contains(filterLower) ||
          tagMatch ||
          categoryMatch;
    }).toList();
  }

  // Controllers
  late TabController mobileTabController;
  late TabController desktopTabController;
  final ScrollController scrollController = ScrollController();
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  late ChannelController channelController;
  MainController get mainController => Get.isRegistered<MainController>()
      ? Get.find<MainController>()
      : Get.put(MainController(), permanent: true);
  PlaylistController get playlistController =>
      Get.isRegistered<PlaylistController>()
      ? Get.find<PlaylistController>()
      : Get.put(PlaylistController());
  late CommentsController commentsController;
  StreamSubscription<DocumentSnapshot>? _videoSubscription;

  bool get isAuthenticated => AuthService.to.isAuthenticated.value;
  String get userPhotoUrl => AuthService.to.activePhotoUrl;

  int get calculatedPlaylistIndex {
    if (playlistVideos.isNotEmpty) {
      final idx = playlistVideos.indexWhere((v) => v.id == video.id);
      if (idx != -1) return idx;
    }
    if (currentPlaylist.value != null &&
        currentPlaylist.value!.videoIds.isNotEmpty) {
      final idx = currentPlaylist.value!.videoIds.indexOf(video.id);
      if (idx != -1) return idx;
    }
    return currentPlaylistIndex.value;
  }

  @override
  void onInit() {
    super.onInit();
    videoPlaylistController = Get.isRegistered<VideoPlaylistController>()
        ? Get.find<VideoPlaylistController>()
        : Get.put(VideoPlaylistController());

    rxIsOffline.value = (Get.arguments?['isOffline'] as bool?) ?? false;
    if (Get.arguments?['isAudioOnly'] == true) {
      isAudioOnly.value = true;
    }
    _setupConnectivityListener();

    // Initialize tab controllers early to prevent UI paint null exceptions
    mobileTabController = TabController(length: 2, vsync: this);
    desktopTabController = TabController(length: 2, vsync: this);

    mobileTabController.addListener(() {
      if (mobileTabController.index != mobileTabIndex.value) {
        mobileTabIndex.value = mobileTabController.index;
      }
    });

    desktopTabController.addListener(() {
      if (desktopTabController.index != desktopTabIndex.value) {
        desktopTabIndex.value = desktopTabController.index;
      }
    });

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

    // Handle initial seek timestamp from args or query params (t=120, t=1m30s, etc.)
    if (args?['initialPosition'] != null && args!['initialPosition'] is Duration) {
      _initialSeekPosition = args['initialPosition'] as Duration;
    } else {
      final timeStr = Get.parameters['t'] ?? Get.parameters['time'] ?? Get.parameters['start'];
      final parsedTime = DeepLinkService.parseTimestamp(timeStr);
      if (parsedTime != null) {
        _initialSeekPosition = parsedTime;
      }
    }

    // Handle Video argument
    if (args?['video'] != null) {
      final videoArg = args!['video'] as Video;
      _video.value = videoArg;
      DeepLinkService.instance.cacheVideo(videoArg);
      _initLoadedVideo(args);
    } else if (currentPlaylist.value != null &&
        currentPlaylist.value!.videoIds.isNotEmpty) {
      _fetchFirstPlaylistVideo(currentPlaylist.value!.videoIds.first);
      return;
    } else {
      // Direct deep link loading (/watch?v=ID or /watch/ID)
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

    // 0. Check offline storage metadata (0ms instant offline startup)
    try {
      final offlineMeta = await getOfflineVideoMetadata(videoId);
      if (offlineMeta != null) {
        rxIsOffline.value = true;
        if (offlineMeta.isAudioOnly) {
          isAudioOnly.value = true;
        }
        final offlineVideo = Video.fromOffline(offlineMeta);
        _video.value = offlineVideo;
        _initLoadedVideo(args);
        return;
      }
    } catch (_) {}

    // 1. Check in-memory entity cache (0ms instant startup)
    final cached = DeepLinkService.instance.getVideoFromCache(videoId);
    if (cached != null) {
      debugPrint('[VideoController] ⚡ 0ms instant cache hit for video: $videoId');
      _video.value = cached;
      _initLoadedVideo(args);
      return;
    }

    // 2. Check prerendered web hydration
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
        _video.value = hydVideo;
        DeepLinkService.instance.cacheVideo(hydVideo);
        _initLoadedVideo(args);
        return;
      }
    }

    // 3. Fast background fetch with persistence
    try {
      debugPrint('[VideoController] ⏳ Loading deep-linked video from Firestore: $videoId');
      final loadedVideo = await DeepLinkService.instance.loadVideo(videoId);
      if (loadedVideo != null) {
        _video.value = loadedVideo;
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

    // Check if we are playing a specific clip BEFORE starting playback flow
    if (args?['clip'] != null) {
      activeClip.value = args!['clip'] as VideoClip;
      debugPrint(
        '[VideoController] 🎬 Starting in Clip Mode: ${activeClip.value?.title}',
      );
    } else {
      final startStr = Get.parameters['start'] ?? Get.parameters['clipStart'];
      final endStr = Get.parameters['end'] ?? Get.parameters['clipEnd'];
      final clipTitleParam =
          Get.parameters['clipTitle'] ?? Get.parameters['title'];
      if (startStr != null && endStr != null) {
        final start = double.tryParse(startStr);
        final end = double.tryParse(endStr);
        if (start != null && end != null && end > start) {
          activeClip.value = VideoClip(
            id:
                Get.parameters['clipId'] ??
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

    // If we have an active handoff controller from miniplayer, avoid loading states
    if (VideoPlaybackHandoff.isActive(video.id)) {
      rxIsLoading.value = false;
      showThumbnail.value = false;
    }

    // 1. Kick off playback immediately for YouTube-style low-latency startup
    _startPlaybackFlow();

    // 2. Initialize heavy UI metadata asynchronously in background without blocking playback stream
    Future.microtask(_initializeAllMetadata);
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Get.find<ConnectivityService>()
        .onConnectivityChanged
        .listen((results) {
          final isConnected = results.any((r) => r != ConnectivityResult.none);
          if (isConnected) {
            debugPrint(
              '[VideoController] 🌐 Internet restored. Refreshing metadata...',
            );
            _initializeAllMetadata();

            // AUTO-RECOVERY: If the video player is in an error state or stalled, try to recover
            if (videoError.value ||
                (_videoPlayerController != null &&
                    !_videoPlayerController!.value.isInitialized)) {
              debugPrint(
                '[VideoController] 🚀 Attempting playback recovery...',
              );
              attemptRecovery();
            }
          }
        });
  }

  void _initializeAllMetadata() {
    final connectivity = Get.find<ConnectivityService>();
    final hasInternet = connectivity.isConnected;

    // Detect traffic source
    _trafficSource = _detectTrafficSource();

    // Resolve viewer identity
    _resolveViewerIdentity();

    // Initialize child controllers
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

    // Initialize channel controller
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
      // Pre-fetch localization (subtitles, audio), credibility (summary, trust, claims), and streaming (chapters)
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
      _listenToLanguageRequests();
    }
  }

  /// Automatically find if this video is part of a playlist if specified in arguments or navigated from playlist
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
    } catch (_) {}
  }

  /// Detect where the user came from to reach this video.
  /// Uses hierarchical TrafficSourceCategory taxonomy.
  String _detectTrafficSource() {
    final args = Get.arguments as Map<String, dynamic>? ?? {};

    // 1. Explicit source passed via navigation argument (highest priority)
    if (args.containsKey('source')) {
      final source = args['source'] as String? ?? 'direct';
      // Check if it's an external share link (contains referrer info)
      return _normalizeTrafficSource(source);
    }

    // 2. Check for deep link / external referrer
    if (args.containsKey('referrer')) {
      final referrer = args['referrer'] as String? ?? '';
      return _classifyExternalReferrer(referrer);
    }

    // 3. Infer from in-app route
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

  /// Normalize legacy source keys to new taxonomy
  String _normalizeTrafficSource(String source) {
    const mapping = {
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

  /// Classify external referrer URL into specific platform
  String _classifyExternalReferrer(String referrer) {
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

  Future<void> _startPlaybackFlow() async {
    // 0. Check offline storage metadata first for instant 0ms offline playback
    if (!rxIsOffline.value) {
      try {
        final offlineMeta = await getOfflineVideoMetadata(video.id);
        if (offlineMeta != null) {
          rxIsOffline.value = true;
          if (offlineMeta.isAudioOnly) {
            isAudioOnly.value = true;
          }
        }
      } catch (_) {}
    }

    if (rxIsOffline.value) {
      await _initializeOfflinePlayback();
      return;
    }

    final mediaService = VideoMediaService();

    // 1. Kick off metadata loading: fetch localization first so audio tracks cache is populated
    final Future<void> metadataFuture = () async {
      await Future.wait([
        mediaService.getLocalization(video.id),
        mediaService.getCredibility(video.id),
      ]);
      await Future.wait([
        fetchAvailableResolutions(),
        fetchAvailableSubtitles(),
        fetchAvailableAudioTracks(),
      ]);
    }();

    // Check if we have an active handoff controller (from miniplayer or card hover)
    final hasHandoff = VideoPlaybackHandoff.isActive(video.id);
    if (hasHandoff) {
      debugPrint(
        '[VideoController] 🚀 Instant handoff playback from active controller for: ${video.id}',
      );
      rxIsLoading.value = false;
      showThumbnail.value = false;
      await initializeVideoPlayer();

      // Once metadata finishes, update resolutions reactively without re-initializing player
      metadataFuture.then((_) {
        if (availableResolutions.isNotEmpty) {
          final best = availableResolutions.firstWhereOrNull(
            (r) => r.url.isNotEmpty && !r.url.contains('.m3u8'),
          ) ?? availableResolutions.first;
          if (currentResolution.value?.url != best.url) {
            currentResolution.value = best;
          }
        }
      });
      return;
    }

    // 2. YouTube-style playback strategy:
    //    - On native (iOS/Android/Desktop): Use HLS adaptive streaming for instant start
    //    - On web: NEVER use raw original.mp4 — always wait for transcoded MP4 resolutions
    if (!kIsWeb &&
        video.hlsUrl.isNotEmpty &&
        !video.hlsUrl.startsWith('gs://')) {
      // Native: HLS adaptive streaming for instant zero-latency start
      debugPrint('[VideoController] 🎬 Native playback: Using HLS adaptive stream');
      await initializeVideoPlayer(overrideUrl: video.hlsUrl);

      // Once metadata finishes, update the quality/resolution menu reactively
      metadataFuture.then((_) {
        if (availableResolutions.isNotEmpty) {
          final best = availableResolutions.first;
          if (currentResolution.value?.url != best.url) {
            currentResolution.value = best;
          }
        }
      });
    } else {
      // Web: Wait for transcoded resolutions — never serve raw original.mp4
      debugPrint('[VideoController] 🌐 Web playback: Waiting for transcoded resolutions...');
      await metadataFuture;

      if (availableResolutions.isNotEmpty) {
        // Pick the best transcoded MP4 (non-HLS) for web browsers
        final mp4Res = availableResolutions.firstWhereOrNull(
          (r) => r.url.isNotEmpty && !r.url.contains('.m3u8'),
        );
        final best = mp4Res ?? availableResolutions.first;
        currentResolution.value = best;
        debugPrint(
          '[VideoController] ✅ Web: Playing ${best.label} (${best.width}x${best.height})',
        );
        await initializeVideoPlayer(overrideUrl: best.url);
      } else {
        // Last resort: try originalUrl only if no transcoded variants exist
        if (video.originalUrl.isNotEmpty &&
            !video.originalUrl.startsWith('gs://')) {
          debugPrint(
            '[VideoController] ⚠️ No transcoded resolutions. Falling back to originalUrl.',
          );
          await initializeVideoPlayer(overrideUrl: video.originalUrl);
        } else {
          debugPrint(
            '[VideoController] ❌ No playable URL found. Video may still be processing.',
          );
          videoError.value = true;
          rxErrorMessage.value =
              'Video is still processing. Please check back later.';
          rxIsLoading.value = false;
          return;
        }
      }
    }

    // If starting with a clip, seek to start time
    if (activeClip.value != null) {
      _videoPlayerController?.seekTo(
        Duration(milliseconds: (activeClip.value!.startTime * 1000).toInt()),
      );
    }
  }

  Future<void> _initializeOfflinePlayback() async {
    rxIsLoading.value = true;
    try {
      final isAudio = isAudioOnly.value || (Get.arguments?['isAudioOnly'] == true);
      if (isAudio) {
        isAudioOnly.value = true;
      }

      // Sync isAudioOnly with TowerPlayerController
      if (Get.isRegistered<TowerPlayerController>(tag: video.id)) {
        Get.find<TowerPlayerController>(tag: video.id).isAudioOnly.value =
            isAudio;
      } else if (Get.isRegistered<TowerPlayerController>()) {
        Get.find<TowerPlayerController>().isAudioOnly.value = isAudio;
      }

      if (kIsWeb) {
        final bytes = await getVideoBytes(video.id);
        if (bytes == null || bytes.length < 512) {
          throw Exception('Offline media content not found or corrupted');
        }
        // Check for M3U8 text playlist header '#EXTM3U'
        if (bytes.length >= 7 &&
            bytes[0] == 0x23 && // '#'
            bytes[1] == 0x45 && // 'E'
            bytes[2] == 0x58 && // 'X'
            bytes[3] == 0x54 && // 'T'
            bytes[4] == 0x4D && // 'M'
            bytes[5] == 0x33 && // '3'
            bytes[6] == 0x55) { // 'U'
          throw Exception('Downloaded file is an HLS playlist rather than direct media. Please re-download.');
        }

        final mime = isAudio ? 'audio/mpeg' : 'video/mp4';
        final blob = html.Blob([bytes], mime);
        _offlineBlobUrl = html.Url.createObjectUrl(blob);
      } else {
        final filePath = await getVideoFilePath(video.id);
        if (filePath != null && File(filePath).existsSync() && (await File(filePath).length()) > 512) {
          _offlineBlobUrl = filePath;
        } else {
          final bytes = await getVideoBytes(video.id);
          if (bytes == null || bytes.length < 512) {
            throw Exception('Offline media content not found or corrupted');
          }
          final dir = await getOfflineDirectory();
          final ext = isAudio ? 'mp3' : 'mp4';
          final mediaFile = File('${dir.path}/${video.id}.$ext');
          await mediaFile.parent.create(recursive: true);
          await mediaFile.writeAsBytes(bytes);
          _offlineBlobUrl = mediaFile.path;
        }
      }

      // Create a dummy resolution for the UI
      availableResolutions.assignAll([
        VideoResolutionV2(
          label: isAudio ? 'Audio only' : 'Offline',
          url: _offlineBlobUrl!,
          width: 0,
          height: 0,
          bitrate: 0,
        ),
      ]);
      currentResolution.value = availableResolutions.first;

      await initializeVideoPlayer(overrideUrl: _offlineBlobUrl);
    } catch (e) {
      debugPrint('[VideoController] ❌ Offline init error: $e');
      videoError.value = true;
      rxErrorMessage.value = 'Failed to load offline media: $e';
    } finally {
      rxIsLoading.value = false;
    }
  }

  Future<void> fetchAvailableResolutions() async {
    try {
      final docId = video.id;
      debugPrint('[VideoController] 🔍 Fetching resolutions for: $docId');

      final doc = await FirebaseFirestore.instance
          .collection('resolution_jobs')
          .doc(docId)
          .getCacheFirst();

      if (doc.exists) {
        final data = doc.data();
        debugPrint('[VideoController] 📄 Doc data found: ${data != null}');

        if (data != null && data['variants'] != null) {
          final variants = data['variants'] as Map<String, dynamic>;
          debugPrint('[VideoController] 📊 Variants count: ${variants.length}');

          final fetchTasks = <Future<VideoResolutionV2?>>[];
          final foundVariants = <VideoResolutionV2>[];

          for (final entry in variants.entries) {
            final variantData = entry.value as Map<String, dynamic>;
            final status = variantData['status'];
            final label = variantData['label'] ?? entry.key;

            debugPrint('[VideoController] 🛠️ Variant $label status: $status');

            if (status == 'completed') {
              final directDownloadUrl = variantData['downloadUrl'] as String?;
              final outputPath = variantData['outputPath'] as String?;
              
              if (directDownloadUrl != null && directDownloadUrl.isNotEmpty) {
                foundVariants.add(
                  VideoResolutionV2(
                    label: label as String,
                    url: directDownloadUrl,
                    width: (variantData['width'] as num?)?.toInt() ?? 0,
                    height: (variantData['height'] as num?)?.toInt() ?? 0,
                    bitrate: (variantData['bitrateKbps'] as num?)?.toInt() ?? 0,
                  ),
                );
              } else if (outputPath != null && outputPath.isNotEmpty) {
                fetchTasks.add(() async {
                  try {
                    String url;
                    if (outputPath.startsWith('gs://')) {
                      url = await FirebaseStorage.instance
                          .refFromURL(outputPath)
                          .getDownloadURL();
                    } else {
                      url = await FirebaseStorage.instance
                          .ref(outputPath)
                          .getDownloadURL();
                    }
                    return VideoResolutionV2(
                      label: label as String,
                      url: url,
                      width: (variantData['width'] as num?)?.toInt() ?? 0,
                      height: (variantData['height'] as num?)?.toInt() ?? 0,
                      bitrate: (variantData['bitrateKbps'] as num?)?.toInt() ?? 0,
                    );
                  } catch (e) {
                    debugPrint(
                      '[VideoController] ❌ Failed to get URL for $label: $e',
                    );
                    return null;
                  }
                }());
              }
            }
          }

          if (fetchTasks.isNotEmpty) {
            final results = await Future.wait(fetchTasks);
            foundVariants.addAll(results.whereType<VideoResolutionV2>());
          }

          if (foundVariants.isNotEmpty) {
            // Sort by height descending
            foundVariants.sort((a, b) => b.height.compareTo(a.height));
            availableResolutions.assignAll(foundVariants);

            // Update ABR ladder with real variants
            if (Get.isRegistered<AdaptiveBitrateController>()) {
              final abr = Get.find<AdaptiveBitrateController>();
              final ladder = foundVariants.reversed
                  .map(ResolutionTier.fromVideoResolution)
                  .toList();

              if (ladder.isNotEmpty) {
                abr.resolutionLadder = ladder;
                abr.currentTierIndex.value = (ladder.length / 2).floor();
              }
            }

            debugPrint(
              '[VideoController] ✅ Successfully loaded ${availableResolutions.length} resolutions',
            );
          }
        } else {
          debugPrint('[VideoController] ⚠️ No variants field in document');
        }
      } else {
        debugPrint('[VideoController] ℹ️ No resolution job found for $docId');
      }

      // FALLBACK 1: If no resolutions from resolution_jobs, check video.adaptiveResolutions
      if (availableResolutions.isEmpty && video.adaptiveResolutions.isNotEmpty) {
        final modelResolutions = video.adaptiveResolutions
            .where((r) => r.url.trim().isNotEmpty)
            .toList();
        if (modelResolutions.isNotEmpty) {
          modelResolutions.sort((a, b) => b.height.compareTo(a.height));
          availableResolutions.assignAll(modelResolutions);

          if (Get.isRegistered<AdaptiveBitrateController>()) {
            final abr = Get.find<AdaptiveBitrateController>();
            final ladder = modelResolutions.reversed
                .map(ResolutionTier.fromVideoResolution)
                .toList();
            if (ladder.isNotEmpty) {
              abr.resolutionLadder = ladder;
              abr.currentTierIndex.value = (ladder.length / 2).floor();
            }
          }
          debugPrint(
            '[VideoController] 💡 Loaded ${availableResolutions.length} resolutions from video.adaptiveResolutions',
          );
        }
      }

      // FALLBACK 2: If still empty, fallback to HLS / Original & standard ladder
      if (availableResolutions.isEmpty) {
        debugPrint('[VideoController] 💡 Using model fallback for resolutions');
        final baseMediaUrl = video.originalUrl.isNotEmpty &&
                !video.originalUrl.contains('.m3u8') &&
                !video.originalUrl.contains('.mpd')
            ? video.originalUrl
            : (video.videoUrl.isNotEmpty &&
                    !video.videoUrl.contains('.m3u8') &&
                    !video.videoUrl.contains('.mpd')
                ? video.videoUrl
                : '');

        if (video.hlsUrl.isNotEmpty) {
          availableResolutions.add(
            VideoResolutionV2(
              label: 'Auto',
              url: video.hlsUrl,
              width: 0,
              height: 0,
              bitrate: 0,
            ),
          );
        }

        if (baseMediaUrl.isNotEmpty) {
          availableResolutions.addAll([
            VideoResolutionV2(
              label: '1080p',
              url: baseMediaUrl,
              width: 1920,
              height: 1080,
              bitrate: 4500000,
            ),
            VideoResolutionV2(
              label: '720p',
              url: baseMediaUrl,
              width: 1280,
              height: 720,
              bitrate: 2500000,
            ),
            VideoResolutionV2(
              label: '480p',
              url: baseMediaUrl,
              width: 854,
              height: 480,
              bitrate: 1200000,
            ),
            VideoResolutionV2(
              label: '360p',
              url: baseMediaUrl,
              width: 640,
              height: 360,
              bitrate: 800000,
            ),
            VideoResolutionV2(
              label: '240p',
              url: baseMediaUrl,
              width: 426,
              height: 240,
              bitrate: 400000,
            ),
            VideoResolutionV2(
              label: '144p',
              url: baseMediaUrl,
              width: 256,
              height: 144,
              bitrate: 200000,
            ),
          ]);
        } else if (video.originalUrl.isNotEmpty &&
            !availableResolutions.any((r) => r.label == 'Original')) {
          availableResolutions.add(
            VideoResolutionV2(
              label: 'Original',
              url: video.originalUrl,
              width: 0,
              height: 0,
              bitrate: 0,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[VideoController] 🔥 Error fetching resolutions: $e');
    }
  }

  Future<void> fetchAvailableSubtitles() async {
    try {
      var subs = video.mediaSubtitles;
      if (subs.isEmpty) {
        final loc = await VideoMediaService().getLocalization(video.id);
        subs = loc.subtitles;
      }
      if (subs.isEmpty) {
        debugPrint('[VideoController] ℹ️ No subtitles found in video metadata');
        return;
      }

      final fetchTasks = <Future<SubtitleTrack?>>[];

      for (final entry in subs.entries) {
        final langCode = entry.key;
        final pathOrUrl = entry.value;

        fetchTasks.add(() async {
          try {
            var url = pathOrUrl;
            if (pathOrUrl.startsWith('gs://')) {
              url = await FirebaseStorage.instance
                  .refFromURL(pathOrUrl)
                  .getDownloadURL();
            } else if (pathOrUrl.startsWith('subtitles/')) {
              url = await FirebaseStorage.instance
                  .ref(pathOrUrl)
                  .getDownloadURL();
            }

            // Find language name
            final lang = supportedLanguages.firstWhereOrNull(
              (l) => l.code == langCode,
            );
            final label =
                lang?.name ??
                (langCode.length <= 3 ? langCode.toUpperCase() : langCode);

            return SubtitleTrack(label: label, langCode: langCode, url: url);
          } catch (e) {
            debugPrint(
              '[VideoController] ❌ Failed to get subtitle URL for $langCode: $e',
            );
            return null;
          }
        }());
      }

      final results = await Future.wait(fetchTasks);
      final found = results.whereType<SubtitleTrack>().toList();
      availableSubtitles.assignAll(found);

      debugPrint('[VideoController] ✅ Loaded ${found.length} subtitle tracks');
    } catch (e) {
      debugPrint('[VideoController] 🔥 Error fetching subtitles: $e');
    }
  }

  /// Proactively finds, downloads, and parses the transcript/subtitles for this video
  /// Searches video.mediaSubtitles, VideoMediaService, Firestore root doc, and Firebase Storage probes.
  Future<void> loadTranscriptForVideo() async {
    final playerCtrl = TowerPlayerController.getForTagOrActive(video.id);

    if (transcriptSegments.isNotEmpty && playerCtrl?.subtitleSegments.isNotEmpty == true) {
      return;
    }

    isLoadingTranscript.value = true;
    playerCtrl?.isLoadingSubtitles.value = true;
    try {
      // 1. Check existing availableSubtitles or mediaSubtitles
      var candidateUrl = video.mediaSubtitles['en'] ??
          (video.mediaSubtitles.isNotEmpty ? video.mediaSubtitles.values.first : null) ??
          (video.transcriptionUrl.isNotEmpty ? video.transcriptionUrl : null) ??
          availableSubtitles.firstOrNull?.url;

      // 2. If null, fetch from localization subcollection
      if (candidateUrl == null || candidateUrl.isEmpty) {
        final loc = await VideoMediaService().getLocalization(video.id);
        if (loc.subtitles.isNotEmpty) {
          candidateUrl = loc.subtitles['en'] ?? loc.subtitles.values.first;
        }
      }

      // 3. If still null, check root video document in Firestore
      if (candidateUrl == null || candidateUrl.isEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(video.id)
            .get();
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          final media = data['media'] as Map<String, dynamic>?;
          candidateUrl = (media?['transcriptionUrl'] as String?) ??
              (data['transcriptionUrl'] as String?) ??
              (data['transcriptUrl'] as String?);
          if (candidateUrl == null || candidateUrl.isEmpty) {
            final subs = (media?['subtitles'] ?? data['subtitles']) as Map?;
            if (subs != null && subs.isNotEmpty) {
              candidateUrl = subs['en']?.toString() ?? subs.values.first?.toString();
            }
          }
        }
      }

      // 4. If candidate URL found, fetch and parse
      if (candidateUrl != null && candidateUrl.isNotEmpty) {
        if (playerCtrl != null) {
          await playerCtrl.fetchAndParseSubtitles(candidateUrl);
          if (playerCtrl.subtitleSegments.isNotEmpty) {
            transcriptSegments.assignAll(playerCtrl.subtitleSegments);
            return;
          }
        }
        final segs = await _downloadAndParseTranscript(candidateUrl);
        if (segs.isNotEmpty) {
          transcriptSegments.assignAll(segs);
          playerCtrl?.subtitleSegments.assignAll(segs);
          return;
        }
      }

      // 5. Direct probe into Firebase Storage for pipeline-generated transcripts
      final storage = FirebaseStorage.instance;
      final probePaths = [
        'subtitles/${video.id}/en.vtt',
        'subtitles/${video.id}/en.srt',
        'subtitles/${video.id}/transcript.json',
        'subtitles/${video.id}/transcription.json',
        'transcripts/${video.id}.json',
        'transcripts/${video.id}.vtt',
        'transcripts/${video.id}.srt',
        'videos/${video.id}/transcript.json',
        'videos/${video.id}/transcription.json',
      ];

      for (final p in probePaths) {
        try {
          final data = await storage.ref(p).getData();
          if (data != null && data.isNotEmpty) {
            final content = utf8.decode(data, allowMalformed: true);
            final segs = _parseTranscriptContent(content);
            if (segs.isNotEmpty) {
              transcriptSegments.assignAll(segs);
              playerCtrl?.subtitleSegments.assignAll(segs);
              debugPrint('[VideoController] ✅ Found transcript via storage probe: $p');
              return;
            }
          }
        } catch (_) {
          // Probe not found, continue to next
        }
      }
    } catch (e) {
      debugPrint('[VideoController] 🔥 Error loading transcript: $e');
    } finally {
      isLoadingTranscript.value = false;
      playerCtrl?.isLoadingSubtitles.value = false;
    }
  }

  Future<List<SubtitleSegment>> _downloadAndParseTranscript(String url) async {
    try {
      String? content;
      try {
        final resolvedUrl = StorageUtils.getFastDownloadUrl(url);
        final response = await http.get(Uri.parse(resolvedUrl));
        if (response.statusCode == 200) {
          content = utf8.decode(response.bodyBytes, allowMalformed: true);
        }
      } catch (_) {}

      if (content == null || content.isEmpty) {
        Uint8List? data;
        if (url.startsWith('gs://') ||
            url.startsWith('https://storage.googleapis.com/') ||
            url.startsWith('https://firebasestorage.googleapis.com/')) {
          data = await FirebaseStorage.instance.refFromURL(url).getData();
        } else if (url.startsWith('subtitles/') || url.startsWith('transcripts/') || url.startsWith('videos/')) {
          data = await FirebaseStorage.instance.ref(url).getData();
        }
        if (data != null && data.isNotEmpty) {
          content = utf8.decode(data, allowMalformed: true);
        }
      }

      if (content != null && content.isNotEmpty) {
        return _parseTranscriptContent(content);
      }
    } catch (e) {
      debugPrint('[VideoController] Subtitle download error: $e');
    }
    return [];
  }

  List<SubtitleSegment> _parseTranscriptContent(String content) {
    return SubtitleParser.parse(content);
  }

  /// Fetches the AI Summary from moderation.summary in the video document or credibility cache
  Future<void> fetchSummary() async {
    if (moderationSummary.value.isNotEmpty) return;
    isLoadingSummary.value = true;
    try {
      // 1. Direct check on video.moderationSummary from Video model
      if (video.moderationSummary.isNotEmpty) {
        moderationSummary.value = video.moderationSummary;
        isLoadingSummary.value = false;
        return;
      }

      // 2. Check VideoMediaService credibility cache
      final credibility = await VideoMediaService().getCredibility(video.id);
      if (credibility.summary.isNotEmpty) {
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
        final summary = (mod != null && mod['summary'] != null && (mod['summary'] as String).isNotEmpty)
            ? (mod['summary'] as String)
            : ((data['summary'] as String?)?.isNotEmpty == true
                ? (data['summary'] as String)
                : ((mod != null && mod['explanation'] != null)
                    ? (mod['explanation'] as String)
                    : (data['description'] as String? ?? '')));
        if (summary.isNotEmpty) {
          moderationSummary.value = summary;
        }
      }
    } catch (e) {
      debugPrint('[VideoController] 🔥 Error fetching moderation summary: $e');
    } finally {
      isLoadingSummary.value = false;
    }
  }

  Future<void> fetchAvailableAudioTracks() async {
    try {
      var audioTracksMap = video.audioTracks;
      if (audioTracksMap.isEmpty) {
        final loc = await VideoMediaService().getLocalization(video.id);
        audioTracksMap = loc.audioTracks;
      }
      final dubbedVideosMap = video.dubbedVideos;
      final fetchTasks = <Future<AudioTrack?>>[];

      // Add original track
      fetchTasks.add(
        Future.value(
          AudioTrack(
            label:
                'Original (${supportedLanguages.firstWhereOrNull((l) => l.code == video.language)?.name ?? video.language.toUpperCase()})',
            langCode: video.language,
          ),
        ),
      );

      // Fetch audio tracks
      for (final entry in audioTracksMap.entries) {
        final langCode = entry.key;
        final pathOrUrl = entry.value;

        fetchTasks.add(() async {
          try {
            var url = pathOrUrl;
            if (pathOrUrl.startsWith('gs://')) {
              url = await FirebaseStorage.instance
                  .refFromURL(pathOrUrl)
                  .getDownloadURL();
            }

            final lang = supportedLanguages.firstWhereOrNull(
              (l) => l.code == langCode,
            );
            final label = lang?.name != null
                ? '${lang!.name} (Audio)'
                : '${langCode.toUpperCase()} (Audio)';

            return AudioTrack(
              label: label,
              langCode: langCode,
              type: 'Audio',
              url: url,
            );
          } catch (e) {
            debugPrint(
              '[VideoController] ❌ Failed to get audio track URL for $langCode: $e',
            );
            return null;
          }
        }());
      }

      // Fetch dubbed video tracks
      for (final entry in dubbedVideosMap.entries) {
        final langCode = entry.key;
        final pathOrUrl = entry.value;

        fetchTasks.add(() async {
          try {
            var url = pathOrUrl;
            if (pathOrUrl.startsWith('gs://')) {
              url = await FirebaseStorage.instance
                  .refFromURL(pathOrUrl)
                  .getDownloadURL();
            }

            final lang = supportedLanguages.firstWhereOrNull(
              (l) => l.code == langCode,
            );
            final label = lang?.name != null
                ? '${lang!.name} (Video)'
                : '${langCode.toUpperCase()} (Video)';

            return AudioTrack(
              label: label,
              langCode: langCode,
              type: 'Video',
              url: url,
            );
          } catch (e) {
            debugPrint(
              '[VideoController] ❌ Failed to get dubbed video URL for $langCode: $e',
            );
            return null;
          }
        }());
      }

      final results = await Future.wait(fetchTasks);
      final found = results.whereType<AudioTrack>().toList();
      availableAudioTracks.assignAll(found);

      debugPrint(
        '[VideoController] ✅ Loaded ${found.length} audio/video tracks',
      );
    } catch (e) {
      debugPrint('[VideoController] 🔥 Error fetching audio tracks: $e');
    }
  }

  void _initializeCommentsController() {
    final tag = 'video_${video.id}';
    if (!Get.isRegistered<CommentsController>(tag: tag)) {
      Get.put(
        CommentsController(video: video, isOffline: rxIsOffline.value),
        tag: tag,
      );
    }
  }

  void videoListener() {
    if (_videoPlayerController == null) return;
    final VideoPlayerValue value;
    try {
      value = _videoPlayerController!.value;
    } catch (_) {
      return;
    }

    // --- Clip Looping Logic ---
    if (activeClip.value != null) {
      final currentPos = value.position.inMilliseconds / 1000.0;
      if (currentPos >= activeClip.value!.endTime) {
        _videoPlayerController?.seekTo(
          Duration(milliseconds: (activeClip.value!.startTime * 1000).toInt()),
        );
        return; // Skip rest of listener to avoid conflicting logic
      }
      if (currentPos < activeClip.value!.startTime - 0.5) {
        // If user manually seeks before clip, we might want to allow it or snap back
        // For premium feel, if we are in "Clip Mode", we snap back unless they click "Watch Full"
        _videoPlayerController?.seekTo(
          Duration(milliseconds: (activeClip.value!.startTime * 1000).toInt()),
        );
      }
    }

    // Manage thumbnail overlay & playing state
    if (isPlayingRx.value != value.isPlaying) {
      isPlayingRx.value = value.isPlaying;
    }
    if (value.isPlaying && showThumbnail.value) {
      showThumbnail.value = false;
    }

    // Manage stopwatch based on playback state
    if (value.isPlaying && !value.isBuffering) {
      if (!_watchStopwatch.isRunning) _watchStopwatch.start();
    } else {
      if (_watchStopwatch.isRunning) {
        _watchStopwatch.stop();
        _flushRemainingWatchTime();
      }
    }

    if (!value.isInitialized) return;

    final currentWatchSeconds = _watchStopwatch.elapsed.inSeconds;
    final totalDuration = value.duration.inSeconds;

    // 1. Qualified View: 20s for standard videos, or min(20, duration * 0.8) for short videos (Industry Standard)
    final effectiveWatchThreshold = totalDuration > 0
        ? math.min(20, (totalDuration >= 5 ? (totalDuration * 0.8).round() : totalDuration))
        : 20;

    if (!_hasCountedQualifiedView &&
        currentWatchSeconds >= effectiveWatchThreshold &&
        effectiveWatchThreshold > 0) {
      if (_canCountQualifiedView()) {
        _hasCountedQualifiedView = true;
        mainController.incrementViews(
          videoId: video.id,
          channelId: video.channelId,
          userId: _viewerHash.isNotEmpty
              ? _viewerHash
              : (AuthService.to.uid.isNotEmpty
                    ? AuthService.to.uid
                    : 'anonymous'),
          isQualified: true,
        );

        // Fire qualified_view milestone event
        _fireMilestoneEvent(
          'qualified_view',
          currentWatchSeconds,
          totalDuration,
        );
        _markQualifiedViewTimestamp();

        debugPrint(
          '[VideoController] ✅ Qualified view counted at $currentWatchSeconds s (threshold: $effectiveWatchThreshold s)',
        );
      }
    }

    // 2. Completion milestones (25%, 50%, 75%, 100%) — fire once each
    if (totalDuration > 0) {
      final currentPct = (currentWatchSeconds / totalDuration) * 100;
      for (final threshold in _milestoneThresholds) {
        final key = 'milestone_$threshold';
        if (currentPct >= threshold && !_firedMilestones.contains(key)) {
          _firedMilestones.add(key);
          _fireMilestoneEvent(key, currentWatchSeconds, totalDuration);
          debugPrint('[VideoController] 📊 Milestone $threshold% reached');
        }
      }
    }

    // 3. Cost-Effective Watch Time Heartbeat (every 20s) with auto-flush on pause/exit
    final unpingedSeconds = currentWatchSeconds - _lastPingWatchSeconds;
    if (unpingedSeconds >= _watchPingIntervalSeconds) {
      _pingWatchEvent('watch_ping', currentWatchSeconds, totalDuration, unpingedSeconds);
      _lastPingWatchSeconds = currentWatchSeconds;
    }

    // 4. Update watch history periodically (every 15s - optimized for resume)
    if (currentWatchSeconds - _lastReportedWatchTime >= _watchHistoryIntervalSeconds) {
      _syncWatchHistory(currentWatchSeconds, totalDuration);
      _lastReportedWatchTime = currentWatchSeconds;
    }

    // 5. Handle video completion for loop and autoplay next
    _handleVideoCompletion(value);
  }

  /// Flush uncommitted watch time seconds to server on pause or exit
  void _flushRemainingWatchTime() {
    final currentWatchSeconds = _watchStopwatch.elapsed.inSeconds;
    final delta = currentWatchSeconds - _lastPingWatchSeconds;
    if (delta > 0 && isVpcInitialized) {
      final totalDuration = _videoPlayerController!.value.duration.inSeconds;
      _lastPingWatchSeconds = currentWatchSeconds;
      _pingWatchEvent('watch_ping', currentWatchSeconds, totalDuration, delta);
    }
  }

  /// Ping watch time delta to backend
  Future<void> _pingWatchEvent(
    String eventType,
    int position,
    int duration,
    int deltaSeconds,
  ) async {
    if (deltaSeconds <= 0 && eventType == 'watch_ping') return;
    final isSub = isSubscribed.value;

    mainController.trackWatchEvent(
      videoId: video.id,
      channelId: video.channelId,
      eventType: eventType,
      position: position,
      duration: duration,
      watchTimeSecondsDelta: deltaSeconds,
      isSubscriber: isSub,
      isNotSubscriber: !isSub,
      trafficSource: _trafficSource,
      viewerHash: _viewerHash.isNotEmpty ? _viewerHash : null,
    );
  }

  /// Check 24h cooldown: 1 qualified view per user/device per video per 24h
  bool _canCountQualifiedView() {
    try {
      final storage = GetStorage();
      final identifier = AuthService.to.uid.isNotEmpty
          ? AuthService.to.uid
          : (_viewerHash.isNotEmpty ? _viewerHash : 'device');
      final key = 'qv_${video.id}_$identifier';
      final lastTimestamp = storage.read<int>(key);
      if (lastTimestamp == null) return true;
      final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
      return DateTime.now().difference(lastTime).inHours >= 24;
    } catch (e) {
      return true; // Allow on error
    }
  }

  /// Record qualified view timestamp for 24h cooldown
  void _markQualifiedViewTimestamp() {
    try {
      final storage = GetStorage();
      final identifier = AuthService.to.uid.isNotEmpty
          ? AuthService.to.uid
          : (_viewerHash.isNotEmpty ? _viewerHash : 'device');
      final key = 'qv_${video.id}_$identifier';
      storage.write(key, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[VideoController] Error writing view timestamp: $e');
    }
  }

  /// Fire a milestone event to Cloud Function
  Future<void> _fireMilestoneEvent(
    String eventType,
    int position,
    int duration,
  ) async {
    final isSub = isSubscribed.value;

    // Generate dedup key for qualified_view events
    String? dedupKey;
    if (eventType == 'qualified_view' && _viewerHash.isNotEmpty) {
      try {
        final identityService = Get.find<ViewerIdentityService>();
        dedupKey = await identityService.generateDedupKey(video.id);
      } catch (_) {}
    }

    final delta = position - _lastPingWatchSeconds;
    if (delta > 0) {
      _lastPingWatchSeconds = position;
    }

    mainController.trackWatchEvent(
      videoId: video.id,
      channelId: video.channelId,
      eventType: eventType,
      position: position,
      duration: duration,
      watchTimeSecondsDelta: delta > 0 ? delta : 0,
      isSubscriber: isSub,
      isNotSubscriber: !isSub,
      trafficSource: _trafficSource,
      viewerHash: _viewerHash.isNotEmpty ? _viewerHash : null,
      dedupKey: dedupKey,
    );
  }

  /// Resolve viewer identity asynchronously
  Future<void> _resolveViewerIdentity() async {
    try {
      final identityService = Get.find<ViewerIdentityService>();
      _viewerHash = await identityService.getViewerIdentity();
    } catch (e) {
      debugPrint('[VideoController] Could not resolve viewer identity: $e');
      _viewerHash = AuthService.to.uid.isNotEmpty ? AuthService.to.uid : '';
    }
  }

  bool _hasHandledCompletion = false;

  void _handleVideoCompletion(VideoPlayerValue value) {
    if (!value.isInitialized || value.duration == Duration.zero) return;

    // Check if video has reached the end (within 500ms of duration)
    final isAtEnd =
        value.position >= value.duration - const Duration(milliseconds: 500);

    if (isAtEnd && value.isPlaying) {
      if (_hasHandledCompletion) return; // Prevent multiple triggers
      _hasHandledCompletion = true;

      // Use a post-frame callback to handle the logic
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processVideoCompletion();
      });
    } else if (!isAtEnd) {
      // Reset flag when video is seeked away from end
      _hasHandledCompletion = false;
    }
  }

  void _processVideoCompletion() {
    final towerPlayerController =
        Get.isRegistered<TowerPlayerController>(tag: video.id)
        ? Get.find<TowerPlayerController>(tag: video.id)
        : null;

    final shouldLoop = towerPlayerController?.isLooping.value ?? false;
    final shouldAutoplayNext =
        towerPlayerController?.isAutoplay.value ?? isAutoplay.value;

    // Track completion via watch history & flush final watch seconds
    final totalDuration = _videoPlayerController?.value.duration.inSeconds ?? 0;
    _flushRemainingWatchTime();
    _syncWatchHistory(_watchStopwatch.elapsed.inSeconds, totalDuration);

    if (shouldLoop) {
      // Loop the current video
      debugPrint('[VideoController] Looping video: ${video.id}');
      _videoPlayerController?.seekTo(Duration.zero);
      _videoPlayerController?.play();
      _hasHandledCompletion = false; // Reset for next loop
    } else if (playlistVideos.isNotEmpty) {
      // Autoplay next video in the playlist
      playNextVideo();
    } else if (shouldAutoplayNext) {
      // Autoplay next video from recommendations
      _autoplayNextVideo();
    }
  }

  void _autoplayNextVideo() {
    if (recommendedVideos.isEmpty) {
      debugPrint('[VideoController] No recommended videos for autoplay');
      return;
    }

    // Find the next video (not the current one)
    final nextVideo = recommendedVideos.firstWhere(
      (v) => v.id != video.id,
      orElse: () => recommendedVideos.first,
    );

    if (nextVideo.id == video.id) {
      debugPrint('[VideoController] No different video found for autoplay');
      return;
    }

    debugPrint('[VideoController] Autoplaying next video: ${nextVideo.id}');

    // Navigate to next video
    Get.offNamed(
      '/watch?v=${nextVideo.id}',
      arguments: {
        'video': nextVideo,
        'playlist': currentPlaylist.value,
      },
    );
  }

  void playNext() {
    // If in a playlist, use playlist navigation
    if (playlistVideos.isNotEmpty &&
        currentPlaylistIndex.value < playlistVideos.length - 1) {
      playNextVideo();
      return;
    }
    // Otherwise use recommendations
    _autoplayNextVideo();
  }

  void playPrevious() {
    // If in a playlist, use playlist navigation
    if (playlistVideos.isNotEmpty && currentPlaylistIndex.value > 0) {
      videoPlaylistController.playPreviousPlaylistVideo();
      return;
    }

    // Otherwise use recommendations
    if (recommendedVideos.isEmpty) return;

    // Find current video index in recommendations
    final currentIndex = recommendedVideos.indexWhere((v) => v.id == video.id);
    Video? prevVideo;
    if (currentIndex > 0) {
      // Navigate to previous recommendation
      prevVideo = recommendedVideos[currentIndex - 1];
    } else if (currentIndex == -1 && recommendedVideos.isNotEmpty) {
      // Current video not in recommendations, just go to first
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
    isAudioOnly.value = !isAudioOnly.value;
    debugPrint('[VideoController] Audio only mode: ${isAudioOnly.value}');
  }

  void clearActiveClip() {
    activeClip.value = null;
    debugPrint('[VideoController] 🔓 Clip mode disabled. Playing full video.');
  }

  void applyClipIfPresent(Map<String, dynamic>? args) {
    if (args != null && args['clip'] is VideoClip) {
      final clip = args['clip'] as VideoClip;
      if (activeClip.value?.id != clip.id) {
        activeClip.value = clip;
        debugPrint('[VideoController] 🎬 Applied Clip Mode: ${clip.title}');
        if (_videoPlayerController != null &&
            _videoPlayerController!.value.isInitialized) {
          final startMs = (clip.startTime * 1000).toInt();
          _videoPlayerController!.seekTo(Duration(milliseconds: startMs));
          _videoPlayerController!.play();
        }
      }
    }
  }

  /// Sync watch history to Firestore (merge-upsert per user per video)
  Future<void> _syncWatchHistory(
    int currentWatchSeconds,
    int totalDuration,
  ) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) return;

    // Check if watch history is paused
    try {
      final storage = GetStorage();
      final isPaused = storage.read<bool>('watch_history_paused') ?? false;
      if (isPaused) {
        debugPrint('[VideoController] Watch history sync skipped (Paused)');
        return;
      }
    } catch (e) {
      debugPrint('[VideoController] Error checking history pause state: $e');
    }

    try {
      final percentage = totalDuration > 0
          ? ((currentWatchSeconds / totalDuration) * 100).clamp(0, 100)
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
                : totalDuration * 1000,
            'views': video.views,
            'likeCount': video.likeCount,
            'category': video.category,
            'tags': video.tags,
            'description': video.description,
            'videoUrl': video.originalUrl,
            'ownerId': video.ownerId,
            'watchedAt': FieldValue.serverTimestamp(),
            'watchedDuration': currentWatchSeconds,
            'watchPercentage': percentage,
            'lastPosition':
                _videoPlayerController?.value.position.inSeconds ?? 0,
            'videoDuration': totalDuration,
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[VideoController] Watch history sync error: $e');
    }
  }

  Future<void> checkUserInteractions() async {
    await engagementController.checkUserInteractions(video.id, video.channelId);
  }

  void _listenToVideoUpdates() {
    FirebaseFirestore.instance
        .collection(FirestoreCollections.videos)
        .doc(video.id)
        .get()
        .then((snapshot) {
          if (snapshot.exists) {
            final newData = snapshot.data();
            if (newData != null) {
              // Update the video object in place
              final updatedVideo = Video.fromMap(newData, snapshot.id);

              // Detect if chapters were added
              if (video.chapters.length != updatedVideo.chapters.length) {
                debugPrint(
                  '[VideoController] 📖 Chapters updated: ${updatedVideo.chapters.length} found',
                );
              }

              _video.value = updatedVideo;

              // Trigger sync in player if it exists
              if (Get.isRegistered<TowerPlayerController>(tag: video.id)) {
                // The player controller calls _syncTracksWithVideoController()
                // automatically on every VPC update, but we can trigger it manually here
                // to ensure immediate UI feedback even if video is paused.
                Get.find<TowerPlayerController>(tag: video.id).update();
              }
            }
          }
        })
        .catchError((e) {
          debugPrint('[VideoController] Error fetching video updates: $e');
        });
  }

  void _listenToLanguageRequests() {
    engagementController.fetchLanguageRequests(video.id);
  }

  Future<void> submitLanguageRequest({
    required String language,
    required String type,
  }) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to request a language.',
      );
      return;
    }

    try {
      final docId = '${video.id}_${type}_${language.replaceAll(' ', '_')}';
      final ref = FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('language_requests')
          .doc(docId);

      final docSnap = await ref.get();
      var requesters = <dynamic>[];
      if (docSnap.exists) {
        requesters = docSnap.data()?['requesters'] as List<dynamic>? ?? [];
      }

      if (requesters.contains(userId)) {
        Get.snackbar(
          'Already Requested',
          'You have already requested this language.',
        );
        return;
      }

      requesters.add(userId);

      await ref.set({
        'language': language,
        'type': type,
        'count': requesters.length,
        'requesters': requesters,
        'createdAt': (docSnap.exists && docSnap.data() != null)
            ? docSnap.data()!['createdAt']
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update local state reactively
      _listenToLanguageRequests();

      Get.snackbar('Success', 'Language request submitted!');
    } catch (e) {
      debugPrint('Error submitting language request: $e');
      Get.snackbar('Error', 'Failed to submit language request: $e');
    }
  }

  Future<bool> requestLanguage(String language, String type) async {
    try {
      await submitLanguageRequest(language: language, type: type);
      return true;
    } catch (_) {
      return false;
    }
  }

  List<VideoChapter> getDisplayChapters() {
    return video.chapters;
  }

  // Truth Index & Fact Checking
  final RxMap<String, dynamic> factCheckData = <String, dynamic>{}.obs;
  final RxBool isLoadingFactCheck = false.obs;

  Future<void> loadFactCheckData([String? overrideUrl]) async {
    final rawUrl = (overrideUrl != null && overrideUrl.isNotEmpty)
        ? overrideUrl
        : video.factCheckUrl;
    if (rawUrl.isEmpty) {
      factCheckData.clear();
      return;
    }

    isLoadingFactCheck.value = true;
    try {
      var url = rawUrl;
      if (url.startsWith('gs://')) {
        url = await FirebaseStorage.instance.refFromURL(url).getDownloadURL();
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        factCheckData.value = jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load fact-check data');
      }
    } catch (e) {
      debugPrint('[VideoController] ❌ Error loading fact check: $e');
      factCheckData.clear();
    } finally {
      isLoadingFactCheck.value = false;
    }
  }

  Future<void> fetchFullDisclosure() async {
    if (video.factCheckUrl.isEmpty) {
      Get.snackbar(
        'Disclosure Unavailable',
        'Detailed fact-checking data is not available for this video.',
        backgroundColor: AppColors.bgPage,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    isLoadingFactCheck.value = true;
    try {
      var url = video.factCheckUrl;
      if (url.startsWith('gs://')) {
        url = await FirebaseStorage.instance.refFromURL(url).getDownloadURL();
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        factCheckData.value = jsonDecode(response.body) as Map<String, dynamic>;
        _showFullDisclosurePanel();
      } else {
        throw Exception('Failed to load fact-check data');
      }
    } catch (e) {
      debugPrint('[VideoController] ❌ Error fetching fact check: $e');
      Get.snackbar(
        'Error',
        'Could not load fact-checking report.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    } finally {
      isLoadingFactCheck.value = false;
    }
  }

  void _showFullDisclosurePanel() {
    Get.bottomSheet(
      FactCheckReportWidget(
        data: Map<String, dynamic>.from(factCheckData),
        video: video,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Future<void> fetchRecommendations() async {
    selectedRecommendationFilter.value = 'All';
    isLoadingRecommendations.value = true;
    try {
      final videoId = video.id;

      // 1. If we are in a playlist, fetch other videos from the playlist
      var hasPlaylistVideos = false;
      if (currentPlaylist.value != null) {
        final playlistVideoIds = currentPlaylist.value!.videoIds
            .where((id) => id != videoId)
            .take(15)
            .toList();

        if (playlistVideoIds.isNotEmpty) {
          final playlistVideos = <Video>[];
          for (var i = 0; i < playlistVideoIds.length; i += 10) {
            final chunk = playlistVideoIds.sublist(
              i,
              i + 10 > playlistVideoIds.length
                  ? playlistVideoIds.length
                  : i + 10,
            );
            final playlistVidsQuery = await FirebaseFirestore.instance
                .collection(FirestoreCollections.videos)
                .where(FieldPath.documentId, whereIn: chunk)
                .get();

            playlistVideos.addAll(
              playlistVidsQuery.docs.map(Video.fromDocumentSnapshot),
            );
          }

          // Sort them to match playlist order if possible
          playlistVideos.sort((a, b) {
            final indexA = currentPlaylist.value!.videoIds.indexOf(a.id);
            final indexB = currentPlaylist.value!.videoIds.indexOf(b.id);
            return indexA.compareTo(indexB);
          });

          recommendedVideos.value = playlistVideos;
          moreFromChannel.value =
              playlistVideos; // In playlist mode, they are the same
          hasPlaylistVideos = true;
        }
      }

      if (!hasPlaylistVideos) {
        final isFlipped = (selectedRecommendationFilter.value == 'Flip Coin') ||
            (Get.isRegistered<FlipCoinService>() &&
                Get.find<FlipCoinService>().isVideoFlipped(video.id));

        if (isFlipped) {
          final candidateList = <Video>[];

          // 1. If video has an explicit paired counter-video (Coin Battle pair), fetch it directly!
          if (video.coinBattlePairVideoId != null &&
              video.coinBattlePairVideoId!.isNotEmpty) {
            try {
              final pairDoc = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.videos)
                  .doc(video.coinBattlePairVideoId)
                  .get();
              if (pairDoc.exists && pairDoc.data() != null) {
                candidateList.add(Video.fromDocumentSnapshot(pairDoc));
              }
            } catch (e) {
              debugPrint('Error fetching coin battle pair video: $e');
            }
          }

          // 2. Fetch a broad pool of public candidate videos
          try {
            final candidatesQuery = await FirebaseFirestore.instance
                .collection(FirestoreCollections.videos)
                .where('status', isEqualTo: 'public')
                .where('visibility', isEqualTo: 'public')
                .limit(60)
                .get();

            for (final doc in candidatesQuery.docs) {
              if (doc.id != videoId &&
                  !candidateList.any((v) => v.id == doc.id)) {
                candidateList.add(Video.fromDocumentSnapshot(doc));
              }
            }
          } catch (e) {
            debugPrint(
              'Error querying candidate videos for flip recommendations: $e',
            );
          }

          if (Get.isRegistered<TruthworldAlgorithm>()) {
            final algorithm = Get.find<TruthworldAlgorithm>();
            final ranked = algorithm.rankVideosForCurrentVideoOpposite(
              video,
              candidateList,
            );
            recommendedVideos.value = ranked.map((s) => s.video).toList();
          } else {
            recommendedVideos.value = candidateList;
          }
        } else {
          // Normal recommendations logic
          final channelId = video.channelId;

          // Single efficient fetch for channel videos
          final channelVidsQuery = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: channelId)
              .where(FieldPath.documentId, isNotEqualTo: videoId)
              .limit(10)
              .get();

          final channelVideos = channelVidsQuery.docs
              .map(Video.fromDocumentSnapshot)
              .toList();

          // Fill the rest with general videos
          final generalVidsQuery = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where(FieldPath.documentId, isNotEqualTo: videoId)
              .limit(20)
              .get();

          final generalVideos = generalVidsQuery.docs
              .map(Video.fromDocumentSnapshot)
              .where(
                (v) =>
                    v.id != videoId && !channelVideos.any((cv) => cv.id == v.id),
              )
              .toList();

          moreFromChannel.value = channelVideos;
          final rawRecommended = {...channelVideos, ...generalVideos}.toList();

          if (Get.isRegistered<TruthworldAlgorithm>()) {
            final algorithm = Get.find<TruthworldAlgorithm>();
            final ranked = algorithm.rankVideos(
              rawRecommended,
              RecommendationSurface.videoRelated,
              diversityConfig: DiversityConfig.videoRelated,
            );
            final rankedList = ranked.map((s) => s.video).toList();
            recommendedVideos.value = rankedList.isNotEmpty
                ? rankedList
                : rawRecommended;
          } else {
            recommendedVideos.value = rawRecommended;
          }
        }
      }

      // Fetch topics and playlists containing this video
      await _fetchTopicsAndPlaylistsForRecommendations();

      // Fetch community posts
      try {
        final postsSnapshot = await FirebaseFirestore.instance
            .collection(FirestoreCollections.community)
            .where('visibility', isEqualTo: 'Public')
            .limit(30)
            .get();
        final posts = postsSnapshot.docs
            .map((doc) => CommunityPostModel.fromMap(doc.data()))
            .toList();
        posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        communityPosts.assignAll(posts.take(5));
      } catch (e) {
        debugPrint('Error fetching community posts for recommendations: $e');
      }
    } catch (e) {
      debugPrint('Error fetching recommendations: $e');
    } finally {
      isLoadingRecommendations.value = false;
    }
  }

  Future<void> _fetchTopicsAndPlaylistsForRecommendations() async {
    try {
      final videoId = video.id;

      // Clear previous caches
      videoTopicsList.clear();
      videoPlaylistsList.clear();
      topicVideosCache.clear();
      playlistVideosCache.clear();

      // --- 1. Topics ---
      final foundTopics = <Topic>[];
      if (video.topics.isNotEmpty) {
        for (var i = 0; i < video.topics.length; i += 10) {
          final chunk = video.topics.sublist(
            i,
            i + 10 > video.topics.length ? video.topics.length : i + 10,
          );
          final topicsSnapshot = await FirebaseFirestore.instance
              .collection(FirestoreCollections.topics)
              .where('slug', whereIn: chunk)
              .get();

          foundTopics.addAll(
            topicsSnapshot.docs.map(Topic.fromDocumentSnapshot),
          );
        }
      }

      if (foundTopics.length < 3) {
        try {
          final publicTopicsSnapshot = await FirebaseFirestore.instance
              .collection(FirestoreCollections.topics)
              .limit(5)
              .get();
          final publicTopics = publicTopicsSnapshot.docs
              .map(Topic.fromDocumentSnapshot)
              .where((t) => !foundTopics.any((ft) => ft.id == t.id))
              .toList();
          foundTopics.addAll(publicTopics);
        } catch (_) {}
      }

        videoTopicsList.assignAll(foundTopics);

        // Fetch videos for each topic in parallel
        final topicFutures = foundTopics.map((topic) async {
          try {
            final query = await FirebaseFirestore.instance
                .collection(FirestoreCollections.videos)
                .where('topics', arrayContains: topic.slug)
                .where('visibility', isEqualTo: 'Public')
                .limit(10)
                .get();

            final topicVids = query.docs
                .map(Video.fromDocumentSnapshot)
                .toList();

            return MapEntry(topic.id, topicVids);
          } catch (e) {
            debugPrint('Error loading topic videos for ${topic.id}: $e');
            return MapEntry(topic.id, <Video>[]);
          }
        }).toList();

        final topicResults = await Future.wait(topicFutures);
        for (final entry in topicResults) {
          topicVideosCache[entry.key] = entry.value;
        }

      // --- 2. Playlists ---
      final foundPlaylists = <PlaylistModel>[];

      // Fetch public playlists containing this video
      final publicPlaylistsQuery = await FirebaseFirestore.instance
          .collection('public_playlists')
          .where('videoIds', arrayContains: videoId)
          .limit(5)
          .get();

      foundPlaylists.addAll(
        publicPlaylistsQuery.docs
            .map(PlaylistModel.fromDocumentSnapshot)
            .toList(),
      );

      // Fetch private playlists of the user containing this video
      final currentUserId = AuthService.to.uid;
      if (currentUserId.isNotEmpty) {
        final privatePlaylistsQuery = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(currentUserId)
            .collection(FirestoreCollections.playlists)
            .where('videoIds', arrayContains: videoId)
            .limit(5)
            .get();

        foundPlaylists.addAll(
          privatePlaylistsQuery.docs
              .map(PlaylistModel.fromDocumentSnapshot)
              .toList(),
        );
      }

      videoPlaylistsList.assignAll(foundPlaylists);

      // Fetch videos for each playlist
      for (final playlist in foundPlaylists) {
        if (playlist.videoIds.isNotEmpty) {
          final playlistVids = await _fetchVideosByIds(playlist.videoIds);
          playlistVideosCache[playlist.id] = playlistVids;
        }
      }
    } catch (e) {
      debugPrint('Error fetching topics and playlists for recommendations: $e');
    }
  }

  Future<List<Video>> _fetchVideosByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final result = <Video>[];
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final snapshot = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        result.addAll(snapshot.docs.map(Video.fromDocumentSnapshot));
      }
      // Sort to match original ids list order
      result.sort((a, b) {
        final indexA = ids.indexOf(a.id);
        final indexB = ids.indexOf(b.id);
        return indexA.compareTo(indexB);
      });
      return result;
    } catch (e) {
      debugPrint('Error fetching videos by ids: $e');
      return [];
    }
  }

  Future<void> _fetchFirstPlaylistVideo(String videoId) async {
    rxIsLoading.value = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .get();
      if (doc.exists) {
        _video.value = Video.fromDocumentSnapshot(doc);
        _continueInitialization();
        // Also fetch the entire playlist for the drawer
        fetchPlaylistVideos();
      } else {
        videoError.value = true;
        rxErrorMessage.value = 'First video of playlist not found';
      }
    } catch (e) {
      videoError.value = true;
      rxErrorMessage.value = 'Error fetching first video: $e';
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
    // Re-initialize comments controller for new video
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

  void _continueInitialization() {
    _initializeAllMetadata();
    _startPlaybackFlow();
  }

  Future<void> initializeVideoPlayer({String? overrideUrl}) async {
    final isAuto = isAutoSwitching.value;

    if (!isAuto) {
      rxIsLoading.value = true;
      disposePlayer();
    }

    videoError.value = false;
    showThumbnail.value = true;

    if (video.status == VideoStatus.rejected ||
        video.visibility == 'rejected' ||
        video.channelStatus == 'rejected') {
      videoError.value = true;
      rxErrorMessage.value =
          'This video has been removed for violating community guidelines.';
      rxIsLoading.value = false;
      return;
    }

    try {
      // YouTube-style URL resolution:
      //   1. Use the override URL if provided (already transcoded or HLS)
      //   2. Use the currently selected transcoded resolution
      //   3. On native: use HLS adaptive stream
      //   4. On web: pick a non-HLS transcoded MP4 from availableResolutions
      //   5. Last resort: originalUrl (may not work on web for raw uploads)
      var targetUrl = overrideUrl;
      if (targetUrl == null || targetUrl.isEmpty) {
        if (currentResolution.value != null &&
            currentResolution.value!.url.isNotEmpty) {
          targetUrl = currentResolution.value!.url;
        } else if (!kIsWeb &&
            video.hlsUrl.isNotEmpty &&
            !video.hlsUrl.startsWith('gs://')) {
          targetUrl = video.hlsUrl;
        } else if (kIsWeb && availableResolutions.isNotEmpty) {
          // On web, pick the best transcoded MP4 resolution
          final mp4Res = availableResolutions.firstWhereOrNull(
            (r) => r.url.isNotEmpty && !r.url.contains('.m3u8'),
          );
          if (mp4Res != null) {
            targetUrl = mp4Res.url;
          }
        }
        // Absolute last fallback
        if (targetUrl == null || targetUrl.isEmpty) {
          if (video.originalUrl.isNotEmpty &&
              !video.originalUrl.startsWith('gs://')) {
            targetUrl = video.originalUrl;
          } else if (video.hlsUrl.isNotEmpty &&
              !video.hlsUrl.startsWith('gs://')) {
            targetUrl = video.hlsUrl;
          }
        }
      }

      // Resolve gs:// and raw storage.googleapis.com references to HTTPS download URLs
      if (targetUrl != null &&
          (targetUrl.startsWith('gs://') ||
              targetUrl.startsWith('https://storage.googleapis.com/') ||
              (targetUrl.contains('firebasestorage.googleapis.com') &&
                  !targetUrl.contains('token=')))) {
        debugPrint(
          '[VideoController] ⚠️ Resolving storage URL to authenticated HTTPS download URL...',
        );
        try {
          targetUrl = await FirebaseStorage.instance
              .refFromURL(targetUrl)
              .getDownloadURL();
          final displayUrl = targetUrl.length > 60
              ? '${targetUrl.substring(0, 60)}...'
              : targetUrl;
          debugPrint(
            '[VideoController] ✅ Resolved to: $displayUrl',
          );

        } catch (e) {
          debugPrint('[VideoController] ❌ Failed to resolve storage URL: $e');
        }
      }

      // On web, if the resolved URL is an HLS manifest and we have transcoded
      // resolutions available, prefer an MP4 resolution instead.
      if (kIsWeb && targetUrl != null && targetUrl.contains('.m3u8')) {
        if (currentResolution.value != null &&
            currentResolution.value!.url.isNotEmpty &&
            !currentResolution.value!.url.contains('.m3u8')) {
          debugPrint(
            '[VideoController] ⚠️ Skipping HLS URL on web, using resolution MP4 instead',
          );
          targetUrl = currentResolution.value!.url;
        } else if (availableResolutions.isNotEmpty) {
          final mp4Res = availableResolutions.firstWhereOrNull(
            (r) => !r.url.contains('.m3u8'),
          );
          if (mp4Res != null) {
            debugPrint(
              '[VideoController] ⚠️ Skipping HLS URL on web, using ${mp4Res.label} MP4 instead',
            );
            targetUrl = mp4Res.url;
          }
        }
      }

      if (targetUrl == null || targetUrl.isEmpty) {
        throw Exception('No optimized video resolution available');
      }

      debugPrint('[VideoController] Initializing player for: $targetUrl');

      final oldVpc = _videoPlayerController;
      final oldCc = _chewieController;

      // Attempt to retrieve a pre-warmed/hovered controller for zero-latency startup
      final handoffVpc = VideoPlaybackHandoff.retrieveController(video.id);
      final VideoPlayerController newVpc;
      final wasHandoff = handoffVpc != null;

      if (wasHandoff) {
        debugPrint(
          '[VideoController] Found active handoff controller for: ${video.id}',
        );
        newVpc = handoffVpc;
        await newVpc.setLooping(
          false,
        ); // Disable looping which was enabled for hover previews
        await newVpc.setVolume(1); // Reset volume to unmute on watch screen
        rxIsLoading.value = false;
        showThumbnail.value = false;
      } else if (!kIsWeb &&
          rxIsOffline.value &&
          !targetUrl.startsWith('http') &&
          !targetUrl.startsWith('blob:')) {
        newVpc = VideoPlayerController.file(
          File(targetUrl),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: true,
          ),
        );
      } else {
        newVpc = (rxIsOffline.value && targetUrl.startsWith('blob:'))
            ? VideoPlayerController.networkUrl(
                Uri.parse(targetUrl),
                videoPlayerOptions: VideoPlayerOptions(
                  mixWithOthers: true,
                  allowBackgroundPlayback: true,
                ),
              )
            : VideoPlayerController.networkUrl(
                Uri.parse(targetUrl),
                httpHeaders: const {
                  'Connection': 'keep-alive',
                  'Accept': '*/*',
                },
                videoPlayerOptions: VideoPlayerOptions(
                  mixWithOthers: true,
                  allowBackgroundPlayback: true,
                ),
              );
      }

      HoverPreviewCoordinator.globalMute.value = true;

      if (!newVpc.value.isInitialized) {
        await newVpc.initialize().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Video initialization timeout');
          },
        );
      }

      // Ensure volume is set to full unmuted playback on watch screen
      try {
        await newVpc.setVolume(1.0);
      } catch (_) {}

      // Add listeners AFTER initialization succeeds to prevent race conditions during setup
      newVpc.addListener(_videoErrorListener);
      newVpc.addListener(videoListener);

      // Immediately start playback to begin decoding and frame rendering
      try {
        await newVpc.play();
      } catch (e) {
        debugPrint('[VideoController] Note: Immediate play trigger exception: $e');
        if (kIsWeb) {
          try {
            await newVpc.setVolume(0);
            await newVpc.play();
          } catch (_) {}
        }
      }

      // --- CLIP MODE & RESUME LOGIC ---
      if (activeClip.value != null) {
        final startMs = (activeClip.value!.startTime * 1000).toInt();
        debugPrint(
          '[VideoController] 🎬 Seeking player to clip start time: ${activeClip.value!.startTime}s ($startMs ms)',
        );
        await newVpc.seekTo(Duration(milliseconds: startMs));
      } else if (_initialSeekPosition != null && _initialSeekPosition! > Duration.zero) {
        debugPrint(
          '[VideoController] ⏩ Seeking player to deep-link timestamp: ${_initialSeekPosition!.inSeconds}s',
        );
        await newVpc.seekTo(_initialSeekPosition!);
        _initialSeekPosition = null; // Consume once
      } else {
        final lastPos = WatchHistoryService.to.getLastPosition(video.id);
        if (lastPos > 0 && lastPos < newVpc.value.duration.inSeconds - 10) {
          // Seek to last position
          await newVpc.seekTo(Duration(seconds: lastPos));

          // Show resume snackbar
          Get.snackbar(
            'Resuming Video',
            'Resumed from ${Duration(seconds: lastPos).toString().split('.').first.padLeft(8, '0').substring(3)}',
            snackPosition: SnackPosition.BOTTOM,
            mainButton: TextButton(
              onPressed: () {
                newVpc.seekTo(Duration.zero);
                Get.back();
              },
              child: const Text(
                'Start Over',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: AppColors.bgPage.withValues(alpha: 0.7),
            colorText: AppColors.textPrimary,
          );
        }
      }

      // Track initiation
      if (!isAuto) {
        final isSub = isSubscribed.value;
        final isNotSub = !isSub;
        // Start stopwatch immediately for accurate tracking from second 0
        if (!_watchStopwatch.isRunning) _watchStopwatch.start();

        mainController.trackWatchEvent(
          videoId: video.id,
          channelId: video.channelId,
          eventType: 'video_start',
          position: 0,
          duration: newVpc.value.duration.inSeconds,
          isSubscriber: isSub,
          isNotSubscriber: isNotSub,
        );
      }

      _videoPlayerController = newVpc;

      // Sync active TowerPlayerController immediately before disposing old controller
      try {
        if (Get.isRegistered<TowerPlayerController>(tag: video.id)) {
          Get.find<TowerPlayerController>(tag: video.id).sync(newVpc);
        } else if (Get.isRegistered<TowerPlayerController>()) {
          Get.find<TowerPlayerController>().sync(newVpc);
        }
      } catch (_) {}

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        allowedScreenSleep: false,
        showControlsOnInitialize: false,
        placeholder: const ColoredBox(
          color: AppColors.bgPage,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.error),
          ),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.error,
          handleColor: AppColors.error,
          backgroundColor: AppColors.textSecondary.withValues(alpha: 0.5),
          bufferedColor: AppColors.textPrimary.withValues(alpha: 0.3),
        ),
        customControls: TowerCustomPlayer(
          videoPlayerController: _videoPlayerController!,
          tag: video.id,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Video playback error',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: initializeVideoPlayer,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        },
        deviceOrientationsOnEnterFullScreen:
            _videoPlayerController!.value.aspectRatio > 1.0
            ? [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
        deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
        systemOverlaysOnEnterFullScreen: const [],
      );

      // Listen for fullscreen changes from Chewie
      _chewieController!.addListener(_onChewieEvent);

      // Warm handoff: dispose old ones now that new ones are ready and synced
      if (oldVpc != null && oldVpc != newVpc) {
        try {
          oldVpc.removeListener(_videoErrorListener);
          oldVpc.removeListener(videoListener);
        } catch (_) {}
        try {
          oldCc?.removeListener(_onChewieEvent);
          oldCc?.dispose();
        } catch (_) {}
        try {
          oldVpc.dispose();
        } catch (_) {}
      }

      debugPrint(
        '[VideoController] Player initialized successfully (Handoff: $isAuto)',
      );
    } catch (e, stackTrace) {
      debugPrint('[VideoController] Playback Error: $e');
      debugPrint('[VideoController] Stack trace: $stackTrace');

      if (!_isRecoveringFromFormatError &&
          (e.toString().contains('MEDIA_ERR_SRC_NOT_SUPPORTED') ||
              e.toString().contains('Format error') ||
              e.toString().contains('format not supported'))) {
        debugPrint('[VideoController] Attempting format fallback from catch block...');
        _attemptFormatFallback();
        return;
      }

      videoError.value = true;
      final errorMsg = e.toString();
      if (errorMsg.contains('Future already completed') ||
          errorMsg.contains('Bad state')) {
        rxErrorMessage.value =
            'Video stream unavailable. Please check your connection or try again.';
      } else {
        rxErrorMessage.value = 'Video unavailable: $e';
      }
    } finally {
      rxIsLoading.value = false;
    }
  }

  bool _isRecoveringFromFormatError = false;

  void _videoErrorListener() {
    try {
      if (_videoPlayerController?.value.hasError ?? false) {
        final error = _videoPlayerController?.value.errorDescription ?? '';

        // Ignore transient web race conditions / audio interruptions
        if (error.contains('removed from the document') ||
            error.contains('play() request was interrupted') ||
            error.contains('The play() request was interrupted') ||
            error.contains('AbortError') ||
            error.contains('NotAllowedError')) {
          debugPrint(
            '[VideoController] ℹ️ Ignoring transient play() interruption (DOM lifecycle)',
          );
          return;
        }

        debugPrint('[VideoController] ❌ Video error: $error');

        // If this is a format/source error and we haven't already tried recovery,
        // attempt to fall back to a transcoded MP4 resolution.
        if (!_isRecoveringFromFormatError &&
            (error.contains('MEDIA_ERR_SRC_NOT_SUPPORTED') ||
                error.contains('Format error') ||
                error.contains('format not supported'))) {
          debugPrint(
            '[VideoController] 🔄 Format error detected — attempting MP4 fallback...',
          );
          _attemptFormatFallback();
          return;
        }

        videoError.value = true;
        rxErrorMessage.value = error.isNotEmpty
            ? error
            : 'Unknown playback error';
      }
    } catch (e) {
      debugPrint('[VideoController] Error in _videoErrorListener: $e');
    }
  }

  /// Tries to recover from a format error by switching to a transcoded MP4 URL.
  Future<void> _attemptFormatFallback() async {
    _isRecoveringFromFormatError = true;
    try {
      // 1. If resolutions haven't been fetched yet, fetch them now
      if (availableResolutions.isEmpty) {
        await fetchAvailableResolutions();
      }

      // 2. Find a non-HLS MP4 resolution
      final mp4Res = availableResolutions.firstWhereOrNull(
        (r) => r.url.isNotEmpty && !r.url.contains('.m3u8'),
      );

      if (mp4Res != null) {
        debugPrint(
          '[VideoController] ✅ Found MP4 fallback: ${mp4Res.label} (${mp4Res.url.substring(0, 60)}...)',
        );
        currentResolution.value = mp4Res;
        await initializeVideoPlayer(overrideUrl: mp4Res.url);
        return;
      }

      // 3. Try originalUrl as last resort (it might be MP4 even if HLS failed)
      if (video.originalUrl.isNotEmpty &&
          !video.originalUrl.contains('.m3u8')) {
        debugPrint('[VideoController] ✅ Falling back to originalUrl');
        await initializeVideoPlayer(overrideUrl: video.originalUrl);
        return;
      }

      // 4. Nothing worked — show the error
      debugPrint('[VideoController] ❌ No MP4 fallback available');
      videoError.value = true;
      rxErrorMessage.value =
          'Video format is not supported by your browser. Please try a different browser.';
    } catch (e) {
      debugPrint('[VideoController] ❌ Format fallback failed: $e');
      videoError.value = true;
      rxErrorMessage.value = 'Video format is not supported by your browser.';
    } finally {
      _isRecoveringFromFormatError = false;
    }
  }

  /// Attempts to re-initialize the player from the current position
  Future<void> attemptRecovery() async {
    if (_videoPlayerController == null) return;

    final currentPos = _videoPlayerController!.value.position;
    final wasPlaying = _videoPlayerController!.value.isPlaying;

    debugPrint(
      '[VideoController] 🔄 Recovering playback from ${currentPos.inSeconds}s...',
    );

    videoError.value = false;
    rxIsLoading.value = true;

    try {
      // Re-fetch resolutions if necessary (in case URLs expired or changed)
      if (!rxIsOffline.value) {
        await fetchAvailableResolutions();
      }

      await initializeVideoPlayer(
        overrideUrl: rxIsOffline.value ? _offlineBlobUrl : null,
      );

      if (_videoPlayerController != null) {
        await _videoPlayerController!.seekTo(currentPos);
        if (wasPlaying) {
          await _videoPlayerController!.play();
        }
      }
    } catch (e) {
      debugPrint('[VideoController] ❌ Recovery failed: $e');
      videoError.value = true;
      rxErrorMessage.value = 'Recovery failed. Please check your connection.';
    } finally {
      rxIsLoading.value = false;
    }
  }

  void _onChewieEvent() {
    // Handled by TowerPlayerController to prevent state conflicts
  }

  void disposePlayer() {
    _videoSubscription?.cancel();
    _languageRequestsSubscription?.cancel();
    try {
      _chewieController?.removeListener(_onChewieEvent);
    } catch (_) {}
    try {
      _videoPlayerController?.removeListener(_videoErrorListener);
      _videoPlayerController?.removeListener(videoListener);
    } catch (_) {}
    try {
      _chewieController?.dispose();
    } catch (_) {}
    _chewieController = null;
    try {
      _videoPlayerController?.dispose();
    } catch (_) {}
    _videoPlayerController = null;
  }

  ChewieController? get chewieController {
    if (_chewieController == null) return null;
    return _chewieController;
  }

  VideoPlayerController? get videoPlayerController => _videoPlayerController;

  bool get isVpcInitialized {
    final vpc = _videoPlayerController;
    if (vpc == null) return false;
    try {
      return vpc.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  bool get isVpcPlaying {
    final vpc = _videoPlayerController;
    if (vpc == null) return false;
    try {
      return vpc.value.isPlaying;
    } catch (_) {
      return false;
    }
  }

  double get vpcAspectRatio {
    final vpc = _videoPlayerController;
    if (vpc == null) return 16 / 9;
    try {
      final ratio = vpc.value.aspectRatio;
      return (ratio.isFinite && ratio > 0) ? ratio : 16 / 9;
    } catch (_) {
      return 16 / 9;
    }
  }

  @override
  void onClose() {
    final currentRoute = Get.currentRoute;
    final isGoingToWatch =
        currentRoute.contains('watch') || currentRoute.contains('videoscreen');

    final shouldStartMiniplayer =
        !isGoingToWatch &&
        isVpcInitialized &&
        Get.isRegistered<MiniplayerController>(tag: 'miniplayer');

    if (isVpcInitialized) {
      try {
        final totalDuration = _videoPlayerController!.value.duration.inSeconds;
        final watchSeconds = _watchStopwatch.elapsed.inSeconds;
        _flushRemainingWatchTime();
        _syncWatchHistory(watchSeconds, totalDuration);
      } catch (_) {}
    }

    if (shouldStartMiniplayer) {
      var pos = Duration.zero;
      try {
        pos = _videoPlayerController!.value.position;
      } catch (_) {}
      final videoToPlay = video;
      final selectedResUrl = currentResolution.value?.url;

      // ── CRITICAL: Pause immediately to prevent dual audio ──
      // The VPC must stop producing audio NOW, before the async handoff.
      try {
        _videoPlayerController!.pause();
      } catch (_) {}

      // Remove listeners so they don't fire when player is in miniplayer
      try {
        _videoPlayerController!.removeListener(_videoErrorListener);
        _videoPlayerController!.removeListener(videoListener);
      } catch (_) {}

      // Detach the ChewieController from the VPC BEFORE disposing it.
      // This prevents Chewie's internal dispose from touching the VPC.
      try {
        _chewieController?.removeListener(_onChewieEvent);
        _chewieController?.dispose();
      } catch (_) {}
      _chewieController = null;

      // Pause all other TowerPlayerController instances to kill any
      // lingering audio from the overlay player.
      TowerPlayerController.pauseAllActivePlayers();

      // Hand off the player controller to the miniplayer on native platforms
      if (_videoPlayerController != null && !kIsWeb) {
        VideoPlaybackHandoff.registerActiveController(
          video.id,
          _videoPlayerController!,
        );
        // Prevent disposePlayer() from destroying the video player controller!
        _videoPlayerController = null;
      }

      // Show the miniplayer
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          MiniplayerController.to.showWithVideo(
            videoToPlay,
            resumeFromPosition: pos,
            overrideUrl: selectedResUrl,
          );
        } catch (e) {
          debugPrint(
            '[VideoController] Error showing miniplayer in onClose: $e',
          );
        }
      });
    }

    try {
      mobileTabController.dispose();
      desktopTabController.dispose();
      scrollController.dispose();
    } catch (_) {}
    disposePlayer();
    _connectivitySubscription?.cancel();
    _languageRequestsSubscription?.cancel();
    if (_offlineBlobUrl != null) {
      try {
        html.Url.revokeObjectUrl(_offlineBlobUrl!);
      } catch (_) {}
    }
    _watchStopwatch.stop();
    super.onClose();
  }

  // UI Actions with Optimistic Updates
  Future<void> toggleLike() async {
    await engagementController.toggleLike(
      video.id,
      video.likeCount,
      video.dislikeCount,
    );
  }

  Future<void> toggleDislike() async {
    await engagementController.toggleDislike(
      video.id,
      video.likeCount,
      video.dislikeCount,
    );
  }

  void toggleSubscription() {
    isSubscribed.toggle();
    // Call channelController.toggleSubscription(...)
  }

  Future<void> setResolution(
    VideoResolutionV2 res, {
    bool isManual = true,
  }) async {
    if (currentResolution.value?.url == res.url &&
        currentResolution.value?.label == res.label) {
      return;
    }

    // If the active controller is already playing this exact dataSource URL, update metadata only
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized &&
        _videoPlayerController!.dataSource == res.url) {
      currentResolution.value = res;
      return;
    }

    final currentPosition =
        _videoPlayerController?.value.position ?? Duration.zero;
    final wasPlaying = _videoPlayerController?.value.isPlaying ?? false;

    isSwitchingResolution.value = true;
    isAutoSwitching.value = !isManual;
    currentResolution.value = res;

    try {
      // Re-initialize with new URL
      await initializeVideoPlayer(overrideUrl: res.url);

      // Resume state
      if (_videoPlayerController != null) {
        await _videoPlayerController!.seekTo(currentPosition);
        if (wasPlaying) {
          await _videoPlayerController!.play();
        }
      }
    } finally {
      isSwitchingResolution.value = false;
      isAutoSwitching.value = false;
    }
  }

  /// Specialized switcher for ABR engine
  Future<void> setResolutionByIndex(int index) async {
    if (index < 0 || index >= availableResolutions.length) return;

    // ABR ladder is reversed (lowest to highest), availableResolutions is highest to lowest
    // We need to map the index correctly or just use the ladder directly.
    if (Get.isRegistered<AdaptiveBitrateController>()) {
      final abr = Get.find<AdaptiveBitrateController>();
      final tier = abr.resolutionLadder[index];

      // Find matching ResolutionV2
      final res = availableResolutions.firstWhereOrNull(
        (r) => r.height == tier.height,
      );
      if (res != null) {
        setResolution(res);
      }
    }
  }

  void prefetchNextPage() {
    // Simply trigger extra recommendations for now to satisfy the call
    if (recommendedVideos.length < 50) {
      fetchRecommendations();
    }
  }

  Future<String> _resolveDownloadableMediaUrl({required bool isAudioOnly}) async {
    // 1. If audio only, check audio tracks first (non-m3u8)
    if (isAudioOnly && video.audioTracks.isNotEmpty) {
      final track = video.audioTracks.values.firstWhere(
        (t) => t.isNotEmpty && !t.contains('.m3u8') && !t.contains('.mpd'),
        orElse: () => '',
      );
      if (track.isNotEmpty) return StorageUtils.getFastDownloadUrl(track);
    }

    // 2. Check availableResolutions for progressive MP4s
    if (availableResolutions.isNotEmpty) {
      final mp4Res = availableResolutions
          .where((r) => r.url.isNotEmpty && !r.url.contains('.m3u8') && !r.url.contains('.mpd'))
          .toList();
      if (mp4Res.isNotEmpty) {
        if (isAudioOnly) {
          // Lowest resolution is best for audio-only (fastest download & least bandwidth)
          mp4Res.sort((a, b) => a.height.compareTo(b.height));
        } else {
          mp4Res.sort((a, b) => b.height.compareTo(a.height));
        }
        return StorageUtils.getFastDownloadUrl(mp4Res.first.url);
      }
    }

    // 3. Check video.adaptiveResolutions
    if (video.adaptiveResolutions.isNotEmpty) {
      final mp4Res = video.adaptiveResolutions
          .where((r) => r.url.isNotEmpty && !r.url.contains('.m3u8') && !r.url.contains('.mpd'))
          .toList();
      if (mp4Res.isNotEmpty) {
        if (isAudioOnly) {
          mp4Res.sort((a, b) => a.height.compareTo(b.height));
        } else {
          mp4Res.sort((a, b) => b.height.compareTo(a.height));
        }
        return StorageUtils.getFastDownloadUrl(mp4Res.first.url);
      }
    }

    // 4. Check Firestore resolution_jobs variants
    try {
      final doc = await FirebaseFirestore.instance
          .collection('resolution_jobs')
          .doc(video.id)
          .getCacheFirst();
      if (doc.exists && doc.data() != null && doc.data()!['variants'] != null) {
        final variants = doc.data()!['variants'] as Map<String, dynamic>;
        for (final entry in variants.entries) {
          final vData = entry.value as Map<String, dynamic>;
          if (vData['status'] == 'completed') {
            final downloadUrl = vData['downloadUrl'] as String?;
            if (downloadUrl != null &&
                downloadUrl.isNotEmpty &&
                !downloadUrl.contains('.m3u8') &&
                !downloadUrl.contains('.mpd')) {
              return downloadUrl;
            }
            final outputPath = vData['outputPath'] as String?;
            if (outputPath != null &&
                outputPath.isNotEmpty &&
                !outputPath.contains('.m3u8') &&
                !outputPath.contains('.mpd')) {
              return StorageUtils.getFastDownloadUrl(outputPath);
            }
          }
        }
      }
    } catch (_) {}

    // 5. Check video.originalUrl (if not m3u8/mpd)
    if (video.originalUrl.isNotEmpty &&
        !video.originalUrl.contains('.m3u8') &&
        !video.originalUrl.contains('.mpd')) {
      return StorageUtils.getFastDownloadUrl(video.originalUrl);
    }

    // 6. Check video.videoUrl (if not m3u8/mpd)
    if (video.videoUrl.isNotEmpty &&
        !video.videoUrl.contains('.m3u8') &&
        !video.videoUrl.contains('.mpd')) {
      return StorageUtils.getFastDownloadUrl(video.videoUrl);
    }

    return '';
  }

  bool _validateDownloadSettings() {
    if (!Get.isRegistered<UserSettingsController>()) return true;
    final dl = UserSettingsController.to.downloads.value;

    // 1. Wi-Fi Only Check
    if (dl.wifiOnly) {
      final isWifi = !Get.isRegistered<ConnectivityService>() ||
          ConnectivityService.to.isWifi;
      if (!isWifi) {
        Get.snackbar(
          'Wi-Fi Required',
          'Downloads are restricted to Wi-Fi connections in Settings.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF1E1E1E),
          colorText: Colors.white,
        );
        return false;
      }
    }

    return true;
  }

  Future<void> saveAudioOffline() async {
    if (isDownloading.value) {
      Get.snackbar('Info', 'Download is already in progress.');
      return;
    }

    final downloadsCtrl = Get.isRegistered<DownloadsController>()
        ? Get.find<DownloadsController>()
        : Get.put(DownloadsController());

    isDownloading.value = true;
    downloadProgress.value = 0.0;

    try {
      final success = await downloadsCtrl.downloadAudioOffline(
        video: video,
        onProgress: (p) => downloadProgress.value = p,
      );
      if (success) {
        await downloadsCtrl.loadVideos();
      }
    } finally {
      isDownloading.value = false;
      downloadProgress.value = 0.0;
    }
  }

  Future<void> saveVideoOffline(
    VideoResolutionV2 resolution, {
    bool isAudioOnly = false,
  }) async {
    if (isAudioOnly) {
      return saveAudioOffline();
    }

    if (isDownloading.value) {
      Get.snackbar('Info', 'Video download is already in progress.');
      return;
    }

    final downloadsCtrl = Get.isRegistered<DownloadsController>()
        ? Get.find<DownloadsController>()
        : Get.put(DownloadsController());

    isDownloading.value = true;
    downloadProgress.value = 0.0;

    try {
      final success = await downloadsCtrl.downloadVideoOffline(
        video: video,
        resolution: resolution,
        onProgress: (p) => downloadProgress.value = p,
      );
      if (success) {
        await downloadsCtrl.loadVideos();
      }
    } finally {
      isDownloading.value = false;
      downloadProgress.value = 0.0;
    }
  }
}
