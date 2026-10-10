import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile.dart';
import 'package:truthworld/core/services/auth_service.dart';

/// Loads and caches the user's interest profile from Firestore.
///
/// Data sources:
/// - users/{uid} (interests map, following array)
/// - users/{uid}/savedTopics (followed topics)
/// - userCache/{uid}/watchHistory (recent watches)
/// - userCache/{uid}/likedVideos (recent likes)
/// - UserPreferencesService (blocked channels, not interested videos)
///
/// Refresh strategy:
/// - Full refresh every 15 minutes
/// - Incremental update on user interactions (via onVideoWatched, onVideoLiked, etc.)
/// - Cached locally in GetStorage for instant startup
class UserInterestProfileService extends GetxService {
  static UserInterestProfileService get to {
    if (!Get.isRegistered<UserInterestProfileService>()) {
      Get.put(UserInterestProfileService(), permanent: true);
    }
    return Get.find<UserInterestProfileService>();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _storage = GetStorage();
  static const _cacheKey = 'user_interest_profile_cache';
  static const _guestCacheKey = 'guest_user_interest_profile';
  static const _refreshInterval = Duration(minutes: 15);

  final profile = Rxn<UserInterestProfile>();
  UserInterestProfile? get currentProfile => profile.value ?? _ensureProfileExists();
  DateTime? _lastFullRefresh;
  bool _isLoading = false;

  /// Ensure an active profile always exists, falling back to guest profile
  UserInterestProfile _ensureProfileExists() {
    if (profile.value != null) return profile.value!;
    final guest = _loadGuestProfile();
    profile.value = guest;
    return guest;
  }

  /// Load or initialize local guest profile
  UserInterestProfile _loadGuestProfile() {
    final cached = _loadFromCache(_guestCacheKey);
    if (cached != null) return cached;
    final guest = UserInterestProfile.guest();
    _saveToCache(guest, key: _guestCacheKey);
    return guest;
  }

  @override
  void onInit() {
    super.onInit();
    final cached = _loadFromCache();
    if (cached != null) {
      profile.value = cached;
    } else {
      profile.value = _loadGuestProfile();
    }

    if (Get.isRegistered<AuthService>()) {
      ever(AuthService.to.currentUser, (user) {
        if (user != null && !user.isAnonymous) {
          loadProfile(user.uid);
        } else {
          profile.value = _loadGuestProfile();
        }
      });
      final currentUid = AuthService.to.uid;
      if (currentUid.isNotEmpty) {
        loadProfile(currentUid);
      }
    }
  }

  /// Immediately mark a video as watched to prevent it from appearing in Unexplored feed
  void markVideoWatched(String videoId, {String? category, List<String>? topics}) {
    if (videoId.isEmpty) return;
    final current = _ensureProfileExists();
    if (current.recentlyWatchedVideoIds.contains(videoId)) return;
    final newWatchedIds = Set<String>.from(current.recentlyWatchedVideoIds)..add(videoId);
    final newWatchProgress = Map<String, double>.from(current.watchProgress);
    newWatchProgress[videoId] = newWatchProgress[videoId] ?? 0.01;

    final updated = current.copyWith(
      recentlyWatchedVideoIds: newWatchedIds,
      watchProgress: newWatchProgress,
    );
    profile.value = updated;
    _saveToCache(updated);
  }

  /// Load profile for authenticated user
  Future<void> loadProfile(String userId) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final cached = _loadFromCache();
      if (cached != null && cached.userId == userId) {
        profile.value = cached;
        if (_lastFullRefresh != null &&
            DateTime.now().difference(_lastFullRefresh!) < _refreshInterval) {
          _isLoading = false;
          return;
        }
      }

      await _fetchFromFirestore(userId);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UserInterestProfileService.loadProfile',
      );
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _fetchFromFirestore(String userId) async {
    final futures = await Future.wait([
      _firestore.collection(FirestoreCollections.users).doc(userId).get(),
      _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('savedTopics')
          .get(),
      _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('watch_history')
          .orderBy('watchedAt', descending: true)
          .limit(500)
          .get(),
      _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('likedVideos')
          .orderBy('likedAt', descending: true)
          .limit(100)
          .get(),
    ]);

    final userDoc = futures[0] as DocumentSnapshot<Map<String, dynamic>>;
    final savedTopicsQuery = futures[1] as QuerySnapshot<Map<String, dynamic>>;
    final watchHistoryQuery = futures[2] as QuerySnapshot<Map<String, dynamic>>;
    final likedVideosQuery = futures[3] as QuerySnapshot<Map<String, dynamic>>;

    var following = <String>[];
    var categoryAffinities = <String, double>{};
    var topicAffinities = <String, double>{};
    var channelAffinities = <String, double>{};
    var dislikedCategories = <String>{};
    var notInterestedVideoIds = <String>{};
    var blockedChannelIds = <String>{};
    var recentSearchQueries = <String>[];
    var searchTopicCounts = <String, int>{};
    var exploredTopicSlugs = <String>{};
    var topicExploreCounts = <String, int>{};
    var discoveredChannelIds = <String>{};
    var channelExploreCounts = <String, int>{};
    var flipCoinCount = 0;
    var oppositeWatchesCount = 0;

    if (userDoc.exists) {
      final data = userDoc.data();
      if (data != null) {
        if (data['following'] != null) {
          following = List<String>.from(data['following']);
        }
        if (data['categoryAffinities'] is Map) {
          categoryAffinities = Map<String, double>.from(
            (data['categoryAffinities'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ),
          );
        }
        if (data['topicAffinities'] is Map) {
          topicAffinities = Map<String, double>.from(
            (data['topicAffinities'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ),
          );
        }
        if (data['channelAffinities'] is Map) {
          channelAffinities = Map<String, double>.from(
            (data['channelAffinities'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ),
          );
        }
        if (data['dislikedCategories'] is List) {
          dislikedCategories = Set<String>.from(data['dislikedCategories']);
        }
        if (data['notInterestedVideoIds'] is List) {
          notInterestedVideoIds = Set<String>.from(data['notInterestedVideoIds']);
        }
        if (data['blockedChannelIds'] is List) {
          blockedChannelIds = Set<String>.from(data['blockedChannelIds']);
        }
        if (data['recentSearchQueries'] is List) {
          recentSearchQueries = List<String>.from(data['recentSearchQueries']);
        }
        if (data['searchTopicCounts'] is Map) {
          searchTopicCounts = Map<String, int>.from(
            (data['searchTopicCounts'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ),
          );
        }
        if (data['exploredTopicSlugs'] is List) {
          exploredTopicSlugs = Set<String>.from(data['exploredTopicSlugs']);
        }
        if (data['topicExploreCounts'] is Map) {
          topicExploreCounts = Map<String, int>.from(
            (data['topicExploreCounts'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ),
          );
        }
        if (data['discoveredChannelIds'] is List) {
          discoveredChannelIds = Set<String>.from(data['discoveredChannelIds']);
        }
        if (data['channelExploreCounts'] is Map) {
          channelExploreCounts = Map<String, int>.from(
            (data['channelExploreCounts'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ),
          );
        }
        flipCoinCount = (data['flipCoinCount'] as num?)?.toInt() ?? 0;
        oppositeWatchesCount = (data['oppositeWatchesCount'] as num?)?.toInt() ?? 0;
      }
    }

    final followedTopics = savedTopicsQuery.docs
        .map((doc) => doc.id)
        .toList();

    final recentlyWatchedVideoIds = watchHistoryQuery.docs.map((d) => d.id).toSet();
    final recentlyLikedVideoIds = likedVideosQuery.docs.map((d) => d.id).toSet();

    final watchHistory = watchHistoryQuery.docs
        .map((doc) => doc.data())
        .toList();

    final categoryWatchCounts = <String, int>{};
    final topicWatchCounts = <String, int>{};
    final watchProgress = <String, double>{};
    var totalDurationSec = 0;
    var totalPct = 0.0;
    var factCheckedCount = 0;
    var longFormCount = 0;

    for (final doc in watchHistoryQuery.docs) {
      final data = doc.data();
      final category = data['category'] as String?;
      if (category != null) {
        categoryWatchCounts[category] =
            (categoryWatchCounts[category] ?? 0) + 1;
        // Boost affinity from watch history if not yet explicitly stored
        categoryAffinities.putIfAbsent(category, () => min(1.0, categoryWatchCounts[category]! * 0.08));
      }
      final topics = data['topics'] as List<dynamic>?;
      if (topics != null) {
        for (final topic in topics) {
          final tStr = topic.toString();
          topicWatchCounts[tStr] = (topicWatchCounts[tStr] ?? 0) + 1;
          topicAffinities.putIfAbsent(tStr, () => min(1.0, topicWatchCounts[tStr]! * 0.05));
        }
      }

      final dur = (data['watchedDuration'] as num?)?.toInt() ?? 0;
      totalDurationSec += dur;
      final pct = (data['watchPercentage'] as num?)?.toDouble() ?? 0.0;
      final normalizedPct = pct / 100.0;
      watchProgress[doc.id] = normalizedPct;
      totalPct += normalizedPct;

      final isFactChecked = data['isFactChecked'] == true ||
          (data['factCheckUrl'] as String?)?.isNotEmpty == true ||
          (data['media'] is Map &&
              (data['media']['factCheckUrl'] as String?)?.isNotEmpty == true);
      if (isFactChecked) factCheckedCount++;

      final videoDurationSec = (data['videoDuration'] as num?)?.toInt() ?? (dur > 0 ? dur : 0);
      if (videoDurationSec >= 300 && normalizedPct >= 0.70) {
        longFormCount++;
      }
    }

    final avgCompletion = watchHistoryQuery.docs.isNotEmpty
        ? (totalPct / watchHistoryQuery.docs.length)
        : 0.0;

    final interestGraph = _buildInterestGraph(watchHistory);

    final newProfile = UserInterestProfile(
      userId: userId,
      categoryAffinities: categoryAffinities,
      topicAffinities: topicAffinities,
      channelAffinities: channelAffinities,
      interestGraph: interestGraph,
      subscribedChannelIds: following.toSet(),
      followedTopicSlugs: followedTopics.toSet(),
      recentlyWatchedVideoIds: recentlyWatchedVideoIds,
      recentlyLikedVideoIds: recentlyLikedVideoIds,
      watchProgress: watchProgress,
      categoryWatchCounts: categoryWatchCounts,
      topicWatchCounts: topicWatchCounts,
      totalWatchDurationSec: totalDurationSec,
      avgWatchCompletion: avgCompletion,
      factCheckedWatchCount: factCheckedCount,
      longFormWatchCount: longFormCount,
      recentSearchQueries: recentSearchQueries,
      searchTopicCounts: searchTopicCounts,
      exploredTopicSlugs: exploredTopicSlugs,
      topicExploreCounts: topicExploreCounts,
      discoveredChannelIds: discoveredChannelIds,
      channelExploreCounts: channelExploreCounts,
      dislikedCategories: dislikedCategories,
      notInterestedVideoIds: notInterestedVideoIds,
      blockedChannelIds: blockedChannelIds,
      flipCoinCount: flipCoinCount,
      oppositeWatchesCount: oppositeWatchesCount,
    );

    profile.value = newProfile;
    _saveToCache(newProfile);
    _lastFullRefresh = DateTime.now();
  }

  /// Force full refresh
  Future<void> refreshProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _fetchFromFirestore(user.uid);
    }
  }

  /// Clear profile on logout
  void clearProfile() {
    _storage.remove(_cacheKey);
    _lastFullRefresh = null;
    profile.value = _loadGuestProfile();
  }

  /// Incremental updates (don't need full Firestore reload)
  void onVideoWatched(
    String videoId,
    String category,
    List<String> topics,
    double completion, {
    int durationSec = 0,
    bool isFactChecked = false,
  }) {
    final p = _ensureProfileExists();

    final newCategoryWatchCounts = Map<String, int>.from(p.categoryWatchCounts);
    newCategoryWatchCounts[category] = (newCategoryWatchCounts[category] ?? 0) + 1;

    final newTopicWatchCounts = Map<String, int>.from(p.topicWatchCounts);
    for (final topic in topics) {
      newTopicWatchCounts[topic] = (newTopicWatchCounts[topic] ?? 0) + 1;
    }

    final newWatchedIds = Set<String>.from(p.recentlyWatchedVideoIds)..add(videoId);
    final newWatchProgress = Map<String, double>.from(p.watchProgress);
    newWatchProgress[videoId] = completion;

    final newTotalWatches = newWatchedIds.length;
    final newAvgCompletion = newTotalWatches > 0
        ? (((p.avgWatchCompletion * (newTotalWatches - 1)) + completion) / newTotalWatches)
        : completion;

    final newCategoryAffinities = Map<String, double>.from(p.categoryAffinities);
    newCategoryAffinities[category] = min(1.0, (newCategoryAffinities[category] ?? 0.0) + (completion >= 0.7 ? 0.04 : 0.02));

    final newTopicAffinities = Map<String, double>.from(p.topicAffinities);
    for (final topic in topics) {
      newTopicAffinities[topic] = min(1.0, (newTopicAffinities[topic] ?? 0.0) + 0.02);
    }

    final updated = p.copyWith(
      categoryWatchCounts: newCategoryWatchCounts,
      topicWatchCounts: newTopicWatchCounts,
      recentlyWatchedVideoIds: newWatchedIds,
      watchProgress: newWatchProgress,
      totalWatchDurationSec: p.totalWatchDurationSec + durationSec,
      avgWatchCompletion: newAvgCompletion,
      factCheckedWatchCount: isFactChecked ? p.factCheckedWatchCount + 1 : p.factCheckedWatchCount,
      longFormWatchCount: (durationSec >= 300 && completion >= 0.7) ? p.longFormWatchCount + 1 : p.longFormWatchCount,
      categoryAffinities: newCategoryAffinities,
      topicAffinities: newTopicAffinities,
    );

    profile.value = updated;
    _saveToCache(updated);
    profile.refresh();
  }

  /// Track when a user performs a search
  void onSearchPerformed(String query, {String? category}) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final p = _ensureProfileExists();

    final newRecentSearches = [clean, ...p.recentSearchQueries.where((q) => q != clean)].take(20).toList();
    final newSearchTopicCounts = Map<String, int>.from(p.searchTopicCounts);
    newSearchTopicCounts[clean.toLowerCase()] = (newSearchTopicCounts[clean.toLowerCase()] ?? 0) + 1;

    final newCategoryAffinities = Map<String, double>.from(p.categoryAffinities);
    if (category != null && category.isNotEmpty) {
      newCategoryAffinities[category] = min(1.0, (newCategoryAffinities[category] ?? 0.0) + 0.04);
    }

    final updated = p.copyWith(
      recentSearchQueries: newRecentSearches,
      searchTopicCounts: newSearchTopicCounts,
      categoryAffinities: newCategoryAffinities,
    );

    profile.value = updated;
    _saveToCache(updated);
    profile.refresh();

    final userId = p.userId;
    if (userId.isNotEmpty && userId != 'guest_user') {
      _firestore.collection(FirestoreCollections.users).doc(userId).set({
        'recentSearchQueries': newRecentSearches,
        'searchTopicCounts': newSearchTopicCounts,
        if (category != null && category.isNotEmpty) 'categoryAffinities': newCategoryAffinities,
      }, SetOptions(merge: true)).catchError((e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'UserInterestProfileService.onSearchQuery',
        );
      });
    }
  }

  /// Track when a user explores a topic
  void onTopicExplored(String topicSlug, {String? category}) {
    final clean = topicSlug.trim().toLowerCase();
    if (clean.isEmpty) return;
    final p = _ensureProfileExists();

    final newExplored = Set<String>.from(p.exploredTopicSlugs)..add(clean);
    final newExploreCounts = Map<String, int>.from(p.topicExploreCounts);
    newExploreCounts[clean] = (newExploreCounts[clean] ?? 0) + 1;

    final newTopicAffinities = Map<String, double>.from(p.topicAffinities);
    newTopicAffinities['topic:$clean'] = min(1.0, (newTopicAffinities['topic:$clean'] ?? 0.0) + 0.05);

    final newCategoryAffinities = Map<String, double>.from(p.categoryAffinities);
    if (category != null && category.isNotEmpty) {
      newCategoryAffinities[category] = min(1.0, (newCategoryAffinities[category] ?? 0.0) + 0.03);
    }

    final updated = p.copyWith(
      exploredTopicSlugs: newExplored,
      topicExploreCounts: newExploreCounts,
      topicAffinities: newTopicAffinities,
      categoryAffinities: newCategoryAffinities,
    );

    profile.value = updated;
    _saveToCache(updated);
    profile.refresh();

    final userId = p.userId;
    if (userId.isNotEmpty && userId != 'guest_user') {
      _firestore.collection(FirestoreCollections.users).doc(userId).set({
        'exploredTopicSlugs': newExplored.toList(),
        'topicExploreCounts': newExploreCounts,
        'topicAffinities': newTopicAffinities,
      }, SetOptions(merge: true)).catchError((e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'UserInterestProfileService.onTopicExplored',
        );
      });
    }
  }

  /// Track when a user discovers/views a channel
  void onChannelDiscovered(String channelId, {String? category}) {
    final clean = channelId.trim();
    if (clean.isEmpty) return;
    final p = _ensureProfileExists();

    final newDiscovered = Set<String>.from(p.discoveredChannelIds)..add(clean);
    final newExploreCounts = Map<String, int>.from(p.channelExploreCounts);
    newExploreCounts[clean] = (newExploreCounts[clean] ?? 0) + 1;

    final newChannelAffinities = Map<String, double>.from(p.channelAffinities);
    newChannelAffinities[clean] = min(1.0, (newChannelAffinities[clean] ?? 0.0) + 0.05);

    final updated = p.copyWith(
      discoveredChannelIds: newDiscovered,
      channelExploreCounts: newExploreCounts,
      channelAffinities: newChannelAffinities,
    );

    profile.value = updated;
    _saveToCache(updated);
    profile.refresh();

    final userId = p.userId;
    if (userId.isNotEmpty && userId != 'guest_user') {
      _firestore.collection(FirestoreCollections.users).doc(userId).set({
        'discoveredChannelIds': newDiscovered.toList(),
        'channelExploreCounts': newExploreCounts,
        'channelAffinities': newChannelAffinities,
      }, SetOptions(merge: true)).catchError((e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'UserInterestProfileService.onChannelDiscovered',
        );
      });
    }
  }


  void onVideoLiked(
    String videoId,
    String category, {
    List<String> topics = const [],
  }) {
    final p = _ensureProfileExists();

    final signal = UserSignal(
      type: 'like',
      targetId: videoId,
      category: category,
      topics: topics,
      confidence: 0.95,
      source: 'explicit',
      timestamp: DateTime.now(),
      decayHalfLifeHours: 168,
    );

    final newRecentSignals = [signal, ...p.recentSignals].take(500).toList();
    final newCategoryAffinities = Map<String, double>.from(
      p.categoryAffinities,
    );
    newCategoryAffinities[category] =
        (newCategoryAffinities[category] ?? 0.0) + 0.05;
    if (newCategoryAffinities[category]! > 1.0) {
      newCategoryAffinities[category] = 1.0;
    }

    final newTopicAffinities = Map<String, double>.from(p.topicAffinities);
    for (final topic in topics) {
      newTopicAffinities[topic] = (newTopicAffinities[topic] ?? 0.0) + 0.03;
      if (newTopicAffinities[topic]! > 1.0) newTopicAffinities[topic] = 1.0;
    }

    final updated = p.copyWith(
      recentSignals: newRecentSignals,
      categoryAffinities: newCategoryAffinities,
      topicAffinities: newTopicAffinities,
    );

    profile.value = updated;
    _saveToCache(updated);
    profile.refresh();

    final userId = p.userId;
    if (userId.isNotEmpty && userId != 'guest_user') {
      _firestore.collection(FirestoreCollections.users).doc(userId).set({
        'categoryAffinities': newCategoryAffinities,
        'topicAffinities': newTopicAffinities,
        'recentSignals': newRecentSignals.map((e) => e.toMap()).toList(),
      }, SetOptions(merge: true));
    }
  }

  void onVideoDisliked(
    String videoId,
    String category, {
    List<String> topics = const [],
  }) {
    final p = _ensureProfileExists();

    final signal = UserSignal(
      type: 'dislike',
      targetId: videoId,
      category: category,
      topics: topics,
      confidence: 0.90,
      source: 'explicit',
      timestamp: DateTime.now(),
      decayHalfLifeHours: 336,
    );

    final newRecentSignals = [signal, ...p.recentSignals].take(500).toList();
    final newCategoryAffinities = Map<String, double>.from(
      p.categoryAffinities,
    );

    var newAffinity = (newCategoryAffinities[category] ?? 0.0) - 0.03;
    if (newAffinity < 0.0) newAffinity = 0.0;
    newCategoryAffinities[category] = newAffinity;

    final newDislikedCategories = Set<String>.from(p.dislikedCategories);
    if (newAffinity < 0.1) {
      newDislikedCategories.add(category);
    }

    final updated = p.copyWith(
      recentSignals: newRecentSignals,
      categoryAffinities: newCategoryAffinities,
      dislikedCategories: newDislikedCategories,
    );

    profile.value = updated;
    _saveToCache(updated);
    profile.refresh();

    final userId = p.userId;
    if (userId.isNotEmpty && userId != 'guest_user' && userId != 'guest') {
      _firestore.collection(FirestoreCollections.users).doc(userId).set({
        'categoryAffinities': newCategoryAffinities,
        'dislikedCategories': newDislikedCategories.toList(),
        'recentSignals': newRecentSignals.map((e) => e.toMap()).toList(),
      }, SetOptions(merge: true));
    }
  }

  void onTopicFollowed(String topicSlug) {
    final p = _ensureProfileExists();
    if (!p.followedTopicSlugs.contains(topicSlug)) {
      p.followedTopicSlugs.add(topicSlug);
      _saveToCache(p);
      profile.refresh();
    }
  }

  void onTopicUnfollowed(String topicSlug) {
    final p = _ensureProfileExists();
    if (p.followedTopicSlugs.contains(topicSlug)) {
      p.followedTopicSlugs.remove(topicSlug);
      _saveToCache(p);
      profile.refresh();
    }
  }

  void onChannelSubscribed(String channelId) {
    final p = _ensureProfileExists();
    if (!p.subscribedChannelIds.contains(channelId)) {
      p.subscribedChannelIds.add(channelId);
      _saveToCache(p);
      profile.refresh();
    }
  }

  void onChannelUnsubscribed(String channelId) {
    final p = _ensureProfileExists();
    if (p.subscribedChannelIds.contains(channelId)) {
      p.subscribedChannelIds.remove(channelId);
      _saveToCache(p);
      profile.refresh();
    }
  }

  void onVideoNotInterested(String videoId, {String? category}) {
    final p = _ensureProfileExists();

    final signal = UserSignal(
      type: 'not_interested',
      targetId: videoId,
      category: category,
      confidence: 0.85,
      source: 'explicit',
      timestamp: DateTime.now(),
      decayHalfLifeHours: 720,
    );

    final newRecentSignals = [signal, ...p.recentSignals].take(500).toList();
    final newNotInterestedVideoIds = Set<String>.from(p.notInterestedVideoIds);
    newNotInterestedVideoIds.add(videoId);

    final updated = p.copyWith(
      recentSignals: newRecentSignals,
      notInterestedVideoIds: newNotInterestedVideoIds,
    );

    profile.value = updated;
    _saveToCache(updated);
    profile.refresh();

    final userId = p.userId;
    if (userId.isNotEmpty && userId != 'guest_user' && userId != 'guest') {
      _firestore.collection(FirestoreCollections.users).doc(userId).set({
        'notInterestedVideoIds': FieldValue.arrayUnion([videoId]),
        'recentSignals': newRecentSignals.map((e) => e.toMap()).toList(),
      }, SetOptions(merge: true));
    }
  }

  void onChannelBlocked(String channelId) {
    final p = _ensureProfileExists();

    final signal = UserSignal(
      type: 'block_channel',
      targetId: channelId,
      confidence: 1.0,
      source: 'explicit',
      timestamp: DateTime.now(),
      decayHalfLifeHours: 8760, // 1 year = permanent
    );

    final newRecentSignals = [signal, ...p.recentSignals].take(500).toList();
    final newBlockedChannelIds = Set<String>.from(p.blockedChannelIds);
    newBlockedChannelIds.add(channelId);

    final newChannelAffinities = Map<String, double>.from(p.channelAffinities);
    newChannelAffinities[channelId] = -1.0;

    final updated = p.copyWith(
      recentSignals: newRecentSignals,
      blockedChannelIds: newBlockedChannelIds,
      channelAffinities: newChannelAffinities,
    );

    profile.value = updated;
    _saveToCache(updated);
    profile.refresh();

    final userId = p.userId;
    if (userId.isNotEmpty && userId != 'guest_user' && userId != 'guest') {
      _firestore.collection(FirestoreCollections.users).doc(userId).set({
        'blockedChannelIds': FieldValue.arrayUnion([channelId]),
        'channelAffinities': newChannelAffinities,
        'recentSignals': newRecentSignals.map((e) => e.toMap()).toList(),
      }, SetOptions(merge: true));
    }
  }

  /// Increments flipCoinCount in profile and saves to cache/Firestore
  void onFlipCoinTapped(String surface) {
    final p = _ensureProfileExists();
    final updated = p.copyWith(
      flipCoinCount: p.flipCoinCount + 1,
    );
    profile.value = updated;
    _saveToCache(updated);
    profile.refresh();

    final userId = p.userId;
    if (userId.isNotEmpty && userId != 'guest_user') {
      _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .set({
            'flipCoinCount': FieldValue.increment(1),
            'lastFlipSurface': surface,
            'lastFlippedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .catchError((e) {
            debugPrint(
              '[UserInterestProfileService] Error updating flipCoinCount: $e',
            );
          });
    }
  }

  /// Build interest graph from watch history co-occurrences
  Map<String, double> _buildInterestGraph(
    List<Map<String, dynamic>> watchHistory,
  ) {
    final graph = <String, double>{};
    for (final item in watchHistory) {
      final topics = item['topics'] as List<dynamic>?;
      if (topics != null && topics.length >= 2) {
        for (var i = 0; i < topics.length; i++) {
          for (var j = i + 1; j < topics.length; j++) {
            final t1 = topics[i].toString();
            final t2 = topics[j].toString();
            final pair = [t1, t2]..sort();
            final pairKey = pair.join('_');
            graph[pairKey] = (graph[pairKey] ?? 0) + 1.0;
          }
        }
      }
    }
    return graph;
  }

  /// Load from local cache
  UserInterestProfile? _loadFromCache([String key = _cacheKey]) {
    final data = _storage.read(key);
    if (data != null && data is Map) {
      try {
        return UserInterestProfile.fromMap(Map<String, dynamic>.from(data));
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'UserInterestProfileService.deserializeCache',
        );
      }
    }
    return null;
  }

  /// Save to local cache
  void _saveToCache(UserInterestProfile profileData, {String? key}) {
    final cacheKey = key ?? (profileData.userId == 'guest' ? _guestCacheKey : _cacheKey);
    _storage.write(cacheKey, profileData.toMap());
  }
}
