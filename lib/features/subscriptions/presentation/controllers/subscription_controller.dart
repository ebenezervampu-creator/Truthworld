import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/data/models/subscription_content.dart';
import 'package:truthworld/data/models/subscriptions.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

enum ContentFilter {
  all,
  videos,
  playlists,
  communityPosts,
  topics,
}

enum SortFilter {
  trending,
  popular,
  newest,
  oldest,
}

enum DurationFilter {
  all,
  short,
  medium,
  long,
}

enum DateRangeFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  thisYear,
}

class SubscriptionController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final RxList<SubscriptionContent> allContent = <SubscriptionContent>[].obs;
  final RxList<SubscriptionContent> filteredContent =
      <SubscriptionContent>[].obs;
  final RxList<Subscription> subscriptions = <Subscription>[].obs;
  final RxList<Channel> subscribedChannels = <Channel>[].obs;

  final RxString selectedContentFilter = ContentFilter.all.name.obs;
  final RxString selectedSortFilter = SortFilter.trending.name.obs;
  final RxString selectedDurationFilter = DurationFilter.all.name.obs;
  final RxString selectedDateRangeFilter = DateRangeFilter.all.name.obs;

  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  String? get currentUserId =>
      AuthService.to.uid.isNotEmpty ? AuthService.to.uid : null;

  @override
  void onInit() {
    super.onInit();

    // Initial load
    refresh();

    // Setup auth listener to automatically refresh on auth status change
    ever(AuthService.to.currentUser, (user) {
      debugPrint(
        '[SubscriptionController] Auth state changed. Refreshing subscriptions...',
      );
      refresh();
    });

    // Setup connectivity listener for automatic recovery
    try {
      if (Get.isRegistered<ConnectivityService>()) {
        _connectivitySubscription = Get.find<ConnectivityService>()
            .onConnectivityChanged
            .listen((results) {
              if (results.isNotEmpty &&
                  results.first != ConnectivityResult.none) {
                debugPrint(
                  '[SubscriptionController] Network restored. Refreshing subscriptions...',
                );
                refresh();
              }
            });
      }
    } on Object catch (e) {
      debugPrint(
        '[SubscriptionController] Connectivity listener setup skipped: $e',
      );
    }
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    super.onClose();
  }

  @override
  Future<void> refresh() async {
    if (currentUserId == null) {
      errorMessage.value = 'Please sign in to view subscriptions';
      hasError.value = true;
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';

    try {
      await loadSubscriptions();
      await loadSubscribedChannels();
      await loadAllContent();
      applyFilters();
    } on Object catch (e) {
      hasError.value = true;
      errorMessage.value = e.toString().contains('permission')
          ? 'Permission denied. Please check your login status.'
          : 'Something went wrong. Pull to retry.';
      debugPrint('Error in refresh: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Industry Standard: Multi-source subscription resolution with channel deduplication
  Future<void> loadSubscriptions() async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    try {
      final subMap = <String, Subscription>{};

      // 1. Primary: Root subscriptions collection
      try {
        final snapshot = await _firestore
            .collection(FirestoreCollections.subscriptions)
            .where('userId', isEqualTo: uid)
            .get();

        for (final doc in snapshot.docs) {
          final sub = Subscription.fromDocumentSnapshot(doc);
          if (sub.channelId.isNotEmpty) {
            subMap[sub.channelId] = sub;
          }
        }
      } on Object catch (e) {
        debugPrint(
          '[SubscriptionController] Query primary subscriptions failed: $e',
        );
      }

      // 2. Alternative: Subscriptions doc subcollection (subscriptions/{uid}/list)
      try {
        final snapshot = await _firestore
            .collection(FirestoreCollections.subscriptions)
            .doc(uid)
            .collection('list')
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final chId = data['channelId'] as String? ?? doc.id;
          if (chId.isNotEmpty && !subMap.containsKey(chId)) {
            subMap[chId] = Subscription(userId: uid, channelId: chId);
          }
        }
      } on Object catch (_) {}

      // 3. Alternative: userCache (userCache/{uid}/subscriptions)
      try {
        final snapshot = await _firestore
            .collection('userCache')
            .doc(uid)
            .collection(FirestoreCollections.subscriptions)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final chId = data['channelId'] as String? ?? doc.id;
          if (chId.isNotEmpty && !subMap.containsKey(chId)) {
            subMap[chId] = Subscription(userId: uid, channelId: chId);
          }
        }
      } on Object catch (_) {}

      // 4. Alternative: users subcollection (users/{uid}/subscriptions)
      try {
        final snapshot = await _firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .collection(FirestoreCollections.subscriptions)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final chId = data['channelId'] as String? ?? doc.id;
          if (chId.isNotEmpty && !subMap.containsKey(chId)) {
            subMap[chId] = Subscription(userId: uid, channelId: chId);
          }
        }
      } on Object catch (_) {}

      subscriptions.value = subMap.values.toList();
    } on Object catch (e) {
      debugPrint('Error loading subscriptions: $e');
      throw Exception('Failed loading subscriptions: $e');
    }
  }

  Future<void> loadSubscribedChannels() async {
    if (subscriptions.isEmpty) {
      subscribedChannels.clear();
      return;
    }
    final channelIds = subscriptions.map((s) => s.channelId).toSet().toList();
    try {
      final batchFutures = <Future<List<Channel>>>[];
      const batchSize = 10;
      for (var i = 0; i < channelIds.length; i += batchSize) {
        final batch = channelIds.sublist(
          i,
          i + batchSize > channelIds.length ? channelIds.length : i + batchSize,
        );
        batchFutures.add(() async {
          try {
            final snapshot = await _firestore
                .collection(FirestoreCollections.channels)
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            return snapshot.docs.map(Channel.fromDocumentSnapshot).toList();
          } on Object catch (e) {
            debugPrint(
              '[SubscriptionController] Batch channel fetch failed for $batch: $e',
            );
            return <Channel>[];
          }
        }());
      }
      final results = await Future.wait(batchFutures);
      subscribedChannels.value = results.expand((c) => c).toList();
    } on Object catch (e) {
      debugPrint('Error loading subscribed channels: $e');
    }
  }

  Future<void> loadAllContent() async {
    if (subscriptions.isEmpty) {
      allContent.clear();
      filteredContent.clear();
      return;
    }

    final channelIds = subscriptions.map((s) => s.channelId).toSet().toList();

    try {
      final contentMap = <String, SubscriptionContent>{};

      // Load videos
      try {
        final videos = await _loadVideos(channelIds);
        for (final v in videos) {
          final content = SubscriptionContent.fromVideo(v);
          contentMap[content.id] = content;
        }
      } on Object catch (e) {
        debugPrint('Error loading subscription videos: $e');
      }

      // Load playlists
      try {
        final playlists = await _loadPlaylists(channelIds);
        for (final p in playlists) {
          final content = SubscriptionContent.fromPlaylist(p);
          contentMap[content.id] = content;
        }
      } on Object catch (e) {
        debugPrint('Error loading subscription playlists: $e');
      }

      // Load community posts
      try {
        final communityPosts = await _loadCommunityPosts(channelIds);
        for (final cp in communityPosts) {
          final content = SubscriptionContent.fromCommunityPost(cp);
          contentMap[content.id] = content;
        }
      } on Object catch (e) {
        debugPrint('Error loading subscription community posts: $e');
      }

      // Load topics
      try {
        final topics = await _loadTopics(channelIds);
        for (final t in topics) {
          final content = SubscriptionContent.fromTopic(t);
          contentMap[content.id] = content;
        }
      } on Object catch (e) {
        debugPrint('Error loading subscription topics: $e');
      }

      final contentList = contentMap.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      allContent.value = contentList;
    } on Object catch (e) {
      debugPrint('Error loading content: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Industry Standard Feed Aggregation: Index-resilient query + in-memory VideoVisibilityPolicy
  Future<List<Video>> _loadVideos(List<String> channelIds) async {
    final videos = <Video>[];
    if (channelIds.isEmpty) return videos;

    const batchSize = 10;
    for (var i = 0; i < channelIds.length; i += batchSize) {
      final batch = channelIds.sublist(
        i,
        i + batchSize > channelIds.length ? channelIds.length : i + batchSize,
      );

      final docs = <DocumentSnapshot>[];

      // Attempt 1: Fetch channel batch without fragile multi-field composite index constraints
      try {
        final snapshot = await _firestore
            .collection(FirestoreCollections.videos)
            .where('channelId', whereIn: batch)
            .limit(50)
            .get();
        docs.addAll(snapshot.docs);
      } on Object catch (e) {
        debugPrint(
          '[SubscriptionController] Batch video query failed ($e). Falling back to per-channel query.',
        );
        for (final cid in batch) {
          try {
            final snap = await _firestore
                .collection(FirestoreCollections.videos)
                .where('channelId', isEqualTo: cid)
                .limit(20)
                .get();
            docs.addAll(snap.docs);
          } on Object catch (err) {
            debugPrint(
              '[SubscriptionController] Per-channel video query failed for $cid: $err',
            );
          }
        }
      }

      for (final doc in docs) {
        try {
          final video = Video.fromDocumentSnapshot(doc);
          if (VideoVisibilityPolicy.isVisibleForFeed(video)) {
            videos.add(video);
          }
        } on Object catch (e) {
          debugPrint('Error parsing video doc ${doc.id}: $e');
        }
      }
    }

    return videos;
  }

  Future<List<PlaylistModel>> _loadPlaylists(List<String> channelIds) async {
    final playlists = <PlaylistModel>[];
    if (channelIds.isEmpty) return playlists;

    const batchSize = 10;
    for (var i = 0; i < channelIds.length; i += batchSize) {
      final batch = channelIds.sublist(
        i,
        i + batchSize > channelIds.length ? channelIds.length : i + batchSize,
      );

      final docs = <DocumentSnapshot>[];

      try {
        final snapshot = await _firestore
            .collection(FirestoreCollections.playlists)
            .where('channelId', whereIn: batch)
            .where('isPublic', isEqualTo: true)
            .limit(30)
            .get();
        docs.addAll(snapshot.docs);
      } on Object catch (e) {
        debugPrint('[SubscriptionController] Batch playlist query failed: $e');
        for (final cid in batch) {
          try {
            final snap = await _firestore
                .collection(FirestoreCollections.playlists)
                .where('channelId', isEqualTo: cid)
                .where('isPublic', isEqualTo: true)
                .limit(10)
                .get();
            docs.addAll(snap.docs);
          } on Object catch (_) {}
        }
      }

      for (final doc in docs) {
        try {
          final playlist = PlaylistModel.fromDocumentSnapshot(doc);
          if (playlist.isPublic) {
            playlists.add(playlist);
          }
        } on Object catch (e) {
          debugPrint('Error parsing playlist doc ${doc.id}: $e');
        }
      }
    }

    return playlists;
  }

  Future<List<CommunityPostModel>> _loadCommunityPosts(
    List<String> channelIds,
  ) async {
    final posts = <CommunityPostModel>[];
    if (channelIds.isEmpty) return posts;

    const batchSize = 10;
    for (var i = 0; i < channelIds.length; i += batchSize) {
      final batch = channelIds.sublist(
        i,
        i + batchSize > channelIds.length ? channelIds.length : i + batchSize,
      );

      final docs = <DocumentSnapshot>[];

      try {
        final snapshot = await _firestore
            .collection(FirestoreCollections.community)
            .where('channelId', whereIn: batch)
            .limit(30)
            .get();
        docs.addAll(snapshot.docs);
      } on Object catch (e) {
        debugPrint(
          '[SubscriptionController] Batch community post query failed: $e',
        );
        for (final cid in batch) {
          try {
            final snap = await _firestore
                .collection(FirestoreCollections.community)
                .where('channelId', isEqualTo: cid)
                .limit(10)
                .get();
            docs.addAll(snap.docs);
          } on Object catch (_) {}
        }
      }

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      for (final doc in docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          final post = CommunityPostModel.fromMap(data);
          final vis = (data['visibility'] as String? ?? 'public').toLowerCase();
          final ownerId = data['ownerId'] as String? ?? '';
          if (vis == 'public' ||
              vis == 'subscribers' ||
              vis == 'members' ||
              ownerId == currentUid) {
            posts.add(post);
          }
        } on Object catch (e) {
          debugPrint('Error parsing community post doc ${doc.id}: $e');
        }
      }
    }

    return posts;
  }

  Future<List<Topic>> _loadTopics(List<String> channelIds) async {
    final topics = <Topic>[];
    if (channelIds.isEmpty) return topics;

    const batchSize = 10;
    for (var i = 0; i < channelIds.length; i += batchSize) {
      final batch = channelIds.sublist(
        i,
        i + batchSize > channelIds.length ? channelIds.length : i + batchSize,
      );

      final docs = <DocumentSnapshot>[];

      try {
        final snapshot = await _firestore
            .collection(FirestoreCollections.topics)
            .where('channelId', whereIn: batch)
            .where('status', isEqualTo: 'active')
            .limit(30)
            .get();
        docs.addAll(snapshot.docs);
      } on Object catch (e) {
        debugPrint('[SubscriptionController] Batch topics query failed: $e');
        for (final cid in batch) {
          try {
            final snap = await _firestore
                .collection(FirestoreCollections.topics)
                .where('channelId', isEqualTo: cid)
                .where('status', isEqualTo: 'active')
                .limit(10)
                .get();
            docs.addAll(snap.docs);
          } on Object catch (_) {}
        }
      }

      for (final doc in docs) {
        try {
          final topic = Topic.fromDocumentSnapshot(doc);
          topics.add(topic);
        } on Object catch (e) {
          debugPrint('Error parsing topic doc ${doc.id}: $e');
        }
      }
    }

    return topics;
  }

  void applyFilters() {
    filteredContent.value = List.from(allContent);

    // Apply content type filter
    final contentFilter = ContentFilter.values.firstWhere(
      (e) => e.name == selectedContentFilter.value,
      orElse: () => ContentFilter.all,
    );

    if (contentFilter != ContentFilter.all) {
      switch (contentFilter) {
        case ContentFilter.videos:
          filteredContent.retainWhere((c) => c.type == ContentType.video);
        case ContentFilter.playlists:
          filteredContent.retainWhere((c) => c.type == ContentType.playlist);
        case ContentFilter.communityPosts:
          filteredContent.retainWhere(
            (c) => c.type == ContentType.communityPost,
          );
        case ContentFilter.topics:
          filteredContent.retainWhere((c) => c.type == ContentType.topic);
        case ContentFilter.all:
          break;
      }
    }

    // Apply duration filter (only for videos)
    final durationFilter = DurationFilter.values.firstWhere(
      (e) => e.name == selectedDurationFilter.value,
      orElse: () => DurationFilter.all,
    );

    if (durationFilter != DurationFilter.all) {
      filteredContent.retainWhere((c) {
        if (c.type != ContentType.video) return false;
        final duration = c.video?.durationValue.inMinutes ?? 0;
        switch (durationFilter) {
          case DurationFilter.short:
            return duration < 5;
          case DurationFilter.medium:
            return duration >= 5 && duration <= 20;
          case DurationFilter.long:
            return duration > 20;
          case DurationFilter.all:
            return true;
        }
      });
    }

    // Apply date range filter
    final dateRangeFilter = DateRangeFilter.values.firstWhere(
      (e) => e.name == selectedDateRangeFilter.value,
      orElse: () => DateRangeFilter.all,
    );

    if (dateRangeFilter != DateRangeFilter.all) {
      final now = DateTime.now();
      filteredContent.retainWhere((c) {
        final contentDate = c.createdAt.toDate();
        switch (dateRangeFilter) {
          case DateRangeFilter.today:
            return contentDate.day == now.day &&
                contentDate.month == now.month &&
                contentDate.year == now.year;
          case DateRangeFilter.thisWeek:
            return now.difference(contentDate).inDays <= 7;
          case DateRangeFilter.thisMonth:
            return contentDate.month == now.month &&
                contentDate.year == now.year;
          case DateRangeFilter.thisYear:
            return contentDate.year == now.year;
          case DateRangeFilter.all:
            return true;
        }
      });
    }

    // Apply sorting
    final sortFilter = SortFilter.values.firstWhere(
      (e) => e.name == selectedSortFilter.value,
      orElse: () => SortFilter.trending,
    );

    switch (sortFilter) {
      case SortFilter.trending:
        if (Get.isRegistered<TruthworldAlgorithm>()) {
          final algorithm = Get.find<TruthworldAlgorithm>();
          filteredContent.sort((a, b) {
            var scoreA = a.algorithmicScore;
            var scoreB = b.algorithmicScore;
            if (a.video != null) {
              final s =
                  algorithm.scoreVideo(
                        a.video!,
                        RecommendationSurface.subscriptionFeed,
                      )
                      as num?;
              if (s != null) scoreA += s.toDouble() * 5.0;
            }
            if (b.video != null) {
              final s =
                  algorithm.scoreVideo(
                        b.video!,
                        RecommendationSurface.subscriptionFeed,
                      )
                      as num?;
              if (s != null) scoreB += s.toDouble() * 5.0;
            }
            return scoreB.compareTo(scoreA);
          });
        } else {
          filteredContent.sort(
            (a, b) => b.algorithmicScore.compareTo(a.algorithmicScore),
          );
        }
      case SortFilter.popular:
        filteredContent.sort((a, b) {
          final aEngagement = _getEngagementScore(a);
          final bEngagement = _getEngagementScore(b);
          return bEngagement.compareTo(aEngagement);
        });
      case SortFilter.newest:
        filteredContent.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortFilter.oldest:
        filteredContent.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
  }

  double _getEngagementScore(SubscriptionContent content) {
    switch (content.type) {
      case ContentType.video:
        return content.video?.views.toDouble() ?? 0;
      case ContentType.playlist:
        return content.playlist?.videoCount.toDouble() ?? 0;
      case ContentType.communityPost:
        return content.communityPost?.likes.toDouble() ?? 0;
      case ContentType.topic:
        return content.topic?.followerCount.toDouble() ?? 0;
    }
  }

  void setContentFilter(String filter) {
    selectedContentFilter.value = filter;
    if (filter == ContentFilter.playlists.name ||
        filter == ContentFilter.communityPosts.name) {
      selectedDurationFilter.value = DurationFilter.all.name;
    }
    applyFilters();
  }

  void setSortFilter(String filter) {
    selectedSortFilter.value = filter;
    applyFilters();
  }

  void setDurationFilter(String filter) {
    selectedDurationFilter.value = filter;
    if (filter != DurationFilter.all.name) {
      selectedContentFilter.value = ContentFilter.videos.name;
    }
    applyFilters();
  }

  void setDateRangeFilter(String filter) {
    selectedDateRangeFilter.value = filter;
    applyFilters();
  }

  Future<void> subscribeToChannel(String channelId) async {
    if (currentUserId == null) {
      Get.snackbar('Error', 'Please sign in to subscribe');
      return;
    }

    try {
      if (subscriptions.any((s) => s.channelId == channelId)) {
        Get.snackbar('Info', 'Already subscribed to this channel');
        return;
      }

      // YouTube-standard: deterministic doc ID for dedup + atomic count
      final subDocId = '${channelId}_$currentUserId';
      final subRef = _firestore
          .collection(FirestoreCollections.subscriptions)
          .doc(subDocId);
      final channelRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId);

      await _firestore.runTransaction((tx) async {
        final existing = await tx.get(subRef);
        if (existing.exists) return;
        tx
          ..set(subRef, {
            'userId': currentUserId,
            'channelId': channelId,
            'subscribedAt': FieldValue.serverTimestamp(),
            'notificationsEnabled': true,
          })
          ..update(channelRef, {
            'subscriberCount': FieldValue.increment(1),
          });
      }, maxAttempts: 3);

      // Optimistic local update instead of full reload
      subscriptions.add(
        Subscription(
          userId: currentUserId!,
          channelId: channelId,
        ),
      );
      await loadSubscribedChannels();
      await loadAllContent();
      applyFilters();

      Get.snackbar('Success', 'Subscribed successfully');
    } on Object catch (e) {
      debugPrint('Error subscribing: $e');
      Get.snackbar('Error', 'Failed to subscribe: $e');
    }
  }

  Future<void> unsubscribeFromChannel(String channelId) async {
    if (currentUserId == null) return;

    try {
      // Try deterministic ID first (new standard)
      final subDocId = '${channelId}_$currentUserId';
      final subRef = _firestore
          .collection(FirestoreCollections.subscriptions)
          .doc(subDocId);
      final channelRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId);

      final subDoc = await subRef.get();
      if (subDoc.exists) {
        // Deterministic ID doc found — atomic delete + decrement
        await _firestore.runTransaction((tx) async {
          tx
            ..delete(subRef)
            ..update(channelRef, {
              'subscriberCount': FieldValue.increment(-1),
            });
        }, maxAttempts: 3);
      } else {
        // Fallback: query for legacy auto-generated ID docs
        final snapshot = await _firestore
            .collection(FirestoreCollections.subscriptions)
            .where('userId', isEqualTo: currentUserId)
            .where('channelId', isEqualTo: channelId)
            .get();
        if (snapshot.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          batch.update(channelRef, {
            'subscriberCount': FieldValue.increment(-1),
          });
          await batch.commit();
        }
      }

      // Optimistic local update
      subscriptions.removeWhere((s) => s.channelId == channelId);
      await loadSubscribedChannels();
      await loadAllContent();
      applyFilters();

      Get.snackbar('Success', 'Unsubscribed successfully');
    } on Object catch (e) {
      debugPrint('Error unsubscribing: $e');
      Get.snackbar('Error', 'Failed to unsubscribe: $e');
    }
  }

  bool isSubscribed(String channelId) {
    return subscriptions.any((s) => s.channelId == channelId);
  }
}
