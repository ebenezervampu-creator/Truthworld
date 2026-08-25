import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/features/home/presentation/controllers/home_feed_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_navigation_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';

class HomeDiscoveryController extends BaseController {
  static const List<String> categories = [
    'Education', 'Entertainment', 'Music', 'News', 'Sports',
    'Technology', 'Science', 'Travel', 'Lifestyle', 'Comedy', 'Documentary',
    'Movies', 'TV Shows', 'Vlogs', 'DIY & How-to', 'Health & Fitness',
    'Fashion', 'Food & Cooking', 'Business & Finance', 'Animation',
    'Short Films', 'Motivation', 'History', 'Art & Design', 'Automotive',
    'Animals & Pets', 'Spirituality', 'Nature & Wildlife', 'Kids & Family',
  ];

  static const List<String> primaryFilterBars = [
    'All', 'Trending', 'From watch history', 'From Subscribed channels', 'Topics', 'Videos',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GetStorage _storage = GetStorage();
  final AuthService _authService = Get.find<AuthService>();

  static const String _kFeaturedTopicsCacheKey = 'featured_topics_cache';
  static const String _kQualifyingCategoriesCacheKey = 'qualifying_categories_cache';
  
  final RxList<Topic> featuredTopics = <Topic>[].obs;
  final RxBool isLoadingFeaturedTopics = true.obs;

  final RxString selectedCategory = 'All'.obs;
  final RxString activeFilterBar = 'All'.obs;
  final RxList<String> availableCategories = <String>['All'].obs;

  final RxMap<String, dynamic> subscribedChannels = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> subscribedChannelList = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingSubscriptions = false.obs;

  static List<String> getFixedCategories({required bool isAuthenticated}) {
    return [
      'All',
      if (isAuthenticated) 'Subscriptions',
      'Trending',
      'Flip Coin',
      'New',
      'Popular',
      'Posts',
    ];
  }

  @override
  void onInit() {
    super.onInit();
    _loadCachedFeaturedTopics();
    _loadCachedQualifyingCategories();
    fetchFeaturedTopics();
    addWorker(
      ever(_authService.isAuthenticated, (isAuth) {
        if (!isAuth && selectedCategory.value == 'Subscriptions') {
          selectCategory('All');
        }
        fetchAvailableCategories();
      }),
    );
  }

  void _loadCachedQualifyingCategories() {
    try {
      final cachedCats = _storage.read<List>(_kQualifyingCategoriesCacheKey);
      if (cachedCats != null && cachedCats.isNotEmpty) {
        final stringCats = cachedCats.map((e) => e.toString()).toList();
        availableCategories.assignAll(_personalizedSortCategories(stringCats));
        return;
      }
    } catch (e) {
      debugPrint('HomeDiscoveryController: Error loading cached categories: $e');
    }
    availableCategories.assignAll(_personalizedSortCategories([]));
  }

  void _loadCachedFeaturedTopics() {
    try {
      final cachedData = _storage.read<List>(_kFeaturedTopicsCacheKey);
      if (cachedData != null && featuredTopics.isEmpty) {
        final cachedTopics = cachedData
            .map((data) => Topic.fromMap(Map<String, dynamic>.from(data)))
            .where((t) => t.isValidTopic)
            .toList();
        if (cachedTopics.isNotEmpty) {
          featuredTopics.assignAll(cachedTopics);
          isLoadingFeaturedTopics.value = false;
        }
      }
    } catch (e) {
      debugPrint('HomeDiscoveryController: Cached topics load error: $e');
    }
  }

  void saveFeaturedTopicsToCache() {
    try {
      final dataToCache = featuredTopics
          .where((t) => t.isValidTopic)
          .map((t) => t.toCacheMap())
          .toList();
      _storage.write(_kFeaturedTopicsCacheKey, dataToCache);
    } catch (e) {
      debugPrint('HomeDiscoveryController: Cached topics save error: $e');
    }
  }

  Future<void> fetchFeaturedTopics() async {
    try {
      if (featuredTopics.isEmpty) isLoadingFeaturedTopics.value = true;
      final snapshot = await _firestore
          .collection('topics')
          .where('isFeatured', isEqualTo: true)
          .limit(6)
          .get();
      var topicsList = <Topic>[];
      if (snapshot.docs.isNotEmpty) {
        topicsList = snapshot.docs
            .map(Topic.fromDocumentSnapshot)
            .where((t) => t.isValidTopic)
            .toList();
      }
      if (topicsList.isEmpty) {
        final fallbackSnapshot = await _firestore
            .collection('topics')
            .orderBy('videoCount', descending: true)
            .limit(6)
            .get();
        if (fallbackSnapshot.docs.isNotEmpty) {
          topicsList = fallbackSnapshot.docs
              .map(Topic.fromDocumentSnapshot)
              .where((t) => t.isValidTopic)
              .toList();
        }
      }
      if (topicsList.isNotEmpty) {
        featuredTopics.assignAll(topicsList);
        saveFeaturedTopicsToCache();
        if (Get.isRegistered<FollowingTopicsController>()) {
          final followingCtrl = Get.find<FollowingTopicsController>();
          for (final t in topicsList) {
            followingCtrl.updateTopicFollowerCount(t.id, t.followerCount);
            if (t.slug.isNotEmpty) {
              followingCtrl.updateTopicFollowerCount(t.slug, t.followerCount);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('HomeDiscoveryController: Error fetching featured topics: $e');
    } finally {
      isLoadingFeaturedTopics.value = false;
    }
  }

  void selectCategory(String category) {
    if (category == 'Subscriptions' && !_authService.isAuthenticated.value) {
      _authService.signInWithGoogle();
      return;
    }
    if (selectedCategory.value == category) return;
    selectedCategory.value = category;

    // Synchronize global FlipCoinService home state
    if (Get.isRegistered<FlipCoinService>()) {
      final flipService = Get.find<FlipCoinService>();
      if (category == 'Flip Coin' || category == '🪙 Flip Coin') {
        flipService.isHomeFlipped.value = true;
        flipService.trackFlipCoinInteraction('home_tab');
      } else {
        flipService.isHomeFlipped.value = false;
      }
    }
    
    if (Get.isRegistered<HomeNavigationController>()) {
      Get.find<HomeNavigationController>().syncTabToCategory(category);
    }
    
    if (Get.isRegistered<HomeFeedController>()) {
      Get.find<HomeFeedController>().resetFeedAndFetch();
    }
  }

  Future<void> selectFilterBar(String bar) async {
    activeFilterBar.value = bar;
    if (!Get.isRegistered<HomeFeedController>()) return;
    
    if (bar == 'All') {
      selectCategory('All');
    } else if (bar == 'Trending') {
      selectCategory('Trending');
    } else if (bar == 'Topics') {
      await fetchFeaturedTopics();
    } else if (bar == 'Videos') {
      final feedCtrl = Get.find<HomeFeedController>();
      feedCtrl.communityPosts.clear();
      feedCtrl.homeFeedItems.assignAll(feedCtrl.videos);
    } else if (bar == 'Posts') {
      selectCategory('Posts');
    } else {
      selectCategory(bar);
    }
  }

  String _capitalizeCategory(String cat) {
    if (cat.isEmpty) return cat;
    final trimmed = cat.trim();
    return categories.firstWhere((c) => c.toLowerCase() == trimmed.toLowerCase(), orElse: () => trimmed[0].toUpperCase() + trimmed.substring(1));
  }

  Future<void> fetchAvailableCategories() async {
    try {
      final categoryCounts = <String, int>{};
      if (Get.isRegistered<HomeFeedController>()) {
        final feedCtrl = Get.find<HomeFeedController>();
        for (final video in feedCtrl.videos) {
          final cat = video.category.trim();
          if (cat.isNotEmpty && cat.toLowerCase() != 'all') {
            final normalized = _capitalizeCategory(cat);
            categoryCounts[normalized] = (categoryCounts[normalized] ?? 0) + 1;
          }
        }
      }

      // Check if we already have cached qualifying categories
      final cachedCats = _storage.read<List>(_kQualifyingCategoriesCacheKey);
      if (cachedCats != null && cachedCats.isNotEmpty && categoryCounts.isNotEmpty) {
        _updateCategoriesFromLoadedVideos();
        return;
      }
      
      final snapshot = await _firestore.collection('videos').where('status', isEqualTo: 'public').limit(50).getCacheFirst();
      final firestoreCounts = <String, int>{};
      for (final doc in snapshot.docs) {
        final rawCat = (doc.data()['category'] as String?)?.trim();
        if (rawCat != null && rawCat.isNotEmpty && rawCat.toLowerCase() != 'all') {
          final normalized = _capitalizeCategory(rawCat);
          firestoreCounts[normalized] = (firestoreCounts[normalized] ?? 0) + 1;
        }
      }
      
      final mergedCounts = firestoreCounts.isNotEmpty ? firestoreCounts : categoryCounts;
      final qualifyingCategories = <String>[];
      for (final cat in categories) {
        if ((mergedCounts[cat] ?? 0) >= 1) qualifyingCategories.add(cat);
      }
      
      mergedCounts.forEach((cat, count) {
        if (count >= 1 && !qualifyingCategories.contains(cat) && cat != 'All') qualifyingCategories.add(cat);
      });
      
      if (qualifyingCategories.isNotEmpty) {
        _storage.write(_kQualifyingCategoriesCacheKey, qualifyingCategories);
      }

      availableCategories.assignAll(_personalizedSortCategories(qualifyingCategories));
      if (Get.isRegistered<HomeNavigationController>()) {
        Get.find<HomeNavigationController>().reinitializeTabController();
      }
    } catch (e) {
      debugPrint('HomeDiscoveryController: Error fetching category counts: $e');
      _updateCategoriesFromLoadedVideos();
    }
  }

  List<String> _personalizedSortCategories(List<String> inputCategories) {
    final sorted = List<String>.from(inputCategories);
    final watchHistoryCategories = <String>[];
    if (Get.isRegistered<UserInterestProfileService>()) {
      final profile = Get.find<UserInterestProfileService>().profile.value;
      if (profile != null && profile.categoryAffinities.isNotEmpty) {
        final sortedEntries = profile.categoryAffinities.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sortedEntries) {
          if (entry.value > 0) {
            final catName = _capitalizeCategory(entry.key);
            if (!watchHistoryCategories.contains(catName) && catName.isNotEmpty) {
              watchHistoryCategories.add(catName);
            }
          }
        }
        sorted.sort((a, b) {
          final scoreA = profile.categoryAffinities[a] ?? 0.0;
          final scoreB = profile.categoryAffinities[b] ?? 0.0;
          return scoreB.compareTo(scoreA);
        });
      }
    }
    final fixedHead = getFixedCategories(
      isAuthenticated: _authService.isAuthenticated.value,
    );
    final result = <String>[...fixedHead];
    for (final cat in watchHistoryCategories) {
      if (!result.contains(cat) && sorted.contains(cat)) result.add(cat);
    }
    for (final cat in sorted) {
      if (!result.contains(cat)) result.add(cat);
    }
    return result;
  }

  void _updateCategoriesFromLoadedVideos() {
    if (!Get.isRegistered<HomeFeedController>()) return;
    final feedCtrl = Get.find<HomeFeedController>();
    final categoryCounts = <String, int>{};
    for (final video in feedCtrl.videos) {
      final cat = video.category.trim();
      if (cat.isNotEmpty && cat.toLowerCase() != 'all') {
        final normalized = _capitalizeCategory(cat);
        categoryCounts[normalized] = (categoryCounts[normalized] ?? 0) + 1;
      }
    }
    final qualifyingCategories = <String>[];
    for (final cat in categories) {
      if ((categoryCounts[cat] ?? 0) >= 2) qualifyingCategories.add(cat);
    }
    categoryCounts.forEach((cat, count) {
      if (count >= 2 && !qualifyingCategories.contains(cat) && cat != 'All') qualifyingCategories.add(cat);
    });
    availableCategories.assignAll(_personalizedSortCategories(qualifyingCategories));
    if (Get.isRegistered<HomeNavigationController>()) {
      Get.find<HomeNavigationController>().reinitializeTabController();
    }
  }

  Future<void> fetchSubscribedChannels() async {
    final userId = _authService.user?.uid;
    if (userId == null) return;
    try {
      isLoadingSubscriptions.value = true;
      final subsSnapshot = await _firestore.collection('subscriptions').where('userId', isEqualTo: userId).getCacheFirst();
      final channelIds = subsSnapshot.docs.map((doc) => doc['channelId'] as String).toList();
      if (channelIds.isEmpty) {
        subscribedChannelList.clear();
        return;
      }
      final channelsData = <Map<String, dynamic>>[];
      for (var i = 0; i < channelIds.length; i += 10) {
        final chunk = channelIds.sublist(i, i + 10 > channelIds.length ? channelIds.length : i + 10);
        final channelsSnapshot = await _firestore.collection('channels').where(FieldPath.documentId, whereIn: chunk).getCacheFirst();
        for (final doc in channelsSnapshot.docs) {
          final data = doc.data();
          var avatarUrl = data['avatarUrl']?.toString() ?? '';
          if (avatarUrl.isEmpty) {
            avatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(data['channelName'] ?? 'Channel')}&background=random';
          }
          channelsData.add({'id': doc.id, 'name': data['channelName'] ?? 'Unknown', 'avatar': avatarUrl});
        }
      }
      subscribedChannelList.assignAll(channelsData);
    } catch (e) {
      debugPrint('Error fetching subscribed channels: $e');
    } finally {
      isLoadingSubscriptions.value = false;
    }
  }
}
