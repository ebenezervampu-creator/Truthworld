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
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.incrementVideoViews',
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
}
