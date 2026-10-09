import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/user_signal_tracker.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/distributed_counter_service.dart';
import 'package:truthworld/core/services/push_notification_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/domain/usecases/channel/toggle_subscription_usecase.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';

class ChannelSubscriptionController extends BaseController {
  final ToggleSubscriptionUseCase? _toggleSubscriptionUseCase;

  ChannelSubscriptionController({
    ToggleSubscriptionUseCase? toggleSubscriptionUseCase,
  }) : _toggleSubscriptionUseCase = toggleSubscriptionUseCase ??
            (Get.isRegistered<ToggleSubscriptionUseCase>()
                ? Get.find<ToggleSubscriptionUseCase>()
                : null);

  static ChannelSubscriptionController get to {
    if (Get.isRegistered<ChannelSubscriptionController>()) {
      return Get.find<ChannelSubscriptionController>();
    }
    return Get.put(ChannelSubscriptionController());
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const String _subsCol = 'subscriptions';
  static const String _channelsCol = 'channels';

  /// Central reactive registry tracking real verified subscriber counts across all channels
  static final RxMap<String, int> channelSubscriberCounts = <String, int>{}.obs;

  final RxBool isSubscribed = false.obs;
  final RxBool isLoadingSubscription = true.obs;
  final RxInt subscriberCount = 0.obs;

  /// Returns real subscriber count for [channelId], prioritizing reactive registry, then [fallback], then local state
  int getSubscriberCount(String channelId, {int? fallback}) {
    if (channelId.isEmpty) return subscriberCount.value;
    if (channelSubscriberCounts.containsKey(channelId)) {
      return channelSubscriberCounts[channelId]!;
    }
    if (fallback != null) {
      channelSubscriberCounts[channelId] = fallback;
      return fallback;
    }
    return subscriberCount.value;
  }

  /// Updates subscriber count in both per-channel registry and active state
  void setSubscriberCount(String channelId, int count) {
    if (channelId.isNotEmpty) {
      channelSubscriberCounts[channelId] = count;
    }
    subscriberCount.value = count;
  }

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
  final RxString notificationOption = 'personalized'.obs;
  final RxMap<String, RxString> _notificationOptionMap =
      <String, RxString>{}.obs;

  /// Returns reactive notification option for [channelId], defaulting to 'personalized'
  RxString getNotificationOption(String channelId) {
    if (channelId.isEmpty) return notificationOption;
    return _notificationOptionMap.putIfAbsent(
      channelId,
      () => 'personalized'.obs,
    );
  }


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
    final legacySubRef = _firestore.collection(_subsCol).doc(subDocId);
    final channelSubRef = _firestore
        .collection(FirestoreCollections.channelSubscribers(channelId))
        .doc(uid);
    final userSubRef = _firestore
        .collection(FirestoreCollections.userSubscriptions(uid))
        .doc(channelId);
    final channelRef = _firestore.collection(_channelsCol).doc(channelId);

    try {
      await _firestore.runTransaction((tx) async {
        final txSubSnapshot = await tx.get(channelSubRef);
        if (txSubSnapshot.exists) {
          throw Exception('already_subscribed');
        }

        final now = FieldValue.serverTimestamp();
        tx.set(channelSubRef, {
          'userId': uid,
          'timestamp': now,
          'notificationsEnabled': true,
          'notificationOption': 'personalized',
          'notificationPreference': 'personalized',
        });
        tx.set(userSubRef, {
          'channelId': channelId,
          'timestamp': now,
          'notificationPreference': 'personalized',
          'notificationOption': 'personalized',
          'notificationsEnabled': true,
        });
        tx.set(legacySubRef, {
          'userId': uid,
          'channelId': channelId,
          'subscribedAt': now,
          'notificationsEnabled': true,
          'notificationOption': 'personalized',
          'notificationPreference': 'personalized',
        });
      }, maxAttempts: 3);

      // Decouple subscriber counter from transaction to eliminate single-document lock contention
      // Spreads high-volume bursts across 20 shards and increments parent atomically
      try {
        final counterService = Get.isRegistered<DistributedCounterService>()
            ? DistributedCounterService.to
            : Get.put(DistributedCounterService());
        counterService.updateChannelSubscribers(
          channelId: channelId,
          delta: 1,
        );
      } catch (_) {}

      // Instantaneous zero-cost topic push delivery for mega channels
      try {
        if (Get.isRegistered<PushNotificationService>()) {
          PushNotificationService.to.subscribeToChannelTopic(channelId);
        }
      } catch (_) {}

      isSubscribed.value = true;
      notificationsEnabled.value = true;
      notificationOption.value = 'personalized';
      if (_notificationOptionMap.containsKey(channelId)) {
        _notificationOptionMap[channelId]!.value = 'personalized';
      } else {
        _notificationOptionMap[channelId] = 'personalized'.obs;
      }
      final current = channelSubscriberCounts[channelId] ?? subscriberCount.value;
      final newCount = current + 1;
      setSubscriberCount(channelId, newCount);
      if (_subscribedMap.containsKey(channelId)) {
        _subscribedMap[channelId]!.value = true;
      }
      if (Get.isRegistered<DashboardController>()) {
        final dash = Get.find<DashboardController>();
        if (dash.channelId == channelId) {
          dash.channelStats['subscribers'] = newCount.toString();
          dash.channelStats['rawSubscribers'] = newCount;
          dash.channelStats.refresh();
        }
      }
      if (Get.isRegistered<DiscoverChannelsController>()) {
        final disc = Get.find<DiscoverChannelsController>();
        disc.channelSubscriberCounts[channelId] = newCount;
        disc.subscribedChannelIds.add(channelId);
      }
      if (Get.isRegistered<SubscriptionController>()) {
        Get.find<SubscriptionController>().loadSubscriptions();
      }
      if (Get.isRegistered<UserSignalTracker>()) {
        Get.find<UserSignalTracker>().trackSubscribe(channelId: channelId);
      }
      _showSuccessSnackbar('Subscribed (Personalized notifications)');
      return true;
    } catch (e) {
      if (e.toString().contains('already_subscribed')) {
        isSubscribed.value = true;
        if (_subscribedMap.containsKey(channelId)) {
          _subscribedMap[channelId]!.value = true;
        }
        return true;
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
    final legacySubRef = _firestore.collection(_subsCol).doc(subDocId);
    final channelSubRef = _firestore
        .collection(FirestoreCollections.channelSubscribers(channelId))
        .doc(uid);
    final userSubRef = _firestore
        .collection(FirestoreCollections.userSubscriptions(uid))
        .doc(channelId);
    final channelRef = _firestore.collection(_channelsCol).doc(channelId);

    try {
      await _firestore.runTransaction((tx) async {
        final subDoc = await tx.get(channelSubRef);
        if (!subDoc.exists) return; // Already unsubscribed

        tx.delete(channelSubRef);
        tx.delete(userSubRef);
        tx.delete(legacySubRef);
      }, maxAttempts: 3);

      // Decouple subscriber decrement from transaction to eliminate write contention
      try {
        final counterService = Get.isRegistered<DistributedCounterService>()
            ? DistributedCounterService.to
            : Get.put(DistributedCounterService());
        counterService.updateChannelSubscribers(
          channelId: channelId,
          delta: -1,
        );
      } catch (_) {}

      try {
        if (Get.isRegistered<PushNotificationService>()) {
          PushNotificationService.to.unsubscribeFromChannelTopic(channelId);
        }
      } catch (_) {}

      isSubscribed.value = false;
      final current = channelSubscriberCounts[channelId] ?? subscriberCount.value;
      final nextCount = (current - 1) < 0 ? 0 : (current - 1);
      setSubscriberCount(channelId, nextCount);
      if (_subscribedMap.containsKey(channelId)) {
        _subscribedMap[channelId]!.value = false;
      }
      if (Get.isRegistered<DashboardController>()) {
        final dash = Get.find<DashboardController>();
        if (dash.channelId == channelId) {
          dash.channelStats['subscribers'] = nextCount.toString();
          dash.channelStats['rawSubscribers'] = nextCount;
          dash.channelStats.refresh();
        }
      }
      if (Get.isRegistered<DiscoverChannelsController>()) {
        final disc = Get.find<DiscoverChannelsController>();
        disc.channelSubscriberCounts[channelId] = nextCount;
        disc.subscribedChannelIds.remove(channelId);
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

    final wasSubscribed = _subscribedMap.containsKey(channelId)
        ? _subscribedMap[channelId]!.value
        : isSubscribed.value;
    final nextState = !wasSubscribed;
    isSubscribed.value = nextState;
    if (_subscribedMap.containsKey(channelId)) {
      _subscribedMap[channelId]!.value = nextState;
    }
    final prevCount = channelSubscriberCounts[channelId] ?? subscriberCount.value;
    final delta = nextState ? 1 : -1;
    final optimisticCount = (prevCount + delta) < 0 ? 0 : (prevCount + delta);
    setSubscriberCount(channelId, optimisticCount);

    if (nextState) {
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
      setSubscriberCount(channelId, prevCount);
      _sessionSubscribedChannels.remove(channelId);
    }
  }

  bool isNewSubscriber(String channelId) {
    return _sessionSubscribedChannels.contains(channelId);
  }

  void listenSubscription(String channelId) {
    if (channelId.isEmpty) return;
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

    // Primary: channels/$channelId/subscribers/$uid
    final channelSubRef = _firestore
        .collection(FirestoreCollections.channelSubscribers(channelId))
        .doc(uid);

    // Fallback 1: users/$uid/subscriptions/$channelId
    final userSubRef = _firestore
        .collection(FirestoreCollections.userSubscriptions(uid))
        .doc(channelId);

    // Fallback 2: subscriptions/${channelId}_$uid
    final legacySubRef = _firestore
        .collection(_subsCol)
        .doc('${channelId}_$uid');

    _subscriptionListener = channelSubRef.snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          isSubscribed.value = true;
          if (_subscribedMap.containsKey(channelId)) {
            _subscribedMap[channelId]!.value = true;
          }
          final data = snapshot.data();
          final notifsEnabled = data?['notificationsEnabled'] ?? true;
          notificationsEnabled.value = notifsEnabled;
          final pref = data?['notificationOption'] as String? ??
              data?['notificationPreference'] as String? ??
              (notifsEnabled ? 'personalized' : 'none');
          notificationOption.value = pref;
          if (_notificationOptionMap.containsKey(channelId)) {
            _notificationOptionMap[channelId]!.value = pref;
          } else {
            _notificationOptionMap[channelId] = pref.obs;
          }
          isLoadingSubscription.value = false;
        } else {
          userSubRef.get().then((userSnap) {
            if (userSnap.exists) {
              isSubscribed.value = true;
              if (_subscribedMap.containsKey(channelId)) {
                _subscribedMap[channelId]!.value = true;
              }
              final data = userSnap.data();
              final notifsEnabled = data?['notificationsEnabled'] ?? true;
              notificationsEnabled.value = notifsEnabled;
              final pref = data?['notificationOption'] as String? ??
                  data?['notificationPreference'] as String? ??
                  (notifsEnabled ? 'personalized' : 'none');
              notificationOption.value = pref;
              if (_notificationOptionMap.containsKey(channelId)) {
                _notificationOptionMap[channelId]!.value = pref;
              } else {
                _notificationOptionMap[channelId] = pref.obs;
              }
              isLoadingSubscription.value = false;
            } else {
              legacySubRef.get().then((legSnap) {
                final exists = legSnap.exists;
                isSubscribed.value = exists;
                if (_subscribedMap.containsKey(channelId)) {
                  _subscribedMap[channelId]!.value = exists;
                }
                if (exists) {
                  final data = legSnap.data();
                  final notifsEnabled = data?['notificationsEnabled'] ?? true;
                  notificationsEnabled.value = notifsEnabled;
                  final pref = data?['notificationOption'] as String? ??
                      data?['notificationPreference'] as String? ??
                      (notifsEnabled ? 'personalized' : 'none');
                  notificationOption.value = pref;
                  if (_notificationOptionMap.containsKey(channelId)) {
                    _notificationOptionMap[channelId]!.value = pref;
                  } else {
                    _notificationOptionMap[channelId] = pref.obs;
                  }
                }
                isLoadingSubscription.value = false;
              }).catchError((_) {
                isSubscribed.value = false;
                isLoadingSubscription.value = false;
              });
            }
          }).catchError((_) {
            isSubscribed.value = false;
            isLoadingSubscription.value = false;
          });
        }
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

    final isNone = option == 'none';
    final notifsEnabled = !isNone;
    final subDocId = '${channelId}_${user.uid}';

    // Optimistically update reactive state
    notificationsEnabled.value = notifsEnabled;
    notificationOption.value = option;
    if (_notificationOptionMap.containsKey(channelId)) {
      _notificationOptionMap[channelId]!.value = option;
    } else {
      _notificationOptionMap[channelId] = option.obs;
    }

    try {
      final now = FieldValue.serverTimestamp();
      final updates = {
        'notificationsEnabled': notifsEnabled,
        'notificationOption': option,
        'notificationPreference': option,
        'updatedAt': now,
      };

      await Future.wait([
        _firestore
            .collection(_subsCol)
            .doc(subDocId)
            .set(updates, SetOptions(merge: true)),
        _firestore
            .collection(FirestoreCollections.userSubscriptions(user.uid))
            .doc(channelId)
            .set(updates, SetOptions(merge: true)),
        _firestore
            .collection(FirestoreCollections.channelSubscribers(channelId))
            .doc(user.uid)
            .set(updates, SetOptions(merge: true)),
      ]);

      if (option == 'all') {
        _showSuccessSnackbar("You'll get all notifications");
      } else if (option == 'personalized') {
        _showSuccessSnackbar("You'll get personalized notifications");
      } else {
        _showSuccessSnackbar('Turned off all notifications');
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ChannelSubscriptionController.updateNotificationPreference');
      _showErrorSnackbar('Unable to update notifications. Please try again.');
    }
  }

  void fetchSubscriberCount(String channelId) {
    if (channelId.isEmpty) return;
    _countListener?.cancel();
    _countListener = _firestore
        .collection(_channelsCol)
        .doc(channelId)
        .snapshots()
        .listen((snapshot) async {
          var count = 0;
          if (snapshot.exists) {
            final data = snapshot.data();
            final docCount = data?['subscriberCount'] ??
                data?['subscribers'] ??
                (data?['metrics'] is Map ? data!['metrics']['subscriberCount'] : null) ??
                0;
            count = docCount is int ? docCount : (docCount as num).toInt();
          } else {
            try {
              final querySnap = await _firestore
                  .collection(_channelsCol)
                  .where('ownerId', isEqualTo: channelId)
                  .limit(1)
                  .get();
              if (querySnap.docs.isNotEmpty) {
                final data = querySnap.docs.first.data();
                final docCount = data['subscriberCount'] ??
                    data['subscribers'] ??
                    (data['metrics'] is Map ? data['metrics']['subscriberCount'] : null) ??
                    0;
                count = docCount is int ? docCount : (docCount as num).toInt();
              }
            } catch (_) {}
          }

          // Only perform an aggregation count fallback if the document count is 0 or missing.
          // For scaled channels (e.g. 100M subscribers), performing an unbounded collection
          // aggregation query on snapshot listener fires incurs massive read latency and billing costs.
          if (count == 0) {
            try {
              final subColSnap = await _firestore
                  .collection(FirestoreCollections.channelSubscribers(channelId))
                  .limit(100)
                  .count()
                  .get();
              final subColCount = subColSnap.count ?? 0;
              if (subColCount > count) {
                count = subColCount;
              }
            } catch (_) {}
          }

          setSubscriberCount(channelId, count);
        }, onError: (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'ChannelSubscriptionController.fetchSubscriberCount');
        });
    trackSubscription(_countListener!);
  }

  RxBool isSubscribedTo(String channelId) {
    if (channelId.isEmpty) return false.obs;

    if (_subscribedMap.containsKey(channelId)) {
      return _subscribedMap[channelId]!;
    }

    final rx = false.obs;
    _subscribedMap[channelId] = rx;

    final user = _auth.currentUser;
    if (user == null) return rx;

    final uid = user.uid;

    final channelSubRef = _firestore
        .collection(FirestoreCollections.channelSubscribers(channelId))
        .doc(uid);
    final userSubRef = _firestore
        .collection(FirestoreCollections.userSubscriptions(uid))
        .doc(channelId);
    final legacySubRef = _firestore
        .collection(_subsCol)
        .doc('${channelId}_$uid');
    final legacySubRef2 = _firestore
        .collection(_subsCol)
        .doc('${uid}_$channelId');

    trackSubscription(channelSubRef.snapshots().listen((snap) {
      if (snap.exists) {
        rx.value = true;
        final data = snap.data();
        final notifsEnabled = data?['notificationsEnabled'] ?? true;
        final pref = data?['notificationOption'] as String? ??
            data?['notificationPreference'] as String? ??
            (notifsEnabled ? 'personalized' : 'none');
        if (_notificationOptionMap.containsKey(channelId)) {
          _notificationOptionMap[channelId]!.value = pref;
        } else {
          _notificationOptionMap[channelId] = pref.obs;
        }
      } else {
        userSubRef.get().then((uSnap) {
          if (uSnap.exists) {
            rx.value = true;
            final data = uSnap.data();
            final notifsEnabled = data?['notificationsEnabled'] ?? true;
            final pref = data?['notificationOption'] as String? ??
                data?['notificationPreference'] as String? ??
                (notifsEnabled ? 'personalized' : 'none');
            if (_notificationOptionMap.containsKey(channelId)) {
              _notificationOptionMap[channelId]!.value = pref;
            } else {
              _notificationOptionMap[channelId] = pref.obs;
            }
          } else {
            legacySubRef.get().then((lSnap) {
              if (lSnap.exists) {
                rx.value = true;
                final data = lSnap.data();
                final notifsEnabled = data?['notificationsEnabled'] ?? true;
                final pref = data?['notificationOption'] as String? ??
                    data?['notificationPreference'] as String? ??
                    (notifsEnabled ? 'personalized' : 'none');
                if (_notificationOptionMap.containsKey(channelId)) {
                  _notificationOptionMap[channelId]!.value = pref;
                } else {
                  _notificationOptionMap[channelId] = pref.obs;
                }
              } else {
                legacySubRef2.get().then((lSnap2) {
                  rx.value = lSnap2.exists;
                }).catchError((_) {
                  rx.value = false;
                });
              }
            }).catchError((_) {
              rx.value = false;
            });
          }
        }).catchError((_) {
          rx.value = false;
        });
      }
    }, onError: (e, s) {
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
