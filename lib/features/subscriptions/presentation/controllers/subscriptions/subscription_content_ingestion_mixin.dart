import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
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
              .getCacheFirst();

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

      // 2. Parallel Multi-Content Ingestion
      final loadVideoFuture = contentMap.length < 15
          ? loadVideos(channelIds)
          : Future.value(<Video>[]);
      final loadPlaylistFuture = loadPlaylists(channelIds);
      final loadCommunityFuture = loadCommunityPosts(channelIds);
      final loadTopicFuture = loadTopics(channelIds);

      final results = await Future.wait([
        loadVideoFuture,
        loadPlaylistFuture,
        loadCommunityFuture,
        loadTopicFuture,
      ]);

      for (final v in results[0] as List<Video>) {
        final content = SubscriptionContent.fromVideo(v);
        contentMap[content.id] = content;
      }
      for (final p in results[1] as List<PlaylistModel>) {
        final content = SubscriptionContent.fromPlaylist(p);
        contentMap[content.id] = content;
      }
      for (final cp in results[2] as List<CommunityPostModel>) {
        final content = SubscriptionContent.fromCommunityPost(cp);
        contentMap[content.id] = content;
      }
      for (final t in results[3] as List<Topic>) {
        final content = SubscriptionContent.fromTopic(t);
        contentMap[content.id] = content;
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

  /// Industry Standard Feed Aggregation: Parallel batching + getCacheFirst + in-memory VideoVisibilityPolicy
  Future<List<Video>> loadVideos(List<String> channelIds) async {
    final videos = <Video>[];
    if (channelIds.isEmpty) return videos;

    final targetChannels =
        channelIds.length > 30 ? channelIds.sublist(0, 30) : channelIds;
    const batchSize = 10;
    final batches = <List<String>>[];
    for (var i = 0; i < targetChannels.length; i += batchSize) {
      batches.add(
        targetChannels.sublist(
          i,
          i + batchSize > targetChannels.length
              ? targetChannels.length
              : i + batchSize,
        ),
      );
    }

    final batchResults = await Future.wait(
      batches.map((batch) async {
        final docs = <DocumentSnapshot>[];
        try {
          final snapshot = await firestore
              .collection(FirestoreCollections.videos)
              .where('channelId', whereIn: batch)
              .limit(50)
              .getCacheFirst();
          docs.addAll(snapshot.docs);
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'SubscriptionController._loadVideos.batch',
          );
          final perChannelResults = await Future.wait(
            batch.map((cid) async {
              try {
                final snap = await firestore
                    .collection(FirestoreCollections.videos)
                    .where('channelId', isEqualTo: cid)
                    .limit(20)
                    .getCacheFirst();
                return snap.docs;
              } on Object catch (err, stackTrace) {
                ErrorHandler.log(
                  err,
                  stackTrace: stackTrace,
                  tag: 'SubscriptionController._loadVideos.perChannel',
                );
                return <DocumentSnapshot>[];
              }
            }),
          );
          perChannelResults.forEach(docs.addAll);
        }
        return docs;
      }),
    );

    for (final docs in batchResults) {
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

    final targetChannels =
        channelIds.length > 30 ? channelIds.sublist(0, 30) : channelIds;
    const batchSize = 10;
    final batches = <List<String>>[];
    for (var i = 0; i < targetChannels.length; i += batchSize) {
      batches.add(
        targetChannels.sublist(
          i,
          i + batchSize > targetChannels.length
              ? targetChannels.length
              : i + batchSize,
        ),
      );
    }

    final batchResults = await Future.wait(
      batches.map((batch) async {
        final docs = <DocumentSnapshot>[];
        try {
          final snapshot = await firestore
              .collection(FirestoreCollections.playlists)
              .where('channelId', whereIn: batch)
              .where('isPublic', isEqualTo: true)
              .limit(30)
              .getCacheFirst();
          docs.addAll(snapshot.docs);
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'SubscriptionController._loadPlaylists.batch',
          );
          final perChannelResults = await Future.wait(
            batch.map((cid) async {
              try {
                final snap = await firestore
                    .collection(FirestoreCollections.playlists)
                    .where('channelId', isEqualTo: cid)
                    .where('isPublic', isEqualTo: true)
                    .limit(10)
                    .getCacheFirst();
                return snap.docs;
              } on Object catch (e, stackTrace) {
                ErrorHandler.log(
                  e,
                  stackTrace: stackTrace,
                  tag: 'SubscriptionController._loadPlaylists.perChannel',
                );
                return <DocumentSnapshot>[];
              }
            }),
          );
          perChannelResults.forEach(docs.addAll);
        }
        return docs;
      }),
    );

    for (final docs in batchResults) {
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

    final targetChannels =
        channelIds.length > 30 ? channelIds.sublist(0, 30) : channelIds;
    const batchSize = 10;
    final batches = <List<String>>[];
    for (var i = 0; i < targetChannels.length; i += batchSize) {
      batches.add(
        targetChannels.sublist(
          i,
          i + batchSize > targetChannels.length
              ? targetChannels.length
              : i + batchSize,
        ),
      );
    }

    final batchResults = await Future.wait(
      batches.map((batch) async {
        final docs = <DocumentSnapshot>[];
        try {
          final snapshot = await firestore
              .collection(FirestoreCollections.community)
              .where('channelId', whereIn: batch)
              .limit(30)
              .getCacheFirst();
          docs.addAll(snapshot.docs);
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'SubscriptionController._loadCommunityPosts.batch',
          );
          final perChannelResults = await Future.wait(
            batch.map((cid) async {
              try {
                final snap = await firestore
                    .collection(FirestoreCollections.community)
                    .where('channelId', isEqualTo: cid)
                    .limit(10)
                    .getCacheFirst();
                return snap.docs;
              } on Object catch (e, stackTrace) {
                ErrorHandler.log(
                  e,
                  stackTrace: stackTrace,
                  tag: 'SubscriptionController._loadCommunityPosts.perChannel',
                );
                return <DocumentSnapshot>[];
              }
            }),
          );
          perChannelResults.forEach(docs.addAll);
        }
        return docs;
      }),
    );

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    for (final docs in batchResults) {
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

    final targetChannels =
        channelIds.length > 30 ? channelIds.sublist(0, 30) : channelIds;
    const batchSize = 10;
    final batches = <List<String>>[];
    for (var i = 0; i < targetChannels.length; i += batchSize) {
      batches.add(
        targetChannels.sublist(
          i,
          i + batchSize > targetChannels.length
              ? targetChannels.length
              : i + batchSize,
        ),
      );
    }

    final batchResults = await Future.wait(
      batches.map((batch) async {
        final docs = <DocumentSnapshot>[];
        try {
          final snapshot = await firestore
              .collection(FirestoreCollections.topics)
              .where('channelId', whereIn: batch)
              .where('status', isEqualTo: 'active')
              .limit(30)
              .getCacheFirst();
          docs.addAll(snapshot.docs);
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'SubscriptionController._loadTopics.batch',
          );
          final perChannelResults = await Future.wait(
            batch.map((cid) async {
              try {
                final snap = await firestore
                    .collection(FirestoreCollections.topics)
                    .where('channelId', isEqualTo: cid)
                    .where('status', isEqualTo: 'active')
                    .limit(10)
                    .getCacheFirst();
                return snap.docs;
              } on Object catch (e, stackTrace) {
                ErrorHandler.log(
                  e,
                  stackTrace: stackTrace,
                  tag: 'SubscriptionController._loadTopics.perChannel',
                );
                return <DocumentSnapshot>[];
              }
            }),
          );
          perChannelResults.forEach(docs.addAll);
        }
        return docs;
      }),
    );

    for (final docs in batchResults) {
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
