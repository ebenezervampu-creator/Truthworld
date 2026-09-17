import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/user_signal_tracker.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';

class ChannelSubscriptionController extends BaseController {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const String _subsCol = 'subscriptions';
  static const String _channelsCol = 'channels';

  final RxBool isSubscribed = false.obs;
  final RxBool isLoadingSubscription = true.obs;
  final RxInt subscriberCount = 0.obs;

  // Channel Membership reactive state
  final RxBool isChannelMember = false.obs;
  final Rxn<ChannelMember> currentMembership = Rxn<ChannelMember>();
  StreamSubscription? _membershipListener;

  // Track channels subscribed to during this app session for "new subscriber" analytics
  final Set<String> _sessionSubscribedChannels = {};
  final RxMap<String, RxBool> _subscribedMap = <String, RxBool>{}.obs;
  final RxList<Channel> subscribedChannels = <Channel>[].obs;

  StreamSubscription? _subscriptionListener;
  StreamSubscription? _countListener;

  final RxBool notificationsEnabled = true.obs;
  final RxString notificationOption = 'all'.obs;


  void _showSuccessSnackbar(String message) {
    AppSnackbar.success(message);
  }

  void _showErrorSnackbar(String message) {
    AppSnackbar.error(message);
  }

  void _showSignInPrompt() {
    AppSnackbar.warning(
      'Please sign in to subscribe to channels.',
      title: 'Sign In Required',
      actionLabel: 'SIGN IN',
      onAction: AuthService.to.signInWithGoogle,
    );
  }

  Future<bool> subscribeToChannel(String channelId) async {
    if (!AuthService.to.isAuthenticated.value) {
      _showSignInPrompt();
      return false;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      _showSignInPrompt();
      return false;
    }

    final subDocId = '${channelId}_$uid';
    final subRef = _firestore.collection(_subsCol).doc(subDocId);
    final channelRef = _firestore.collection(_channelsCol).doc(channelId);

    try {
      await _firestore.runTransaction((tx) async {
        final txSubSnapshot = await tx.get(subRef);
        if (txSubSnapshot.exists) {
          throw Exception('already_subscribed');
        }

        tx.set(subRef, {
          'userId': uid,
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
      if (_subscribedMap.containsKey(channelId)) {
        _subscribedMap[channelId]!.value = true;
      }
      if (Get.isRegistered<SubscriptionController>()) {
        Get.find<SubscriptionController>().loadSubscriptions();
      }
      if (Get.isRegistered<UserSignalTracker>()) {
        Get.find<UserSignalTracker>().trackSubscribe(channelId: channelId);
      }
      _showSuccessSnackbar('Subscribed successfully');
      return true;
    } catch (e) {
      if (e.toString().contains('already_subscribed')) {
        isSubscribed.value = true;
        if (_subscribedMap.containsKey(channelId)) {
          _subscribedMap[channelId]!.value = true;
        }
        return false;
      }
      ErrorHandler.log(e, tag: 'ChannelSubscriptionController');
      _showErrorSnackbar('Unable to subscribe to channel. Please try again.');
      return false;
    }
  }

  Future<bool> unsubscribeFromChannel(String channelId) async {
    if (!AuthService.to.isAuthenticated.value) return false;
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return false;

    final subDocId = '${channelId}_$uid';
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
      if (_subscribedMap.containsKey(channelId)) {
        _subscribedMap[channelId]!.value = false;
      }
      if (Get.isRegistered<SubscriptionController>()) {
        Get.find<SubscriptionController>().loadSubscriptions();
      }
      _showSuccessSnackbar('Unsubscribed successfully');
      return true;
    } catch (e) {
      _showErrorSnackbar('Failed to unsubscribe');
      return false;
    }
  }

  Future<void> toggleSubscription(String channelId) async {
    if (Get.isRegistered<AuthService>() && !AuthService.to.isAuthenticated.value) {
      _showSignInPrompt();
      return;
    }

    final wasSubscribed = isSubscribed.value;
    isSubscribed.value = !wasSubscribed;
    if (_subscribedMap.containsKey(channelId)) {
      _subscribedMap[channelId]!.value = !wasSubscribed;
    }
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
      if (_subscribedMap.containsKey(channelId)) {
        _subscribedMap[channelId]!.value = wasSubscribed;
      }
      subscriberCount.value += wasSubscribed ? 1 : -1;
      if (subscriberCount.value < 0) subscriberCount.value = 0;
      _sessionSubscribedChannels.remove(channelId);
    }
  }

  bool isNewSubscriber(String channelId) {
    return _sessionSubscribedChannels.contains(channelId);
  }

  void listenSubscription(String channelId) {
    listenMembership(channelId);
    if (!AuthService.to.isAuthenticated.value) {
      isSubscribed.value = false;
      isLoadingSubscription.value = false;
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      isSubscribed.value = false;
      isLoadingSubscription.value = false;
      return;
    }

    if (_subscribedMap.containsKey(channelId)) {
      isSubscribed.value = _subscribedMap[channelId]!.value;
    }

    isLoadingSubscription.value = true;
    _subscriptionListener?.cancel();

    final subDocId = '${channelId}_$uid';
    _subscriptionListener = _firestore
        .collection(_subsCol)
        .doc(subDocId)
        .snapshots()
        .listen(
          (snapshot) {
            isSubscribed.value = snapshot.exists;
            if (_subscribedMap.containsKey(channelId)) {
              _subscribedMap[channelId]!.value = snapshot.exists;
            }
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
          onError: (error, stackTrace) {
            ErrorHandler.log(error, stackTrace: stackTrace, tag: 'ChannelSubscriptionController._subscriptionListener');
            isSubscribed.value = false;
            isLoadingSubscription.value = false;
          },
        );
    trackSubscription(_subscriptionListener!);
  }

  void listenMembership(String channelId) {
    if (!AuthService.to.isAuthenticated.value) {
      isChannelMember.value = false;
      currentMembership.value = null;
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty || channelId.isEmpty) {
      isChannelMember.value = false;
      currentMembership.value = null;
      return;
    }

    _membershipListener?.cancel();
    _membershipListener = _firestore
        .collection(_channelsCol)
        .doc(channelId)
        .collection('members')
        .doc(uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              final data = snapshot.data()!;
              final status = (data['status'] ?? 'active').toString().toLowerCase();
              if (status == 'active') {
                isChannelMember.value = true;
                currentMembership.value = ChannelMember.fromMap(data, snapshot.id);
                return;
              }
            }
            _checkUserMembershipFallback(channelId, uid);
          },
          onError: (error, stackTrace) {
            ErrorHandler.log(error, stackTrace: stackTrace, tag: 'ChannelSubscriptionController.listenMembership');
            _checkUserMembershipFallback(channelId, uid);
          },
        );
    trackSubscription(_membershipListener!);
  }

  void _checkUserMembershipFallback(String channelId, String uid) {
    _firestore
        .collection('users')
        .doc(uid)
        .collection('channel_memberships')
        .doc(channelId)
        .get()
        .then((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            final status = (data['status'] ?? 'active').toString().toLowerCase();
            if (status == 'active') {
              isChannelMember.value = true;
              currentMembership.value = ChannelMember.fromMap(data, doc.id);
              return;
            }
          }
          isChannelMember.value = false;
          currentMembership.value = null;
        })
        .catchError((e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'ChannelSubscriptionController._checkUserMembershipFallback');
          isChannelMember.value = false;
          currentMembership.value = null;
        });
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ChannelSubscriptionController.updateNotificationPreference');
      _showErrorSnackbar('Unable to update notifications. Please try again.');
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
        }, onError: (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'ChannelSubscriptionController.fetchSubscriberCount');
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
        .listen((snap) => rx.value = snap.exists, onError: (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'ChannelSubscriptionController.isSubscribedTo');
        }));

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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ChannelSubscriptionController.fetchSubscribedChannels');
    } finally {
      isLoadingSubscription.value = false;
    }
  }

  @override
  void onClose() {
    _subscriptionListener?.cancel();
    _subscriptionListener = null;
    _membershipListener?.cancel();
    _membershipListener = null;
    _countListener?.cancel();
    _countListener = null;
    super.onClose();
  }
}
