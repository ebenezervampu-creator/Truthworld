import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/data/models/subscriptions.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/commnuity/data/models/community_post_model.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/subscription_content.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/core/services/auth_service.dart';

enum ContentFilter {
  all,
  videos,
  playlists,
  communityPosts,
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
  StreamSubscription? _connectivitySubscription;

  final RxList<SubscriptionContent> allContent = <SubscriptionContent>[].obs;
  final RxList<SubscriptionContent> filteredContent = <SubscriptionContent>[].obs;
  final RxList<Subscription> subscriptions = <Subscription>[].obs;
  final RxList<Channel> subscribedChannels = <Channel>[].obs;

  final RxString selectedContentFilter = ContentFilter.all.name.obs;
  final RxString selectedSortFilter = SortFilter.trending.name.obs;
  final RxString selectedDurationFilter = DurationFilter.all.name.obs;
  final RxString selectedDateRangeFilter = DateRangeFilter.all.name.obs;

  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  String? get currentUserId => AuthService.to.uid.isNotEmpty ? AuthService.to.uid : null;

  @override
  void onInit() {
    super.onInit();
    
    // Initial load
    refresh();

    // Setup auth listener to automatically refresh on auth status change
    ever(AuthService.to.currentUser, (user) {
      debugPrint('[SubscriptionController] Auth state changed. Refreshing subscriptions...');
      refresh();
    });

    // Setup connectivity listener for automatic recovery
    _connectivitySubscription = Get.find<ConnectivityService>().onConnectivityChanged.listen((results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        debugPrint('[SubscriptionController] Network restored. Refreshing subscriptions...');
        refresh();
      }
    });
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
    } catch (e) {
      hasError.value = true;
      errorMessage.value = e.toString().contains('permission')
          ? 'Permission denied. Please check your login status.'
          : 'Something went wrong. Pull to retry.';
      debugPrint('Error in refresh: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadSubscriptions() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final snapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: currentUserId)
          .get();

      subscriptions.value = snapshot.docs
          .map((doc) => Subscription.fromDocumentSnapshot(doc))
          .toList();
    } catch (e) {
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
      final List<Channel> channels = [];
      if (channelIds.length > 10) {
        for (int i = 0; i < channelIds.length; i += 10) {
          final batch = channelIds.sublist(
            i,
            i + 10 > channelIds.length ? channelIds.length : i + 10,
          );
          final snapshot = await _firestore
              .collection('channels')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          channels.addAll(snapshot.docs.map((doc) => Channel.fromDocumentSnapshot(doc)));
        }
      } else {
        final snapshot = await _firestore
            .collection('channels')
            .where(FieldPath.documentId, whereIn: channelIds)
            .get();
        channels.addAll(snapshot.docs.map((doc) => Channel.fromDocumentSnapshot(doc)));
      }
      subscribedChannels.value = channels;
    } catch (e) {
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
      final List<SubscriptionContent> contentList = [];
      
      // Load videos
      try {
        final videos = await _loadVideos(channelIds);
        contentList.addAll(videos.map((v) => SubscriptionContent.fromVideo(v)));
      } catch (e) {
        debugPrint('Error loading subscription videos: $e');
      }
      
      // Load playlists
      try {
        final playlists = await _loadPlaylists(channelIds);
        contentList.addAll(playlists.map((p) => SubscriptionContent.fromPlaylist(p)));
      } catch (e) {
        debugPrint('Error loading subscription playlists: $e');
      }
      
      // Load community posts
      try {
        final communityPosts = await _loadCommunityPosts(channelIds);
        contentList.addAll(communityPosts.map((cp) => SubscriptionContent.fromCommunityPost(cp)));
      } catch (e) {
        debugPrint('Error loading subscription community posts: $e');
      }
      
      allContent.value = contentList;
    } catch (e) {
      debugPrint('Error loading content: $e');
      // Do not throw here so the page can show partial results or empty state
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<Video>> _loadVideos(List<String> channelIds) async {
    final List<Video> videos = [];
    
    if (channelIds.length > 10) {
      for (int i = 0; i < channelIds.length; i += 10) {
        final batch = channelIds.sublist(
          i,
          i + 10 > channelIds.length ? channelIds.length : i + 10,
        );
        final snapshot = await _firestore
            .collection('videos')
            .where('channelId', whereIn: batch)
            .where('visibility', isEqualTo: 'Public')
            .orderBy('uploadedAt', descending: true)
            .limit(50)
            .get();
        videos.addAll(snapshot.docs.map((doc) => Video.fromDocumentSnapshot(doc)));
      }
    } else {
      final snapshot = await _firestore
          .collection('videos')
          .where('channelId', whereIn: channelIds)
          .where('visibility', isEqualTo: 'Public')
          .orderBy('uploadedAt', descending: true)
          .limit(50)
          .get();
      videos.addAll(snapshot.docs.map((doc) => Video.fromDocumentSnapshot(doc)));
    }
    
    return videos;
  }

  Future<List<PlaylistModel>> _loadPlaylists(List<String> channelIds) async {
    final List<PlaylistModel> playlists = [];
    
    if (channelIds.length > 10) {
      for (int i = 0; i < channelIds.length; i += 10) {
        final batch = channelIds.sublist(
          i,
          i + 10 > channelIds.length ? channelIds.length : i + 10,
        );
        final snapshot = await _firestore
            .collection('playlists')
            .where('channelId', whereIn: batch)
            .where('visibility', isEqualTo: 'public')
            .orderBy('createdAt', descending: true)
            .limit(30)
            .get();
        playlists.addAll(snapshot.docs.map((doc) => PlaylistModel.fromDocumentSnapshot(doc)));
      }
    } else {
      final snapshot = await _firestore
          .collection('playlists')
          .where('channelId', whereIn: channelIds)
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();
      playlists.addAll(snapshot.docs.map((doc) => PlaylistModel.fromDocumentSnapshot(doc)));
    }
    
    return playlists;
  }

  Future<List<CommunityPostModel>> _loadCommunityPosts(List<String> channelIds) async {
    final List<CommunityPostModel> posts = [];
    
    if (channelIds.length > 10) {
      for (int i = 0; i < channelIds.length; i += 10) {
        final batch = channelIds.sublist(
          i,
          i + 10 > channelIds.length ? channelIds.length : i + 10,
        );
        final snapshot = await _firestore
            .collection('Community')
            .where('channelId', whereIn: batch)
            .where('visibility', isEqualTo: 'Public')
            .orderBy('uploadedAt', descending: true)
            .limit(30)
            .get();
        posts.addAll(snapshot.docs.map((doc) => CommunityPostModel.fromMap(doc.data())));
      }
    } else {
      final snapshot = await _firestore
          .collection('Community')
          .where('channelId', whereIn: channelIds)
          .where('visibility', isEqualTo: 'Public')
          .orderBy('uploadedAt', descending: true)
          .limit(30)
          .get();
      posts.addAll(snapshot.docs.map((doc) => CommunityPostModel.fromMap(doc.data())));
    }
    
    return posts;
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
          break;
        case ContentFilter.playlists:
          filteredContent.retainWhere((c) => c.type == ContentType.playlist);
          break;
        case ContentFilter.communityPosts:
          filteredContent.retainWhere((c) => c.type == ContentType.communityPost);
          break;
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
        filteredContent.sort((a, b) => b.algorithmicScore.compareTo(a.algorithmicScore));
        break;
      case SortFilter.popular:
        filteredContent.sort((a, b) {
          final aEngagement = _getEngagementScore(a);
          final bEngagement = _getEngagementScore(b);
          return bEngagement.compareTo(aEngagement);
        });
        break;
      case SortFilter.newest:
        filteredContent.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortFilter.oldest:
        filteredContent.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
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
    }
  }

  void setContentFilter(String filter) {
    selectedContentFilter.value = filter;
    if (filter == ContentFilter.playlists.name || filter == ContentFilter.communityPosts.name) {
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
      final subRef = _firestore.collection('subscriptions').doc(subDocId);
      final channelRef = _firestore.collection('channels').doc(channelId);

      await _firestore.runTransaction((tx) async {
        final existing = await tx.get(subRef);
        if (existing.exists) return;
        tx.set(subRef, {
          'userId': currentUserId,
          'channelId': channelId,
          'subscribedAt': FieldValue.serverTimestamp(),
          'notificationsEnabled': true,
        });
        tx.update(channelRef, {
          'subscriberCount': FieldValue.increment(1),
        });
      }, maxAttempts: 3);

      // Optimistic local update instead of full reload
      subscriptions.add(Subscription(
        userId: currentUserId!,
        channelId: channelId,
        notificationsEnabled: true,
      ));
      await loadSubscribedChannels();
      await loadAllContent();
      applyFilters();

      Get.snackbar('Success', 'Subscribed successfully');
    } catch (e) {
      debugPrint('Error subscribing: $e');
      Get.snackbar('Error', 'Failed to subscribe: ${e.toString()}');
    }
  }

  Future<void> unsubscribeFromChannel(String channelId) async {
    if (currentUserId == null) return;

    try {
      // Try deterministic ID first (new standard)
      final subDocId = '${channelId}_$currentUserId';
      final subRef = _firestore.collection('subscriptions').doc(subDocId);
      final channelRef = _firestore.collection('channels').doc(channelId);

      final subDoc = await subRef.get();
      if (subDoc.exists) {
        // Deterministic ID doc found — atomic delete + decrement
        await _firestore.runTransaction((tx) async {
          tx.delete(subRef);
          tx.update(channelRef, {
            'subscriberCount': FieldValue.increment(-1),
          });
        }, maxAttempts: 3);
      } else {
        // Fallback: query for legacy auto-generated ID docs
        final snapshot = await _firestore
            .collection('subscriptions')
            .where('userId', isEqualTo: currentUserId)
            .where('channelId', isEqualTo: channelId)
            .get();
        if (snapshot.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (var doc in snapshot.docs) {
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
    } catch (e) {
      debugPrint('Error unsubscribing: $e');
      Get.snackbar('Error', 'Failed to unsubscribe: ${e.toString()}');
    }
  }

  bool isSubscribed(String channelId) {
    return subscriptions.any((s) => s.channelId == channelId);
  }
}



