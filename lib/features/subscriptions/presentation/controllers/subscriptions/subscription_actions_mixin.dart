import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/subscriptions.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscriptions/subscription_state_base.dart';

/// Mixin handling subscription loading, channel deduplication, subscribing, and unsubscribing.
mixin SubscriptionActionsMixin on SubscriptionStateBase {
  /// Industry Standard: Multi-source subscription resolution with channel deduplication
  @override
  Future<void> loadSubscriptions() async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    try {
      final subMap = <String, Subscription>{};

      // 1. Primary: Root subscriptions collection
      try {
        final snapshot = await firestore
            .collection(FirestoreCollections.subscriptions)
            .where('userId', isEqualTo: uid)
            .limit(100)
            .getCacheFirst();

        for (final doc in snapshot.docs) {
          final sub = Subscription.fromDocumentSnapshot(doc);
          if (sub.channelId.isNotEmpty) {
            subMap[sub.channelId] = sub;
          }
        }
      } on Object catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'SubscriptionController.loadSubscriptions.primary',
        );
      }

      // If primary found subscriptions, skip unnecessary legacy fallback queries
      if (subMap.isEmpty) {
        // 2. Alternative: Subscriptions doc subcollection (subscriptions/{uid}/list)
        try {
          final snapshot = await firestore
              .collection(FirestoreCollections.subscriptions)
              .doc(uid)
              .collection('list')
              .limit(100)
              .getCacheFirst();

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final chId = data['channelId'] as String? ?? doc.id;
            if (chId.isNotEmpty && !subMap.containsKey(chId)) {
              subMap[chId] = Subscription(userId: uid, channelId: chId);
            }
          }
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'SubscriptionController.loadSubscriptions.alternativeList',
          );
        }

        // 3. Alternative: userCache (userCache/{uid}/subscriptions)
        if (subMap.isEmpty) {
          try {
            final snapshot = await firestore
                .collection('userCache')
                .doc(uid)
                .collection(FirestoreCollections.subscriptions)
                .limit(100)
                .getCacheFirst();

            for (final doc in snapshot.docs) {
              final data = doc.data();
              final chId = data['channelId'] as String? ?? doc.id;
              if (chId.isNotEmpty && !subMap.containsKey(chId)) {
                subMap[chId] = Subscription(userId: uid, channelId: chId);
              }
            }
          } on Object catch (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'SubscriptionController.loadSubscriptions.alternativeUserCache',
            );
          }
        }

        // 4. Alternative: users subcollection (users/{uid}/subscriptions)
        if (subMap.isEmpty) {
          try {
            final snapshot = await firestore
                .collection(FirestoreCollections.users)
                .doc(uid)
                .collection(FirestoreCollections.subscriptions)
                .limit(100)
                .getCacheFirst();

            for (final doc in snapshot.docs) {
              final data = doc.data();
              final chId = data['channelId'] as String? ?? doc.id;
              if (chId.isNotEmpty && !subMap.containsKey(chId)) {
                subMap[chId] = Subscription(userId: uid, channelId: chId);
              }
            }
          } on Object catch (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'SubscriptionController.loadSubscriptions.alternativeUsersSubcollection',
            );
          }
        }
      }

      subscriptions.value = subMap.values.toList();
    } on Object catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SubscriptionController.loadSubscriptions',
      );
      throw AppException.from(e, stackTrace);
    }
  }

  @override
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
            final snapshot = await firestore
                .collection(FirestoreCollections.channels)
                .where(FieldPath.documentId, whereIn: batch)
                .getCacheFirst();
            return snapshot.docs.map(Channel.fromDocumentSnapshot).toList();
          } on Object catch (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'SubscriptionController.loadSubscribedChannels.batch',
            );
            return <Channel>[];
          }
        }());
      }
      final results = await Future.wait(batchFutures);
      subscribedChannels.value = results.expand((c) => c).toList();
    } on Object catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SubscriptionController.loadSubscribedChannels',
      );
    }
  }

  Future<void> subscribeToChannel(String channelId) async {
    if (currentUserId == null) {
      AppSnackbar.warning('Please sign in to subscribe.');
      return;
    }

    try {
      if (subscriptions.any((s) => s.channelId == channelId)) {
        AppSnackbar.info('Already subscribed to this channel.');
        return;
      }

      // Deterministic doc ID for dedup + atomic count
      final subDocId = '${channelId}_$currentUserId';
      final subRef = firestore
          .collection(FirestoreCollections.subscriptions)
          .doc(subDocId);
      final channelRef = firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId);

      await firestore.runTransaction((tx) async {
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

      AppSnackbar.success('Subscribed successfully');
    } on Object catch (e) {
      ErrorHandler.log(e, context: 'SubscriptionController.subscribeToChannel');
      AppSnackbar.error('Unable to subscribe to channel. Please try again.');
    }
  }

  Future<void> unsubscribeFromChannel(String channelId) async {
    if (currentUserId == null) return;

    try {
      // Try deterministic ID first (new standard)
      final subDocId = '${channelId}_$currentUserId';
      final subRef = firestore
          .collection(FirestoreCollections.subscriptions)
          .doc(subDocId);
      final channelRef = firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId);

      final subDoc = await subRef.get();
      if (subDoc.exists) {
        // Deterministic ID doc found — atomic delete + decrement
        await firestore.runTransaction((tx) async {
          tx
            ..delete(subRef)
            ..update(channelRef, {
              'subscriberCount': FieldValue.increment(-1),
            });
        }, maxAttempts: 3);
      } else {
        // Fallback: query for legacy auto-generated ID docs
        final snapshot = await firestore
            .collection(FirestoreCollections.subscriptions)
            .where('userId', isEqualTo: currentUserId)
            .where('channelId', isEqualTo: channelId)
            .get();
        if (snapshot.docs.isNotEmpty) {
          final batch = firestore.batch();
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

      AppSnackbar.success('Unsubscribed successfully');
    } on Object catch (e) {
      ErrorHandler.log(
        e,
        context: 'SubscriptionController.unsubscribeFromChannel',
      );
      AppSnackbar.error('Unable to unsubscribe from channel. Please try again.');
    }
  }

  bool isSubscribed(String channelId) {
    return subscriptions.any((s) => s.channelId == channelId);
  }
}
