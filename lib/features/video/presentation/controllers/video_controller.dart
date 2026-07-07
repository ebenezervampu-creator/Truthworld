import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:universal_html/html.dart' as html;
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/presentation/controllers/custom_play.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_birate_controller.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/features/analytics/data/services/viewer_identity_service.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check_report_widget.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'dart:typed_data';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/features/video/domain/database_helpers.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';


class VideoController extends GetxController with GetTickerProviderStateMixin {
  final Rx<Video> _video = Video.empty().obs;
  Video get video => _video.value;

  final RxList<LanguageRequest> languageRequests = <LanguageRequest>[].obs;
  final RxBool isLoadingLanguageRequests = false.obs;
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
    (recommendedVideos.indexWhere((v) => v.id == video.id) < recommendedVideos.length - 1 &&
     recommendedVideos.isNotEmpty);

  // Clips Support
  final Rx<VideoClip?> activeClip = Rx<VideoClip?>(null);

  // State variables
  final RxBool isDownloading = false.obs;
  final RxDouble downloadProgress = 0.0.obs;
  final RxBool isSubscribed = false.obs;
  final RxBool isLiked = false.obs;
  final RxBool isDisliked = false.obs;
  final RxBool isExpanded = false.obs;
  final RxBool isLoading = true.obs;
  final RxBool videoError = false.obs;
  final RxBool showThumbnail = true.obs;
  final RxBool isAutoplay = true.obs;
  RxBool get isAutoplayEnabled => isAutoplay; // Alias for UI consistency
  final RxString errorMessage = ''.obs;
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
  final RxBool isOffline = false.obs;
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
  int get watchTimeSeconds => _watchStopwatch.elapsed.inSeconds;

  // Recommendations Cache
  final RxList<Video> recommendedVideos = <Video>[].obs;
  final RxList<Video> moreFromChannel = <Video>[].obs;
  final RxBool isLoadingRecommendations = true.obs;
  final RxString selectedRecommendationFilter = 'All'.obs;

  List<String> get recommendationFilters {
    final list = ['All'];
    if (video.channelName.isNotEmpty) {
      list.add('From ${video.channelName}');
    }
    if (video.tags.isNotEmpty) {
      list.addAll(video.tags.take(3));
    } else if (video.category.isNotEmpty) {
      list.add(video.category);
    }
    return list;
  }

  List<Video> get filteredRecommendedVideos {
    final filter = selectedRecommendationFilter.value;
    if (filter == 'All') {
      return recommendedVideos;
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

  late final ChannelController channelController;
  final MainController mainController = Get.find<MainController>();
  final PlaylistController playlistController = Get.find<PlaylistController>();
  late CommentsController commentsController;
  StreamSubscription<DocumentSnapshot>? _videoSubscription;

  bool get isAuthenticated => AuthService.to.isAuthenticated.value;
  String? get userPhotoUrl => AuthService.to.user?.photoURL;

  @override
  void onInit() {
    super.onInit();
    isOffline.value = Get.arguments?['isOffline'] ?? false;
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
      errorMessage.value = "No arguments found";
      isLoading.value = false;
      return;
    }

    // Handle Playlist argument
    if (Get.arguments["playlist"] != null) {
      currentPlaylist.value = Get.arguments["playlist"] as PlaylistModel;
    }

    // Handle Video argument
    if (Get.arguments["video"] != null) {
      _video.value = Get.arguments["video"] as Video;
    } else if (currentPlaylist.value != null && currentPlaylist.value!.videoIds.isNotEmpty) {
      _fetchFirstPlaylistVideo(currentPlaylist.value!.videoIds.first);
      return;
    } else {
      videoError.value = true;
      errorMessage.value = "Video data not found";
      isLoading.value = false;
      return;
    }
    
    _initializeAllMetadata();

    // Strict Enforcement: Start playback
    _startPlaybackFlow();

    // Check if we are playing a specific clip
    if (Get.arguments != null && Get.arguments["clip"] != null) {
      activeClip.value = Get.arguments["clip"] as VideoClip;
      debugPrint(
        '[VideoController] 🎬 Starting in Clip Mode: ${activeClip.value?.title}',
      );
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Get.find<ConnectivityService>()
        .onConnectivityChanged
        .listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        debugPrint('[VideoController] 🌐 Internet restored. Refreshing metadata...');
        _initializeAllMetadata();
        
        // AUTO-RECOVERY: If the video player is in an error state or stalled, try to recover
        if (videoError.value || (_videoPlayerController != null && !_videoPlayerController!.value.isInitialized)) {
          debugPrint('[VideoController] 🚀 Attempting playback recovery...');
          attemptRecovery();
        }
      }
    });
  }

  void _initializeAllMetadata() {
    final connectivity = Get.find<ConnectivityService>();
    final bool hasInternet = connectivity.isConnected;

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
      _initializeCommentsController();
      _listenToVideoUpdates();
      _listenToLanguageRequests();
    } else if (isOffline.value) {
      isLoading.value = false;
    }
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
    if (isOffline.value) {
      await _initializeOfflinePlayback();
      return;
    }

    final mediaService = VideoMediaService();

    // 1. Kick off all metadata loading concurrently in the background
    final Future<void> metadataFuture = Future.wait([
      mediaService.getLocalization(video.id),
      mediaService.getCredibility(video.id),
      fetchAvailableResolutions(),
      fetchAvailableSubtitles(),
      fetchAvailableAudioTracks(),
    ]);

    // 2. Identify initial playback URL immediately from video model to prevent startup latency
    String? initialUrl;
    if (video.hlsUrl.isNotEmpty) {
      initialUrl = video.hlsUrl;
    } else if (video.videoUrl.isNotEmpty) {
      initialUrl = video.videoUrl;
    } else if (video.originalUrl.isNotEmpty) {
      initialUrl = video.originalUrl;
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
        errorMessage.value =
            "Video is still processing. Please check back later.";
        isLoading.value = false;
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
    isLoading.value = true;
    try {
      final bytes = await getVideoBytes(video.id);
      if (bytes == null) {
        throw Exception("Offline video content not found");
      }
      final blob = html.Blob([bytes], 'video/mp4');
      _offlineBlobUrl = html.Url.createObjectUrl(blob);
      
      // Create a dummy resolution for the UI
      availableResolutions.assignAll([
        VideoResolutionV2(
          label: "Offline",
          url: _offlineBlobUrl!,
          width: 0,
          height: 0,
          bitrate: 0,
        )
      ]);
      currentResolution.value = availableResolutions.first;

      await initializeVideoPlayer(overrideUrl: _offlineBlobUrl);
    } catch (e) {
      debugPrint('[VideoController] ❌ Offline init error: $e');
      videoError.value = true;
      errorMessage.value = "Failed to load offline video";
    } finally {
      isLoading.value = false;
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

          final List<Future<VideoResolutionV2?>> fetchTasks = [];

          for (var entry in variants.entries) {
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
                    label: label,
                    url: url,
                    width: variantData['width'] ?? 0,
                    height: variantData['height'] ?? 0,
                    bitrate: variantData['bitrateKbps'] ?? 0,
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
          final List<VideoResolutionV2> found = results
              .whereType<VideoResolutionV2>()
              .toList();

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
      debugPrint("[VideoController] 🔥 Error fetching resolutions: $e");
    }
  }

  Future<void> fetchAvailableSubtitles() async {
    try {
      final subs = video.mediaSubtitles;
      if (subs.isEmpty) {
        debugPrint('[VideoController] ℹ️ No subtitles found in video metadata');
        return;
      }

      final List<Future<SubtitleTrack?>> fetchTasks = [];

      for (var entry in subs.entries) {
        final langCode = entry.key;
        final pathOrUrl = entry.value;

        fetchTasks.add(() async {
          try {
            String url = pathOrUrl;
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
            final label = lang?.name ?? langCode.toUpperCase();

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
      final tracks = video.audioTracks;
      final List<Future<AudioTrack?>> fetchTasks = [];

      // Add original track
      fetchTasks.add(
        Future.value(
          AudioTrack(
            label:
                'Original (${supportedLanguages.firstWhereOrNull((l) => l.code == video.language)?.name ?? video.language.toUpperCase()})',
            langCode: video.language,
            type: 'Original',
            url: null, // Original uses the video resolution URL
          ),
        ),
      );

      for (var entry in tracks.entries) {
        final langCode = entry.key;
        final pathOrUrl = entry.value;

        fetchTasks.add(() async {
          try {
            String url = pathOrUrl;
            if (pathOrUrl.startsWith('gs://')) {
              url = await FirebaseStorage.instance
                  .refFromURL(pathOrUrl)
                  .getDownloadURL();
            }

            final lang = supportedLanguages.firstWhereOrNull(
              (l) => l.code == langCode,
            );
            final label = lang?.name ?? langCode.toUpperCase();

            return AudioTrack(
              label: label,
              langCode: langCode,
              type: 'Dubbed',
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

      final results = await Future.wait(fetchTasks);
      final found = results.whereType<AudioTrack>().toList();
      availableAudioTracks.assignAll(found);

      debugPrint('[VideoController] ✅ Loaded ${found.length} audio tracks');
    } catch (e) {
      debugPrint('[VideoController] 🔥 Error fetching audio tracks: $e');
    }
  }

  void _initializeCommentsController() {
    final tag = 'video_${video.id}';
    if (!Get.isRegistered<CommentsController>(tag: tag)) {
      Get.put(CommentsController(video: video, isOffline: isOffline.value), tag: tag);
    }
  }

  void videoListener() {
    if (_videoPlayerController == null) return;
    final value = _videoPlayerController!.value;

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

    // Manage thumbnail overlay
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
    final towerPlayerController = Get.isRegistered<TowerPlayerController>(tag: video.id)
        ? Get.find<TowerPlayerController>(tag: video.id)
        : null;

    final bool shouldLoop = towerPlayerController?.isLooping.value ?? false;
    final bool shouldAutoplayNext =
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
    Get.offNamed('/watch?v=${nextVideo.id}', arguments: {
      'video': nextVideo,
      'playlist': currentPlaylist.value,
    });
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
        CommentsController(video: prevVideo, isOffline: false),
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
      Get.offNamed('/watch?v=${prevVideo.id}', arguments: {
        'video': prevVideo,
        'playlist': currentPlaylist.value,
      });
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
          .collection('users')
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
            'views': video.views,
            'likeCount': video.likeCount,
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
    final userId = AuthService.to.uid;
    if (userId.isEmpty) return;

    try {
      final futures = await Future.wait([
        FirebaseFirestore.instance
            .collection('videos')
            .doc(video.id)
            .collection('likes')
            .doc(userId)
            .getCacheFirst(),
        FirebaseFirestore.instance
            .collection('videos')
            .doc(video.id)
            .collection('dislikes')
            .doc(userId)
            .getCacheFirst(),
        FirebaseFirestore.instance
            .collection('channels')
            .doc(video.channelId)
            .getCacheFirst(),
      ]);

      final likeDoc = futures[0];
      final dislikeDoc = futures[1];
      final channelDoc = futures[2];

      isLiked.value = likeDoc.exists;
      isDisliked.value = dislikeDoc.exists;

      if (channelDoc.exists) {
        final data = channelDoc.data();
        isSubscribed.value =
            (data?['subscribers'] as List?)?.contains(userId) ?? false;
      }
    } catch (e) {
      if (!e.toString().contains('permission-denied')) {
        debugPrint("Error checking user interactions: $e");
      }
    }
  }

  void _listenToVideoUpdates() {
    FirebaseFirestore.instance
        .collection('videos')
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
        }).catchError((e) {
          debugPrint('[VideoController] Error fetching video updates: $e');
        });
  }

  void _listenToLanguageRequests() {
    isLoadingLanguageRequests.value = true;
    FirebaseFirestore.instance
        .collection('videos')
        .doc(video.id)
        .collection('language_requests')
        .get()
        .then((snapshot) {
          final List<LanguageRequest> requests = snapshot.docs.map((doc) {
            return LanguageRequest.fromMap(doc.data(), doc.id);
          }).toList();
          languageRequests.assignAll(requests);
          isLoadingLanguageRequests.value = false;
        }).catchError((e) {
          debugPrint('Error fetching language requests: $e');
          isLoadingLanguageRequests.value = false;
        });
  }

  Future<void> submitLanguageRequest({required String language, required String type}) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) {
      Get.snackbar('Authentication Required', 'Please sign in to request a language.');
      return;
    }
    
    try {
      final docId = '${video.id}_${type}_${language.replaceAll(' ', '_')}';
      final ref = FirebaseFirestore.instance
          .collection('videos')
          .doc(video.id)
          .collection('language_requests')
          .doc(docId);
          
      await ref.set({
        'language': language,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
      });
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
  final RxMap factCheckData = {}.obs;
  final RxBool isLoadingFactCheck = false.obs;

  Future<void> fetchFullDisclosure() async {
    if (video.factCheckUrl.isEmpty) {
      Get.snackbar(
        'Disclosure Unavailable',
        'Detailed fact-checking data is not available for this video.',
        backgroundColor: Colors.black87,
        colorText: Colors.white,
      );
      return;
    }

    isLoadingFactCheck.value = true;
    try {
      String url = video.factCheckUrl;
      if (url.startsWith('gs://')) {
        url = await FirebaseStorage.instance.refFromURL(url).getDownloadURL();
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        factCheckData.value = jsonDecode(response.body);
        _showFullDisclosurePanel();
      } else {
        throw Exception("Failed to load fact-check data");
      }
    } catch (e) {
      debugPrint('[VideoController] ❌ Error fetching fact check: $e');
      Get.snackbar(
        'Error',
        'Could not load fact-checking report.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
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
    isLoadingRecommendations.value = true;
    try {
      final String videoId = video.id;

      // 1. If we are in a playlist, fetch other videos from the playlist
      if (currentPlaylist.value != null) {
        final playlistVideoIds = currentPlaylist.value!.videoIds
            .where((id) => id != videoId)
            .take(15)
            .toList();

        if (playlistVideoIds.isNotEmpty) {
          final playlistVidsQuery = await FirebaseFirestore.instance
              .collection('videos')
              .where(FieldPath.documentId, whereIn: playlistVideoIds)
              .get();

          final playlistVideos = playlistVidsQuery.docs
              .map((d) => Video.fromDocumentSnapshot(d))
              .toList();

          // Sort them to match playlist order if possible
          playlistVideos.sort((a, b) {
            final indexA = currentPlaylist.value!.videoIds.indexOf(a.id);
            final indexB = currentPlaylist.value!.videoIds.indexOf(b.id);
            return indexA.compareTo(indexB);
          });

          recommendedVideos.value = playlistVideos;
          moreFromChannel.value = playlistVideos; // In playlist mode, they are the same
          return;
        }
      }

      // 2. Normal recommendations logic
      final String channelId = video.channelId;

      // Single efficient fetch for channel videos
      final channelVidsQuery = await FirebaseFirestore.instance
          .collection('videos')
          .where('channelId', isEqualTo: channelId)
          .where(FieldPath.documentId, isNotEqualTo: videoId)
          .limit(10)
          .get();

      final channelVideos = channelVidsQuery.docs
          .map((d) => Video.fromDocumentSnapshot(d))
          .toList();

      // Fill the rest with general videos
      final generalVidsQuery = await FirebaseFirestore.instance
          .collection('videos')
          .where(FieldPath.documentId, isNotEqualTo: videoId)
          .limit(20)
          .get();

      final generalVideos = generalVidsQuery.docs
          .map((d) => Video.fromDocumentSnapshot(d))
          .where((v) => v.id != videoId && !channelVideos.any((cv) => cv.id == v.id))
          .toList();

      moreFromChannel.value = channelVideos;
      recommendedVideos.value = {...channelVideos, ...generalVideos}.toList();
    } catch (e) {
      debugPrint("Error fetching recommendations: $e");
    } finally {
      isLoadingRecommendations.value = false;
    }
  }

  Future<void> _fetchFirstPlaylistVideo(String videoId) async {
    isLoading.value = true;
    try {
      final doc = await FirebaseFirestore.instance.collection('videos').doc(videoId).get();
      if (doc.exists) {
        _video.value = Video.fromDocumentSnapshot(doc);
        _continueInitialization();
        // Also fetch the entire playlist for the drawer
        fetchPlaylistVideos();
      } else {
        videoError.value = true;
        errorMessage.value = "First video of playlist not found";
      }
    } catch (e) {
      videoError.value = true;
      errorMessage.value = "Error fetching first video: $e";
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchPlaylistVideos() async {
    if (currentPlaylist.value == null || currentPlaylist.value!.videoIds.isEmpty) return;
    
    try {
      final ids = currentPlaylist.value!.videoIds;
      List<Video> fetchedVideos = [];
      
      // Firestore 'whereIn' supports max 10 items. Chunking:
      for (int i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final snapshot = await FirebaseFirestore.instance
            .collection('videos')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        fetchedVideos.addAll(snapshot.docs.map((d) => Video.fromDocumentSnapshot(d)));
      }
      
      // Restore original playlist order
      fetchedVideos.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
      
      playlistVideos.value = fetchedVideos;

      int activeIndex = fetchedVideos.indexWhere((v) => v.id == video.id);
      currentPlaylistIndex.value = activeIndex != -1 ? activeIndex : 0;
      
    } catch (e) {
      debugPrint("Error fetching full playlist videos: $e");
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
      CommentsController(video: nextVideo, isOffline: false),
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
    final bool isAuto = isAutoSwitching.value;

    if (!isAuto) {
      isLoading.value = true;
      disposePlayer();
    }

    videoError.value = false;
    showThumbnail.value = true;

    try {
      // Validate video URL
      final targetUrl = overrideUrl;
      if (targetUrl == null || targetUrl.isEmpty) {
        throw Exception("No optimized video resolution available");
      }

      debugPrint('[VideoController] Initializing player for: $targetUrl');

      final oldVpc = _videoPlayerController;
      final oldCc = _chewieController;

      // Attempt to retrieve a pre-warmed/hovered controller for zero-latency startup
      VideoPlayerController? handoffVpc = VideoPlaybackHandoff.retrieveController(video.id);
      final VideoPlayerController newVpc;
      final bool wasHandoff = handoffVpc != null;

      if (wasHandoff) {
        debugPrint('[VideoController] Found active handoff controller for: ${video.id}');
        newVpc = handoffVpc;
        await newVpc.setLooping(false); // Disable looping which was enabled for hover previews
        await newVpc.setVolume(1.0); // Reset volume to unmute on watch screen
      } else {
        newVpc = (isOffline.value && targetUrl.startsWith('blob:'))
            ? VideoPlayerController.networkUrl(Uri.parse(targetUrl))
            : VideoPlayerController.networkUrl(
                Uri.parse(targetUrl),
                videoPlayerOptions: VideoPlayerOptions(
                  mixWithOthers: false,
                  allowBackgroundPlayback: false,
                ),
              );
      }

      // Add listeners BEFORE initialization to catch all events
      newVpc.addListener(_videoErrorListener);
      newVpc.addListener(videoListener);

      if (!wasHandoff) {
        await newVpc.initialize().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception("Video initialization timeout");
          },
        );
      }

      // --- RESUME LOGIC ---
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
            child: const Text('Start Over', style: TextStyle(color: Colors.redAccent)),
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.black.withValues(alpha: 0.7),
          colorText: Colors.white,
        );
      }

      // Track initiation
      if (!isAuto) {
        final isSub = isSubscribed.value;
        final isNotSub = !isSub;
        // Start stopwatch immediately for accurate tracking from second 0
        if (!_watchStopwatch.isRunning) _watchStopwatch.start();

        mainController.trackWatchEvent(
          videoId: video.id,
          eventType: "video_start",
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
        looping: false,
        allowMuting: true,
        showControls: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio.isFinite
            ? _videoPlayerController!.value.aspectRatio
            : 16 / 9,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey.withValues(alpha: 0.5),
          bufferedColor: Colors.white.withValues(alpha: 0.3),
        ),
        customControls: TowerCustomPlayer(tag: video.id),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Video playback error',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => initializeVideoPlayer(),
                  icon: Icon(Icons.refresh),
                  label: Text('Retry'),
                ),
              ],
            ),
          );
        },
        // Add fullscreen listener
        fullScreenByDefault: false,
        allowFullScreen: true,
      );

      // Listen for fullscreen changes from Chewie
      _chewieController!.addListener(_onChewieEvent);

      // Warm handoff: dispose old ones now that new ones are ready
      if (isAuto && oldVpc != null) {
        oldVpc.removeListener(_videoErrorListener);
        oldVpc.removeListener(videoListener);
        oldCc?.removeListener(_onChewieEvent);
        oldCc?.dispose();
        oldVpc.dispose();
      }

      debugPrint(
        '[VideoController] Player initialized successfully (Handoff: $isAuto)',
      );
    } catch (e, stackTrace) {
      debugPrint("[VideoController] Playback Error: $e");
      debugPrint("[VideoController] Stack trace: $stackTrace");
      videoError.value = true;
      errorMessage.value = "Video unavailable: ${e.toString()}";
    } finally {
      isLoading.value = false;
    }
  }

  void _videoErrorListener() {
    if (_videoPlayerController?.value.hasError == true) {
      final error = _videoPlayerController?.value.errorDescription;
      debugPrint('[VideoController] ❌ Video error: $error');
      
      // If we are currently offline, don't show a fatal error yet, 
      // just wait for connectivity listener to trigger recovery.
      if (!Get.find<ConnectivityService>().isConnected) {
        debugPrint('[VideoController] ⏳ Offline during playback. Waiting for network...');
        return; 
      }

      videoError.value = true;
      errorMessage.value = error ?? "Unknown playback error";
    }
  }

  /// Attempts to re-initialize the player from the current position
  Future<void> attemptRecovery() async {
    if (_videoPlayerController == null) return;
    
    final currentPos = _videoPlayerController!.value.position;
    final wasPlaying = _videoPlayerController!.value.isPlaying;
    
    debugPrint('[VideoController] 🔄 Recovering playback from ${currentPos.inSeconds}s...');
    
    videoError.value = false;
    isLoading.value = true;
    
    try {
      // Re-fetch resolutions if necessary (in case URLs expired or changed)
      if (!isOffline.value) {
        await fetchAvailableResolutions();
      }
      
      await initializeVideoPlayer(overrideUrl: isOffline.value ? _offlineBlobUrl : null);
      
      if (_videoPlayerController != null) {
        await _videoPlayerController!.seekTo(currentPos);
        if (wasPlaying) {
          await _videoPlayerController!.play();
        }
      }
    } catch (e) {
      debugPrint('[VideoController] ❌ Recovery failed: $e');
      videoError.value = true;
      errorMessage.value = "Recovery failed. Please check your connection.";
    } finally {
      isLoading.value = false;
    }
  }

  void _onChewieEvent() {
    // Listen for fullscreen changes
    if (_chewieController?.isFullScreen == true && !isFullScreen.value) {
      isFullScreen.value = true;
    } else if (_chewieController?.isFullScreen == false && isFullScreen.value) {
      isFullScreen.value = false;
    }
  }

  void disposePlayer() {
    _videoSubscription?.cancel();
    _languageRequestsSubscription?.cancel();
    _chewieController?.removeListener(_onChewieEvent);
    _videoPlayerController?.removeListener(_videoErrorListener);
    _videoPlayerController?.removeListener(videoListener);
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }

  ChewieController? get chewieController {
    if (_chewieController == null) return null;
    // Safety check for web/disposed objects
    try {
      // Accessing a property to trigger an error if disposed
      // but in Flutter/GetX we usually just check null.
      // Chewie doesn't have a public isDisposed but the underlying
      // videoPlayerController might.
      return _chewieController;
    } catch (_) {
      return null;
    }
  }

  VideoPlayerController? get videoPlayerController => _videoPlayerController;

  @override
  void onClose() {
    final currentRoute = Get.currentRoute;
    final isGoingToWatch = currentRoute.contains('watch') || currentRoute.contains('videoscreen');
    
    final bool shouldStartMiniplayer = !isGoingToWatch && 
        _videoPlayerController != null && 
        _videoPlayerController!.value.isInitialized &&
        Get.isRegistered<MiniplayerController>(tag: 'miniplayer');

    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      final totalDuration = _videoPlayerController!.value.duration.inSeconds;
      final watchSeconds = _watchStopwatch.elapsed.inSeconds;
      _syncWatchHistory(watchSeconds, totalDuration);
    }

    if (shouldStartMiniplayer) {
      final pos = _videoPlayerController!.value.position;
      final videoToPlay = video;
      final selectedResUrl = currentResolution.value?.url;

      // Remove listeners so they don't fire when player is in miniplayer
      _videoPlayerController!.removeListener(_videoErrorListener);
      _videoPlayerController!.removeListener(videoListener);

      // Hand off the player controller to the miniplayer
      VideoPlaybackHandoff.registerActiveController(video.id, _videoPlayerController!);
      
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
          debugPrint('[VideoController] Error showing miniplayer in onClose: $e');
        }
      });
    }

    mobileTabController.dispose();
    desktopTabController.dispose();
    scrollController.dispose();
    disposePlayer();
    _connectivitySubscription?.cancel();
    if (_offlineBlobUrl != null) {
      html.Url.revokeObjectUrl(_offlineBlobUrl!);
    }
    _watchStopwatch.stop();
    super.onClose();
  }

  // UI Actions with Optimistic Updates
  Future<void> toggleLike() async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) return;

    // --- Optimistic Update ---
    final wasLiked = isLiked.value;
    final wasDisliked = isDisliked.value;

    isLiked.value = !wasLiked;
    if (isLiked.value) isDisliked.value = false;

    // Update local count for immediate feedback
    if (isLiked.value) {
      // In a real app, Video model views/likes would be reactive.
      // For now, we update local observable counts if they existed.
    }

    // --- Backend ---
    try {
      await mainController.likeVideo(video.id, userId);
    } catch (e) {
      // Revert on error
      isLiked.value = wasLiked;
      isDisliked.value = wasDisliked;
    }
  }

  Future<void> toggleDislike() async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) return;

    // --- Optimistic Update ---
    final wasLiked = isLiked.value;
    final wasDisliked = isDisliked.value;

    isDisliked.value = !wasDisliked;
    if (isDisliked.value) isLiked.value = false;

    // --- Backend ---
    try {
      await mainController.dislikeVideo(video.id, userId);
    } catch (e) {
      // Revert on error
      isLiked.value = wasLiked;
      isDisliked.value = wasDisliked;
    }
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

      List<int> bytes = [];
      await for (var chunk in response.stream) {
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
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      debugPrint('[VideoController] Offline download error: $e');
      Get.snackbar(
        'Download Failed',
        'Could not save video offline: $e',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
      );
    } finally {
      isDownloading.value = false;
      downloadProgress.value = 0.0;
    }
  }
}





