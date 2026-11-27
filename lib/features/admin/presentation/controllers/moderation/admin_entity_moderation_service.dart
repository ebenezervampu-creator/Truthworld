import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/admin/presentation/controllers/moderation/admin_moderation_predicates.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';

/// Service executing moderation actions for channels, topics, ad campaigns, and bulk operations.
class AdminEntityModerationService {
  const AdminEntityModerationService._();

  /// Executes manual channel moderation action (Approve/Reject)
  static Future<bool> moderateChannel({
    required String channelId,
    required String action,
    required String reason,
    required RxList<Map<String, dynamic>> channels,
    required RxInt pendingChannels,
    required Rxn<Map<String, dynamic>> selectedChannel,
    required RxBool isActionSubmitting,
  }) async {
    isActionSubmitting.value = true;
    try {
      final isApprove = action == 'approve';
      final isHold = action == 'hold';
      final status = isHold ? 'onHold' : (isApprove ? 'active' : 'verificationRejected');

      // 0ms Optimistic UI update
      final chIdx = channels.indexWhere((c) => c['id'] == channelId);
      if (chIdx != -1) {
        final item = Map<String, dynamic>.from(channels[chIdx]);
        item['status'] = status;
        if (isApprove) {
          item.remove('moderationReason');
          item['isVerified'] = true;
          item['isMonetized'] = true;
          item['monetizationTier'] = 'eligible';
          item['monetizationStatus'] = 'approved';
        } else if (isHold) {
          item['moderationReason'] =
              reason.isNotEmpty ? reason : 'Placed on hold by administrator.';
          item['isVerified'] = false;
          item['isMonetized'] = false;
          item['monetizationTier'] = 'none';
          item['monetizationStatus'] = 'onHold';
        } else {
          item['moderationReason'] = reason;
          item['isVerified'] = false;
          item['isMonetized'] = false;
          item['monetizationTier'] = 'none';
          item['monetizationStatus'] = 'rejected';
        }
        item['geminiApproved'] = isApprove;
        channels[chIdx] = item;
        channels.refresh();
        pendingChannels.value =
            channels.where(AdminModerationPredicates.isChannelPending).length;
      }

      // Update the channel document in Firestore directly
      final channelUpdate = <String, dynamic>{
        'status': status,
        'moderationReason': isApprove
            ? FieldValue.delete()
            : (reason.isNotEmpty
                ? reason
                : (isHold
                    ? 'Channel placed on hold by administrator.'
                    : 'Rejected by administrator.')),
        'geminiApproved': isApprove,
        'isVerified': isApprove,
        'isMonetized': isApprove,
        'monetizationTier': isApprove ? 'eligible' : 'none',
        'monetizationStatus': isHold ? 'onHold' : (isApprove ? 'approved' : 'rejected'),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isApprove) {
        channelUpdate['monetizationApprovedAt'] = FieldValue.serverTimestamp();
      } else if (isHold) {
        channelUpdate['monetizationHoldReason'] =
            reason.isNotEmpty ? reason : 'Channel placed on hold.';
      } else {
        channelUpdate['monetizationRejectedReason'] = reason;
      }

      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .update(channelUpdate)
            .catchError((e) {
              debugPrint('Firestore moderateChannel error: $e');
            }),
      );

      // Instantly propagate channelStatus to all videos belonging to this channel
      unawaited(
        FirebaseFirestore.instance
            .collection('videos')
            .where('channelId', isEqualTo: channelId)
            .get()
            .then((snap) {
              if (snap.docs.isNotEmpty) {
                final batch = FirebaseFirestore.instance.batch();
                for (final doc in snap.docs) {
                  batch.update(doc.reference, {
                    'channelStatus': status,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }
                return batch.commit();
              }
            })
            .catchError((e) {
              debugPrint('Firestore propagate channelStatus to videos error: $e');
            }),
      );

      // Update reactive memory cache
      final cachedChannel = ChannelMemoryCache.get(channelId);
      if (cachedChannel != null) {
        ChannelMemoryCache.set(
          channelId,
          cachedChannel.copyWith(
            status: isHold
                ? ChannelStatus.onHold
                : (isApprove
                    ? ChannelStatus.active
                    : ChannelStatus.verificationRejected),
          ),
        );
      }

      // Update monetization application and KYC status in Firestore
      unawaited(
        FirebaseFirestore.instance
            .collection('monetization_applications')
            .doc(channelId)
            .update(isApprove
                ? {
                    'status': 'approved',
                    'approvedAt': FieldValue.serverTimestamp(),
                  }
                : {
                    'status': 'rejected',
                    'rejectedReason': reason,
                    'rejectedAt': FieldValue.serverTimestamp(),
                  })
            .catchError((_) {}),
      );

      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .collection('kyc')
            .doc('identity')
            .update({'status': isApprove ? 'verified' : 'rejected'})
            .catchError((_) {}),
      );

      // Call Cloud Function endpoint if administrator is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        unawaited(
          (() async {
            try {
              final idToken = await currentUser.getIdToken();
              await http.post(
                Uri.parse('${AppConfig.cloudFunctionsBaseUrl}/moderateChannelManual'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
                body: jsonEncode({
                  'channelId': channelId,
                  'action': action,
                  'reason': reason.isNotEmpty ? reason : 'Manual $action by administrator.',
                }),
              );
            } catch (err) {
              debugPrint('Cloud function moderateChannelManual error: $err');
            }
          })(),
        );
      }

      final successMsg = isHold
          ? 'Channel successfully placed on hold.'
          : (isApprove ? 'Channel successfully approved.' : 'Channel successfully rejected.');
      AppSnackbar.success(successMsg);
      selectedChannel.value = null;
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update channel status. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Updates or increases daily video upload quota for a channel manually by admin
  static Future<bool> updateChannelQuota({
    required String channelId,
    required int dailyDurationMinutes,
    required String reason,
    required RxList<Map<String, dynamic>> channels,
    required Rxn<Map<String, dynamic>> selectedChannel,
    required RxBool isActionSubmitting,
    int? maxVideoDurationMinutes,
  }) async {
    isActionSubmitting.value = true;
    try {
      final dailySeconds = dailyDurationMinutes * 60;
      final maxVideoSeconds = (maxVideoDurationMinutes ?? dailyDurationMinutes) * 60;
      final hasCustomQuota = dailyDurationMinutes > 10;
      final adminUser = FirebaseAuth.instance.currentUser;
      final adminIdentifier = adminUser?.email ?? adminUser?.uid ?? 'Administrator';

      // 0ms Optimistic UI update
      final chIdx = channels.indexWhere((c) => c['id'] == channelId);
      if (chIdx != -1) {
        final item = Map<String, dynamic>.from(channels[chIdx]);
        item['customDailyVideoDurationSeconds'] = hasCustomQuota ? dailySeconds : null;
        item['customDailyUploadLimitMinutes'] = hasCustomQuota ? dailyDurationMinutes : null;
        item['customMaxVideoDurationSeconds'] = hasCustomQuota ? maxVideoSeconds : null;
        item['maxDailyVideoDurationSeconds'] = dailySeconds;
        item['maxVideoDurationSeconds'] = maxVideoSeconds;
        item['hasCustomQuota'] = hasCustomQuota;
        item['quotaIncreasedBy'] = adminIdentifier;
        item['quotaIncreasedAt'] = Timestamp.now();
        item['quotaIncreaseReason'] = reason;
        channels[chIdx] = item;
        channels.refresh();

        if (selectedChannel.value?['id'] == channelId) {
          selectedChannel.value = Map<String, dynamic>.from(item);
        }
      }

      // Update the channel document in Firestore directly
      final updates = <String, dynamic>{
        'customDailyVideoDurationSeconds': hasCustomQuota ? dailySeconds : FieldValue.delete(),
        'customDailyUploadLimitMinutes': hasCustomQuota ? dailyDurationMinutes : FieldValue.delete(),
        'customMaxVideoDurationSeconds': hasCustomQuota ? maxVideoSeconds : FieldValue.delete(),
        'maxDailyVideoDurationSeconds': dailySeconds,
        'maxVideoDurationSeconds': maxVideoSeconds,
        'hasCustomQuota': hasCustomQuota,
        'quotaIncreasedBy': adminIdentifier,
        'quotaIncreasedAt': FieldValue.serverTimestamp(),
        'quotaIncreaseReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .update(updates)
            .catchError((e) {
              debugPrint('Firestore updateChannelQuota error: $e');
            }),
      );

      final quotaLabel = ContentValidationMixin.formatDurationMinutesSeconds(dailySeconds);
      AppSnackbar.success(
        'Channel daily upload quota updated to $quotaLabel/day.',
      );
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update channel quota. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Updates AI Feature discounts (Dubbing & Subtitles) for a specific channel.
  /// Strictly restricted to Super Admin only.
  static Future<bool> updateChannelAiDiscounts({
    required String channelId,
    required String dubbingDiscountType, // 'none', '50%', 'free', 'custom'
    required double dubbingDiscountPercent, // 0.0 - 100.0
    required String subtitlesDiscountType, // 'none', '50%', 'free', 'custom'
    required double subtitlesDiscountPercent, // 0.0 - 100.0
    required RxList<Map<String, dynamic>> channels,
    required Rxn<Map<String, dynamic>> selectedChannel,
    required RxBool isActionSubmitting,
    Future<void> Function({
      required String action,
      required String targetType,
      required String targetId,
      required String reason,
      Map<String, dynamic>? metadata,
    })? logAdminAction,
  }) async {
    isActionSubmitting.value = true;
    try {
      final adminUser = FirebaseAuth.instance.currentUser;
      final adminIdentifier = adminUser?.email ?? adminUser?.uid ?? 'Super Admin';

      final dubPercentClamped = dubbingDiscountType == 'free'
          ? 100.0
          : (dubbingDiscountType == '50%'
              ? 50.0
              : (dubbingDiscountType == 'none'
                  ? 0.0
                  : dubbingDiscountPercent.clamp(0.0, 100.0)));

      final subPercentClamped = subtitlesDiscountType == 'free'
          ? 100.0
          : (subtitlesDiscountType == '50%'
              ? 50.0
              : (subtitlesDiscountType == 'none'
                  ? 0.0
                  : subtitlesDiscountPercent.clamp(0.0, 100.0)));

      final aiDiscounts = {
        'dubbing': {
          'type': dubbingDiscountType,
          'percent': dubPercentClamped,
          'enabled': dubPercentClamped > 0,
        },
        'subtitles': {
          'type': subtitlesDiscountType,
          'percent': subPercentClamped,
          'enabled': subPercentClamped > 0,
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminIdentifier,
      };

      // 0ms Optimistic UI update
      final chIdx = channels.indexWhere((c) => c['id'] == channelId);
      if (chIdx != -1) {
        final item = Map<String, dynamic>.from(channels[chIdx]);
        item['dubbingDiscountType'] = dubbingDiscountType;
        item['dubbingDiscountPercent'] = dubPercentClamped;
        item['subtitlesDiscountType'] = subtitlesDiscountType;
        item['subtitlesDiscountPercent'] = subPercentClamped;
        item['aiDiscounts'] = {
          'dubbing': {
            'type': dubbingDiscountType,
            'percent': dubPercentClamped,
            'enabled': dubPercentClamped > 0,
          },
          'subtitles': {
            'type': subtitlesDiscountType,
            'percent': subPercentClamped,
            'enabled': subPercentClamped > 0,
          },
          'updatedAt': Timestamp.now(),
          'updatedBy': adminIdentifier,
        };
        channels[chIdx] = item;
        channels.refresh();

        if (selectedChannel.value?['id'] == channelId) {
          selectedChannel.value = Map<String, dynamic>.from(item);
        }
      }

      // Update Firestore document directly
      final updates = <String, dynamic>{
        'dubbingDiscountType': dubbingDiscountType,
        'dubbingDiscountPercent': dubPercentClamped,
        'subtitlesDiscountType': subtitlesDiscountType,
        'subtitlesDiscountPercent': subPercentClamped,
        'aiDiscounts': aiDiscounts,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update(updates);

      // Audit Log
      if (logAdminAction != null) {
        unawaited(
          logAdminAction(
            action: 'update_channel_ai_discounts',
            targetType: 'channel',
            targetId: channelId,
            reason: 'Super Admin updated Dubbing ($dubbingDiscountType, $dubPercentClamped%) and Subtitles ($subtitlesDiscountType, $subPercentClamped%) discounts.',
            metadata: {
              'channelId': channelId,
              'dubbingDiscountType': dubbingDiscountType,
              'dubbingDiscountPercent': dubPercentClamped,
              'subtitlesDiscountType': subtitlesDiscountType,
              'subtitlesDiscountPercent': subPercentClamped,
            },
          ),
        );
      }

      final dubLabel = dubPercentClamped >= 100.0 ? 'Free' : (dubPercentClamped > 0 ? '${dubPercentClamped.toStringAsFixed(0)}% off' : 'Standard');
      final subLabel = subPercentClamped >= 100.0 ? 'Free' : (subPercentClamped > 0 ? '${subPercentClamped.toStringAsFixed(0)}% off' : 'Standard');

      AppSnackbar.success(
        'Discounts updated for channel: Dubbing $dubLabel, Subtitles $subLabel.',
      );
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'AdminEntityModerationService.updateChannelAiDiscounts');
      AppSnackbar.error(
        'Unable to update channel discounts. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Grants free Dubbing Studio credits directly to a particular channel and its creator wallet.
  static Future<bool> grantChannelDubbingCredits({
    required String channelId,
    required int amountCredits,
    required String reason,
    required RxList<Map<String, dynamic>> channels,
    required Rxn<Map<String, dynamic>> selectedChannel,
    required RxBool isActionSubmitting,
    Future<void> Function({
      required String action,
      required String targetType,
      required String targetId,
      required String reason,
      Map<String, dynamic>? metadata,
    })? logAdminAction,
  }) async {
    if (channelId.isEmpty || amountCredits <= 0) return false;
    isActionSubmitting.value = true;
    try {
      final adminUser = FirebaseAuth.instance.currentUser;
      final adminIdentifier = adminUser?.email ?? adminUser?.uid ?? 'Super Admin';

      // 0ms Optimistic UI update
      final chIdx = channels.indexWhere((c) => c['id'] == channelId);
      if (chIdx != -1) {
        final item = Map<String, dynamic>.from(channels[chIdx]);
        final prevCredits = (item['freeDubbingCredits'] as num?)?.toInt() ?? 0;
        final newCredits = prevCredits + amountCredits;
        item['freeDubbingCredits'] = newCredits;
        item['dubbingCreditsGrantedTotal'] = ((item['dubbingCreditsGrantedTotal'] as num?)?.toInt() ?? 0) + amountCredits;
        item['lastDubbingCreditsGranted'] = amountCredits;
        item['lastDubbingGrantReason'] = reason;
        item['lastDubbingGrantAt'] = Timestamp.now();
        item['lastDubbingGrantBy'] = adminIdentifier;
        channels[chIdx] = item;
        channels.refresh();

        if (selectedChannel.value?['id'] == channelId) {
          selectedChannel.value = Map<String, dynamic>.from(item);
        }
      }

      // 1. Authoritative Cloud Function call
      try {
        final callable = FirebaseFunctions.instanceFor(region: AppConfig.dubbingFunctionsRegion)
            .httpsCallable('adminGrantChannelDubbingCredits');
        await callable.call({
          'channelId': channelId,
          'amountCredits': amountCredits,
          'reason': reason.isNotEmpty ? reason : 'Super Admin Channel Dubbing Grant',
        });
      } catch (cfErr, s) {
        ErrorHandler.log(cfErr, stackTrace: s, tag: 'AdminEntityModerationService.grantChannelDubbingCredits.callable');
        // Resilient fallback direct to Firestore
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .set({
          'freeDubbingCredits': FieldValue.increment(amountCredits),
          'dubbingCreditsGrantedTotal': FieldValue.increment(amountCredits),
          'lastDubbingCreditsGranted': amountCredits,
          'lastDubbingGrantReason': reason,
          'lastDubbingGrantAt': FieldValue.serverTimestamp(),
          'lastDubbingGrantBy': adminIdentifier,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Audit Log
      if (logAdminAction != null) {
        unawaited(
          logAdminAction(
            action: 'grant_channel_dubbing_credits',
            targetType: 'channel',
            targetId: channelId,
            reason: 'Super Admin granted +$amountCredits free Dubbing Studio credits to channel: $reason',
            metadata: {
              'channelId': channelId,
              'amountCredits': amountCredits,
              'reason': reason,
            },
          ),
        );
      }

      AppSnackbar.success(
        'Granted +${amountCredits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} free Dubbing Studio characters to channel.',
      );
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'AdminEntityModerationService.grantChannelDubbingCredits');
      AppSnackbar.error(
        'Unable to grant dubbing credits to channel. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Comprehensive Super Admin Privileges: Atomically updates AI discounts, grants free Dubbing Studio credits,
  /// and configures channel upload duration limit for any channel.
  static Future<bool> updateChannelSuperAdminPrivileges({
    required String channelId,
    required String dubbingDiscountType, // 'none', '50%', 'free', 'custom'
    required double dubbingDiscountPercent, // 0.0 - 100.0
    required String subtitlesDiscountType, // 'none', '50%', 'free', 'custom'
    required double subtitlesDiscountPercent, // 0.0 - 100.0
    required int dailyUploadDurationMinutes, // 10 - 1440
    required int freeCreditsToGrant, // 0+
    required String reason,
    required RxList<Map<String, dynamic>> channels,
    required Rxn<Map<String, dynamic>> selectedChannel,
    required RxBool isActionSubmitting,
    Future<void> Function({
      required String action,
      required String targetType,
      required String targetId,
      required String reason,
      Map<String, dynamic>? metadata,
    })? logAdminAction,
  }) async {
    if (channelId.isEmpty) return false;
    isActionSubmitting.value = true;
    try {
      final adminUser = FirebaseAuth.instance.currentUser;
      final adminIdentifier = adminUser?.email ?? adminUser?.uid ?? 'Super Admin';

      final dubPercentClamped = dubbingDiscountType == 'free'
          ? 100.0
          : (dubbingDiscountType == '50%'
              ? 50.0
              : (dubbingDiscountType == 'none'
                  ? 0.0
                  : dubbingDiscountPercent.clamp(0.0, 100.0)));

      final subPercentClamped = subtitlesDiscountType == 'free'
          ? 100.0
          : (subtitlesDiscountType == '50%'
              ? 50.0
              : (subtitlesDiscountType == 'none'
                  ? 0.0
                  : subtitlesDiscountPercent.clamp(0.0, 100.0)));

      final minutesClamped = dailyUploadDurationMinutes.clamp(10, 1440);
      final dailySeconds = minutesClamped * 60;
      final maxVideoSeconds = dailySeconds;
      final hasCustomQuota = minutesClamped > 10;
      final isDubFree = dubbingDiscountType == 'free' || dubPercentClamped >= 100.0;
      final isSubFree = subtitlesDiscountType == 'free' || subPercentClamped >= 100.0;

      // 0ms Optimistic UI update
      final chIdx = channels.indexWhere((c) => c['id'] == channelId);
      if (chIdx != -1) {
        final item = Map<String, dynamic>.from(channels[chIdx]);
        item['dubbingDiscountType'] = dubbingDiscountType;
        item['dubbingDiscountPercent'] = dubPercentClamped;
        item['isDubbingFree'] = isDubFree;
        item['subtitlesDiscountType'] = subtitlesDiscountType;
        item['subtitlesDiscountPercent'] = subPercentClamped;
        item['isSubtitlesFree'] = isSubFree;

        item['customDailyVideoDurationSeconds'] = hasCustomQuota ? dailySeconds : null;
        item['customDailyUploadLimitMinutes'] = hasCustomQuota ? minutesClamped : null;
        item['customMaxVideoDurationSeconds'] = hasCustomQuota ? maxVideoSeconds : null;
        item['maxDailyVideoDurationSeconds'] = dailySeconds;
        item['maxVideoDurationSeconds'] = maxVideoSeconds;
        item['hasCustomQuota'] = hasCustomQuota;
        item['quotaIncreasedBy'] = adminIdentifier;
        item['quotaIncreasedAt'] = Timestamp.now();
        item['quotaIncreaseReason'] = reason;

        if (freeCreditsToGrant > 0) {
          final prevCredits = (item['freeDubbingCredits'] as num?)?.toInt() ?? 0;
          item['freeDubbingCredits'] = prevCredits + freeCreditsToGrant;
          item['dubbingCreditsGrantedTotal'] = ((item['dubbingCreditsGrantedTotal'] as num?)?.toInt() ?? 0) + freeCreditsToGrant;
          item['lastDubbingCreditsGranted'] = freeCreditsToGrant;
          item['lastDubbingGrantReason'] = reason;
          item['lastDubbingGrantAt'] = Timestamp.now();
          item['lastDubbingGrantBy'] = adminIdentifier;
        }

        item['aiDiscounts'] = {
          'dubbing': {
            'type': dubbingDiscountType,
            'percent': dubPercentClamped,
            'enabled': dubPercentClamped > 0,
          },
          'subtitles': {
            'type': subtitlesDiscountType,
            'percent': subPercentClamped,
            'enabled': subPercentClamped > 0,
          },
          'updatedAt': Timestamp.now(),
          'updatedBy': adminIdentifier,
        };

        channels[chIdx] = item;
        channels.refresh();

        if (selectedChannel.value?['id'] == channelId) {
          selectedChannel.value = Map<String, dynamic>.from(item);
        }
      }

      // 1. Authoritative Cloud Function call
      try {
        final callable = FirebaseFunctions.instanceFor(region: AppConfig.dubbingFunctionsRegion)
            .httpsCallable('adminGrantChannelDubbingCredits');
        await callable.call({
          'channelId': channelId,
          'amountCredits': freeCreditsToGrant,
          'reason': reason.isNotEmpty ? reason : 'Super Admin Channel Privileges',
          'customDailyDurationMinutes': minutesClamped,
          'dubbingDiscountPercent': dubPercentClamped,
          'dubbingDiscountType': dubbingDiscountType,
          'subtitlesDiscountPercent': subPercentClamped,
          'subtitlesDiscountType': subtitlesDiscountType,
        });
      } catch (cfErr, s) {
        ErrorHandler.log(cfErr, stackTrace: s, tag: 'AdminEntityModerationService.updateChannelSuperAdminPrivileges.callable');
        // Resilient direct Firestore update
        final updates = <String, dynamic>{
          'dubbingDiscountType': dubbingDiscountType,
          'dubbingDiscountPercent': dubPercentClamped,
          'isDubbingFree': isDubFree,
          'subtitlesDiscountType': subtitlesDiscountType,
          'subtitlesDiscountPercent': subPercentClamped,
          'isSubtitlesFree': isSubFree,
          'customDailyVideoDurationSeconds': hasCustomQuota ? dailySeconds : FieldValue.delete(),
          'customDailyUploadLimitMinutes': hasCustomQuota ? minutesClamped : FieldValue.delete(),
          'customMaxVideoDurationSeconds': hasCustomQuota ? maxVideoSeconds : FieldValue.delete(),
          'maxDailyVideoDurationSeconds': dailySeconds,
          'maxVideoDurationSeconds': maxVideoSeconds,
          'hasCustomQuota': hasCustomQuota,
          'quotaIncreasedBy': adminIdentifier,
          'quotaIncreasedAt': FieldValue.serverTimestamp(),
          'quotaIncreaseReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (freeCreditsToGrant > 0) {
          updates['freeDubbingCredits'] = FieldValue.increment(freeCreditsToGrant);
          updates['dubbingCreditsGrantedTotal'] = FieldValue.increment(freeCreditsToGrant);
          updates['lastDubbingCreditsGranted'] = freeCreditsToGrant;
          updates['lastDubbingGrantReason'] = reason;
          updates['lastDubbingGrantAt'] = FieldValue.serverTimestamp();
          updates['lastDubbingGrantBy'] = adminIdentifier;
        }

        await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .set(updates, SetOptions(merge: true));
      }

      // Audit Log
      if (logAdminAction != null) {
        unawaited(
          logAdminAction(
            action: 'update_channel_super_admin_privileges',
            targetType: 'channel',
            targetId: channelId,
            reason: 'Super Admin updated channel privileges: Dubbing ($dubbingDiscountType, $dubPercentClamped%), Subtitles ($subtitlesDiscountType, $subPercentClamped%), ${freeCreditsToGrant > 0 ? "+$freeCreditsToGrant chars, " : ""}Upload Limit: ${minutesClamped}m/day.',
            metadata: {
              'channelId': channelId,
              'dubbingDiscountPercent': dubPercentClamped,
              'dubbingDiscountType': dubbingDiscountType,
              'subtitlesDiscountPercent': subPercentClamped,
              'subtitlesDiscountType': subtitlesDiscountType,
              'dailyUploadDurationMinutes': minutesClamped,
              'freeCreditsToGrant': freeCreditsToGrant,
            },
          ),
        );
      }

      final dubLabel = dubPercentClamped >= 100.0 ? 'Free' : (dubPercentClamped > 0 ? '${dubPercentClamped.toStringAsFixed(0)}% off' : 'Standard');
      final creditsMsg = freeCreditsToGrant > 0 ? ', +${freeCreditsToGrant.toString()} free credits' : '';
      AppSnackbar.success(
        'Updated privileges for channel: Dubbing $dubLabel, ${minutesClamped}m upload limit$creditsMsg.',
      );
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'AdminEntityModerationService.updateChannelSuperAdminPrivileges');
      AppSnackbar.error(
        'Unable to update channel privileges. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Toggles Trusted Channel Moderation Exemption (bypasses all content and image moderation)
  static Future<bool> toggleChannelTrustedModeration({
    required String channelId,
    required bool enabled,
    required RxList<Map<String, dynamic>> channels,
    required Rxn<Map<String, dynamic>> selectedChannel,
    required RxBool isActionSubmitting,
    String? reason,
  }) async {
    isActionSubmitting.value = true;
    try {
      final adminUser = FirebaseAuth.instance.currentUser;
      final adminIdentifier = adminUser?.email ?? adminUser?.uid ?? 'Administrator';
      final defaultReason = enabled
          ? 'Exempted from all content and image moderation by administrator (Trusted Channel).'
          : 'Trusted channel moderation exemption revoked by administrator.';
      final effectiveReason = reason ?? defaultReason;

      // 0ms Optimistic UI update
      final chIdx = channels.indexWhere((c) => c['id'] == channelId);
      if (chIdx != -1) {
        final item = Map<String, dynamic>.from(channels[chIdx]);
        item['trustedModerationBypass'] = enabled;
        item['bypassModeration'] = enabled;
        item['trustedChannel'] = enabled;
        item['trustedModerationBypassSetBy'] = adminIdentifier;
        item['trustedModerationBypassSetAt'] = Timestamp.now();
        item['trustedModerationBypassReason'] = effectiveReason;
        if (enabled) {
          item['status'] = 'active';
          item['geminiApproved'] = true;
          item['isVerified'] = true;
        }
        channels[chIdx] = item;
        channels.refresh();

        if (selectedChannel.value?['id'] == channelId) {
          selectedChannel.value = Map<String, dynamic>.from(item);
        }
      }

      final updates = <String, dynamic>{
        'trustedModerationBypass': enabled,
        'bypassModeration': enabled,
        'trustedChannel': enabled,
        'trustedModerationBypassSetBy': adminIdentifier,
        'trustedModerationBypassSetAt': FieldValue.serverTimestamp(),
        'trustedModerationBypassReason': effectiveReason,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (enabled) {
        updates['status'] = 'active';
        updates['geminiApproved'] = true;
        updates['isVerified'] = true;
      }

      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .update(updates)
            .catchError((e) {
              debugPrint('Firestore toggleChannelTrustedModeration error: $e');
            }),
      );

      // Audit log
      unawaited(
        FirebaseFirestore.instance.collection('admin_actions_log').add({
          'adminId': adminIdentifier,
          'action': enabled
              ? 'enable_trusted_channel_moderation_bypass'
              : 'disable_trusted_channel_moderation_bypass',
          'channelId': channelId,
          'reason': effectiveReason,
          'timestamp': FieldValue.serverTimestamp(),
        }),
      );

      AppSnackbar.success(
        enabled
            ? 'Trusted Channel exemption enabled. All content & image moderation is now off for this channel.'
            : 'Trusted Channel exemption disabled. Standard moderation resumed.',
      );
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update trusted channel moderation setting. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Executes manual topic moderation action (Approve/Reject)
  static Future<bool> moderateTopic({
    required String topicId,
    required String action,
    required String reason,
    required RxList<Map<String, dynamic>> topics,
    required RxInt pendingTopics,
    required Rxn<Map<String, dynamic>> selectedTopic,
    required RxBool isActionSubmitting,
  }) async {
    isActionSubmitting.value = true;
    try {
      final tIdx = topics.indexWhere((t) => t['id'] == topicId);
      if (action == 'approve') {
        final currentTopicMap = tIdx != -1 ? topics[tIdx] : null;
        final vCount = (currentTopicMap?['videoCount'] as num?)?.toInt() ?? 0;
        final featVids = currentTopicMap?['featuredVideoIds'] as List? ?? [];
        if (vCount <= 0 && featVids.isEmpty) {
          AppSnackbar.warning(
            'This topic contains 0 videos and cannot be published or approved.',
            title: 'Cannot Approve',
          );
          isActionSubmitting.value = false;
          return false;
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      final status = action == 'approve' ? 'active' : 'verificationRejected';
      final isApproved = action == 'approve';
      final adminUid = user?.uid ?? 'admin';

      // 0ms Optimistic UI update
      if (tIdx != -1) {
        final item = Map<String, dynamic>.from(topics[tIdx]);
        item['status'] = status;
        item['isApproved'] = isApproved;
        item['geminiApproved'] = isApproved;
        item['moderationReason'] = reason;
        item['manuallyVerified'] = true;
        item['verifiedBy'] = adminUid;
        topics[tIdx] = item;
        topics.refresh();
        pendingTopics.value =
            topics.where(AdminModerationPredicates.isTopicPending).length;
      }

      // Direct Firestore update for real-time synchronization
      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.topics)
            .doc(topicId)
            .set({
              'status': status,
              'isApproved': isApproved,
              'geminiApproved': isApproved,
              'moderationReason': reason,
              'manuallyVerified': true,
              'verifiedBy': adminUid,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((e) {
              debugPrint('Firestore moderateTopic error: $e');
            }),
      );

      // Call Cloud Function endpoint if available
      if (user != null) {
        unawaited(
          (() async {
            try {
              final idToken = await user.getIdToken();
              await http.post(
                Uri.parse(
                  '${AppConfig.cloudFunctionsBaseUrl}/moderateTopicManual',
                ),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
                body: jsonEncode({
                  'topicId': topicId,
                  'action': action,
                  'reason': reason,
                }),
              );
            } catch (cfErr, cfStack) {
              ErrorHandler.log(
                cfErr,
                stackTrace: cfStack,
                tag: 'AdminEntityModerationService.moderateTopic.cloudFunction',
              );
            }
          })(),
        );
      }

      AppSnackbar.info(
        'Topic status updated to ${status.toUpperCase()}.',
        title: 'Topic ${action == 'approve' ? 'Approved' : 'Rejected'}',
      );
      selectedTopic.value = null;
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update topic status. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Executes manual ad moderation action (Approve/Reject)
  static Future<bool> moderateAd({
    required String adId,
    required String action,
    required RxList<Map<String, dynamic>> ads,
    required RxInt pendingAds,
    required Rxn<Map<String, dynamic>> selectedAd,
    required RxBool isActionSubmitting,
    String? reason,
  }) async {
    isActionSubmitting.value = true;
    try {
      final status = action == 'approve' ? 'active' : 'verification_rejected';

      // 0ms Optimistic UI update
      final adIdx = ads.indexWhere((a) => a['id'] == adId);
      if (adIdx != -1) {
        final item = Map<String, dynamic>.from(ads[adIdx]);
        item['status'] = status;
        if (action == 'approve') {
          item.remove('moderationReason');
        } else {
          item['moderationReason'] = reason ?? 'Violates advertising policy';
        }
        item['geminiApproved'] = action == 'approve';
        ads[adIdx] = item;
        ads.refresh();
        pendingAds.value =
            ads.where((a) => a['status'] == 'underReview').length;
      }

      // Update Firestore ad_campaigns document
      unawaited(
        FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(adId)
            .update({
              'status': status,
              'moderationReason': action == 'approve'
                  ? FieldValue.delete()
                  : (reason ?? 'Violates advertising policy'),
              'geminiApproved': action == 'approve',
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .catchError((e) {
              debugPrint('Firestore moderateAd error: $e');
            }),
      );

      AppSnackbar.success(
        'Campaign successfully ${action}d.',
      );
      selectedAd.value = null;
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update ad campaign. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Trigger batch AI dubbing and subtitles generation for all video ads
  static Future<void> generateAllVideoAdsAI({
    required RxBool isGeneratingAllVideoAdsAI,
    List<String> features = const ['subtitles', 'dubbing'],
    List<String> targetLanguages = const ['te', 'hi', 'ta', 'es'],
    String voiceStyle = 'natural',
    bool forceRegenerate = false,
  }) async {
    if (isGeneratingAllVideoAdsAI.value) return;
    isGeneratingAllVideoAdsAI.value = true;

    try {
      AppSnackbar.info(
        'Initiating AI dubbing and subtitles generation for all video ads...',
        title: 'Queueing AI Pipeline',
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      final token = currentUser != null ? await currentUser.getIdToken() : null;

      final url = Uri.parse(
        '${AppConfig.cloudFunctionsBaseUrl}/generateAllVideoAdsAIFeatures',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'features': features,
          'targetLanguages': targetLanguages,
          'voiceStyle': voiceStyle,
          'forceRegenerate': forceRegenerate,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        AppSnackbar.info(
          'Dubbing & subtitles are generating for all video ads in the background.',
          title: 'Batch AI Started',
        );
      } else {
        AppSnackbar.info(
          'Batch AI job queued in background.',
          title: 'Notice',
        );
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to start batch AI generation. Please try again.',
      );
    } finally {
      isGeneratingAllVideoAdsAI.value = false;
    }
  }

  /// Executes bulk moderation action on selected items
  static Future<void> bulkModerate({
    required String contentType,
    required String action,
    required String reason,
    required RxSet<String> selectedItemIds,
    required RxBool isBulkActionSubmitting,
    required VoidCallback onClearSelection,
  }) async {
    if (selectedItemIds.isEmpty) return;
    isBulkActionSubmitting.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Session expired.');
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(
          '${AppConfig.cloudFunctionsBaseUrl}/adminBulkModerate',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'contentType': contentType,
          'action': action,
          'itemIds': selectedItemIds.toList(),
          'reason': reason,
        }),
      );

      if (response.statusCode != 200) {
        final errBody = jsonDecode(response.body);
        throw Exception(errBody['error'] ?? 'Bulk moderation failed.');
      }

      final result = jsonDecode(response.body);
      final successCount =
          (result['results'] as List?)
              ?.where((r) => r['success'] == true)
              .length ??
          0;

      AppSnackbar.success(
        '$successCount/${selectedItemIds.length} items ${action}ed successfully.',
        title: 'Bulk Action Complete',
      );
      onClearSelection();
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to complete bulk moderation. Please try again.',
      );
    } finally {
      isBulkActionSubmitting.value = false;
    }
  }
}
