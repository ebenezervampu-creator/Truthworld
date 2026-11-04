import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';

import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_comment_models_and_helpers.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// GetX controller for the Following Topics page
class FollowingTopicsController extends BaseController {
  FollowingTopicsController({TopicRepository? repository})
    : _repository = repository ?? TopicRepository();
  final TopicRepository _repository;

  String get _currentUserId =>
      Get.isRegistered<AuthService>() ? AuthService.to.uid : '';

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

  // Video filter & view mode state (Matching uploaded UI architecture)
  final RxString activeVideoFilter = 'Latest'.obs; // 'Latest', 'From followed channels', 'Trending', 'Popular'
  final RxString selectedSortOrder = 'Newest first'.obs; // 'Newest first', 'Oldest first', 'Most popular', 'Most viewed'
  final RxBool isGridView = true.obs;

  // In-flight follow toggle debouncing
  final Set<String> _pendingFollowTopicIds = <String>{};

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
    final userId = _currentUserId;
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
        _repository.fetchTopicNotificationSettings(userId),
      ]);

      final followedList = results[0] as List<Topic>;
      final favoriteList = results[1] as List<Topic>;
      final notifSettings = results[2] as Map<String, String>;
      topicNotificationSettings.addAll(notifSettings);

      final uniqueTopicsMap = <String, Topic>{};
      for (final t in followedList) {
        uniqueTopicsMap[t.id] = t;
        followingStates[t.id] = true;
        if (t.slug.isNotEmpty) followingStates[t.slug] = true;
        followerCounts[t.id] = t.followerCount;
        if (t.slug.isNotEmpty) followerCounts[t.slug] = t.followerCount;
      }
      for (final t in favoriteList) {
        uniqueTopicsMap[t.id] = t;
        followerCounts[t.id] = t.followerCount;
        if (t.slug.isNotEmpty) followerCounts[t.slug] = t.followerCount;
      }

      followedTopics.value = uniqueTopicsMap.values
          .where((t) => t.isValidTopic && t.videoCount > 0)
          .toList();
      favoriteTopics.value = favoriteList
          .where((t) => t.isValidTopic && t.videoCount > 0)
          .toList();

      if (followedTopics.isNotEmpty) {
        if (selectedTopic.value == null ||
            !followedTopics.any((t) => t.id == selectedTopic.value?.id)) {
          selectedTopic.value = followedTopics.first;
        }
        if (selectedTopic.value != null) {
          fetchVideosForTopic(selectedTopic.value!);
          fetchPostsForTopic(selectedTopic.value!);
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
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'FollowingTopicsController.fetchVideosForTopic',
      );
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
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'FollowingTopicsController.fetchPostsForTopic',
      );
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

  /// Clears the search field and active query
  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  /// Sets active video filter chip ('Latest', 'From followed channels', 'Trending', 'Popular')
  void setVideoFilter(String filter) {
    activeVideoFilter.value = filter;
  }

  /// Sets active sort order ('Newest first', 'Oldest first', 'Most popular', 'Most viewed')
  void setSortOrder(String sort) {
    selectedSortOrder.value = sort;
  }

  /// Sets grid view flag
  void setGridView(bool value) {
    isGridView.value = value;
  }

  /// Toggles between grid and list views
  void toggleViewMode() {
    isGridView.value = !isGridView.value;
  }

  /// Retrieves reactively filtered and sorted videos for a topic (or all topics if null)
  List<Video> getFilteredVideosForTopic(Topic? topic) {
    List<Video> videos;
    if (topic != null) {
      videos = List<Video>.from(topicVideosMap[topic.id] ?? []);
    } else {
      final allVideos = <String, Video>{};
      for (final t in followedTopics) {
        final list = topicVideosMap[t.id] ?? [];
        for (final v in list) {
          allVideos[v.id] = v;
        }
      }
      videos = allVideos.values.toList();
    }

    // 1. Search Query filter
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      videos = videos.where((v) {
        return v.title.toLowerCase().contains(query) ||
            v.channelName.toLowerCase().contains(query) ||
            v.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    // 2. Active Tab / Chip filter
    switch (activeVideoFilter.value) {
      case 'From followed channels':
        if (Get.isRegistered<SubscriptionController>()) {
          final subCtrl = Get.find<SubscriptionController>();
          final subbedIds = subCtrl.subscribedChannels.map((c) => c.id).toSet();
          final subbedNames = subCtrl.subscribedChannels.map((c) => c.name.toLowerCase()).toSet();
          videos = videos.where((v) {
            return subbedIds.contains(v.channelId) || subbedNames.contains(v.channelName.toLowerCase());
          }).toList();
        } else {
          videos = [];
        }
      case 'Trending':
        videos.sort((a, b) => b.views.compareTo(a.views));
      case 'Popular':
        videos.sort((a, b) => b.views.compareTo(a.views));
      case 'Latest':
      default:
    }

    // 3. Sort Order
    switch (selectedSortOrder.value) {
      case 'Newest first':
        videos.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      case 'Oldest first':
        videos.sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
      case 'Most popular':
      case 'Most viewed':
        videos.sort((a, b) => b.views.compareTo(a.views));
    }

    return videos;
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
    final userId = _currentUserId;
    if (userId.isEmpty) {
      showTopicSignInPrompt('follow topics');
      return;
    }

    final topicId = topic.id;
    if (_pendingFollowTopicIds.contains(topicId)) return;
    _pendingFollowTopicIds.add(topicId);

    try {
      final topicSlug = topic.slug;
      final wasFollowed = isTopicFollowed(topicId) ||
          (topicSlug.isNotEmpty && isTopicFollowed(topicSlug));

      final hasVideos = topic.effectiveVideoCount > 0 || topic.featuredVideoIds.isNotEmpty;
      if (!wasFollowed && (topic.isArchivedOrDeleted || (!topic.isValidTopic && !hasVideos))) {
        SnackbarService.error(message: 'Cannot follow an inactive or empty topic.');
        return;
      }

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
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'FollowingTopicsController.syncUserProfile',
        );
      }

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
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'FollowingTopicsController.syncDiscoveryTopics',
        );
      }

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
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'FollowingTopicsController.syncTopicController',
        );
      }

      try {
        final success = wasFollowed
            ? await _repository.unfollowTopic(userId, topicId)
            : await _repository.followTopic(userId, topicId);

        if (success) {
          if (wasFollowed) {
            topicNotificationSettings.remove(topicId);
            if (topicSlug.isNotEmpty) topicNotificationSettings.remove(topicSlug);
            SnackbarService.success(
              message: 'You unfollowed "${topic.name}" successfully.',
            );
          } else {
            topicNotificationSettings[topicId] = 'personalized';
            if (topicSlug.isNotEmpty) topicNotificationSettings[topicSlug] = 'personalized';
            SnackbarService.success(
              message: 'You followed "${topic.name}" successfully.',
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
            message: 'Unable to update follow status. Please try again.',
          );
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'FollowingTopicsController.toggleTopicFollowed',
        );
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
    } finally {
      _pendingFollowTopicIds.remove(topicId);
    }
  }

  /// Helper to check if a specific topic is followed (reactively)
  bool isTopicFollowed(String topicIdOrSlug) {
    if (topicIdOrSlug.isEmpty) return false;
    final clean = topicIdOrSlug.trim();
    if (followingStates.containsKey(clean)) {
      return followingStates[clean]!;
    }
    final cleanLower = clean.toLowerCase();
    if (followingStates.containsKey(cleanLower)) {
      return followingStates[cleanLower]!;
    }
    return followedTopics.any(
      (t) =>
          t.id == clean ||
          t.id.toLowerCase() == cleanLower ||
          (t.slug.isNotEmpty &&
              (t.slug == clean || t.slug.toLowerCase() == cleanLower)),
    );
  }

  /// Safely unfollow a topic
  Future<void> unfollowTopic(Topic topic) async {
    if (isTopicFollowed(topic.id) ||
        (topic.slug.isNotEmpty && isTopicFollowed(topic.slug))) {
      await toggleFollowTopic(topic);
    }
  }

  /// Get reactive follower count for a topic
  int getFollowerCount(Topic topic) {
    var count = topic.followerCount;
    if (followerCounts.containsKey(topic.id)) {
      count = followerCounts[topic.id]!;
    } else if (topic.slug.isNotEmpty && followerCounts.containsKey(topic.slug)) {
      count = followerCounts[topic.slug]!;
    }
    // TruthWorld Epistemic Consistency: If the current user follows this topic,
    // the follower count must never be displayed as 0 (always at least 1).
    if (isTopicFollowed(topic.id) ||
        (topic.slug.isNotEmpty && isTopicFollowed(topic.slug))) {
      if (count < 1) {
        count = 1;
      }
    }
    return count;
  }

  /// Update follower count from external fresh sources (e.g. HomeDiscoveryController)
  void updateTopicFollowerCount(String topicIdOrSlug, int count) {
    var safeCount = count;
    if (isTopicFollowed(topicIdOrSlug) && safeCount < 1) {
      safeCount = 1;
    }
    followerCounts[topicIdOrSlug] = safeCount;
  }

  /// Get reactive follower count by topic ID with optional fallback
  int getFollowerCountById(String topicId, {int fallback = 0}) {
    var count = fallback;
    if (followerCounts.containsKey(topicId)) {
      count = followerCounts[topicId]!;
    }
    if (isTopicFollowed(topicId) && count < 1) {
      count = 1;
    }
    return count;
  }

  /// Fetch notification setting for a topic
  Future<String> fetchTopicNotificationSetting(String topicId) async {
    final userId = _currentUserId;
    if (userId.isEmpty) {
      topicNotificationSettings[topicId] ??= 'personalized';
      return topicNotificationSettings[topicId]!;
    }

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
    final userId = _currentUserId;
    if (userId.isEmpty) {
      showTopicSignInPrompt('update notification settings');
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
      ErrorHandler.log(e);
      SnackbarService.error(message: 'Unable to update notification settings. Please try again.');
    }
  }
}
