import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/data/models/subscription_content.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscriptions/subscription_state_base.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Mixin handling multi-content feed aggregation across videos, playlists, community posts, and topics.
mixin SubscriptionContentIngestionMixin on SubscriptionStateBase {
  @override
  Future<void> loadAllContent() async {
    if (subscriptions.isEmpty) {
      allContent.clear();
      filteredContent.clear();
      return;
    }

    final channelIds = subscriptions.map((s) => s.channelId).toSet().toList();

    try {
      final contentMap = <String, SubscriptionContent>{};

      // 1. O(1) Fast-Path: Pre-materialized Server-Side Timeline Feed Inbox
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null && currentUid.isNotEmpty) {
        try {
          final inboxSnap = await firestore
              .collection(FirestoreCollections.users)
              .doc(currentUid)
              .collection('feed_inbox')
              .orderBy('uploadedAt', descending: true)
              .limit(30)
              .get();

          for (final doc in inboxSnap.docs) {
            try {
              final video = Video.fromDocumentSnapshot(doc);
              final content = SubscriptionContent.fromVideo(video);
              contentMap[content.id] = content;
            } catch (_) {}
          }
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'SubscriptionController.loadAllContent.feedInbox',
          );
        }
      }

      // 2. Multi-Channel Ingestion (if feed inbox has few or no items)
      if (contentMap.length < 15) {
        try {
          final videos = await loadVideos(channelIds);
          for (final v in videos) {
            final content = SubscriptionContent.fromVideo(v);
            contentMap[content.id] = content;
          }
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'SubscriptionController.loadAllContent.videos',
          );
        }
      }

      // Load playlists
      try {
        final playlists = await loadPlaylists(channelIds);
        for (final p in playlists) {
          final content = SubscriptionContent.fromPlaylist(p);
          contentMap[content.id] = content;
        }
      } on Object catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'SubscriptionController.loadAllContent.playlists',
        );
      }

      // Load community posts
      try {
        final communityPosts = await loadCommunityPosts(channelIds);
        for (final cp in communityPosts) {
          final content = SubscriptionContent.fromCommunityPost(cp);
          contentMap[content.id] = content;
        }
      } on Object catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'SubscriptionController.loadAllContent.communityPosts',
        );
      }

      // Load topics
      try {
        final topics = await loadTopics(channelIds);
        for (final t in topics) {
          final content = SubscriptionContent.fromTopic(t);
          contentMap[content.id] = content;
        }
      } on Object catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'SubscriptionController.loadAllContent.topics',
        );
      }

      final contentList = contentMap.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      allContent.value = contentList;
    } on Object catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SubscriptionController.loadAllContent',
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Industry Standard Feed Aggregation: Index-resilient query + in-memory VideoVisibilityPolicy
  Future<List<Video>> loadVideos(List<String> channelIds) async {
    final videos = <Video>[];
    if (channelIds.isEmpty) return videos;

    // Cap to top 30 subscribed channels to bound network queries to max 3 batches
    final targetChannels =
        channelIds.length > 30 ? channelIds.sublist(0, 30) : channelIds;
    const batchSize = 10;
    for (var i = 0; i < targetChannels.length; i += batchSize) {
      final batch = targetChannels.sublist(
        i,
        i + batchSize > targetChannels.length
            ? targetChannels.length
            : i + batchSize,
      );

      final docs = <DocumentSnapshot>[];

      // Attempt 1: Fetch channel batch without fragile multi-field composite index constraints
      try {
        final snapshot = await firestore
            .collection(FirestoreCollections.videos)
            .where('channelId', whereIn: batch)
            .limit(50)
            .get();
        docs.addAll(snapshot.docs);
      } on Object catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'SubscriptionController._loadVideos.batch',
        );
        for (final cid in batch) {
          try {
            final snap = await firestore
                .collection(FirestoreCollections.videos)
                .where('channelId', isEqualTo: cid)
                .limit(20)
                .get();
            docs.addAll(snap.docs);
          } on Object catch (err, stackTrace) {
            ErrorHandler.log(
              err,
              stackTrace: stackTrace,
              tag: 'SubscriptionController._loadVideos.perChannel',
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
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'SubscriptionController._loadVideos.parseDoc',
          );
        }
      }
    }

    return videos;
  }

  Future<List<PlaylistModel>> loadPlaylists(List<String> channelIds) async {
    final playlists = <PlaylistModel>[];
    if (channelIds.isEmpty) return playlists;

    // Cap to top 30 channels to avoid cascading reads
    final targetChannels =
        channelIds.length > 30 ? channelIds.sublist(0, 30) : channelIds;
    const batchSize = 10;
    for (var i = 0; i < targetChannels.length; i += batchSize) {
      final batch = targetChannels.sublist(
        i,
        i + batchSize > targetChannels.length
            ? targetChannels.length
            : i + batchSize,
      );

      final docs = <DocumentSnapshot>[];

      try {
        final snapshot = await firestore
            .collection(FirestoreCollections.playlists)
            .where('channelId', whereIn: batch)
            .where('isPublic', isEqualTo: true)
            .limit(30)
            .get();
        docs.addAll(snapshot.docs);
      } on Object catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'SubscriptionController._loadPlaylists.batch',
        );
        for (final cid in batch) {
          try {
            final snap = await firestore
                .collection(FirestoreCollections.playlists)
                .where('channelId', isEqualTo: cid)
                .where('isPublic', isEqualTo: true)
                .limit(10)
                .get();
            docs.addAll(snap.docs);
          } on Object catch (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'SubscriptionController._loadPlaylists.perChannel',
            );
          }
        }
      }

      for (final doc in docs) {
        try {
          final playlist = PlaylistModel.fromDocumentSnapshot(doc);
          if (playlist.isPublic) {
            playlists.add(playlist);
          }
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'SubscriptionController._loadPlaylists.parseDoc',
          );
        }
      }
    }

    return playlists;
  }

  Future<List<CommunityPostModel>> loadCommunityPosts(
    List<String> channelIds,
  ) async {
    final posts = <CommunityPostModel>[];
    if (channelIds.isEmpty) return posts;

    // Cap to top 30 channels to avoid cascading reads
    final targetChannels =
        channelIds.length > 30 ? channelIds.sublist(0, 30) : channelIds;
    const batchSize = 10;
    for (var i = 0; i < targetChannels.length; i += batchSize) {
      final batch = targetChannels.sublist(
        i,
        i + batchSize > targetChannels.length
            ? targetChannels.length
            : i + batchSize,
      );

      final docs = <DocumentSnapshot>[];

      try {
        final snapshot = await firestore
            .collection(FirestoreCollections.community)
            .where('channelId', whereIn: batch)
            .limit(30)
            .get();
        docs.addAll(snapshot.docs);
      } on Object catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'SubscriptionController._loadCommunityPosts.batch',
        );
        for (final cid in batch) {
          try {
            final snap = await firestore
                .collection(FirestoreCollections.community)
                .where('channelId', isEqualTo: cid)
                .limit(10)
                .get();
            docs.addAll(snap.docs);
          } on Object catch (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'SubscriptionController._loadCommunityPosts.perChannel',
            );
          }
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
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'SubscriptionController._loadCommunityPosts.parseDoc',
          );
        }
      }
    }

    return posts;
  }

  Future<List<Topic>> loadTopics(List<String> channelIds) async {
    final topics = <Topic>[];
    if (channelIds.isEmpty) return topics;

    // Cap to top 30 channels to avoid cascading reads
    final targetChannels =
        channelIds.length > 30 ? channelIds.sublist(0, 30) : channelIds;
    const batchSize = 10;
    for (var i = 0; i < targetChannels.length; i += batchSize) {
      final batch = targetChannels.sublist(
        i,
        i + batchSize > targetChannels.length
            ? targetChannels.length
            : i + batchSize,
      );

      final docs = <DocumentSnapshot>[];

      try {
        final snapshot = await firestore
            .collection(FirestoreCollections.topics)
            .where('channelId', whereIn: batch)
            .where('status', isEqualTo: 'active')
            .limit(30)
            .get();
        docs.addAll(snapshot.docs);
      } on Object catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'SubscriptionController._loadTopics.batch',
        );
        for (final cid in batch) {
          try {
            final snap = await firestore
                .collection(FirestoreCollections.topics)
                .where('channelId', isEqualTo: cid)
                .where('status', isEqualTo: 'active')
                .limit(10)
                .get();
            docs.addAll(snap.docs);
          } on Object catch (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'SubscriptionController._loadTopics.perChannel',
            );
          }
        }
      }

      for (final doc in docs) {
        try {
          final topic = Topic.fromDocumentSnapshot(doc);
          if (topic.isValidTopic && topic.videoCount > 0) {
            topics.add(topic);
          }
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'SubscriptionController._loadTopics.parseDoc',
          );
        }
      }
    }

    return topics;
  }
}
