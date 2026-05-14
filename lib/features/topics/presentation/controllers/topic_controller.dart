import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  final TopicRepository _repository;

  TopicController({TopicRepository? repository})
      : _repository = repository ?? TopicRepository();

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

  /// Pagination
  DocumentSnapshot? _lastVideoDoc;
  static const int _videosPerPage = 12;

  /// Sorting options
  final RxString sortBy = 'uploadedAt'.obs; // 'uploadedAt', 'views', 'rating'

  // ==========================================================================
  // GETTERS
  // ==========================================================================

  String get topicSlug => topic.value?.slug ?? '';
  String get topicTitle => topic.value?.title ?? 'Topic';
  bool get isEmpty => videos.isEmpty && !isLoading.value;

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  /// Initialize controller with topic slug from route arguments
  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args is Map && args.containsKey('slug')) {
      loadTopic(args['slug'] as String);
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
        hasError.value = true;
        errorMessage.value = 'Topic not found';
        isLoading.value = false;
        return;
      }

      topic.value = topicData;

      // Load featured videos
      if (topicData.featuredVideoIds.isNotEmpty) {
        featuredVideos.value =
            await _repository.getFeaturedVideos(topicData.featuredVideoIds);
      }

      // Load related topics
      if (topicData.relatedTopics.isNotEmpty) {
        relatedTopics.value =
            await _repository.getRelatedTopics(topicData.relatedTopics);
      } else {
        // Fallback: get similar topics by category
        relatedTopics.value = await _repository.getSimilarTopics(
          topicData.category,
          excludeSlug: topicData.slug,
          limit: 8,
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
      final newVideos = await _repository.getVideosByTopic(
        topicSlug,
        limit: _videosPerPage,
        lastDoc: _lastVideoDoc,
        orderBy: sortBy.value,
        descending: true,
      );

      if (newVideos.isEmpty) {
        hasMoreVideos.value = false;
      } else {
        videos.addAll(newVideos);

        // Store last document for next pagination
        // Note: We need to fetch the raw snapshot to get the DocumentSnapshot
        final snapshot = await FirebaseFirestore.instance
            .collection('videos')
            .where('topics', arrayContains: topicSlug)
            .where('visibility', isEqualTo: 'Public')
            .orderBy(sortBy.value, descending: true)
            .startAfter([newVideos.last.toMap()[sortBy.value]])
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          _lastVideoDoc = snapshot.docs.first;
        }

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
    await _loadVideos(reset: false);
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




