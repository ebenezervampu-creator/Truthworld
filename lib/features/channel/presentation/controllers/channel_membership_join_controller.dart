import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
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
            return;
          }
        }
        isMember.value = false;
        currentMembership.value = null;
      },
      onError: (err) {
        debugPrint('[ChannelMembershipJoinController] Error checking membership: $err');
      },
    );
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
      AppSnackbar.show('Error', 'Please select a valid membership tier.');
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

    isProcessing.value = true;
    try {
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
        joinedAt: DateTime.now(),
      );

      batch.set(memberRef, memberData.toMap());

      // 2. Increment member count on the tier document
      final tierRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection('membership_tiers')
          .doc(tier.id);

      batch.update(tierRef, {
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Record membership in user's joined_memberships subcollection
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
        'badgeColorHex': tier.badgeColorHex,
        'badgeIcon': tier.badgeIcon,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      AppSnackbar.show(
        'Welcome to the Family!',
        'You have successfully joined the ${tier.name} tier! Enjoy your loyalty badge and member perks.',
      );

      Get.back<void>();
    } catch (e) {
      debugPrint('[ChannelMembershipJoinController] Error joining tier: $e');
      AppSnackbar.show('Membership Error', 'Failed to join tier: $e');
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
      debugPrint('[ChannelMembershipJoinController] Error cancelling membership: $e');
      AppSnackbar.show('Error', 'Failed to cancel membership: $e');
    } finally {
      isProcessing.value = false;
    }
  }
}
