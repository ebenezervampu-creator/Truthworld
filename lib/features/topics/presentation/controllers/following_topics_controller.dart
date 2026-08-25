import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';

import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// GetX controller for the Following Topics page
class FollowingTopicsController extends BaseController {
  FollowingTopicsController({TopicRepository? repository})
    : _repository = repository ?? TopicRepository();
  final TopicRepository _repository;

  // ==========================================================================
  // OBSERVABLE STATE VARIABLES
  // ==========================================================================
  final RxList<Topic> followedTopics = <Topic>[].obs;
  final RxList<Topic> favoriteTopics = <Topic>[].obs;
  final RxMap<String, int> followerCounts = <String, int>{}.obs;
  final RxMap<String, bool> followingStates = <String, bool>{}.obs;
  final RxString activeTab = 'Following'.obs; // 'Following', 'Favorites'
  final RxBool rxIsLoading = false.obs;
  final RxString rxErrorMessage = ''.obs;

  // Selected topic for filtering (null means 'All' selected)
  final Rxn<Topic> selectedTopic = Rxn<Topic>();

  // Topic videos map: topic.id/slug -> List<Video>
  final RxMap<String, List<Video>> topicVideosMap = <String, List<Video>>{}.obs;
  final RxMap<String, bool> isLoadingVideosMap = <String, bool>{}.obs;

  // Topic posts map: topic.id/slug -> List<CommunityPostModel>
  final RxMap<String, List<CommunityPostModel>> topicPostsMap =
      <String, List<CommunityPostModel>>{}.obs;
  final RxMap<String, bool> isLoadingPostsMap = <String, bool>{}.obs;

  // Search & Filtering State (Matching PlaylistController model)
  final RxString searchQuery = ''.obs;
  final RxString selectedCategory = 'All'.obs;
  final RxBool isSearchExpanded = false.obs;
  late final TextEditingController searchController = trackTextController(TextEditingController());

  // Topic notification settings map: topicId -> 'all' | 'personalized' | 'none'
  final RxMap<String, String> topicNotificationSettings =
      <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() {
      updateSearchQuery(searchController.text);
    });
    fetchFollowingTopics();
  }

  /// Retrieve all topics followed and liked/favorited by the authenticated user
  Future<void> fetchFollowingTopics() async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) {
      rxErrorMessage.value = 'Please sign in to view your followed topics.';
      return;
    }

    rxIsLoading.value = true;
    rxErrorMessage.value = '';

    try {
      final results = await Future.wait([
        _repository.fetchFollowedTopics(userId),
        _repository.fetchFavoriteTopics(userId),
      ]);

      final uniqueTopicsMap = <String, Topic>{};
      for (final t in results[0]) {
        uniqueTopicsMap[t.id] = t;
        followingStates[t.id] = true;
        if (t.slug.isNotEmpty) followingStates[t.slug] = true;
        followerCounts[t.id] = t.followerCount;
        if (t.slug.isNotEmpty) followerCounts[t.slug] = t.followerCount;
      }
      for (final t in results[1]) {
        uniqueTopicsMap[t.id] = t;
        followerCounts[t.id] = t.followerCount;
        if (t.slug.isNotEmpty) followerCounts[t.slug] = t.followerCount;
      }

      followedTopics.value = uniqueTopicsMap.values.toList();
      favoriteTopics.value = results[1];

      if (followedTopics.isNotEmpty) {
        if (selectedTopic.value == null ||
            !followedTopics.any((t) => t.id == selectedTopic.value?.id)) {
          selectedTopic.value = followedTopics.first;
        }
        for (final t in followedTopics) {
          fetchVideosForTopic(t);
          fetchPostsForTopic(t);
        }
      } else {
        selectedTopic.value = null;
      }
    } catch (e) {
      rxErrorMessage.value = FriendlyErrorTranslator.getFriendlyMessage(
        e,
        defaultActionMessage: 'fetch followed topics',
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Fetch videos associated with a specific topic
  Future<void> fetchVideosForTopic(Topic topic) async {
    final key = topic.id;
    if (topicVideosMap.containsKey(key) && isLoadingVideosMap[key] != true) {
      return;
    }

    isLoadingVideosMap[key] = true;
    try {
      var videos = await _repository.getVideosByTopic(topic.slug);
      if (videos.isEmpty && topic.id != topic.slug) {
        videos = await _repository.getVideosByTopic(topic.id);
      }
      topicVideosMap[key] = videos;
    } catch (e) {
      debugPrint('Error fetching videos for topic ${topic.title}: $e');
      topicVideosMap[key] = [];
    } finally {
      isLoadingVideosMap[key] = false;
    }
  }

  /// Fetch community posts associated with a specific topic
  Future<void> fetchPostsForTopic(Topic topic) async {
    final key = topic.id;
    if (topicPostsMap.containsKey(key) && isLoadingPostsMap[key] != true) {
      return;
    }

    isLoadingPostsMap[key] = true;
    try {
      var posts = await _repository.getCommunityPostsByTopic(topic.slug);
      if (posts.isEmpty && topic.id != topic.slug) {
        posts = await _repository.getCommunityPostsByTopic(topic.id);
      }
      topicPostsMap[key] = posts;
    } catch (e) {
      debugPrint('Error fetching posts for topic ${topic.title}: $e');
      topicPostsMap[key] = [];
    } finally {
      isLoadingPostsMap[key] = false;
    }
  }

  /// Select a topic pill
  void selectTopic(Topic? topic) {
    selectedTopic.value = topic;
    if (topic != null) {
      fetchVideosForTopic(topic);
      fetchPostsForTopic(topic);
    }
  }

  /// Updates local search query
  void updateSearchQuery(String value) {
    searchQuery.value = value;
  }

  /// Sets active category filter
  void setCategory(String category) {
    selectedCategory.value = category;
  }

  /// Get uniquely derived categories from loaded followed topics for the filter chips
  List<String> get derivedCategories {
    final cats = <String>['All'];
    for (final topic in followedTopics) {
      final cat = _capitalize(topic.category);
      if (cat.isNotEmpty && !cats.contains(cat)) {
        cats.add(cat);
      }
    }
    return cats;
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1).toLowerCase();
  }

  /// Toggle follow state and dynamically update local lists and counters to remain reactive
  Future<void> toggleFollowTopic(Topic topic) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) {
      SnackbarService.error(message: 'Please sign in to follow topics.');
      return;
    }

    final topicId = topic.id;
    final topicSlug = topic.slug;
    final wasFollowed = isTopicFollowed(topicId);
    final previousCount = getFollowerCount(topic);
    final nextCount = (previousCount + (wasFollowed ? -1 : 1)).clamp(0, 999999999);

    // Immediate optimistic state update
    followingStates[topicId] = !wasFollowed;
    followerCounts[topicId] = nextCount;
    if (topicSlug.isNotEmpty) {
      followingStates[topicSlug] = !wasFollowed;
      followerCounts[topicSlug] = nextCount;
    }

    if (wasFollowed) {
      followedTopics.removeWhere(
        (t) => t.id == topicId || (topicSlug.isNotEmpty && t.slug == topicSlug),
      );
      if (selectedTopic.value?.id == topicId ||
          (topicSlug.isNotEmpty && selectedTopic.value?.slug == topicSlug)) {
        selectedTopic.value = followedTopics.isNotEmpty
            ? followedTopics.first
            : null;
      }
    } else {
      final updatedTopic = topic.copyWith(followerCount: nextCount);
      if (!followedTopics.any(
        (t) => t.id == topicId || (topicSlug.isNotEmpty && t.slug == topicSlug),
      )) {
        followedTopics.add(updatedTopic);
      }
    }

    // Sync with UserInterestProfileService
    try {
      if (Get.isRegistered<UserInterestProfileService>()) {
        final profileService = Get.find<UserInterestProfileService>();
        if (!wasFollowed) {
          profileService.onTopicFollowed(topic.slug);
        } else {
          profileService.onTopicUnfollowed(topic.slug);
        }
      }
    } catch (_) {}

    // Sync with HomeDiscoveryController featured topics if loaded
    try {
      if (Get.isRegistered<HomeDiscoveryController>()) {
        final discoveryCtrl = Get.find<HomeDiscoveryController>();
        final idx = discoveryCtrl.featuredTopics.indexWhere(
          (t) => t.id == topicId || (topicSlug.isNotEmpty && t.slug == topicSlug),
        );
        if (idx != -1) {
          discoveryCtrl.featuredTopics[idx] = discoveryCtrl.featuredTopics[idx].copyWith(
            followerCount: nextCount,
          );
          discoveryCtrl.saveFeaturedTopicsToCache();
        }
      }
    } catch (_) {}

    // Sync with TopicController if currently viewing this topic
    try {
      if (Get.isRegistered<TopicController>()) {
        final topicCtrl = Get.find<TopicController>();
        if (topicCtrl.topic.value?.id == topicId ||
            (topicSlug.isNotEmpty && topicCtrl.topic.value?.slug == topicSlug)) {
          topicCtrl.topic.value = topicCtrl.topic.value?.copyWith(
            followerCount: nextCount,
          );
        }
      }
    } catch (_) {}

    try {
      final success = wasFollowed
          ? await _repository.unfollowTopic(userId, topicId)
          : await _repository.followTopic(userId, topicId);

      if (success) {
        if (wasFollowed) {
          SnackbarService.success(
            message: 'You unfollowed "${topic.title}" successfully.',
          );
        } else {
          SnackbarService.success(
            message: 'You followed "${topic.title}" successfully.',
          );
          fetchVideosForTopic(topic);
        }
      } else {
        // Rollback on failure
        followingStates[topicId] = wasFollowed;
        followerCounts[topicId] = previousCount;
        if (topicSlug.isNotEmpty) {
          followingStates[topicSlug] = wasFollowed;
          followerCounts[topicSlug] = previousCount;
        }
        if (wasFollowed) {
          if (!followedTopics.any(
            (t) => t.id == topicId || (topicSlug.isNotEmpty && t.slug == topicSlug),
          )) {
            followedTopics.add(topic);
          }
        } else {
          followedTopics.removeWhere(
            (t) => t.id == topicId || (topicSlug.isNotEmpty && t.slug == topicSlug),
          );
        }
        SnackbarService.error(
          message: 'Failed to update follow status. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('Error toggling topic followed state: $e');
      // Rollback on error
      followingStates[topicId] = wasFollowed;
      followerCounts[topicId] = previousCount;
      if (topicSlug.isNotEmpty) {
        followingStates[topicSlug] = wasFollowed;
        followerCounts[topicSlug] = previousCount;
      }
      if (wasFollowed) {
        if (!followedTopics.any(
          (t) => t.id == topicId || (topicSlug.isNotEmpty && t.slug == topicSlug),
        )) {
          followedTopics.add(topic);
        }
      } else {
        followedTopics.removeWhere(
          (t) => t.id == topicId || (topicSlug.isNotEmpty && t.slug == topicSlug),
        );
      }
      SnackbarService.error(
        message: FriendlyErrorTranslator.getFriendlyMessage(
          e,
          defaultActionMessage: 'toggle follow status',
        ),
      );
    }
  }

  /// Helper to check if a specific topic is followed (reactively)
  bool isTopicFollowed(String topicIdOrSlug) {
    if (followingStates.containsKey(topicIdOrSlug)) {
      return followingStates[topicIdOrSlug]!;
    }
    return followedTopics.any(
      (t) => t.id == topicIdOrSlug || (t.slug.isNotEmpty && t.slug == topicIdOrSlug),
    );
  }

  /// Get reactive follower count for a topic
  int getFollowerCount(Topic topic) {
    if (followerCounts.containsKey(topic.id)) {
      return followerCounts[topic.id]!;
    }
    if (topic.slug.isNotEmpty && followerCounts.containsKey(topic.slug)) {
      return followerCounts[topic.slug]!;
    }
    return topic.followerCount;
  }

  /// Update follower count from external fresh sources (e.g. HomeDiscoveryController)
  void updateTopicFollowerCount(String topicIdOrSlug, int count) {
    followerCounts[topicIdOrSlug] = count;
  }

  /// Get reactive follower count by topic ID with optional fallback
  int getFollowerCountById(String topicId, {int fallback = 0}) {
    if (followerCounts.containsKey(topicId)) {
      return followerCounts[topicId]!;
    }
    return fallback;
  }

  /// Fetch notification setting for a topic
  Future<String> fetchTopicNotificationSetting(String topicId) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) return 'all';

    if (topicNotificationSettings.containsKey(topicId)) {
      return topicNotificationSettings[topicId]!;
    }

    final setting = await _repository.getTopicNotificationSetting(
      userId,
      topicId,
    );
    topicNotificationSettings[topicId] = setting;
    return setting;
  }

  /// Update notification setting for a topic ('all' | 'personalized' | 'none')
  Future<void> updateTopicNotificationSetting(
    String topicId,
    String setting,
  ) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) {
      SnackbarService.error(
        message: 'Please sign in to update notification settings.',
      );
      return;
    }

    try {
      topicNotificationSettings[topicId] = setting;
      await _repository.updateTopicNotificationSetting(
        userId,
        topicId,
        setting,
      );

      final label = setting == 'all'
          ? 'All notifications'
          : (setting == 'personalized'
                ? 'Personalized notifications'
                : 'Notifications turned off');
      SnackbarService.success(
        message: 'Notification preference updated to "$label".',
      );
    } catch (e) {
      debugPrint('Error updating topic notification setting: $e');
      SnackbarService.error(message: 'Failed to update notification settings.');
    }
  }
}
