import 'dart:async';







import 'package:chewie/chewie.dart';



import 'package:cloud_firestore/cloud_firestore.dart';



import 'package:flutter/foundation.dart' show kIsWeb;



import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';



import 'package:get/get.dart';

import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';



import 'package:truthworld/data/models/playlist_model.dart';



import 'package:truthworld/domain/usecases/video/get_video_by_id_usecase.dart';



import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';



import 'package:truthworld/features/community/data/models/community_post_model.dart';



import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';



import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';



import 'package:truthworld/features/topics/data/models/topic.dart';



import 'package:truthworld/features/video/data/models/video.dart';



import 'package:truthworld/features/video/data/models/video_clip.dart';



import 'package:truthworld/features/video/data/repositories/firestore_video_repository.dart';



import 'package:truthworld/features/video/domain/repositories/video_repository.dart';



import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';



import 'package:truthworld/features/video/presentation/controllers/mixins/mixins.dart';
import 'package:truthworld/features/video/presentation/controllers/policies/video_playback_access_policy.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_analytics_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_engagement_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playlist_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_recommendations_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_transcript_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart'
    hide LanguageRequest;
import 'package:video_player/video_player.dart';







class VideoController extends BaseController



    with



        GetTickerProviderStateMixin,



        VideoErrorRecoveryMixin,



        VideoFactCheckMixin,



        VideoOfflineDownloadMixin,



        VideoAnalyticsTrackingMixin,



        VideoPlaylistNavigationMixin,



        VideoTrackManagementMixin,



        VideoHydrationFlowMixin,



        VideoPlaybackFlowMixin,



        VideoPlaybackEngineMixin,



        VideoEngagementActionsMixin,

        VideoDragToMiniplayerMixin



    implements VideoPlaybackAccessPolicy {



  VideoController({



    VideoRepository? videoRepository,



    GetVideoByIdUseCase? getVideoByIdUseCase,



    this.tag,



  })  : _videoRepository = videoRepository ?? FirestoreVideoRepository(),



        _getVideoByIdUseCase = getVideoByIdUseCase ??



            (Get.isRegistered<GetVideoByIdUseCase>()



                ? Get.find<GetVideoByIdUseCase>()



                : null);







  final VideoRepository _videoRepository;



  final GetVideoByIdUseCase? _getVideoByIdUseCase;



  @override
  final String? tag;







  @override



  VideoRepository get videoRepository => _videoRepository;







  @override



  Stopwatch get watchStopwatch => _watchStopwatch;







  @override



  int get lastPingWatchSeconds => _lastPingWatchSeconds;







  @override



  set lastPingWatchSeconds(int val) => _lastPingWatchSeconds = val;







  @override



  int get lastReportedWatchTime => _lastReportedWatchTime;







  @override



  set lastReportedWatchTime(int val) => _lastReportedWatchTime = val;







  @override



  bool get hasCountedQualifiedView => _hasCountedQualifiedView;







  @override



  set hasCountedQualifiedView(bool val) => _hasCountedQualifiedView = val;







  @override



  Set<String> get firedMilestones => _firedMilestones;







  @override



  set offlineBlobUrl(String? value) => _offlineBlobUrl = value;







  @override



  String get trafficSource => _trafficSource;







  @override



  set trafficSource(String val) => _trafficSource = val;







  @override



  String get viewerHash => _viewerHash;







  @override



  set viewerHash(String val) => _viewerHash = val;







  Duration get currentPosition =>



      TowerPlayerController.getForTagOrActive(video.id)?.videoPlayerController.value.position ??



      Duration.zero;







  @override
  Duration? get initialSeekPosition => _initialSeekPosition;







  @override



  set initialSeekPosition(Duration? pos) => _initialSeekPosition = pos;







  @override



  VideoPlayerController? get videoPlayerController => rxVideoPlayerController.value;







  @override



  @override
  set videoPlayerController(VideoPlayerController? c) {
    if (rxVideoPlayerController.value != c) {
      rxVideoPlayerController.value = c;
    } else {
      rxVideoPlayerController.refresh();
    }
    isPlayerInitialized.value = c?.value.isInitialized ?? false;
  }







  @override



  ChewieController? get chewieController => _chewieController;







  @override



  set chewieController(ChewieController? c) => _chewieController = c;







  @override



  StreamSubscription? get connectivitySubscription => _connectivitySubscription;







  @override



  set connectivitySubscription(StreamSubscription? s) =>



      _connectivitySubscription = s;







  @override



  StreamSubscription<DocumentSnapshot>? get videoSubscription =>



      _videoSubscription;







  @override



  set videoSubscription(StreamSubscription<DocumentSnapshot>? s) =>



      _videoSubscription = s;







  @override



  StreamSubscription? get languageRequestsSubscription =>



      _languageRequestsSubscription;



  @override



  set languageRequestsSubscription(StreamSubscription? s) =>



      _languageRequestsSubscription = s;







  @override



  Future<void> fetchRecommendations() =>



      recommendationsController.fetchRecommendations();







  Future<void> fetchVideoById(String id) async {



    if (_getVideoByIdUseCase != null) {



      final result = await _getVideoByIdUseCase(id);



      result.when(



        success: (entity) => _video.value = Video.fromEntity(entity),



        failure: (err) => setError(err.displayMessage),



      );



      return;



    }



    final result = await _videoRepository.getVideoById(id);



    result.when(



      success: (entity) => _video.value = Video.fromEntity(entity),



      failure: (err) => setError(err.displayMessage),



    );



  }







  final Rx<Video> _video = Video.empty().obs;



  @override



  Video get video => _video.value;



  @override



  set video(Video v) {



    final oldId = _video.value.id;



    _video.value = v;



    if (v.id.isNotEmpty && oldId.isNotEmpty && v.id != oldId) {



      try {



        transcriptController.resetForVideo(v.id);



      } catch (_) {}



    }



  }



  @override



  Rx<Video> get rxVideo => _video;







  @override



  bool isAlreadyWatched = false;







  @override
  bool get isChannelMember {



    try {



      return channelController.subController.isChannelMember.value;



    } catch (_) {



      return false;



    }



  }







  @override
  bool get channelHasMemberAdFreePerk {



    try {



      return channelController.selectedChannel.value?.noAdsForMembers ?? false;



    } catch (_) {



      return false;



    }



  }







  @override



  bool get hasAdFreePlayback {



    try {



      if (Get.isRegistered<AuthService>() && AuthService.to.hasFullPremium) {



        return true;



      }



      return isChannelMember && channelHasMemberAdFreePerk;



    } catch (_) {



      return false;



    }



  }







  @override



  bool get canStreamHighResolution {



    try {



      if (Get.isRegistered<AuthService>() && AuthService.to.hasFullPremium) {



        return true;



      }



      return isChannelMember && channelHasMemberAdFreePerk;



    } catch (_) {



      return false;



    }



  }







  String get _engagementTag => video.id.isNotEmpty
      ? 'video_${video.id}'
      : (tag != null ? 'video_$tag' : 'video_engagement');

  VideoEngagementController? _engagementController;
  @override
  VideoEngagementController get engagementController {
    if (_engagementController != null && !_engagementController!.isClosed) {
      return _engagementController!;
    }
    final engTag = _engagementTag;
    if (Get.isRegistered<VideoEngagementController>(tag: engTag)) {
      final ctrl = Get.find<VideoEngagementController>(tag: engTag);
      _engagementController = ctrl;
      return ctrl;
    }
    final ctrl = Get.put(VideoEngagementController(), tag: engTag);
    _engagementController = ctrl;
    return ctrl;
  }

  @override
  set engagementController(VideoEngagementController c) => _engagementController = c;







  VideoAnalyticsController? _analyticsController;
  @override
  VideoAnalyticsController get analyticsController {
    if (_analyticsController != null) return _analyticsController!;
    final effectiveTag = tag ?? (video.id.isNotEmpty ? video.id : null);
    if (effectiveTag != null && Get.isRegistered<VideoAnalyticsController>(tag: effectiveTag)) {
      final ctrl = Get.find<VideoAnalyticsController>(tag: effectiveTag);
      _analyticsController = ctrl;
      return ctrl;
    }
    if (Get.isRegistered<VideoAnalyticsController>()) {
      final ctrl = Get.find<VideoAnalyticsController>();
      _analyticsController = ctrl;
      return ctrl;
    }
    final ctrl = Get.put(VideoAnalyticsController(), tag: effectiveTag);
    _analyticsController = ctrl;
    return ctrl;
  }

  @override
  set analyticsController(VideoAnalyticsController c) => _analyticsController = c;







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



  StreamSubscription? _languageRequestsSubscription;







  VideoPlaylistController? _videoPlaylistController;
  @override
  VideoPlaylistController get videoPlaylistController {
    if (_videoPlaylistController != null) return _videoPlaylistController!;
    final effectiveTag = tag ?? (video.id.isNotEmpty ? video.id : null);
    if (effectiveTag != null && Get.isRegistered<VideoPlaylistController>(tag: effectiveTag)) {
      final ctrl = Get.find<VideoPlaylistController>(tag: effectiveTag);
      _videoPlaylistController = ctrl;
      return ctrl;
    }
    if (Get.isRegistered<VideoPlaylistController>()) {
      final ctrl = Get.find<VideoPlaylistController>();
      _videoPlaylistController = ctrl;
      return ctrl;
    }
    final ctrl = Get.put(VideoPlaylistController(), tag: effectiveTag);
    _videoPlaylistController = ctrl;
    return ctrl;
  }

  set videoPlaylistController(VideoPlaylistController c) => _videoPlaylistController = c;







  // Playlist Support (Delegated)



  @override



  Rx<PlaylistModel?> get currentPlaylist => videoPlaylistController.currentPlaylist;



  @override



  RxList<Video> get playlistVideos => videoPlaylistController.playlistVideos;



  @override



  RxInt get currentPlaylistIndex => videoPlaylistController.currentPlaylistIndex;



  RxBool get isPlaylistLooping => videoPlaylistController.isPlaylistLooping;



  @override



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



  @override



  final Rx<VideoClip?> activeClip = Rx<VideoClip?>(null);



  Duration? _initialSeekPosition;







  // State variables



  @override



  final RxBool isDownloading = false.obs;



  @override



  final RxDouble downloadProgress = 0.0.obs;



  @override



  RxBool get isSubscribed => engagementController.isSubscribed;



  RxBool get isLiked => engagementController.isLiked;



  RxBool get isDisliked => engagementController.isDisliked;



  final RxBool isExpanded = false.obs;



  VideoTranscriptController? _transcriptController;
  @override
  VideoTranscriptController get transcriptController {
    if (_transcriptController != null) return _transcriptController!;
    final effectiveTag = tag ?? (video.id.isNotEmpty ? video.id : null);
    if (effectiveTag != null && Get.isRegistered<VideoTranscriptController>(tag: effectiveTag)) {
      final ctrl = Get.find<VideoTranscriptController>(tag: effectiveTag);
      _transcriptController = ctrl;
      return ctrl;
    }
    if (Get.isRegistered<VideoTranscriptController>()) {
      final ctrl = Get.find<VideoTranscriptController>();
      _transcriptController = ctrl;
      return ctrl;
    }
    final ctrl = Get.put(VideoTranscriptController(), tag: effectiveTag);
    _transcriptController = ctrl;
    return ctrl;
  }
  @override
  set transcriptController(VideoTranscriptController c) => _transcriptController = c;



  RxBool get isTranscriptVisible => transcriptController.isTranscriptVisible;



  RxList<SubtitleSegment> get transcriptSegments => transcriptController.transcriptSegments;



  RxBool get isLoadingTranscript => transcriptController.isLoadingTranscript;



  RxBool get isSummaryVisible => transcriptController.isSummaryVisible;



  RxString get moderationSummary => transcriptController.moderationSummary;



  RxBool get isLoadingSummary => transcriptController.isLoadingSummary;



  @override



  final RxBool rxIsLoading = true.obs;



  RxBool get isLoadingRx => rxIsLoading;



  @override



  bool get isLoading => rxIsLoading.value || super.isLoading;







  @override



  final RxBool videoError = false.obs;



  @override



  final RxBool showThumbnail = true.obs;



  @override



  final RxBool isAutoplay = true.obs;



  @override



  final RxBool isPlayingRx = false.obs;



  @override



  final RxBool navigatedFromPlaylist = false.obs;



  @override
  final RxBool navigatedFromTopic = false.obs;

  @override
  final Rx<Topic?> currentTopic = Rx<Topic?>(null);



  RxBool get isAutoplayEnabled => isAutoplay; // Alias for UI consistency







  @override



  final RxString rxErrorMessage = ''.obs;



  RxString get errorMessageRx => rxErrorMessage;



  @override



  String get errorMessage => rxErrorMessage.value.isNotEmpty



      ? rxErrorMessage.value



      : super.errorMessage;







  final RxInt selectedIndex = 0.obs;



  final RxBool isFullScreen = false.obs;

  void exitFullscreen() {
    isFullScreen.value = false;
    try {
      if (video.id.isNotEmpty &&
          Get.isRegistered<TowerPlayerController>(tag: video.id)) {
        final tpc = Get.find<TowerPlayerController>(tag: video.id);
        if (tpc.isFullScreen.value) {
          tpc.toggleFullscreen();
        }
      }
    } catch (_) {}
  }



  final RxInt mobileTabIndex = 0.obs;



  final RxInt desktopTabIndex = 0.obs;



  final RxBool isActivePage = true.obs;







  // Quality & Resolutions



  @override



  final RxList<VideoResolutionV2> availableResolutions =



      <VideoResolutionV2>[].obs;



  @override
  final Rx<VideoResolutionV2?> currentResolution = Rx<VideoResolutionV2?>(null);

  @override
  final RxSet<String> blacklistedStreamUrls = <String>{}.obs;



  @override



  final RxList<SubtitleTrack> availableSubtitles = <SubtitleTrack>[].obs;



  @override
  final RxList<AudioTrack> availableAudioTracks = <AudioTrack>[].obs;

  @override
  final RxList<VideoTrack> availableVideoTracks = <VideoTrack>[].obs;

  @override
  final Rx<VideoTrack?> activeVideoTrack = Rx<VideoTrack?>(null);



  @override



  final RxBool isAudioOnly = false.obs;







  // Analytics & View Tracking



  final Stopwatch _watchStopwatch = Stopwatch();



  bool _hasCountedQualifiedView = false;



  int _lastReportedWatchTime = 0;



  int _lastPingWatchSeconds = 0;



  @override



  final RxBool isSwitchingResolution = false.obs;



  @override



  final RxBool isAutoSwitching = false.obs;







  @override



  final RxBool rxIsOffline = false.obs;



  RxBool get isOfflineRx => rxIsOffline;



  @override



  bool get isOffline => rxIsOffline.value || super.isOffline;



  String? _offlineBlobUrl;



  @override



  String? get offlineBlobUrl => _offlineBlobUrl;



  StreamSubscription? _connectivitySubscription;







  // Milestone tracking — only fire each milestone once per session



  final Set<String> _firedMilestones = {};



  



  



  







  // Traffic source for this viewing session



  String _trafficSource = 'direct';







  // Viewer identity (for anonymous dedup)



  String _viewerHash = '';







  // Total watch time for this session (seconds)



  int get watchTimeSeconds => analyticsController.watchTimeSeconds;







  // Recommendations Cache (Delegated to VideoRecommendationsController)



  VideoRecommendationsController? _recommendationsController;
  @override
  VideoRecommendationsController get recommendationsController {
    if (_recommendationsController != null) return _recommendationsController!;
    final effectiveTag = tag ?? (video.id.isNotEmpty ? video.id : null);
    if (effectiveTag != null && Get.isRegistered<VideoRecommendationsController>(tag: effectiveTag)) {
      final ctrl = Get.find<VideoRecommendationsController>(tag: effectiveTag);
      _recommendationsController = ctrl;
      return ctrl;
    }
    if (Get.isRegistered<VideoRecommendationsController>()) {
      final ctrl = Get.find<VideoRecommendationsController>();
      _recommendationsController = ctrl;
      return ctrl;
    }
    final ctrl = Get.put(
      VideoRecommendationsController(
        getVideo: () => video,
        getCurrentPlaylist: () => currentPlaylist.value,
        getPlaylistVideos: () => playlistVideos,
        getCurrentTopic: () => currentTopic.value,
        getTopicVideos: () => currentTopic.value != null
            ? (recommendationsController.topicVideosCache[currentTopic.value!.id] ??
                <Video>[])
            : <Video>[],
        getNavigatedFromTopic: () => navigatedFromTopic.value,
        getNavigatedFromPlaylist: () => navigatedFromPlaylist.value,
      ),
      tag: effectiveTag,
    );
    _recommendationsController = ctrl;
    return ctrl;
  }
  @override
  set recommendationsController(VideoRecommendationsController c) => _recommendationsController = c;



  @override



  RxList<Video> get recommendedVideos => recommendationsController.recommendedVideos;



  RxList<CommunityPostModel> get communityPosts => recommendationsController.communityPosts;



  RxList<Video> get moreFromChannel => recommendationsController.moreFromChannel;
  RxList<Video> get flipVideos => recommendationsController.flipVideos;
  bool get hasFlipCoinVideos => recommendationsController.hasFlipCoinVideos;
  bool hasVideosForTag(String tagOrCategory) =>
      recommendationsController.hasVideosForTag(tagOrCategory);



  RxBool get isLoadingRecommendations => recommendationsController.isLoadingRecommendations;
  RxBool get isTabLoading => recommendationsController.isTabLoading;
  Future<void> ensureFilterVideosLoaded(String filter) =>
      recommendationsController.ensureFilterVideosLoaded(filter);



  RxString get selectedRecommendationFilter => recommendationsController.selectedRecommendationFilter;



  RxInt get recommendationActiveTab => recommendationsController.recommendationActiveTab;



  RxList<Topic> get videoTopicsList => recommendationsController.videoTopicsList;



  RxList<PlaylistModel> get videoPlaylistsList => recommendationsController.videoPlaylistsList;



  RxMap<String, List<Video>> get topicVideosCache => recommendationsController.topicVideosCache;



  RxMap<String, List<Video>> get playlistVideosCache => recommendationsController.playlistVideosCache;

  RxMap<String, List<Video>> get tagVideosCache => recommendationsController.tagVideosCache;

  Future<List<Video>> fetchChannelVideos({
    bool setTabLoading = false,
    bool forceRefresh = false,
  }) =>
      recommendationsController.fetchChannelVideos(
        setTabLoading: setTabLoading,
        forceRefresh: forceRefresh,
      );



  List<dynamic> get recommendedItems => recommendationsController.recommendedItems;



  List<String> get recommendationFilters => recommendationsController.recommendationFilters;



  List<Video> get filteredRecommendedVideos => recommendationsController.filteredRecommendedVideos;







  // Controllers



  TabController? _mobileTabController;
  TabController get mobileTabController => _mobileTabController ??= TabController(length: 2, vsync: this);
  set mobileTabController(TabController c) => _mobileTabController = c;

  TabController? _desktopTabController;
  TabController get desktopTabController => _desktopTabController ??= TabController(length: 2, vsync: this);
  set desktopTabController(TabController c) => _desktopTabController = c;



  final ScrollController scrollController = ScrollController();



  @override
  final Rx<VideoPlayerController?> rxVideoPlayerController = Rx<VideoPlayerController?>(null);

  @override
  final RxBool isPlayerInitialized = false.obs;



  ChewieController? _chewieController;







  ChannelController? _channelController;
  @override
  ChannelController get channelController {
    if (_channelController != null) return _channelController!;
    if (tag != null && Get.isRegistered<ChannelController>(tag: tag)) {
      final ctrl = Get.find<ChannelController>(tag: tag);
      _channelController = ctrl;
      return ctrl;
    }
    if (Get.isRegistered<ChannelController>()) {
      final ctrl = Get.find<ChannelController>();
      _channelController = ctrl;
      return ctrl;
    }
    final ctrl = Get.put(ChannelController(), tag: tag);
    _channelController = ctrl;
    return ctrl;
  }

  @override
  set channelController(ChannelController c) => _channelController = c;



  @override



  MainController get mainController => Get.isRegistered<MainController>()



      ? Get.find<MainController>()



      : Get.put(MainController(), permanent: true);



  PlaylistController get playlistController =>



      Get.isRegistered<PlaylistController>()



      ? Get.find<PlaylistController>()



      : Get.put(PlaylistController());



  CommentsController? _commentsController;
  @override
  CommentsController get commentsController {
    if (_commentsController != null) return _commentsController!;
    final commentsTag = 'video_${video.id}';
    if (Get.isRegistered<CommentsController>(tag: commentsTag)) {
      final ctrl = Get.find<CommentsController>(tag: commentsTag);
      _commentsController = ctrl;
      return ctrl;
    }
    if (Get.isRegistered<CommentsController>()) {
      final ctrl = Get.find<CommentsController>();
      _commentsController = ctrl;
      return ctrl;
    }
    final ctrl = Get.put(CommentsController(), tag: commentsTag);
    _commentsController = ctrl;
    return ctrl;
  }

  @override
  set commentsController(CommentsController c) => _commentsController = c;



  StreamSubscription<DocumentSnapshot>? _videoSubscription;
  Worker? _memberUnlockWorker;
  Worker? _subUnlockWorker;







  @override



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
    initDragToMiniplayer();



    final effectiveTag = tag ?? (video.id.isNotEmpty ? video.id : null);



    videoPlaylistController = Get.isRegistered<VideoPlaylistController>(tag: effectiveTag)



        ? Get.find<VideoPlaylistController>(tag: effectiveTag)



        : Get.put(VideoPlaylistController(), tag: effectiveTag);



    transcriptController = Get.isRegistered<VideoTranscriptController>(tag: effectiveTag)



        ? Get.find<VideoTranscriptController>(tag: effectiveTag)



        : Get.put(VideoTranscriptController(), tag: effectiveTag);



    recommendationsController = Get.isRegistered<VideoRecommendationsController>(tag: effectiveTag)



        ? Get.find<VideoRecommendationsController>(tag: effectiveTag)



        : Get.put(



            VideoRecommendationsController(



              getVideo: () => video,
              getCurrentPlaylist: () => currentPlaylist.value,
              getPlaylistVideos: () => playlistVideos,
              getCurrentTopic: () => currentTopic.value,
              getTopicVideos: () => currentTopic.value != null
                  ? (recommendationsController.topicVideosCache[currentTopic.value!.id] ??
                      <Video>[])
                  : <Video>[],
              getNavigatedFromTopic: () => navigatedFromTopic.value,
              getNavigatedFromPlaylist: () => navigatedFromPlaylist.value,
            ),



            tag: effectiveTag,



          );















    setupConnectivityListener();







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







    void startInitialHydration() {
      if (isClosed) return;
  
      if (Get.arguments?['isAudioOnly'] == true) {
        isAudioOnly.value = true;
      } else {
        isAudioOnly.value = false;
        TowerPlayerPreferences.globalAudioOnly = false;
      }
      parseAndHydrateInitialVideo();
    }

    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        startInitialHydration();
      });
    } else {
      startInitialHydration();
    }

    _memberUnlockWorker = ever(channelController.subController.isChannelMember, (isMember) {
      if (isMember && video.isMembersOnly && !isPlayerInitialized.value) {
        debugPrint('[VideoController] 🔓 Channel membership unlocked: Starting playback');
        startPlaybackFlow();
      }
    });

    _subUnlockWorker = ever(channelController.subController.isSubscribed, (isSub) {
      if (isSub && video.isSubscribersOnly && !isPlayerInitialized.value) {
        debugPrint('[VideoController] 🔓 Channel subscription unlocked: Starting playback');
        startPlaybackFlow();
      }
    });
  }







  // Claim Verification & Fact Checking



  @override



  final RxMap<String, dynamic> factCheckData = <String, dynamic>{}.obs;



  @override



  final RxBool isLoadingFactCheck = false.obs;







  @override



  void onClose() {

    disposeDragToMiniplayer();

    handoffToMiniplayerOrDispose();



    try {



      mobileTabController.dispose();



      desktopTabController.dispose();



      scrollController.dispose();



    } catch (_) {}



    _connectivitySubscription?.cancel();



    _languageRequestsSubscription?.cancel();



    _videoSubscription?.cancel();
    _memberUnlockWorker?.dispose();
    _subUnlockWorker?.dispose();



    if (kIsWeb && _offlineBlobUrl != null && _offlineBlobUrl!.startsWith('blob:')) {



      WebPlatformUtils.revokeBlobUrl(_offlineBlobUrl!);



    }



    final effectiveTag = tag ?? (video.id.isNotEmpty ? video.id : null);



    if (Get.isRegistered<TowerPlayerController>(tag: video.id)) {



      Get.delete<TowerPlayerController>(tag: video.id, force: true);



    }



    final commentsTag = 'video_${video.id}';



    if (Get.isRegistered<CommentsController>(tag: commentsTag)) {
      Get.delete<CommentsController>(tag: commentsTag, force: true);
    }

    final engTag = _engagementTag;
    if (Get.isRegistered<VideoEngagementController>(tag: engTag)) {
      Get.delete<VideoEngagementController>(tag: engTag, force: true);
    }



    if (effectiveTag != null) {



      if (Get.isRegistered<VideoPlaylistController>(tag: effectiveTag)) {



        Get.delete<VideoPlaylistController>(tag: effectiveTag, force: true);



      }



      if (Get.isRegistered<VideoTranscriptController>(tag: effectiveTag)) {



        Get.delete<VideoTranscriptController>(tag: effectiveTag, force: true);



      }



      if (Get.isRegistered<VideoRecommendationsController>(tag: effectiveTag)) {



        Get.delete<VideoRecommendationsController>(tag: effectiveTag, force: true);



      }



    } else {



      if (Get.isRegistered<VideoRecommendationsController>()) {



        Get.delete<VideoRecommendationsController>(force: true);



      }



    }



    _watchStopwatch.stop();



    super.onClose();



  }



}



