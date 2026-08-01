import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:path_provider/path_provider.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/analytics/data/services/viewer_identity_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/domain/database_helpers.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_birate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_analytics_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_engagement_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart'
    hide LanguageRequest;
import 'package:truthworld/features/video/presentation/views/player/tower_custom_player.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check_report_widget.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

class VideoController extends BaseController with GetTickerProviderStateMixin {
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

  // Playlist Support
  final Rx<PlaylistModel?> currentPlaylist = Rx<PlaylistModel?>(null);
  final RxList<Video> playlistVideos = <Video>[].obs;
  final RxInt currentPlaylistIndex = 0.obs;
  final RxBool isPlaylistLooping = false.obs;
  final RxBool isPlaylistShuffled = false.obs;
  final RxBool showPlaylistDrawer = true.obs;

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

  // State variables
  final RxBool isDownloading = false.obs;
  final RxDouble downloadProgress = 0.0.obs;
  RxBool get isSubscribed => engagementController.isSubscribed;
  RxBool get isLiked => engagementController.isLiked;
  RxBool get isDisliked => engagementController.isDisliked;
  final RxBool isExpanded = false.obs;
  final RxBool isTranscriptVisible = false.obs;
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
    final mixed = <dynamic>[];
    var videoIndex = 0;
    var postIndex = 0;
    final displayVideos = filteredRecommendedVideos;

    while (videoIndex < displayVideos.length ||
        postIndex < communityPosts.length) {
      for (var i = 0; i < 4 && videoIndex < displayVideos.length; i++) {
        mixed.add(displayVideos[videoIndex++]);
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
    final list = ['All'];

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
    if (filter == 'All') {
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
      : Get.put(MainController());
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
    rxIsOffline.value = (Get.arguments?['isOffline'] as bool?) ?? false;
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

    // Safety check for arguments
    if (Get.arguments == null) {
      videoError.value = true;
      rxErrorMessage.value = 'No arguments found';
      rxIsLoading.value = false;
      return;
    }

    final args = Get.arguments as Map<String, dynamic>?;
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
        currRoute.contains('playlist');

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
      }
    } else {
      navigatedFromPlaylist.value = false;
      navigatedFromTopic.value = false;
    }

    // Handle Video argument
    if (args?['video'] != null) {
      _video.value = args!['video'] as Video;
    } else if (currentPlaylist.value != null &&
        currentPlaylist.value!.videoIds.isNotEmpty) {
      _fetchFirstPlaylistVideo(currentPlaylist.value!.videoIds.first);
      return;
    } else {
      videoError.value = true;
      rxErrorMessage.value = 'Video data not found';
      rxIsLoading.value = false;
      return;
    }

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
    if (args['clip'] != null) {
      activeClip.value = args['clip'] as VideoClip;
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

    _initializeAllMetadata();

    // Strict Enforcement: Start playback
    _startPlaybackFlow();
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

    if (hasInternet) {
      channelController.listenSubscription(video.channelId);
      if (isAuthenticated) {
        checkUserInteractions();
      }
      fetchRecommendations();
      fetchPlaylistForVideo();
      _initializeCommentsController();
      _listenToVideoUpdates();
      _listenToLanguageRequests();
    } else if (rxIsOffline.value) {
      rxIsLoading.value = false;
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

    // 2. Identify initial playback URL immediately from video model to prevent startup latency
    //    On web, skip HLS (.m3u8) because non-Safari browsers don't support it natively
    //    and there's no HLS.js polyfill. Prefer direct MP4 URLs instead.
    //    Always skip gs:// URLs — they are storage references, not playable URLs.
    String? initialUrl;
    if (!kIsWeb &&
        video.hlsUrl.isNotEmpty &&
        !video.hlsUrl.startsWith('gs://')) {
      initialUrl = video.hlsUrl;
    } else if (video.originalUrl.isNotEmpty &&
        !video.originalUrl.startsWith('gs://')) {
      initialUrl = video.originalUrl;
    } else if (video.hlsUrl.isNotEmpty && !video.hlsUrl.startsWith('gs://')) {
      // Fallback: use HLS even on web if it's the only option
      initialUrl = video.hlsUrl;
    }

    // 3. If we have a direct url on the model, initialize player instantly while metadata loads
    if (initialUrl != null && initialUrl.isNotEmpty) {
      await initializeVideoPlayer(overrideUrl: initialUrl);

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
      // Fallback: if no direct URL is present on the model, wait for resolution metadata
      await metadataFuture;
      if (availableResolutions.isEmpty) {
        debugPrint(
          '[VideoController] ❌ No transcoded resolutions found. Blocking playback.',
        );
        videoError.value = true;
        rxErrorMessage.value =
            'Video is still processing. Please check back later.';
        rxIsLoading.value = false;
        return;
      }
      final best = availableResolutions.first;
      currentResolution.value = best;
      await initializeVideoPlayer(overrideUrl: best.url);
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
      if (kIsWeb) {
        final bytes = await getVideoBytes(video.id);
        if (bytes == null || bytes.isEmpty) {
          throw Exception('Offline video content not found');
        }
        final blob = html.Blob([bytes], 'video/mp4');
        _offlineBlobUrl = html.Url.createObjectUrl(blob);
      } else {
        final filePath = await getVideoFilePath(video.id);
        if (filePath != null && File(filePath).existsSync()) {
          _offlineBlobUrl = filePath;
        } else {
          final bytes = await getVideoBytes(video.id);
          if (bytes == null || bytes.isEmpty) {
            throw Exception('Offline video content not found');
          }
          final dir = await getApplicationDocumentsDirectory();
          final videoFile = File('${dir.path}/offline_videos/${video.id}.mp4');
          await videoFile.parent.create(recursive: true);
          await videoFile.writeAsBytes(bytes);
          _offlineBlobUrl = videoFile.path;
        }
      }

      // Create a dummy resolution for the UI
      availableResolutions.assignAll([
        VideoResolutionV2(
          label: 'Offline',
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
      rxErrorMessage.value = 'Failed to load offline video';
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

          for (final entry in variants.entries) {
            final variantData = entry.value as Map<String, dynamic>;
            final status = variantData['status'];
            final label = variantData['label'] ?? entry.key;

            debugPrint('[VideoController] 🛠️ Variant $label status: $status');

            if (status == 'completed') {
              final outputPath = variantData['outputPath'] as String?;
              if (outputPath == null) {
                debugPrint('[VideoController] ⚠️ No outputPath for $label');
                continue;
              }

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

          final results = await Future.wait(fetchTasks);
          final found = results.whereType<VideoResolutionV2>().toList();

          // Sort by height descending
          found.sort((a, b) => b.height.compareTo(a.height));
          availableResolutions.assignAll(found);

          // Update ABR ladder with real variants
          if (Get.isRegistered<AdaptiveBitrateController>()) {
            final abr = Get.find<AdaptiveBitrateController>();
            final ladder = found.reversed
                .map(
                  (v) => ResolutionTier(
                    label: v.label,
                    url: v.url,
                    height: v.height,
                    bitrate: v.bitrate,
                    minBandwidth: (v.bitrate * 1.2).toInt(), // 20% margin
                  ),
                )
                .toList();

            if (ladder.isNotEmpty) {
              abr.resolutionLadder = ladder;
              // Reset to a reasonable middle tier if we just loaded them
              abr.currentTierIndex.value = (ladder.length / 2).floor();
            }
          }

          debugPrint(
            '[VideoController] ✅ Successfully loaded ${availableResolutions.length} resolutions',
          );
        } else {
          debugPrint('[VideoController] ⚠️ No variants field in document');
        }
      } else {
        debugPrint('[VideoController] ℹ️ No resolution job found for $docId');
      }

      // FALLBACK: If no resolutions found in resolution_jobs, check the Video model itself
      if (availableResolutions.isEmpty) {
        debugPrint('[VideoController] 💡 Using model fallback for resolutions');
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
        } else if (video.originalUrl.isNotEmpty) {
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
      final subs = video.mediaSubtitles;
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

  Future<void> fetchAvailableAudioTracks() async {
    try {
      final audioTracksMap = video.audioTracks;
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
    isPlayingRx.value = value.isPlaying;
    if (value.isPlaying && showThumbnail.value) {
      showThumbnail.value = false;
    }

    // Manage stopwatch based on playback state
    if (value.isPlaying && !value.isBuffering) {
      if (!_watchStopwatch.isRunning) _watchStopwatch.start();
    } else {
      if (_watchStopwatch.isRunning) _watchStopwatch.stop();
    }

    if (!value.isInitialized) return;

    final currentWatchSeconds = _watchStopwatch.elapsed.inSeconds;
    final totalDuration = value.duration.inSeconds;

    // 1. Qualified View at 20s — with 24h cooldown per user per video
    const watchThreshold = 20;

    if (!_hasCountedQualifiedView && currentWatchSeconds >= watchThreshold) {
      if (_canCountQualifiedView()) {
        _hasCountedQualifiedView = true;
        mainController.incrementViews(
          videoId: video.id,
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
          '[VideoController] ✅ Qualified view at $currentWatchSeconds s',
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

    // 3. Update watch history periodically (every 5s - optimized for resume)
    if (currentWatchSeconds - _lastReportedWatchTime >= 5) {
      _syncWatchHistory(currentWatchSeconds, totalDuration);
      _lastReportedWatchTime = currentWatchSeconds;
    }

    // 4. Handle video completion for loop and autoplay next
    _handleVideoCompletion(value);
  }

  /// Check 24h cooldown: 1 qualified view per user per video per 24h
  bool _canCountQualifiedView() {
    try {
      final storage = GetStorage();
      final key = 'qv_${video.id}_${AuthService.to.uid}';
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
      final key = 'qv_${video.id}_${AuthService.to.uid}';
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

    mainController.trackWatchEvent(
      videoId: video.id,
      eventType: eventType,
      position: position,
      duration: duration,
      watchTimeSecondsDelta: position - _lastReportedWatchTime,
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

    // Track completion via watch history
    final totalDuration = _videoPlayerController?.value.duration.inSeconds ?? 0;
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
      final prevIndex = currentPlaylistIndex.value - 1;
      currentPlaylistIndex.value = prevIndex;
      final prevVideo = playlistVideos[prevIndex];
      _video.value = prevVideo;

      // Re-initialize comments controller
      Get.delete<CommentsController>(tag: 'video_${prevVideo.id}', force: true);
      commentsController = Get.put(
        CommentsController(video: prevVideo),
        tag: 'video_${prevVideo.id}',
      );

      initializeVideoPlayer(overrideUrl: prevVideo.videoUrl);
      fetchRecommendations();
      checkUserInteractions();
      channelController.listenSubscription(prevVideo.channelId);
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

  Future<void> loadFactCheckData() async {
    if (video.factCheckUrl.isEmpty) {
      factCheckData.clear();
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
        // 2. Normal recommendations logic
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
          final isFlipped =
              Get.isRegistered<FlipCoinService>() &&
              Get.find<FlipCoinService>().isVideoFlipped(video.id);

          final ranked = isFlipped
              ? algorithm.rankVideosForCurrentVideoOpposite(
                  video,
                  rawRecommended,
                )
              : algorithm.rankVideos(
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
      if (video.topics.isNotEmpty) {
        final foundTopics = <Topic>[];
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
    if (currentPlaylist.value == null ||
        currentPlaylist.value!.videoIds.isEmpty) {
      return;
    }

    try {
      final ids = currentPlaylist.value!.videoIds;
      final fetchedVideos = <Video>[];

      // Firestore 'whereIn' supports max 10 items. Chunking:
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final snapshot = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        fetchedVideos.addAll(snapshot.docs.map(Video.fromDocumentSnapshot));
      }

      // Restore original playlist order
      fetchedVideos.sort(
        (a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)),
      );

      playlistVideos.value = fetchedVideos;

      final activeIndex = fetchedVideos.indexWhere((v) => v.id == video.id);
      currentPlaylistIndex.value = activeIndex != -1 ? activeIndex : 0;
    } catch (e) {
      debugPrint('Error fetching full playlist videos: $e');
    }
  }

  void playNextVideo() {
    if (playlistVideos.isEmpty) return;

    int nextIndex;
    if (isPlaylistShuffled.value && playlistVideos.length > 1) {
      // Pick a random index that is not the current one
      final random = DateTime.now().millisecondsSinceEpoch;
      final seed = random % 1000000;
      final rng = (seed * 1103515245 + 12345) & 0x7fffffff;
      nextIndex = rng % playlistVideos.length;

      // Ensure we don't pick the same one twice in a row if possible
      if (nextIndex == currentPlaylistIndex.value) {
        nextIndex = (nextIndex + 1) % playlistVideos.length;
      }
    } else {
      nextIndex = currentPlaylistIndex.value + 1;
      if (nextIndex >= playlistVideos.length) {
        if (isPlaylistLooping.value) {
          nextIndex = 0;
        } else {
          return; // Reached the end
        }
      }
    }
    playPlaylistVideoAtIndex(nextIndex);
  }

  void playPlaylistVideoAtIndex(int index) {
    if (index < 0 || index >= playlistVideos.length) return;

    currentPlaylistIndex.value = index;
    final nextVideo = playlistVideos[index];

    _video.value = nextVideo;

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

    try {
      // Validate video URL
      //    On web, skip HLS (.m3u8) because non-Safari browsers don't support it natively.
      //    Always skip gs:// URLs — they are storage references, not playable URLs.
      var targetUrl = overrideUrl;
      if (targetUrl == null || targetUrl.isEmpty) {
        if (currentResolution.value != null &&
            currentResolution.value!.url.isNotEmpty) {
          targetUrl = currentResolution.value!.url;
        } else if (!kIsWeb &&
            video.hlsUrl.isNotEmpty &&
            !video.hlsUrl.startsWith('gs://')) {
          targetUrl = video.hlsUrl;
        } else if (video.originalUrl.isNotEmpty &&
            !video.originalUrl.startsWith('gs://')) {
          targetUrl = video.originalUrl;
        } else if (video.hlsUrl.isNotEmpty &&
            !video.hlsUrl.startsWith('gs://')) {
          targetUrl = video.hlsUrl;
        }
      }

      // Resolve gs:// storage references to HTTPS download URLs
      if (targetUrl != null && targetUrl.startsWith('gs://')) {
        debugPrint(
          '[VideoController] ⚠️ Resolving gs:// URL to HTTPS download URL...',
        );
        try {
          targetUrl = await FirebaseStorage.instance
              .refFromURL(targetUrl)
              .getDownloadURL();
          debugPrint(
            '[VideoController] ✅ Resolved to: ${targetUrl.substring(0, 60)}...',
          );
        } catch (e) {
          debugPrint('[VideoController] ❌ Failed to resolve gs:// URL: $e');
          targetUrl = null;
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
      } else if (!kIsWeb &&
          rxIsOffline.value &&
          !targetUrl.startsWith('http') &&
          !targetUrl.startsWith('blob:')) {
        newVpc = VideoPlayerController.file(
          File(targetUrl),
          videoPlayerOptions: VideoPlayerOptions(),
        );
      } else {
        newVpc = (rxIsOffline.value && targetUrl.startsWith('blob:'))
            ? VideoPlayerController.networkUrl(Uri.parse(targetUrl))
            : VideoPlayerController.networkUrl(
                Uri.parse(targetUrl),
                videoPlayerOptions: VideoPlayerOptions(),
              );
      }

      // Add listeners BEFORE initialization to catch all events
      newVpc.addListener(_videoErrorListener);
      newVpc.addListener(videoListener);

      HoverPreviewCoordinator.globalMute.value = true;

      if (!wasHandoff) {
        await newVpc.initialize().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Video initialization timeout');
          },
        );
      }

      // --- CLIP MODE & RESUME LOGIC ---
      if (activeClip.value != null) {
        final startMs = (activeClip.value!.startTime * 1000).toInt();
        debugPrint(
          '[VideoController] 🎬 Seeking player to clip start time: ${activeClip.value!.startTime}s ($startMs ms)',
        );
        await newVpc.seekTo(Duration(milliseconds: startMs));
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
          eventType: 'video_start',
          position: 0,
          duration: newVpc.value.duration.inSeconds,
          isSubscriber: isSub,
          isNotSubscriber: isNotSub,
        );
      }

      _videoPlayerController = newVpc;
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

      // Warm handoff: dispose old ones now that new ones are ready
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
      videoError.value = true;
      rxErrorMessage.value = 'Video unavailable: $e';
    } finally {
      rxIsLoading.value = false;
    }
  }

  bool _isRecoveringFromFormatError = false;

  void _videoErrorListener() {
    try {
      if (_videoPlayerController?.value.hasError ?? false) {
        final error = _videoPlayerController?.value.errorDescription ?? '';
        debugPrint('[VideoController] ❌ Video error: $error');

        // If we are currently offline, don't show a fatal error yet,
        // just wait for connectivity listener to trigger recovery.
        if (!Get.find<ConnectivityService>().isConnected) {
          debugPrint(
            '[VideoController] ⏳ Offline during playback. Waiting for network...',
          );
          return;
        }

        // Ignore transient web race condition: play() interrupted because the
        // <video> element was removed from the DOM during re-initialization.
        // This is not a real playback failure and resolves itself.
        if (error.contains('removed from the document') ||
            error.contains('play() request was interrupted')) {
          debugPrint(
            '[VideoController] ℹ️ Ignoring transient play() interruption (DOM lifecycle)',
          );
          return;
        }

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

      // Hand off the player controller to the miniplayer
      if (_videoPlayerController != null) {
        VideoPlaybackHandoff.registerActiveController(
          video.id,
          _videoPlayerController!,
        );
      }

      // Prevent disposePlayer() from destroying the video player controller!
      _videoPlayerController = null;

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
    if (currentResolution.value?.url == res.url) return;

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

  Future<void> saveVideoOffline(VideoResolutionV2 resolution) async {
    final targetUrl = resolution.url;
    if (targetUrl.isEmpty) {
      Get.snackbar('Error', 'No video URL available to save offline.');
      return;
    }

    if (isDownloading.value) {
      Get.snackbar('Info', 'Video download is already in progress.');
      return;
    }

    isDownloading.value = true;
    downloadProgress.value = 0.0;

    try {
      final request = http.Request('GET', Uri.parse(targetUrl));
      final response = await http.Client().send(request);
      final contentLength = response.contentLength ?? 0;

      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (contentLength > 0) {
          downloadProgress.value = bytes.length / contentLength;
        }
      }

      final offlineVideo = OfflineVideo(
        id: video.id,
        title: '${video.title} (${resolution.label})',
        channelName: video.channelName,
        channelImage: video.channelImage,
        views: FormatUtils.formatCount(video.views),
        thumbnailUrl: video.thumbnailUrl,
        downloadedAt: DateTime.now(),
      );

      await saveOfflineVideoBytes(
        video.id,
        Uint8List.fromList(bytes),
        offlineVideo,
      );

      Get.snackbar(
        'Success',
        'Video saved offline successfully!',
        backgroundColor: const Color(0xFF10B981),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      debugPrint('[VideoController] Offline download error: $e');
      Get.snackbar(
        'Download Failed',
        'Could not save video offline: $e',
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
      );
    } finally {
      isDownloading.value = false;
      downloadProgress.value = 0.0;
    }
  }
}
