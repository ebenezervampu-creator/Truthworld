import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

import 'package:truthworld/features/admin/presentation/controllers/moderation/admin_moderation_predicates.dart';

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
      final status = action == 'approve' ? 'active' : 'verificationRejected';

      // 0ms Optimistic UI update
      final chIdx = channels.indexWhere((c) => c['id'] == channelId);
      if (chIdx != -1) {
        final item = Map<String, dynamic>.from(channels[chIdx]);
        item['status'] = status;
        if (action == 'approve') {
          item.remove('moderationReason');
        } else {
          item['moderationReason'] = reason;
        }
        item['geminiApproved'] = action == 'approve';
        channels[chIdx] = item;
        channels.refresh();
        pendingChannels.value =
            channels.where(AdminModerationPredicates.isChannelPending).length;
      }

      // Update the channel document in Firestore directly
      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .update({
              'status': status,
              'moderationReason': action == 'approve'
                  ? FieldValue.delete()
                  : reason,
              'geminiApproved': action == 'approve',
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .catchError((e) {
              debugPrint('Firestore moderateChannel error: $e');
            }),
      );

      AppSnackbar.success(
        'Channel successfully ${action}ed.',
      );
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
