import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      // Unsigned / guest viewers are strictly excluded from video and channel view counts
      return;
    }

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

      // Best-effort update on parent video document for immediate O(1) UI reads (authenticated only).
      // Without this, viewCount stays 0 until the nightly midnight rollup.
      // Matches the same pattern already used by incrementVideoComments.
      if (FirebaseAuth.instance.currentUser != null) {
        _firestore
            .collection(FirestoreCollections.videos)
            .doc(videoId)
            .update({
              'viewCount': FieldValue.increment(1),
              'views': FieldValue.increment(1),
            })
            .catchError((e, s) {
              // Fallback: If document schema has only one of the view keys, try single-field updates
              _firestore
                  .collection(FirestoreCollections.videos)
                  .doc(videoId)
                  .update({'viewCount': FieldValue.increment(1)})
                  .catchError((error, stackTrace) {
                    _firestore
                        .collection(FirestoreCollections.videos)
                        .doc(videoId)
                        .update({'views': FieldValue.increment(1)})
                        .catchError((err, st) {});
                  });
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'DistributedCounterService.videoParentViewCount',
              );
            });
      }

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

        // Best-effort update on parent channel document for immediate viewCount reads (authenticated only)
        if (FirebaseAuth.instance.currentUser != null) {
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

      // Best-effort update on parent video document for immediate UI reads (authenticated only)
      if (FirebaseAuth.instance.currentUser != null) {
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
      }

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
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.incrementWatchTime',
      );
    }
  }

  /// Calculates total real-time watch time for a video by aggregating across all 20 shards.
  Future<int> getRealtimeVideoWatchTime(String videoId) async {
    if (videoId.trim().isEmpty) return 0;

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('shards')
          .get();

      var total = 0;
      for (final doc in snapshot.docs) {
        final sec = (doc.data()['watchTimeSeconds'] as num?)?.toInt() ?? 0;
        total += sec;
      }
      return total;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.getRealtimeVideoWatchTime',
      );
      return 0;
    }
  }

  /// Attempts to heal parent video document if its totalWatchTimeSeconds is 0 but shards have recorded watch time.
  Future<void> healParentVideoWatchTime(String videoId, int currentShardWatchTime) async {
    if (videoId.trim().isEmpty || currentShardWatchTime <= 0) return;
    if (FirebaseAuth.instance.currentUser == null) return;

    try {
      final docRef = _firestore.collection(FirestoreCollections.videos).doc(videoId);
      final snap = await docRef.get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final rawWatchTime = (data['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0;
      if (rawWatchTime < currentShardWatchTime) {
        await docRef.set({
          'totalWatchTimeSeconds': currentShardWatchTime,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'DistributedCounterService.healParentVideoWatchTime.catch');
        });
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DistributedCounterService.healParentVideoWatchTime');
    }
  }

  /// Calculates total real-time watch time for a channel across its distributed shards.
  Future<int> getRealtimeChannelWatchTime(String channelId) async {
    if (channelId.trim().isEmpty) return 0;

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection('shards')
          .get();

      var total = 0;
      for (final doc in snapshot.docs) {
        final sec = (doc.data()['watchTimeSeconds'] as num?)?.toInt() ?? 0;
        total += sec;
      }
      return total;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.getRealtimeChannelWatchTime',
      );
      return 0;
    }
  }

  /// Attempts to heal parent channel document if its totalWatchTimeSeconds is 0 but shards have recorded watch time.
  Future<void> healParentChannelWatchTime(String channelId, int currentShardWatchTime) async {
    if (channelId.trim().isEmpty || currentShardWatchTime <= 0) return;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) return;

    try {
      final docRef = _firestore.collection(FirestoreCollections.channels).doc(channelId);
      final snap = await docRef.get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};

      // Client can only update channels they own under Firestore security rules
      final ownerId = data['ownerId'] as String? ?? data['userId'] as String?;
      if (ownerId != currentUid) return;

      final rawWatchTime = (data['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0;
      if (rawWatchTime < currentShardWatchTime) {
        await docRef.set({
          'totalWatchTimeSeconds': currentShardWatchTime,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'DistributedCounterService.healParentChannelWatchTime.catch');
        });
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DistributedCounterService.healParentChannelWatchTime');
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

  /// Attempts to heal parent video document if its viewCount is 0 but shards have counts.
  Future<void> healParentVideoViews(String videoId, int currentShardViews) async {
    if (videoId.trim().isEmpty || currentShardViews <= 0) return;
    if (FirebaseAuth.instance.currentUser == null) return;

    try {
      final docRef = _firestore.collection(FirestoreCollections.videos).doc(videoId);
      final snap = await docRef.get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final rawVCount = (data['viewCount'] as num?)?.toInt() ?? 0;
      final rawViews = (data['views'] as num?)?.toInt() ?? 0;
      if (rawVCount == 0 && rawViews == 0) {
        await docRef.update({
          'viewCount': FieldValue.increment(1),
          'views': FieldValue.increment(1),
        }).catchError((_) {
          docRef.update({'viewCount': FieldValue.increment(1)}).catchError((_) {});
        });
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DistributedCounterService.healParentVideoViews');
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

  /// Atomically increments or decrements a randomly selected shard for channel subscribers.
  ///
  /// Distributes high-velocity subscription bursts across [numShards] sub-counters,
  /// preventing write contention and transaction aborts when 100M channels receive viral subscription spikes.
  Future<void> updateChannelSubscribers({
    required String channelId,
    required int delta,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (channelId.trim().isEmpty || delta == 0) return;

    try {
      final shardId = _random.nextInt(numShards).toString();
      final shardRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection('shards')
          .doc(shardId);

      await shardRef.set({
        'subscriberDelta': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(timeout);

      // Best-effort atomic increment on parent channel document for immediate O(1) UI reads
      _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update({
            'subscriberCount': FieldValue.increment(delta),
            'lastActiveAt': FieldValue.serverTimestamp(),
          })
          .catchError((e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'DistributedCounterService.channelParentSubscriberCount',
            );
          });
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.updateChannelSubscribers',
      );
    }
  }

  /// Calculates total real-time subscriber count delta for a channel across all shards.
  Future<int> getRealtimeChannelSubscriberDelta(String channelId) async {
    if (channelId.trim().isEmpty) return 0;

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection('shards')
          .get();

      var total = 0;
      for (final doc in snapshot.docs) {
        final delta = (doc.data()['subscriberDelta'] as num?)?.toInt() ?? 0;
        total += delta;
      }
      return total;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DistributedCounterService.getRealtimeChannelSubscriberDelta',
      );
      return 0;
    }
  }
}
