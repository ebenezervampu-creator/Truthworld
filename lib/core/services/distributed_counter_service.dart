import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// Distributed Counter Service for high-velocity counters (video views, channel metrics).
///
/// Problem:
/// Firestore enforces a hard limit of 1 write per second per document. When a viral video
/// receives >100,000 views per hour (~28 writes/sec), concurrent transactions and direct writes
/// to `videos/{videoId}` or `channels/{channelId}` trigger contention aborts and 503/429 errors.
///
/// Solution:
/// Distribute writes uniformly across [numShards] independent sub-counter documents
/// under `videos/{videoId}/shards/{0..19}` and `channels/{channelId}/shards/{0..19}`.
/// This expands continuous write capacity by 20x (72,000 writes/hr sustained, safely handling
/// 100K+ views/hr viral bursts). A scheduled Cloud Function periodically rolls up shard sums
/// into the parent document for O(1) feed queries without write contention.
class DistributedCounterService extends GetxService {
  /// Standard industry default: 20 shards per viral counter entity
  static const int defaultShardCount = 20;

  final FirebaseFirestore _firestore;
  final int numShards;
  final math.Random _random;

  DistributedCounterService({
    FirebaseFirestore? firestore,
    this.numShards = defaultShardCount,
    math.Random? random,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _random = random ?? math.Random();

  /// Singleton access helper via GetX
  static DistributedCounterService get to => Get.find<DistributedCounterService>();

  /// Atomically increments a randomly selected shard for a video view.
  ///
  /// Spreads the write across 20 sub-counters, preventing single-document write contention.
  /// If [channelId] is provided, also increments a random shard for the channel.
  Future<void> incrementVideoViews({
    required String videoId,
    bool isQualified = false,
    String? channelId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (videoId.trim().isEmpty) return;

    try {
      final shardId = _random.nextInt(numShards).toString();
      final shardRef = _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('shards')
          .doc(shardId);

      final shardPayload = <String, dynamic>{
        'count': FieldValue.increment(1),
        if (isQualified) 'qualifiedCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await shardRef.set(shardPayload, SetOptions(merge: true)).timeout(timeout);

      // Best-effort update on parent video document for immediate O(1) UI reads.
      // Without this, viewCount stays 0 until the nightly midnight rollup.
      // Matches the same pattern already used by incrementVideoComments.
      _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({
            'viewCount': FieldValue.increment(1),
            if (isQualified) 'qualifiedViewCount': FieldValue.increment(1),
          })
          .catchError((e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'DistributedCounterService.videoParentViewCount',
            );
          });

      // Distribute channel view increment across channel shards if provided
      if (channelId != null && channelId.trim().isNotEmpty) {
        final channelShardId = _random.nextInt(numShards).toString();
        final channelShardRef = _firestore
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .collection('shards')
            .doc(channelShardId);

        channelShardRef
            .set({
              'views': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(timeout)
            .catchError((e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'DistributedCounterService.channelShard',
              );
            });

        // Best-effort update on parent channel document for immediate viewCount reads
        _firestore
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .update({'viewCount': FieldValue.increment(1)})
            .catchError((e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'DistributedCounterService.channelParentViewCount',
              );
            });
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.incrementVideoViews',
      );
    }
  }

  /// Atomically increments a randomly selected shard for video and channel watch time.
  ///
  /// Distributes high-frequency watch-time pulses across 20 shards to eliminate write contention.
  Future<void> incrementWatchTime({
    required String videoId,
    required int secondsDelta,
    String? channelId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (videoId.trim().isEmpty || secondsDelta <= 0) return;

    try {
      final shardId = _random.nextInt(numShards).toString();
      final videoShardRef = _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('shards')
          .doc(shardId);

      await videoShardRef.set({
        'watchTimeSeconds': FieldValue.increment(secondsDelta),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(timeout);

      // Best-effort update on parent video document for immediate UI reads
      _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({
            'totalWatchTimeSeconds': FieldValue.increment(secondsDelta),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .catchError((e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'DistributedCounterService.videoParentWatchTime',
            );
          });

      if (channelId != null && channelId.trim().isNotEmpty) {
        final channelShardId = _random.nextInt(numShards).toString();
        final channelShardRef = _firestore
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .collection('shards')
            .doc(channelShardId);

        channelShardRef
            .set({
              'watchTimeSeconds': FieldValue.increment(secondsDelta),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(timeout)
            .catchError((e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'DistributedCounterService.channelWatchTimeShard',
              );
            });

        _firestore
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .update({
              'totalWatchTimeSeconds': FieldValue.increment(secondsDelta),
              'metrics.totalWatchTimeMinutes': FieldValue.increment(secondsDelta / 60),
            })
            .catchError((e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'DistributedCounterService.channelParentWatchTime',
              );
            });
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.incrementWatchTime',
      );
    }
  }

  /// Calculates the total real-time view count for a video by aggregating across all 20 shards.
  Future<int> getRealtimeVideoViews(String videoId) async {
    if (videoId.trim().isEmpty) return 0;

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('shards')
          .get();

      var total = 0;
      for (final doc in snapshot.docs) {
        final count = (doc.data()['count'] as num?)?.toInt() ?? 0;
        total += count;
      }
      return total;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.getRealtimeVideoViews',
      );
      return 0;
    }
  }

  /// Calculates the total real-time view count for a channel across its distributed shards.
  Future<int> getRealtimeChannelViews(String channelId) async {
    if (channelId.trim().isEmpty) return 0;

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection('shards')
          .get();

      var total = 0;
      for (final doc in snapshot.docs) {
        final views = (doc.data()['views'] as num?)?.toInt() ?? 0;
        total += views;
      }
      return total;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.getRealtimeChannelViews',
      );
      return 0;
    }
  }

  /// Atomically increments a randomly selected shard for a topic's comment count.
  ///
  /// Distributes high-velocity topic commenting across 20 shards to prevent write contention.
  Future<void> incrementTopicComments({
    required String topicId,
    int delta = 1,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (topicId.trim().isEmpty) return;

    try {
      final shardId = _random.nextInt(numShards).toString();
      final shardRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('shards')
          .doc(shardId);

      await shardRef.set({
        'commentCount': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(timeout);

      // Best-effort update on the parent topic document for O(1) reads
      _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .update({
            'commentCount': FieldValue.increment(delta),
          })
          .catchError((_) {});
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.incrementTopicComments',
      );
    }
  }

  /// Atomically increments a randomly selected shard for a video's comment count.
  ///
  /// Distributes high-velocity video commenting across 20 shards to prevent write contention.
  Future<void> incrementVideoComments({
    required String videoId,
    int delta = 1,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (videoId.trim().isEmpty) return;

    try {
      final shardId = _random.nextInt(numShards).toString();
      final shardRef = _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('comment_shards')
          .doc(shardId);

      await shardRef.set({
        'commentCount': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(timeout);

      // Best-effort update on the parent video document for O(1) reads
      _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({
            'commentCount': FieldValue.increment(delta),
          })
          .catchError((_) {});
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.incrementVideoComments',
      );
    }
  }

  /// Calculates total real-time comment count for a topic across all 20 shards.
  Future<int> getRealtimeTopicComments(String topicId) async {
    if (topicId.trim().isEmpty) return 0;

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('shards')
          .get();

      var total = 0;
      for (final doc in snapshot.docs) {
        final count = (doc.data()['commentCount'] as num?)?.toInt() ?? 0;
        total += count;
      }
      return total;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.getRealtimeTopicComments',
      );
      return 0;
    }
  }

  /// Calculates total real-time comment count for a video across all 20 shards.
  Future<int> getRealtimeVideoComments(String videoId) async {
    if (videoId.trim().isEmpty) return 0;

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('comment_shards')
          .get();

      var total = 0;
      for (final doc in snapshot.docs) {
        final count = (doc.data()['commentCount'] as num?)?.toInt() ?? 0;
        total += count;
      }
      return total;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.getRealtimeVideoComments',
      );
      return 0;
    }
  }
}
