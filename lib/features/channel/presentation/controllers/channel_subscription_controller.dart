import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/data/models/channel.dart';

class ChannelSubscriptionController extends BaseController {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const String _subsCol = 'subscriptions';
  static const String _channelsCol = 'channels';

  final RxBool isSubscribed = false.obs;
  final RxBool isLoadingSubscription = true.obs;
  final RxInt subscriberCount = 0.obs;

  // Track channels subscribed to during this app session for "new subscriber" analytics
  final Set<String> _sessionSubscribedChannels = {};
  final RxMap<String, RxBool> _subscribedMap = <String, RxBool>{}.obs;
  final RxList<Channel> subscribedChannels = <Channel>[].obs;

  StreamSubscription? _subscriptionListener;
  StreamSubscription? _countListener;

  final RxBool notificationsEnabled = true.obs;
  final RxString notificationOption = 'all'.obs;


  void _showSuccessSnackbar(String message) {
    Get.snackbar('Success', message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.1),
        colorText: Colors.green);
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar('Error', message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red);
  }

  Future<bool> subscribeToChannel(String channelId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showErrorSnackbar('You must be logged in to subscribe.');
      return false;
    }

    final subDocId = '${channelId}_${user.uid}';
    final subRef = _firestore.collection(_subsCol).doc(subDocId);
    final channelRef = _firestore.collection(_channelsCol).doc(channelId);

    try {
      await _firestore.runTransaction((tx) async {
        final txSubSnapshot = await tx.get(subRef);
        if (txSubSnapshot.exists) {
          throw Exception('already_subscribed');
        }

        tx.set(subRef, {
          'userId': user.uid,
          'channelId': channelId,
          'subscribedAt': FieldValue.serverTimestamp(),
          'notificationsEnabled': true,
        });

        tx.update(channelRef, {
          'subscriberCount': FieldValue.increment(1),
          'lastActiveAt': FieldValue.serverTimestamp(),
        });
      }, maxAttempts: 3);

      isSubscribed.value = true;
      subscriberCount.value++;
      _showSuccessSnackbar('Subscribed successfully');
      return true;
    } catch (e) {
      if (e.toString().contains('already_subscribed')) {
        isSubscribed.value = true;
        return false;
      }
      _showErrorSnackbar('Failed to subscribe: $e');
      return false;
    }
  }

  Future<bool> unsubscribeFromChannel(String channelId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final subDocId = '${channelId}_${user.uid}';
    final subRef = _firestore.collection(_subsCol).doc(subDocId);
    final channelRef = _firestore.collection(_channelsCol).doc(channelId);

    try {
      await _firestore.runTransaction((tx) async {
        final subDoc = await tx.get(subRef);
        if (!subDoc.exists) return; // Already unsubscribed

        tx.delete(subRef);
        tx.update(channelRef, {'subscriberCount': FieldValue.increment(-1)});
      }, maxAttempts: 3);

      isSubscribed.value = false;
      subscriberCount.value = (subscriberCount.value - 1).clamp(0, 999999999);
      _showSuccessSnackbar('Unsubscribed successfully');
      return true;
    } catch (e) {
      _showErrorSnackbar('Failed to unsubscribe');
      return false;
    }
  }

  Future<void> toggleSubscription(String channelId) async {
    final wasSubscribed = isSubscribed.value;
    isSubscribed.value = !wasSubscribed;
    subscriberCount.value += wasSubscribed ? -1 : 1;
    if (subscriberCount.value < 0) subscriberCount.value = 0;

    if (!wasSubscribed) {
      _sessionSubscribedChannels.add(channelId);
    } else {
      _sessionSubscribedChannels.remove(channelId);
    }

    try {
      if (wasSubscribed) {
        await unsubscribeFromChannel(channelId);
      } else {
        await subscribeToChannel(channelId);
      }
    } catch (_) {
      isSubscribed.value = wasSubscribed;
      subscriberCount.value += wasSubscribed ? 1 : -1;
      if (subscriberCount.value < 0) subscriberCount.value = 0;
      _sessionSubscribedChannels.remove(channelId);
    }
  }

  bool isNewSubscriber(String channelId) {
    return _sessionSubscribedChannels.contains(channelId);
  }

  void listenSubscription(String channelId) {
    final user = _auth.currentUser;
    if (user == null) {
      isSubscribed.value = false;
      isLoadingSubscription.value = false;
      return;
    }

    isLoadingSubscription.value = true;
    _subscriptionListener?.cancel();

    final subDocId = '${channelId}_${user.uid}';
    _subscriptionListener = _firestore
        .collection(_subsCol)
        .doc(subDocId)
        .snapshots()
        .listen(
          (snapshot) {
            isSubscribed.value = snapshot.exists;
            if (snapshot.exists) {
              final data = snapshot.data();
              notificationsEnabled.value =
                  data?['notificationsEnabled'] ?? true;
              notificationOption.value =
                  data?['notificationOption'] as String? ??
                  (notificationsEnabled.value ? 'all' : 'none');
            }
            isLoadingSubscription.value = false;
          },
          onError: (error) {
            isSubscribed.value = false;
            isLoadingSubscription.value = false;
          },
        );
    trackSubscription(_subscriptionListener!);
  }

  Future<void> updateNotificationPreference(
    String channelId,
    String option,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final subDocId = '${channelId}_${user.uid}';
    try {
      final isAll = option == 'all';
      await _firestore.collection(_subsCol).doc(subDocId).update({
        'notificationsEnabled': isAll,
        'notificationOption': option,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      notificationsEnabled.value = isAll;
      notificationOption.value = option;
      _showSuccessSnackbar('Notification preferences updated');
    } catch (e) {
      _showErrorSnackbar('Failed to update notifications');
    }
  }

  void fetchSubscriberCount(String channelId) {
    _countListener?.cancel();
    _countListener = _firestore
        .collection(_channelsCol)
        .doc(channelId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final count = snapshot.data()?['subscriberCount'] ?? 0;
            subscriberCount.value = count is int
                ? count
                : (count as num).toInt();
          }
        });
    trackSubscription(_countListener!);
  }

  RxBool isSubscribedTo(String channelId) {
    final user = _auth.currentUser;
    if (user == null) return false.obs;

    if (_subscribedMap.containsKey(channelId)) {
      return _subscribedMap[channelId]!;
    }

    final rx = false.obs;
    _subscribedMap[channelId] = rx;

    final subDocId = '${channelId}_${user.uid}';
    // Use trackSubscription since we don't manage its cancellation manually
    trackSubscription(_firestore
        .collection(_subsCol)
        .doc(subDocId)
        .snapshots()
        .listen((snap) => rx.value = snap.exists));

    return rx;
  }

  Future<void> fetchSubscribedChannels() async {
    final user = _auth.currentUser;
    if (user == null) return;

    isLoadingSubscription.value = true;
    try {
      final subSnap = await _firestore
          .collection(_subsCol)
          .where('userId', isEqualTo: user.uid)
          .get();

      if (subSnap.docs.isEmpty) {
        subscribedChannels.clear();
        return;
      }

      final channelIds = subSnap.docs
          .map((doc) => doc.data()['channelId'] as String)
          .toList();

      final chunks = <List<String>>[];
      for (var i = 0; i < channelIds.length; i += 10) {
        chunks.add(channelIds.sublist(
            i, i + 10 > channelIds.length ? channelIds.length : i + 10));
      }

      final channels = <Channel>[];
      for (final chunk in chunks) {
        final querySnap = await _firestore
            .collection(_channelsCol)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        channels.addAll(
            querySnap.docs.map(Channel.fromDocumentSnapshot));
      }

      subscribedChannels.assignAll(channels);
    } catch (e) {
      debugPrint('Error fetching subscribed channels: $e');
    } finally {
      isLoadingSubscription.value = false;
    }
  }
}
