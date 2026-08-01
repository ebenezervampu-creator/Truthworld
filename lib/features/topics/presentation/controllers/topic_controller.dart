import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// GetX Controller for Topic Page
///
/// Manages state for:
/// - Topic metadata loading
/// - Video pagination with infinite scroll
/// - Related topics
/// - UI state (loading, error, empty)
class TopicController extends GetxController {
  TopicController({TopicRepository? repository})
    : _repository = repository ?? TopicRepository();
  final TopicRepository _repository;

  // ==========================================================================
  // OBSERVABLE STATE
  // ==========================================================================

  /// Current topic being viewed
  final Rxn<Topic> topic = Rxn<Topic>();

  /// List of videos for this topic
  final RxList<Video> videos = <Video>[].obs;

  /// Featured videos (editor's pick / trending)
  final RxList<Video> featuredVideos = <Video>[].obs;

  /// Related topics
  final RxList<Topic> relatedTopics = <Topic>[].obs;

  /// UI State
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool hasMoreVideos = true.obs;

  /// Search & View state
  final RxString searchQuery = ''.obs;
  final RxBool isSearchVisible = false.obs;
  final RxString selectedView = 'List'.obs; // 'Grid', 'List' (List default)

  /// Active video filter tab
  final RxString selectedTab = 'Trending'.obs;

  /// User subscribed channel IDs
  final RxList<String> subscribedChannelIds = <String>[].obs;

  /// Cached real channel data from Firestore
  final RxMap<String, Channel> cachedChannels = <String, Channel>{}.obs;

  /// Pagination
  DocumentSnapshot? _lastVideoDoc;
  static const int _videosPerPage = 12;

  /// Sorting options
  final RxString sortBy = 'views'.obs; // Default to 'views' for 'Trending'

  // ==========================================================================
  // GETTERS
  // ==========================================================================

  String get topicSlug => topic.value?.slug ?? '';
  String get topicTitle => topic.value?.title ?? 'Topic';
  bool get isEmpty => filteredVideos.isEmpty && !isLoading.value;

  bool get hasFactCheckedVideos {
    return videos.any((v) => v.factCheckUrl.isNotEmpty);
  }

  List<Video> get filteredVideos {
    var list = List<Video>.from(videos);

    // 1. Filter by search query if any
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where(
            (v) =>
                v.title.toLowerCase().contains(query) ||
                v.channelName.toLowerCase().contains(query),
          )
          .toList();
    }

    // 2. Apply active tab filter
    if (selectedTab.value == 'From Subscribed channels') {
      list = list
          .where((v) => subscribedChannelIds.contains(v.channelId))
          .toList();
    } else if (selectedTab.value == 'Fact checked') {
      list = list.where((v) => v.factCheckUrl.isNotEmpty).toList();
    }

    return list;
  }

  List<Map<String, String>> get topicChannels {
    final channelMap = <String, Map<String, String>>{};
    for (final video in videos) {
      if (video.channelId.isNotEmpty) {
        final cached = cachedChannels[video.channelId];
        channelMap[video.channelId] = {
          'id': video.channelId,
          'name': cached?.name ?? video.channelName,
          'avatarUrl': (cached?.avatarUrl.isNotEmpty ?? false)
              ? cached!.avatarUrl
              : video.channelAvatarUrl,
        };
      }
    }
    for (final video in featuredVideos) {
      if (video.channelId.isNotEmpty) {
        final cached = cachedChannels[video.channelId];
        channelMap[video.channelId] = {
          'id': video.channelId,
          'name': cached?.name ?? video.channelName,
          'avatarUrl': (cached?.avatarUrl.isNotEmpty ?? false)
              ? cached!.avatarUrl
              : video.channelAvatarUrl,
        };
      }
    }
    return channelMap.values.toList();
  }

  void clearSearch() {
    searchQuery.value = '';
    isSearchVisible.value = false;
  }

  Future<void> _fetchChannelsForVideos(List<Video> videoList) async {
    final channelIds = videoList
        .map((v) => v.channelId)
        .where((id) => id.isNotEmpty && !cachedChannels.containsKey(id))
        .toSet()
        .toList();

    if (channelIds.isEmpty) return;

    try {
      for (var i = 0; i < channelIds.length; i += 30) {
        final chunk = channelIds.sublist(
          i,
          i + 30 > channelIds.length ? channelIds.length : i + 30,
        );
        final snapshot = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          try {
            final channel = Channel.fromDocumentSnapshot(doc);
            cachedChannels[channel.id] = channel;
          } catch (e) {
            debugPrint('Error parsing channel document ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching channels for videos: $e');
    }
  }

  /// Change active tab and reload videos
  void selectTab(String tab) {
    if (selectedTab.value == tab) return;
    selectedTab.value = tab;

    // Reset scroll & state, and trigger loading
    if (tab == 'Trending' || tab == 'Popular') {
      sortBy.value = 'views';
    } else {
      sortBy.value = 'uploadedAt';
    }
    _loadVideos(reset: true);
  }

  /// Fetch user's subscribed channel IDs
  Future<void> loadUserSubscriptions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      subscribedChannelIds.clear();
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.subscriptions)
          .where('userId', isEqualTo: uid)
          .get();
      subscribedChannelIds.value = snapshot.docs
          .map((doc) => doc.data()['channelId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error loading user subscriptions in TopicController: $e');
    }
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  @override
  void onInit() {
    super.onInit();
    loadUserSubscriptions();
    final args = Get.arguments;
    if (args != null && args is Map && args.containsKey('slug')) {
      loadTopic(args['slug'] as String);
    } else {
      final slug = Get.parameters['slug'];
      if (slug != null) {
        loadTopic(slug);
      }
    }
  }

  /// Load topic and initial videos
  Future<void> loadTopic(String slug) async {
    isLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';

    try {
      // Load topic metadata
      final topicData = await _repository.getTopicBySlug(slug);

      if (topicData == null) {
        if (topic.value != null && topic.value!.slug == slug) {
          final currentPreloaded = topic.value!;
          relatedTopics.value = await _repository.getSimilarTopics(
            currentPreloaded.category,
            excludeSlug: currentPreloaded.slug,
          );
          await _loadVideos(reset: true);
          isLoading.value = false;
          return;
        }
        hasError.value = true;
        errorMessage.value = 'Topic not found';
        isLoading.value = false;
        return;
      }

      topic.value = topicData;

      // Load featured videos
      if (topicData.featuredVideoIds.isNotEmpty) {
        featuredVideos.value = await _repository.getFeaturedVideos(
          topicData.featuredVideoIds,
        );
        _fetchChannelsForVideos(featuredVideos);
      }

      // Load related topics
      if (topicData.relatedTopics.isNotEmpty) {
        relatedTopics.value = await _repository.getRelatedTopics(
          topicData.relatedTopics,
        );
      } else {
        // Fallback: get similar topics by category
        relatedTopics.value = await _repository.getSimilarTopics(
          topicData.category,
          excludeSlug: topicData.slug,
        );
      }

      // Load initial videos
      await _loadVideos(reset: true);
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'Failed to load topic: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh topic data
  Future<void> refreshTopic() async {
    if (topicSlug.isEmpty) return;
    await loadTopic(topicSlug);
  }

  // ==========================================================================
  // VIDEO PAGINATION
  // ==========================================================================

  /// Load videos with pagination
  Future<void> _loadVideos({bool reset = false}) async {
    if (isLoadingMore.value) return;

    if (reset) {
      videos.clear();
      _lastVideoDoc = null;
      hasMoreVideos.value = true;
    }

    if (!hasMoreVideos.value && !reset) return;

    isLoadingMore.value = true;

    try {
      final page = await _repository.getVideosPageByTopic(
        topicSlug,
        lastDoc: _lastVideoDoc,
        orderBy: sortBy.value,
      );

      final newVideos = page.videos;
      _lastVideoDoc = page.lastDoc;

      if (newVideos.isEmpty) {
        hasMoreVideos.value = false;
      } else {
        videos.addAll(newVideos);
        _fetchChannelsForVideos(newVideos);

        if (newVideos.length < _videosPerPage) {
          hasMoreVideos.value = false;
        }
      }
    } catch (e) {
      debugPrint('Error loading more videos: $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Load more videos (called by infinite scroll)
  Future<void> loadMoreVideos() async {
    await _loadVideos();
  }

  // ==========================================================================
  // SORTING
  // ==========================================================================

  /// Change sort order and reload videos
  void setSortBy(String newSort) {
    if (sortBy.value == newSort) return;

    sortBy.value = newSort;
    _loadVideos(reset: true);
  }

  // ==========================================================================
  // UTILITY
  // ==========================================================================

  /// Get hero tag for video transitions
  String getHeroTag(String videoId) {
    return 'topic_video_${topicSlug}_$videoId';
  }

  /// Check if video is featured
  bool isFeatured(Video video) {
    return topic.value?.featuredVideoIds.contains(video.id) ?? false;
  }
}
