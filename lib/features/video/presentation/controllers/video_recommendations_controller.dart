import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Sub-controller responsible for fetching, ranking, filtering, and caching
/// video recommendations, channel videos, related topics, and playlists.
class VideoRecommendationsController extends BaseController {
  VideoRecommendationsController({
    required this.getVideo,
    this.getCurrentPlaylist,
    this.getPlaylistVideos,
    this.getCurrentTopic,
    this.getTopicVideos,
    this.getNavigatedFromTopic,
    this.getNavigatedFromPlaylist,
  });

  final Video Function() getVideo;
  final PlaylistModel? Function()? getCurrentPlaylist;
  final List<Video> Function()? getPlaylistVideos;
  final Topic? Function()? getCurrentTopic;
  final List<Video> Function()? getTopicVideos;
  final bool Function()? getNavigatedFromTopic;
  final bool Function()? getNavigatedFromPlaylist;

  /// Session-level shared candidate video pool for low-latency recommendations across video navigations.
  static final List<Video> _candidatePoolMemoryCache = [];
  static DateTime? _candidatePoolCacheTimestamp;
  static const Duration _candidatePoolTTL = Duration(minutes: 5);

  /// Check whether the in-memory pool is warm and valid
  static bool get isCandidatePoolWarm =>
      _candidatePoolMemoryCache.isNotEmpty &&
      _candidatePoolCacheTimestamp != null &&
      DateTime.now().difference(_candidatePoolCacheTimestamp!) < _candidatePoolTTL;

  /// Manually invalidate candidate pool cache (e.g. on manual pull-to-refresh)
  static void clearCandidatePoolCache() {
    _candidatePoolMemoryCache.clear();
    _candidatePoolCacheTimestamp = null;
  }

  Worker? _filterWorker;

  @override
  void onInit() {
    super.onInit();

    // Auto-load tab data on-demand whenever user switches filter tabs
    _filterWorker = ever(selectedRecommendationFilter, ensureFilterVideosLoaded);

    final currentPlaylist = getCurrentPlaylist?.call();
    final isPlaylist =
        (getNavigatedFromPlaylist?.call() ?? false) || currentPlaylist != null;
    if (isPlaylist &&
        currentPlaylist != null &&
        currentPlaylist.playlistName.trim().isNotEmpty) {
      selectedRecommendationFilter.value = currentPlaylist.playlistName.trim();
      return;
    }

    final currentTopic = getCurrentTopic?.call();
    final isTopic =
        (getNavigatedFromTopic?.call() ?? false) || currentTopic != null;
    if (isTopic) {
      final topicTitle = currentTopic?.title.trim() ??
          (videoTopicsList.isNotEmpty ? videoTopicsList.first.title.trim() : '');
      if (topicTitle.isNotEmpty) {
        selectedRecommendationFilter.value = topicTitle;
      }
    }
  }

  @override
  void onClose() {
    _filterWorker?.dispose();
    super.onClose();
  }

  // Recommendations Cache
  final RxList<Video> recommendedVideos = <Video>[].obs;
  final RxList<CommunityPostModel> communityPosts = <CommunityPostModel>[].obs;
  final RxList<Video> moreFromChannel = <Video>[].obs;
  final RxBool isLoadingRecommendations = true.obs;
  final RxBool isTabLoading = false.obs;
  final RxString selectedRecommendationFilter = 'All'.obs;
  final RxInt recommendationActiveTab = 0.obs;

  // Track in-flight tab requests to avoid duplicate parallel queries
  final Set<String> _loadingFilterIds = {};

  // Topics and Playlists recommendation tabs state
  final RxList<Topic> videoTopicsList = <Topic>[].obs;
  final RxList<PlaylistModel> videoPlaylistsList = <PlaylistModel>[].obs;
  final RxMap<String, List<Video>> topicVideosCache =
      <String, List<Video>>{}.obs;
  final RxMap<String, List<Video>> playlistVideosCache =
      <String, List<Video>>{}.obs;
  final RxMap<String, List<Video>> tagVideosCache =
      <String, List<Video>>{}.obs;

  List<dynamic> get recommendedItems {
    final video = getVideo();
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
    var adIndex = 0;
    final scrollAds = Get.isRegistered<AdService>()
        ? AdService.to.getAdsForType('scroll')
        : <AdItem>[];

    while (videoIndex < displayVideos.length ||
        postIndex < communityPosts.length ||
        topicIndex < videoTopicsList.length) {
      for (var i = 0; i < 4 && videoIndex < displayVideos.length; i++) {
        mixed.add(displayVideos[videoIndex++]);
      }
      if (scrollAds.isNotEmpty && videoIndex < displayVideos.length) {
        mixed.add(scrollAds[adIndex++ % scrollAds.length]);
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

  List<String> get recommendationFilters {
    final video = getVideo();
    final list = <String>['All'];

    // Tab in between All and Flip Coin in playlist name
    final currentPlaylist = getCurrentPlaylist?.call();
    final isPlaylist =
        (getNavigatedFromPlaylist?.call() ?? false) || currentPlaylist != null;
    if (isPlaylist &&
        currentPlaylist != null &&
        currentPlaylist.playlistName.trim().isNotEmpty) {
      final playlistName = currentPlaylist.playlistName.trim();
      if (!list.contains(playlistName)) {
        list.add(playlistName);
      }
    }

    // Tab in between All and Flip Coin in topic name
    final currentTopic = getCurrentTopic?.call();
    final isTopic =
        (getNavigatedFromTopic?.call() ?? false) || currentTopic != null;
    if (isTopic) {
      final topicTitle = currentTopic?.title.trim() ??
          (videoTopicsList.isNotEmpty ? videoTopicsList.first.title.trim() : '');
      if (topicTitle.isNotEmpty && !list.contains(topicTitle)) {
        list.add(topicTitle);
      }
    }

    list.add('Flip Coin');

    // 2. Channel tab
    if (video.channelName.trim().isNotEmpty) {
      list.add('From ${video.channelName.trim()}');
    }

    // 3. Tags / Category
    if (video.tags.isNotEmpty) {
      for (final t in video.tags.take(3)) {
        final cleanTag = t.trim();
        if (cleanTag.isNotEmpty && !list.contains(cleanTag)) list.add(cleanTag);
      }
    } else if (video.category.trim().isNotEmpty && !list.contains(video.category.trim())) {
      list.add(video.category.trim());
    }

    return list;
  }

  List<Video> get filteredRecommendedVideos {
    final video = getVideo();
    final filter = selectedRecommendationFilter.value;
    if (filter == 'All' || filter == 'Flip Coin') {
      return recommendedVideos;
    }

    // Check if filter is a Playlist tab
    final currentPlaylist = getCurrentPlaylist?.call();
    final playlistVideos = getPlaylistVideos?.call() ?? <Video>[];
    if (currentPlaylist != null) {
      final pName = currentPlaylist.playlistName.trim();
      if (filter == pName || filter == 'Playlist: $pName') {
        if (playlistVideos.isNotEmpty) return playlistVideos;
        final cached = playlistVideosCache[currentPlaylist.id];
        if (cached != null && cached.isNotEmpty) return cached;
      }
    }

    if (filter.startsWith('Playlist: ')) {
      final plName = filter.replaceFirst('Playlist: ', '');
      if (currentPlaylist != null && currentPlaylist.playlistName == plName) {
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
    final currentTopic = getCurrentTopic?.call();
    final topicVideos = getTopicVideos?.call() ?? <Video>[];
    if (currentTopic != null) {
      final tName = currentTopic.title.trim();
      if (filter == tName || filter == 'Topic: $tName') {
        if (topicVideos.isNotEmpty) return topicVideos;
        final cached = topicVideosCache[currentTopic.id];
        if (cached != null && cached.isNotEmpty) return cached;
      }
    }

    if (filter.startsWith('Topic: ')) {
      final topicTitle = filter.replaceFirst('Topic: ', '');
      if (currentTopic != null && currentTopic.title == topicTitle) {
        if (topicVideos.isNotEmpty) return topicVideos;
      }
      final matchedTopic = videoTopicsList.firstWhereOrNull(
        (t) => t.title == topicTitle,
      );
      if (matchedTopic != null) {
        final cached = topicVideosCache[matchedTopic.id];
        if (cached != null && cached.isNotEmpty) return cached;
      }
    }

    final matchedTopicDirect = videoTopicsList.firstWhereOrNull(
      (t) => t.title == filter,
    );
    if (matchedTopicDirect != null) {
      final cached = topicVideosCache[matchedTopicDirect.id];
      if (cached != null && cached.isNotEmpty) return cached;
      if (topicVideos.isNotEmpty) return topicVideos;
    }

    final cleanFilter = filter.trim();
    final channelTabName = 'From ${video.channelName.trim()}';
    if (cleanFilter == channelTabName ||
        cleanFilter == 'From ${video.channelName}' ||
        cleanFilter.startsWith('From ')) {
      return moreFromChannel;
    }

    if (tagVideosCache.containsKey(cleanFilter) &&
        tagVideosCache[cleanFilter]!.isNotEmpty) {
      return tagVideosCache[cleanFilter]!;
    }

    final filterLower = cleanFilter.toLowerCase();
    return recommendedVideos.where((v) {
      if (v.id == video.id) return false;
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

  /// Fetches other videos from the same channel, prioritizing channelId with ownerId and channelName fallbacks,
  /// ensuring cache hits containing only the current video do not block server retrieval.
  Future<List<Video>> fetchChannelVideos({
    bool setTabLoading = false,
    bool forceRefresh = false,
  }) async {
    final video = getVideo();
    final videoId = video.id;
    final effectiveChannelId = video.channelId.trim().isNotEmpty
        ? video.channelId.trim()
        : (video.ownerId.trim().isNotEmpty ? video.ownerId.trim() : '');

    if (effectiveChannelId.isEmpty && video.channelName.trim().isEmpty) {
      return [];
    }

    if (setTabLoading) isTabLoading.value = true;
    try {
      final loadedVideos = <Video>[];

      Future<List<Video>> executeChannelQuery(Query<Map<String, dynamic>> query) async {
        try {
          QuerySnapshot<Map<String, dynamic>> snapshot;
          if (forceRefresh) {
            snapshot = await query.get();
          } else {
            QuerySnapshot<Map<String, dynamic>>? cacheSnap;
            try {
              cacheSnap = await query.get(const GetOptions(source: Source.cache));
            } catch (_) {
              cacheSnap = null;
            }
            final validCacheDocs = (cacheSnap != null)
                ? cacheSnap.docs.where((d) => d.id != videoId).toList()
                : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            if (validCacheDocs.isNotEmpty) {
              snapshot = cacheSnap!;
            } else {
              snapshot = await query.get();
            }
          }
          return snapshot.docs
              .map(Video.fromDocumentSnapshot)
              .where((v) => v.id != videoId)
              .where(VideoVisibilityPolicy.isVisibleForRecommendation)
              .toList();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'VideoRecommendationsController.executeChannelQuery',
          );
          return [];
        }
      }

      // 1. Primary query by channelId
      if (effectiveChannelId.isNotEmpty) {
        final byChannelId = await executeChannelQuery(
          FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: effectiveChannelId)
              .limit(20),
        );
        loadedVideos.addAll(byChannelId);
      }

      // 2. Fallback by ownerId if empty
      if (loadedVideos.isEmpty &&
          video.ownerId.trim().isNotEmpty &&
          video.ownerId.trim() != effectiveChannelId) {
        final byOwnerId = await executeChannelQuery(
          FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('ownerId', isEqualTo: video.ownerId.trim())
              .limit(20),
        );
        loadedVideos.addAll(byOwnerId);
      }

      // 3. Fallback by channelName if still empty
      if (loadedVideos.isEmpty && video.channelName.trim().isNotEmpty) {
        final byChannelName = await executeChannelQuery(
          FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('channelName', isEqualTo: video.channelName.trim())
              .limit(20),
        );
        loadedVideos.addAll(byChannelName);
      }

      final uniqueChannelVideos = <String, Video>{};
      for (final v in loadedVideos) {
        uniqueChannelVideos[v.id] = v;
      }

      moreFromChannel.assignAll(uniqueChannelVideos.values);
      return moreFromChannel.toList();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoRecommendationsController.fetchChannelVideos',
      );
      return [];
    } finally {
      if (setTabLoading) isTabLoading.value = false;
    }
  }

  Future<void> fetchRecommendations() async {
    final currentPlaylist = getCurrentPlaylist?.call();
    final isPlaylist =
        (getNavigatedFromPlaylist?.call() ?? false) || currentPlaylist != null;
    final currentTopic = getCurrentTopic?.call();
    final isTopic =
        (getNavigatedFromTopic?.call() ?? false) || currentTopic != null;

    if (isPlaylist &&
        currentPlaylist != null &&
        currentPlaylist.playlistName.trim().isNotEmpty) {
      final pName = currentPlaylist.playlistName.trim();
      if (selectedRecommendationFilter.value == 'All' ||
          !recommendationFilters.contains(selectedRecommendationFilter.value)) {
        selectedRecommendationFilter.value = pName;
      }
    } else if (isTopic) {
      final tTitle = currentTopic?.title.trim() ??
          (videoTopicsList.isNotEmpty ? videoTopicsList.first.title.trim() : '');
      if (tTitle.isNotEmpty &&
          (selectedRecommendationFilter.value == 'All' ||
           !recommendationFilters.contains(selectedRecommendationFilter.value))) {
        selectedRecommendationFilter.value = tTitle;
      }
    } else if (!recommendationFilters.contains(selectedRecommendationFilter.value)) {
      selectedRecommendationFilter.value = 'All';
    }

    final video = getVideo();
    final videoId = video.id;

    // STEP 1: FAST PATH (Stale-While-Revalidate / Instant Warm Render)
    // If we have a warm candidate pool in memory and recommendations are empty,
    // rank them instantly and UNSHIMMER IMMEDIATELY (< 50ms)!
    if (recommendedVideos.isEmpty && isCandidatePoolWarm) {
      final fastCandidates = _candidatePoolMemoryCache
          .where((v) => v.id != videoId && VideoVisibilityPolicy.isVisibleForRecommendation(v))
          .toList();
      if (fastCandidates.isNotEmpty) {
        _rankAndApplyFast(video, fastCandidates);
      }
    } else if (recommendedVideos.isEmpty) {
      isLoadingRecommendations.value = true;
    }

    try {
      // 1. If in a playlist, load playlist videos (check cache / passed list first)
      if (currentPlaylist != null && currentPlaylist.videoIds.isNotEmpty) {
        if (!playlistVideosCache.containsKey(currentPlaylist.id)) {
          final passedVideos = getPlaylistVideos?.call();
          if (passedVideos != null && passedVideos.isNotEmpty) {
            playlistVideosCache[currentPlaylist.id] = passedVideos;
          } else {
            unawaited(_loadPlaylistVideosIntoCache(currentPlaylist));
          }
        }
      }

      // 1b. If in a topic, ensure topic videos are cached
      if (currentTopic != null &&
          (!topicVideosCache.containsKey(currentTopic.id) ||
              topicVideosCache[currentTopic.id]!.isEmpty)) {
        final passedTopicVids = getTopicVideos?.call();
        if (passedTopicVids != null && passedTopicVids.isNotEmpty) {
          topicVideosCache[currentTopic.id] = passedTopicVids;
        } else {
          unawaited(ensureFilterVideosLoaded(currentTopic.title));
        }
      }

      final isFlipped = (selectedRecommendationFilter.value == 'Flip Coin') ||
          (Get.isRegistered<FlipCoinService>() &&
              Get.find<FlipCoinService>().isVideoFlipped(video.id));

      if (isFlipped) {
        await _fetchFlipRecommendations(video);
      } else {
        // STEP 2: CONCURRENT CHANNEL & GENERAL VIDEO QUERIES (Parallelized via Future.wait)
        final channelFuture = fetchChannelVideos(setTabLoading: false);

        // Only query general candidates from network if pool cache is cold or expired
        final generalFuture = isCandidatePoolWarm
            ? Future<QuerySnapshot<Map<String, dynamic>>?>.value()
            : FirebaseFirestore.instance
                .collection(FirestoreCollections.videos)
                .where('status', whereIn: const ['ready', 'published', 'public'])
                .limit(30)
                .getCacheFirst()
                .catchError((e, s) {
                  ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.generalVideos');
                  return FirebaseFirestore.instance
                      .collection(FirestoreCollections.videos)
                      .limit(0)
                      .get();
                });

        final results = await Future.wait([channelFuture, generalFuture]);
        final channelVideos = results[0] as List<Video>;
        final generalSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>?;

        if (generalSnapshot != null && generalSnapshot.docs.isNotEmpty) {
          final fetchedGeneral = generalSnapshot.docs
              .map(Video.fromDocumentSnapshot)
              .where(VideoVisibilityPolicy.isVisibleForRecommendation)
              .toList();
          if (fetchedGeneral.isNotEmpty) {
            _candidatePoolMemoryCache
              ..clear()
              ..addAll(fetchedGeneral);
            _candidatePoolCacheTimestamp = DateTime.now();
          }
        }

        final generalVideos = _candidatePoolMemoryCache
            .where((v) => v.id != videoId && !channelVideos.any((cv) => cv.id == v.id))
            .where(VideoVisibilityPolicy.isVisibleForRecommendation)
            .toList();

        final rawRecommended = {...channelVideos, ...generalVideos}.toList();

        // STEP 3: ASYNC BACKGROUND ISOLATE RANKING (Zero UI frame jank!)
        List<Video> rankedList;
        if (Get.isRegistered<TruthworldAlgorithm>()) {
          final algorithm = Get.find<TruthworldAlgorithm>();
          final ranked = await algorithm.rankVideosAsync(
            rawRecommended,
            RecommendationSurface.videoRelated,
            diversityConfig: DiversityConfig.videoRelated,
          );
          rankedList = ranked.map((s) => s.video).toList();
        } else {
          rankedList = rawRecommended;
        }

        recommendedVideos.value = rankedList.isNotEmpty ? rankedList : rawRecommended;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchRecommendations');
    } finally {
      // STEP 4: PROGRESSIVE UNSHIMMER (Dismiss Skeleton Shimmer IMMEDIATELY!)
      isLoadingRecommendations.value = false;
    }

    // STEP 5: ASYNCHRONOUS TIER-2 BACKGROUND HYDRATION (Does NOT block user viewing recommendations!)
    unawaited(_fetchTopicsAndPlaylistsForRecommendations());
    unawaited(_fetchCommunityPosts());
  }

  void _rankAndApplyFast(Video video, List<Video> candidates) {
    if (candidates.isEmpty) return;
    try {
      if (Get.isRegistered<TruthworldAlgorithm>()) {
        final algorithm = Get.find<TruthworldAlgorithm>();
        final ranked = algorithm.rankVideos(
          candidates,
          RecommendationSurface.videoRelated,
          diversityConfig: DiversityConfig.videoRelated,
        );
        final rankedList = ranked.map((s) => s.video).toList();
        if (rankedList.isNotEmpty) {
          recommendedVideos.value = rankedList;
          isLoadingRecommendations.value = false;
        }
      } else {
        recommendedVideos.value = candidates;
        isLoadingRecommendations.value = false;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController._rankAndApplyFast');
    }
  }

  Future<void> _fetchFlipRecommendations(Video video) async {
    final candidateList = <Video>[];
    final videoId = video.id;

    // 1. If video has an explicit paired counter-video (Coin Battle pair), fetch it directly!
    if (video.coinBattlePairVideoId != null &&
        video.coinBattlePairVideoId!.isNotEmpty) {
      try {
        final pairDoc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(video.coinBattlePairVideoId)
            .getCacheFirst();
        if (pairDoc.exists && pairDoc.data() != null) {
          final cand = Video.fromDocumentSnapshot(pairDoc);
          if (VideoVisibilityPolicy.isVisibleForRecommendation(cand)) {
            candidateList.add(cand);
          }
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchCoinBattlePair');
      }
    }

    // 2. Fetch a broad pool of public candidate videos
    try {
      final candidatesQuery = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .where('status', whereIn: const ['ready', 'published', 'public'])
          .limit(40)
          .getCacheFirst();

      for (final doc in candidatesQuery.docs) {
        if (doc.id != videoId &&
            !candidateList.any((v) => v.id == doc.id)) {
          final cand = Video.fromDocumentSnapshot(doc);
          if (VideoVisibilityPolicy.isVisibleForRecommendation(cand)) {
            candidateList.add(cand);
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchFlipCandidates');
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
  }

  Future<void> _loadPlaylistVideosIntoCache(PlaylistModel playlist) async {
    if (playlist.videoIds.isEmpty) return;
    try {
      final pVideos = await _fetchVideosByIds(playlist.videoIds);
      playlistVideosCache[playlist.id] = pVideos;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController._loadPlaylistVideosIntoCache');
    }
  }

  Future<void> _fetchTopicsAndPlaylistsForRecommendations() async {
    try {
      final video = getVideo();
      final videoId = video.id;

      // Preserve pre-populated topic/playlist videos
      final currentTopic = getCurrentTopic?.call();
      final preservedCurrentTopicVideos = currentTopic != null
          ? topicVideosCache[currentTopic.id]
          : null;
      final currentPlaylist = getCurrentPlaylist?.call();
      final preservedPlaylistVideos = currentPlaylist != null
          ? playlistVideosCache[currentPlaylist.id]
          : null;

      // --- 1. Topics Metadata ---
      final foundTopics = <Topic>[];
      if (video.topics.isNotEmpty) {
        final chunks = <List<String>>[];
        for (var i = 0; i < video.topics.length; i += 10) {
          chunks.add(
            video.topics.sublist(
              i,
              i + 10 > video.topics.length ? video.topics.length : i + 10,
            ),
          );
        }
        final snapshots = await Future.wait(
          chunks.map(
            (chunk) => FirebaseFirestore.instance
                .collection(FirestoreCollections.topics)
                .where('slug', whereIn: chunk)
                .where('status', isEqualTo: 'active')
                .getCacheFirst()
                .catchError((e, s) {
                  ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchTopicsChunk');
                  return FirebaseFirestore.instance
                      .collection(FirestoreCollections.topics)
                      .limit(0)
                      .get();
                }),
          ),
        );

        for (final snap in snapshots) {
          foundTopics.addAll(
            snap.docs
                .map(Topic.fromDocumentSnapshot)
                .where((t) => t.isValidTopic && t.videoCount > 0),
          );
        }
      }

      if (foundTopics.length < 3) {
        try {
          final publicTopicsSnapshot = await FirebaseFirestore.instance
              .collection(FirestoreCollections.topics)
              .where('status', isEqualTo: 'active')
              .orderBy('videoCount', descending: true)
              .limit(6)
              .getCacheFirst();
          final publicTopics = publicTopicsSnapshot.docs
              .map(Topic.fromDocumentSnapshot)
              .where((t) =>
                  t.isValidTopic &&
                  t.videoCount > 0 &&
                  !foundTopics.any((ft) => ft.id == t.id))
              .toList();
          foundTopics.addAll(publicTopics);
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchPublicTopicsFallback');
        }
      }

      videoTopicsList.assignAll(
        foundTopics.where((t) => t.isValidTopic && t.videoCount > 0),
      );

      if (currentTopic != null &&
          preservedCurrentTopicVideos != null &&
          preservedCurrentTopicVideos.isNotEmpty) {
        topicVideosCache[currentTopic.id] = preservedCurrentTopicVideos;
      }

      // (Note: Videos for other topic tabs are loaded lazily on demand when clicked)

      // --- 2. Playlists Metadata ---
      final foundPlaylists = <PlaylistModel>[];
      final currentUserId = AuthService.to.uid;
      final playlistFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        FirebaseFirestore.instance
            .collection('public_playlists')
            .where('videoIds', arrayContains: videoId)
            .limit(3)
            .getCacheFirst()
            .catchError((e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.publicPlaylists');
              return FirebaseFirestore.instance.collection('public_playlists').limit(0).get();
            }),
        if (currentUserId.isNotEmpty)
          FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(currentUserId)
              .collection(FirestoreCollections.playlists)
              .where('videoIds', arrayContains: videoId)
              .limit(3)
              .getCacheFirst()
              .catchError((e, s) {
                ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.privatePlaylists');
                return FirebaseFirestore.instance
                    .collection(FirestoreCollections.users)
                    .doc(currentUserId)
                    .collection(FirestoreCollections.playlists)
                    .limit(0)
                    .get();
              }),
      ];

      final playlistSnapshots = await Future.wait(playlistFutures);
      for (final snap in playlistSnapshots) {
        foundPlaylists.addAll(
          snap.docs.map(PlaylistModel.fromDocumentSnapshot).toList(),
        );
      }
      videoPlaylistsList.assignAll(foundPlaylists);

      if (currentPlaylist != null &&
          preservedPlaylistVideos != null &&
          preservedPlaylistVideos.isNotEmpty) {
        playlistVideosCache[currentPlaylist.id] = preservedPlaylistVideos;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchTopicsAndPlaylists');
    }
  }

  /// Lazily fetches and caches videos for a selected topic, playlist, channel, or tag on-demand when clicked.
  Future<void> ensureFilterVideosLoaded(String filter) async {
    final cleanFilter = filter.trim();
    if (cleanFilter.isEmpty || cleanFilter == 'All' || cleanFilter == 'Flip Coin') {
      return;
    }

    final video = getVideo();
    final channelTabName = 'From ${video.channelName.trim()}';

    // 1. Check Channel match
    if (cleanFilter == channelTabName ||
        cleanFilter == 'From ${video.channelName}' ||
        cleanFilter.startsWith('From ')) {
      if (moreFromChannel.isEmpty) {
        await fetchChannelVideos(setTabLoading: true);
      }
      return;
    }

    // 2. Check Topic match
    var matchedTopic = videoTopicsList.firstWhereOrNull(
      (t) => t.title.trim() == cleanFilter || 'Topic: ${t.title.trim()}' == cleanFilter,
    );
    final currentTopic = getCurrentTopic?.call();
    if (matchedTopic == null && currentTopic != null) {
      final tTitle = currentTopic.title.trim();
      if (tTitle == cleanFilter || 'Topic: $tTitle' == cleanFilter) {
        matchedTopic = currentTopic;
      }
    }

    if (matchedTopic != null) {
      final topicId = matchedTopic.id;
      if (topicVideosCache.containsKey(topicId) && topicVideosCache[topicId]!.isNotEmpty) {
        return; // Already cached
      }
      if (_loadingFilterIds.contains(topicId)) return;

      _loadingFilterIds.add(topicId);
      isTabLoading.value = true;
      try {
        final query = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where('topics', arrayContains: matchedTopic.slug)
            .limit(20)
            .getCacheFirst()
            .catchError((e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.topicVideosBySlug');
              return FirebaseFirestore.instance.collection(FirestoreCollections.videos).limit(0).get();
            });

        var topicVids = query.docs
            .map(Video.fromDocumentSnapshot)
            .where((v) => v.id != video.id)
            .where(VideoVisibilityPolicy.isVisibleForRecommendation)
            .toList();

        if (topicVids.isEmpty && matchedTopic.title.trim().isNotEmpty) {
          final fallbackQuery = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('topics', arrayContains: matchedTopic.title.trim())
              .limit(20)
              .getCacheFirst()
              .catchError((e, s) {
                ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.topicVideosByTitle');
                return FirebaseFirestore.instance.collection(FirestoreCollections.videos).limit(0).get();
              });
          topicVids = fallbackQuery.docs
              .map(Video.fromDocumentSnapshot)
              .where((v) => v.id != video.id)
              .where(VideoVisibilityPolicy.isVisibleForRecommendation)
              .toList();
        }

        topicVideosCache[topicId] = topicVids;
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.ensureTopicVideosLoaded');
      } finally {
        _loadingFilterIds.remove(topicId);
        isTabLoading.value = false;
      }
      return;
    }

    // 3. Check Playlist match
    var matchedPlaylist = videoPlaylistsList.firstWhereOrNull(
      (p) => p.playlistName.trim() == cleanFilter || 'Playlist: ${p.playlistName.trim()}' == cleanFilter,
    );
    final currentPlaylist = getCurrentPlaylist?.call();
    if (matchedPlaylist == null && currentPlaylist != null) {
      final pName = currentPlaylist.playlistName.trim();
      if (pName == cleanFilter || 'Playlist: $pName' == cleanFilter) {
        matchedPlaylist = currentPlaylist;
      }
    }

    if (matchedPlaylist != null) {
      final playlistId = matchedPlaylist.id;
      if (playlistVideosCache.containsKey(playlistId) && playlistVideosCache[playlistId]!.isNotEmpty) {
        return; // Already cached
      }
      if (_loadingFilterIds.contains(playlistId)) return;

      _loadingFilterIds.add(playlistId);
      isTabLoading.value = true;
      try {
        final playlistVids = await _fetchVideosByIds(matchedPlaylist.videoIds);
        playlistVideosCache[playlistId] = playlistVids;
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.ensurePlaylistVideosLoaded');
      } finally {
        _loadingFilterIds.remove(playlistId);
        isTabLoading.value = false;
      }
      return;
    }

    // 4. Check Tags / Categories
    if (!tagVideosCache.containsKey(cleanFilter) || tagVideosCache[cleanFilter]!.isEmpty) {
      if (_loadingFilterIds.contains(cleanFilter)) return;

      _loadingFilterIds.add(cleanFilter);
      isTabLoading.value = true;
      try {
        final tagSnapshot = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where('tags', arrayContains: cleanFilter)
            .limit(15)
            .getCacheFirst()
            .catchError((e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.tagVideos');
              return FirebaseFirestore.instance.collection(FirestoreCollections.videos).limit(0).get();
            });

        var loadedTagVideos = tagSnapshot.docs
            .map(Video.fromDocumentSnapshot)
            .where((v) => v.id != video.id)
            .where(VideoVisibilityPolicy.isVisibleForRecommendation)
            .toList();

        // Fallback to category query if no videos found with tag
        if (loadedTagVideos.isEmpty) {
          final categorySnapshot = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('category', isEqualTo: cleanFilter)
              .limit(15)
              .getCacheFirst()
              .catchError((e, s) {
                ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.categoryVideos');
                return FirebaseFirestore.instance.collection(FirestoreCollections.videos).limit(0).get();
              });
          loadedTagVideos = categorySnapshot.docs
              .map(Video.fromDocumentSnapshot)
              .where((v) => v.id != video.id)
              .where(VideoVisibilityPolicy.isVisibleForRecommendation)
              .toList();
        }

        tagVideosCache[cleanFilter] = loadedTagVideos;
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.ensureTagVideosLoaded');
      } finally {
        _loadingFilterIds.remove(cleanFilter);
        isTabLoading.value = false;
      }
    }
  }

  Future<void> _fetchCommunityPosts() async {
    try {
      final postsSnapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.community)
          .where('visibility', isEqualTo: 'Public')
          .limit(15)
          .getCacheFirst();
      final posts = postsSnapshot.docs
          .map((doc) => CommunityPostModel.fromMap(doc.data()))
          .toList();
      posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      communityPosts.assignAll(posts.take(5));
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchCommunityPosts');
    }
  }

  Future<List<Video>> _fetchVideosByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final result = <Video>[];
      final chunks = <List<String>>[];
      for (var i = 0; i < ids.length; i += 10) {
        chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
      }
      final snapshots = await Future.wait(
        chunks.map(
          (chunk) => FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where(FieldPath.documentId, whereIn: chunk)
              .getCacheFirst()
              .catchError((e, s) {
                ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController._fetchVideosByIds.chunk');
                return FirebaseFirestore.instance.collection(FirestoreCollections.videos).limit(0).get();
              }),
        ),
      );
      for (final snapshot in snapshots) {
        result.addAll(
          snapshot.docs
              .map(Video.fromDocumentSnapshot)
              .where(VideoVisibilityPolicy.canViewVideo),
        );
      }
      // Sort to match original ids list order
      result.sort((a, b) {
        final indexA = ids.indexOf(a.id);
        final indexB = ids.indexOf(b.id);
        return indexA.compareTo(indexB);
      });
      return result;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController._fetchVideosByIds');
      return [];
    }
  }
}
