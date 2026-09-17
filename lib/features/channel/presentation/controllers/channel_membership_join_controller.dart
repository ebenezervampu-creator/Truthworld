import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';

/// 100% GetX Controller managing viewer-facing Channel Membership joins, perks, and status.
class ChannelMembershipJoinController extends BaseController {
  ChannelMembershipJoinController({
    required this.channelId,
    this.channel,
  });

  final String channelId;
  final Channel? channel;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reactive State
  final RxList<ChannelMembershipTier> tiers = <ChannelMembershipTier>[].obs;
  final RxBool isLoadingTiers = true.obs;
  final RxBool isMember = false.obs;
  final Rxn<ChannelMember> currentMembership = Rxn<ChannelMember>();
  final RxInt selectedTierIndex = 0.obs;
  final RxBool isProcessing = false.obs;

  StreamSubscription? _tiersSubscription;
  StreamSubscription? _membershipSubscription;

  ChannelMembershipTier? get selectedTier {
    if (tiers.isEmpty) return null;
    final idx = selectedTierIndex.value.clamp(0, tiers.length - 1);
    return tiers[idx];
  }

  @override
  void onInit() {
    super.onInit();
    _loadTiers();
    _checkMembership();

    if (Get.isRegistered<AuthService>()) {
      addWorker(ever(AuthService.to.isAuthenticated, (_) {
        _checkMembership();
      }));
    }
  }

  @override
  void onClose() {
    _tiersSubscription?.cancel();
    _membershipSubscription?.cancel();
    super.onClose();
  }

  void _loadTiers() {
    if (channelId.isEmpty) {
      isLoadingTiers.value = false;
      return;
    }

    isLoadingTiers.value = true;
    _tiersSubscription = _firestore
        .collection(FirestoreCollections.channels)
        .doc(channelId)
        .collection('membership_tiers')
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs
            .map((doc) => ChannelMembershipTier.fromMap(doc.data(), doc.id))
            .where((tier) => tier.isEnabled)
            .toList();

        list.sort((a, b) {
          if (a.order != b.order) return a.order.compareTo(b.order);
          return a.price.compareTo(b.price);
        });

        tiers.value = list;
        isLoadingTiers.value = false;
        _syncSelectedTierToCurrentMembership();
      },
      onError: (err) {
        isLoadingTiers.value = false;
        debugPrint('[ChannelMembershipJoinController] Error loading tiers: $err');
      },
    );
  }

  void _checkMembership() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || channelId.isEmpty) {
      isMember.value = false;
      currentMembership.value = null;
      return;
    }

    _membershipSubscription?.cancel();
    _membershipSubscription = _firestore
        .collection(FirestoreCollections.channels)
        .doc(channelId)
        .collection('members')
        .doc(uid)
        .snapshots()
        .listen(
      (doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final status = (data['status'] ?? 'active').toString().toLowerCase();
          if (status == 'active') {
            isMember.value = true;
            currentMembership.value = ChannelMember.fromMap(data, doc.id);
            _syncSelectedTierToCurrentMembership();
            return;
          }
        }
        _checkUserMembershipFallback(uid);
      },
      onError: (err) {
        debugPrint('[ChannelMembershipJoinController] Error checking membership: $err');
        _checkUserMembershipFallback(uid);
      },
    );
  }

  void _checkUserMembershipFallback(String uid) {
    _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection('channel_memberships')
        .doc(channelId)
        .get()
        .then((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            final status = (data['status'] ?? 'active').toString().toLowerCase();
            if (status == 'active') {
              isMember.value = true;
              currentMembership.value = ChannelMember.fromMap(data, doc.id);
              _syncSelectedTierToCurrentMembership();
              return;
            }
          }
          isMember.value = false;
          currentMembership.value = null;
        })
        .catchError((_) {
          isMember.value = false;
          currentMembership.value = null;
        });
  }

  void _syncSelectedTierToCurrentMembership() {
    final curTierId = currentMembership.value?.tierId;
    if (curTierId != null && curTierId.isNotEmpty && tiers.isNotEmpty) {
      final idx = tiers.indexWhere((t) => t.id == curTierId);
      if (idx != -1) {
        selectedTierIndex.value = idx;
      }
    }
  }

  void selectTier(int index) {
    if (index >= 0 && index < tiers.length) {
      selectedTierIndex.value = index;
    }
  }

  Future<void> joinSelectedTier() async {
    final auth = AuthService.to;
    if (!auth.isAuthenticated.value) {
      AppSnackbar.show(
        'Sign In Required',
        'Please sign in to join channel memberships.',
      );
      return;
    }

    final tier = selectedTier;
    if (tier == null) {
      AppSnackbar.warning('Please select a membership tier to continue.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (isMember.value && currentMembership.value?.tierId == tier.id) {
      AppSnackbar.show(
        'Already a Member',
        'You are already subscribed to the ${tier.name} tier.',
      );
      return;
    }

    final isUpgrading = isMember.value && currentMembership.value?.tierId != tier.id;
    final previousTierId = currentMembership.value?.tierId;

    isProcessing.value = true;
    try {
      final amountINR = tier.currency.toUpperCase() == 'INR'
          ? tier.price
          : (tier.price * 85.0).roundToDouble();
      final paymentResult = await CashfreePaymentService.to.startPayment(
        amount: amountINR,
        purpose: 'channel_membership',
        orderNote: isUpgrading
            ? 'Upgrade Membership: ${channel?.name ?? "Channel"} - ${tier.name}'
            : 'Membership: ${channel?.name ?? "Channel"} - ${tier.name}',
        metadata: {
          'channelId': channelId,
          'channelName': channel?.name ?? '',
          'tierId': tier.id,
          'tierName': tier.name,
          'currency': tier.currency,
          'isUpgrade': isUpgrading ? 'true' : 'false',
          'previousTierId': previousTierId ?? '',
          'userName': user.displayName ?? 'Channel Supporter',
          'userAvatarUrl': user.photoURL ?? '',
        },
      );

      if (!paymentResult.success) {
        if (paymentResult.errorMessage != null &&
            !paymentResult.errorMessage!.toLowerCase().contains('cancel')) {
          AppSnackbar.error(paymentResult.errorMessage!);
        }
        return;
      }

      final batch = _firestore.batch();

      // 1. Write or update member document in channel's members subcollection
      final memberRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection('members')
          .doc(user.uid);

      final memberData = ChannelMember(
        userId: user.uid,
        userName: user.displayName ?? 'Channel Supporter',
        userAvatarUrl: user.photoURL ?? '',
        tierId: tier.id,
        tierName: tier.name,
        price: tier.price,
        currency: tier.currency,
        joinedAt: DateTime.now(),
      );

      batch.set(memberRef, memberData.toMap());

      // 2. Record membership in user's channel_memberships subcollection
      final userMembershipRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .collection('channel_memberships')
          .doc(channelId);

      batch.set(userMembershipRef, {
        'channelId': channelId,
        'channelName': channel?.name ?? '',
        'channelAvatarUrl': channel?.avatarUrl ?? '',
        'tierId': tier.id,
        'tierName': tier.name,
        'price': tier.price,
        'currency': tier.currency,
        'badgeColorHex': tier.badgeColorHex,
        'badgeIcon': tier.badgeIcon,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // 3. If upgrading from another tier, decrement previous tier's memberCount
      if (isUpgrading && previousTierId != null && previousTierId.isNotEmpty) {
        final prevTierRef = _firestore
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .collection('membership_tiers')
            .doc(previousTierId);
        batch.update(prevTierRef, {
          'memberCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      isMember.value = true;
      currentMembership.value = memberData;
      _syncSelectedTierToCurrentMembership();

      if (Get.isRegistered<ChannelSubscriptionController>()) {
        final sub = Get.find<ChannelSubscriptionController>();
        sub.isChannelMember.value = true;
        sub.currentMembership.value = memberData;
      }

      AppSnackbar.success(
        isUpgrading
            ? 'You have successfully upgraded to the ${tier.name} tier! Enjoy your enhanced perks.'
            : 'You have successfully joined the ${tier.name} tier! Enjoy your loyalty badge and member perks.',
        title: isUpgrading ? 'Membership Upgraded!' : 'Welcome to the Family!',
      );

      Get.back<void>();
    } catch (e) {
      ErrorHandler.log(e, tag: 'ChannelMembershipJoinController');
      AppSnackbar.error('Unable to join membership tier. Please try again.');
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> cancelMembership() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    isProcessing.value = true;
    try {
      final batch = _firestore.batch();

      final memberRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection('members')
          .doc(user.uid);

      batch.update(memberRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      final tierId = currentMembership.value?.tierId;
      if (tierId != null && tierId.isNotEmpty) {
        final tierRef = _firestore
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .collection('membership_tiers')
            .doc(tierId);

        batch.update(tierRef, {
          'memberCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final userMembershipRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .collection('channel_memberships')
          .doc(channelId);

      batch.update(userMembershipRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      AppSnackbar.show(
        'Membership Cancelled',
        'Your membership has been deactivated.',
      );
      Get.back<void>();
    } catch (e) {
      ErrorHandler.log(e, tag: 'ChannelMembershipJoinController');
      AppSnackbar.error('Unable to cancel membership. Please try again.');
    } finally {
      isProcessing.value = false;
    }
  }
}
