import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_mixins/channel_controller_base.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';

mixin ChannelManagementMixin on ChannelControllerBase {
  Future<bool> archiveChannel(String channelId) async {
    try {
      await firestore.collection(ChannelControllerBase.channelsCol).doc(channelId).update({
        'status': 'deleted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      showSuccessSnackbar('Channel archived successfully');
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelManagementMixin.archiveChannel');
      showErrorSnackbar('Unable to archive channel. Please try again.');
      return false;
    }
  }

  Future<bool> updateChannel(
    String channelId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await firestore.collection(ChannelControllerBase.channelsCol).doc(channelId).update(updates);
      showSuccessSnackbar('Channel updated successfully');
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelManagementMixin.updateChannel');
      showErrorSnackbar('Unable to update channel. Please try again.');
      return false;
    }
  }

  // ==========================================================================
  // SUBSCRIPTIONS
  // ==========================================================================

  Future<bool> subscribeToChannel(String channelId) => subController.subscribeToChannel(channelId);

  Future<bool> unsubscribeFromChannel(String channelId) => subController.unsubscribeFromChannel(channelId);

  Future<void> toggleSubscription(String channelId) => subController.toggleSubscription(channelId);
  Future<void> fetchSubscribedChannels() => subController.fetchSubscribedChannels();

  bool isNewSubscriber(String channelId) => subController.isNewSubscriber(channelId);

  @override
  void listenSubscription(String channelId) => subController.listenSubscription(channelId);

  @override
  void listenMembership(String channelId) => subController.listenMembership(channelId);

  Future<void> updateNotificationPreference(String channelId, String option) => subController.updateNotificationPreference(channelId, option);

  /// Check if current user is subscribed to a specific channel (reactive)
  @override
  RxBool get isSubscribed => subController.isSubscribed;

  @override
  RxBool get notificationsEnabled => subController.notificationsEnabled;

  @override
  RxString get notificationOption => subController.notificationOption;

  RxString getNotificationOption(String channelId) =>
      subController.getNotificationOption(channelId);

  @override
  RxBool get isChannelMember => subController.isChannelMember;

  @override
  Rxn<ChannelMember> get currentMembership => subController.currentMembership;

  @override
  RxBool get hasChannelMemberships => subController.hasChannelMemberships;

  RxBool isSubscribedTo(String channelId) => subController.isSubscribedTo(channelId);

  @override
  void fetchSubscriberCount(String channelId) => subController.fetchSubscriberCount(channelId);

  String get formattedSubscribers {
    final chId = selectedChannel.value?.channelId;
    final registryCount = (chId != null && chId.isNotEmpty)
        ? ChannelSubscriptionController.channelSubscriberCounts[chId]
        : null;
    final count = registryCount ??
        (subscriberCount.value > 0
            ? subscriberCount.value
            : (selectedChannel.value?.subscriberCount ?? 0));
    return FormatUtils.formatCount(count);
  }

  // ==========================================================================
  // MODERATION
  // ==========================================================================

  Future<bool> addModerator(String channelId, String userId) async {
    try {
      await firestore
          .collection(ChannelControllerBase.channelsCol)
          .doc(channelId)
          .collection('moderators')
          .doc(userId)
          .set({
            'userId': userId,
            'addedAt': FieldValue.serverTimestamp(),
          });
      showSuccessSnackbar('Moderator added successfully');
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelManagementMixin.addModerator');
      showErrorSnackbar('Unable to add moderator. Please try again.');
      return false;
    }
  }

  Future<bool> removeModerator(String channelId, String userId) async {
    try {
      await firestore
          .collection(ChannelControllerBase.channelsCol)
          .doc(channelId)
          .collection('moderators')
          .doc(userId)
          .delete();
      showSuccessSnackbar('Moderator removed successfully');
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelManagementMixin.removeModerator');
      showErrorSnackbar('Unable to remove moderator. Please try again.');
      return false;
    }
  }

  Future<bool> blockUser(String channelId, String userId) async {
    try {
      await firestore
          .collection(ChannelControllerBase.channelsCol)
          .doc(channelId)
          .collection('blocked_users')
          .doc(userId)
          .set({
            'userId': userId,
            'blockedAt': FieldValue.serverTimestamp(),
          });
      showSuccessSnackbar('User blocked successfully');
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelManagementMixin.blockUser');
      showErrorSnackbar('Unable to block user. Please try again.');
      return false;
    }
  }

  Future<bool> unblockUser(String channelId, String userId) async {
    try {
      await firestore
          .collection(ChannelControllerBase.channelsCol)
          .doc(channelId)
          .collection('blocked_users')
          .doc(userId)
          .delete();
      showSuccessSnackbar('User unblocked successfully');
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelManagementMixin.unblockUser');
      showErrorSnackbar('Unable to unblock user. Please try again.');
      return false;
    }
  }

  // ==========================================================================
  // NOTIFICATION PREFERENCES
  // ==========================================================================

  Future<void> saveNotificationPreferences(String channelId) async {
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final prefsRef = firestore
          .collection('notification_preferences')
          .doc('${channelId}_${user.uid}');

      await prefsRef.set({
        'userId': user.uid,
        'channelId': channelId,
        'notificationAll': notificationAll.value,
        'notificationPersonalized': notificationPersonalized.value,
        'notificationNew': notificationNew.value,
        'notificationLive': notificationLive.value,
        'notificationPlaylist': notificationPlaylist.value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('âœ… Notification preferences saved');
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelManagementMixin.saveNotificationPreferences');
    }
  }

  Future<void> loadNotificationPreferences(String channelId) async {
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final prefsRef = firestore
          .collection('notification_preferences')
          .doc('${channelId}_${user.uid}');

      final doc = await prefsRef.get();

      if (doc.exists) {
        final data = doc.data();
        notificationAll.value = data?['notificationAll'] ?? true;
        notificationPersonalized.value =
            data?['notificationPersonalized'] ?? true;
        notificationNew.value = data?['notificationNew'] ?? true;
        notificationLive.value = data?['notificationLive'] ?? true;
        notificationPlaylist.value = data?['notificationPlaylist'] ?? false;
        debugPrint('âœ… Notification preferences loaded');
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelManagementMixin.loadNotificationPreferences');
    }
  }

  Future<bool> updateChannelType(
    String channelId,
    ChannelType newType, {
    CustomChannelInfraConfig? config,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'channelType': newType.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newType == ChannelType.custom) {
        final infra =
            config ??
            CustomChannelInfraConfig(
              subscriptionId: '',
              flatPlatformFee: 25.0,
            );
        updateData['infraConfig'] = infra.toMap();
      }

      await firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update(updateData);

      if (selectedChannel.value?.id == channelId) {
        final updatedDoc = await firestore
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .get();
        if (updatedDoc.exists) {
          selectedChannel.value = Channel.fromDocumentSnapshot(updatedDoc);
        }
      }
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelManagementMixin.updateChannelType');
      return false;
    }
  }

  /// Schedules a channel type change to take effect on the 1st of next month (Next Billing Cycle)
  Future<bool> scheduleChannelTypeChange(
    String channelId,
    ChannelType targetType,
  ) async {
    try {
      final now = DateTime.now();
      // Calculate 1st of next month (e.g. July 10 -> August 1)
      final effectiveDate = DateTime(now.year, now.month + 1);
      final effectiveTimestamp = Timestamp.fromDate(effectiveDate);

      final updateData = <String, dynamic>{
        'pendingChannelType': targetType.name,
        'pendingTypeEffectiveDate': effectiveTimestamp,
        'nextBillingCycleDate': effectiveTimestamp,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update(updateData);

      if (selectedChannel.value?.id == channelId) {
        final updatedDoc = await firestore
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .get();
        if (updatedDoc.exists) {
          selectedChannel.value = Channel.fromDocumentSnapshot(updatedDoc);
        }
      }
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelManagementMixin.scheduleChannelTypeChange');
      return false;
    }
  }

  /// Cancels a pending scheduled channel type change
  Future<bool> cancelScheduledChannelTypeChange(String channelId) async {
    try {
      final updateData = <String, dynamic>{
        'pendingChannelType': FieldValue.delete(),
        'pendingTypeEffectiveDate': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update(updateData);

      if (selectedChannel.value?.id == channelId) {
        final updatedDoc = await firestore
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .get();
        if (updatedDoc.exists) {
          selectedChannel.value = Channel.fromDocumentSnapshot(updatedDoc);
        }
      }
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelManagementMixin.cancelScheduledChannelTypeChange');
      return false;
    }
  }

}
