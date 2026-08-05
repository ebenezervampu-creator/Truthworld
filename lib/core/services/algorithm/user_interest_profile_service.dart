import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile.dart';

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
  static const _refreshInterval = Duration(minutes: 15);

  final profile = Rxn<UserInterestProfile>();
  DateTime? _lastFullRefresh;
  bool _isLoading = false;

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
    } catch (e) {
      debugPrint('[UserInterestProfileService] Error loading profile: $e');
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
          .limit(200)
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
    // final likedVideosQuery = futures[3] as QuerySnapshot<Map<String, dynamic>>;

    var following = <String>[];
    if (userDoc.exists) {
      final data = userDoc.data();
      if (data != null && data['following'] != null) {
        following = List<String>.from(data['following']);
      }
    }

    final followedTopics = savedTopicsQuery.docs
        .map((doc) => doc.id)
        .toList();

    final watchHistory = watchHistoryQuery.docs
        .map((doc) => doc.data())
        .toList();

    final categoryWatchCounts = <String, int>{};
    final topicWatchCounts = <String, int>{};

    for (final doc in watchHistory) {
      final category = doc['category'] as String?;
      if (category != null) {
        categoryWatchCounts[category] =
            (categoryWatchCounts[category] ?? 0) + 1;
      }
      final topics = doc['topics'] as List<dynamic>?;
      if (topics != null) {
        for (final topic in topics) {
          topicWatchCounts[topic.toString()] =
              (topicWatchCounts[topic.toString()] ?? 0) + 1;
        }
      }
    }

    final interestGraph = _buildInterestGraph(watchHistory);

    final newProfile = UserInterestProfile(
      userId: userId,
      interestGraph: interestGraph,
      subscribedChannelIds: following.toSet(),
      followedTopicSlugs: followedTopics.toSet(),
      categoryWatchCounts: categoryWatchCounts,
      topicWatchCounts: topicWatchCounts,
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
    profile.value = null;
    _storage.remove(_cacheKey);
    _lastFullRefresh = null;
  }

  /// Incremental updates (don't need full Firestore reload)
  void onVideoWatched(
    String videoId,
    String category,
    List<String> topics,
    double completion,
  ) {
    if (profile.value == null) return;
    final p = profile.value!;
    p.categoryWatchCounts[category] =
        (p.categoryWatchCounts[category] ?? 0) + 1;
    for (final topic in topics) {
      p.topicWatchCounts[topic] = (p.topicWatchCounts[topic] ?? 0) + 1;
    }
    _saveToCache(p);
    profile.refresh();
  }

  void onVideoLiked(
    String videoId,
    String category, {
    List<String> topics = const [],
  }) {
    if (profile.value == null) return;
    final p = profile.value!;

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
    if (profile.value == null) return;
    final p = profile.value!;

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
    if (userId.isNotEmpty && userId != 'guest_user') {
      _firestore.collection(FirestoreCollections.users).doc(userId).set({
        'categoryAffinities': newCategoryAffinities,
        'dislikedCategories': newDislikedCategories.toList(),
        'recentSignals': newRecentSignals.map((e) => e.toMap()).toList(),
      }, SetOptions(merge: true));
    }
  }

  void onTopicFollowed(String topicSlug) {
    if (profile.value == null) return;
    if (!profile.value!.followedTopicSlugs.contains(topicSlug)) {
      profile.value!.followedTopicSlugs.add(topicSlug);
      _saveToCache(profile.value!);
      profile.refresh();
    }
  }

  void onTopicUnfollowed(String topicSlug) {
    if (profile.value == null) return;
    if (profile.value!.followedTopicSlugs.contains(topicSlug)) {
      profile.value!.followedTopicSlugs.remove(topicSlug);
      _saveToCache(profile.value!);
      profile.refresh();
    }
  }

  void onChannelSubscribed(String channelId) {
    if (profile.value == null) return;
    if (!profile.value!.subscribedChannelIds.contains(channelId)) {
      profile.value!.subscribedChannelIds.add(channelId);
      _saveToCache(profile.value!);
      profile.refresh();
    }
  }

  void onChannelUnsubscribed(String channelId) {
    if (profile.value == null) return;
    if (profile.value!.subscribedChannelIds.contains(channelId)) {
      profile.value!.subscribedChannelIds.remove(channelId);
      _saveToCache(profile.value!);
      profile.refresh();
    }
  }

  void onVideoNotInterested(String videoId, {String? category}) {
    if (profile.value == null) return;
    final p = profile.value!;

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
    if (userId.isNotEmpty && userId != 'guest_user') {
      _firestore.collection(FirestoreCollections.users).doc(userId).set({
        'notInterestedVideoIds': FieldValue.arrayUnion([videoId]),
        'recentSignals': newRecentSignals.map((e) => e.toMap()).toList(),
      }, SetOptions(merge: true));
    }
  }

  void onChannelBlocked(String channelId) {
    if (profile.value == null) return;
    final p = profile.value!;

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
    if (userId.isNotEmpty && userId != 'guest_user') {
      _firestore.collection(FirestoreCollections.users).doc(userId).set({
        'blockedChannelIds': FieldValue.arrayUnion([channelId]),
        'channelAffinities': newChannelAffinities,
        'recentSignals': newRecentSignals.map((e) => e.toMap()).toList(),
      }, SetOptions(merge: true));
    }
  }

  /// Increments flipCoinCount in profile and saves to cache/Firestore
  void onFlipCoinTapped(String surface) {
    if (profile.value == null) return;
    final p = profile.value!;
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
  UserInterestProfile? _loadFromCache() {
    final data = _storage.read(_cacheKey);
    if (data != null && data is Map<String, dynamic>) {
      return UserInterestProfile.fromMap(data);
    }
    return null;
  }

  /// Save to local cache
  void _saveToCache(UserInterestProfile profileData) {
    _storage.write(_cacheKey, profileData.toMap());
  }
}
