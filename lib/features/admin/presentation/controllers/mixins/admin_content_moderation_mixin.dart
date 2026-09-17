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

/// Mixin providing real-time content moderation queues, predicates, and moderation actions.
mixin AdminContentModerationMixin on GetxController {
  /// Base controller contracts
  RxString get currentAdminEmail;

  Future<void> logAdminAction({
    required String action,
    String? targetId,
    String? userId,
    String? reason,
    Map<String, dynamic>? extra,
  });

  // Backward-compatible alias
  Future<void> _logAdminAction({
    required String action,
    String? targetId,
    String? userId,
    String? reason,
    Map<String, dynamic>? extra,
  }) =>
      logAdminAction(
        action: action,
        targetId: targetId,
        userId: userId,
        reason: reason,
        extra: extra,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // Content Moderation Queues & Observables
  // ═══════════════════════════════════════════════════════════════════════════
  final RxBool isActionSubmitting = false.obs;

  // Real-time Lists
  final RxList<Map<String, dynamic>> videos = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> topics = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> images = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> channels = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> reports = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> ads = <Map<String, dynamic>>[].obs;

  // Selected Detail views
  final Rxn<Map<String, dynamic>> selectedVideo = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedTopic = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedImage = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedChannel = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedReport = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedAd = Rxn<Map<String, dynamic>>();

  // System statistics
  final RxInt pendingVideos = 0.obs;
  final RxInt pendingTopics = 0.obs;
  final RxInt pendingImages = 0.obs;
  final RxInt pendingChannels = 0.obs;
  final RxInt pendingReports = 0.obs;
  final RxInt pendingAds = 0.obs;
  final RxInt totalVideos = 0.obs;
  final RxInt totalTopics = 0.obs;
  final RxInt totalImages = 0.obs;
  final RxInt totalChannels = 0.obs;
  final RxInt totalReports = 0.obs;
  final RxInt totalAds = 0.obs;
  final RxString adFilterTab = 'all'.obs;

  // Search & Filter
  final RxString searchQuery = ''.obs;
  final RxString filterStatus = ''.obs;
  final RxString filterCategory = ''.obs;
  final RxString filterTrustTier = ''.obs;
  final RxString videoFilterTab = 'all'.obs;
  final RxString topicFilterTab = 'pending'.obs;
  final RxString imageFilterTab = 'all'.obs;
  final RxString channelFilterTab = 'all'.obs;
  final RxString reportFilterTab = 'all'.obs;
  final RxBool isSearching = false.obs;
  final RxSet<String> selectedItemIds = <String>{}.obs;
  final RxBool isBulkActionSubmitting = false.obs;

  bool isVideoPending(Map<String, dynamic> v) {
    if (isVideoRejected(v)) return false;
    final mod = v['moderation'] as Map<String, dynamic>?;
    final modStatus = mod?['status']?.toString().toLowerCase();
    final vStatus = v['status']?.toString().toLowerCase();
    final status = modStatus ?? vStatus;

    if (mod?['violationCategories']?.contains('timeout_passthrough') == true) {
      return true;
    }
    if (status == null) {
      if (v['isApproved'] == false) return true;
      return false;
    }
    return status == 'pending' ||
        status == 'processing' ||
        status == 'error' ||
        status == 'under_review' ||
        status == 'underreview' ||
        status == 'in_review' ||
        status == 'pending_review' ||
        status == 'flagged' ||
        status == 'uploading' ||
        status == 'unverified' ||
        status == 'pending_approval';
  }

  /// Checks if a video is approved/published/active
  bool isVideoApproved(Map<String, dynamic> v) {
    if (isVideoRejected(v)) return false;
    if (isVideoPending(v)) return false;
    final mod = v['moderation'] as Map<String, dynamic>?;
    final modStatus = mod?['status']?.toString().toLowerCase();
    final vStatus = v['status']?.toString().toLowerCase();
    final status = modStatus ?? vStatus;

    if (status == 'approved' ||
        status == 'published' ||
        status == 'active' ||
        status == 'ready' ||
        status == 'passed') {
      return true;
    }
    if (v['isApproved'] == true || v['visibility'] == 'public') {
      return true;
    }
    return true; // Default fallback for existing videos without status
  }

  /// Checks if a video is rejected
  bool isVideoRejected(Map<String, dynamic> v) {
    final mod = v['moderation'] as Map<String, dynamic>?;
    final modStatus = mod?['status']?.toString().toLowerCase();
    final vStatus = v['status']?.toString().toLowerCase();
    return modStatus == 'rejected' || vStatus == 'rejected';
  }

  /// Checks if a channel is pending verification/review
  bool isChannelPending(Map<String, dynamic> c) {
    if (isChannelRejected(c)) return false;
    final status = (c['status'] ?? '').toString().toLowerCase();
    if (status == 'underreview' ||
        status == 'under_review' ||
        status == 'pending' ||
        status == 'pending_approval' ||
        status == 'unverified' ||
        status == 'verification_pending' ||
        status == 'in_review') {
      return true;
    }
    if (status.isEmpty && (c['isVerified'] == false || c['geminiApproved'] == false)) {
      return true;
    }
    return false;
  }

  /// Checks if a channel is active/verified
  bool isChannelActive(Map<String, dynamic> c) {
    if (isChannelRejected(c)) return false;
    if (isChannelPending(c)) return false;
    final status = (c['status'] ?? 'active').toString().toLowerCase();
    return status == 'active' ||
        status == 'verified' ||
        status == 'approved' ||
        status == 'published' ||
        status == 'ready' ||
        c['isApproved'] == true ||
        c['isVerified'] == true ||
        c['geminiApproved'] == true ||
        c['status'] == null;
  }

  /// Checks if a channel is approved (alias for isChannelActive)
  bool isChannelApproved(Map<String, dynamic> c) => isChannelActive(c);

  /// Checks if a channel verification was rejected or banned
  bool isChannelRejected(Map<String, dynamic> c) {
    final status = (c['status'] ?? '').toString().toLowerCase();
    return status == 'verificationrejected' ||
        status == 'verification_rejected' ||
        status == 'rejected' ||
        status == 'banned' ||
        status == 'suspended';
  }

  /// Checks if a topic is pending review / verification
  bool isTopicPending(Map<String, dynamic> t) {
    if (isTopicRejected(t)) return false;
    final status = (t['status'] ?? '').toString().toLowerCase();
    if (status == 'underreview' ||
        status == 'under_review' ||
        status == 'pending' ||
        status == 'pending_approval' ||
        status == 'unverified' ||
        status == 'in_review' ||
        status == 'flagged') {
      return true;
    }
    if (t['geminiApproved'] == false && status != 'active' && status != 'approved') {
      return true;
    }
    return false;
  }

  /// Checks if a topic is active / approved
  bool isTopicApproved(Map<String, dynamic> t) {
    if (isTopicRejected(t)) return false;
    if (isTopicPending(t)) return false;
    final status = (t['status'] ?? '').toString().toLowerCase();
    return status == 'active' ||
        status == 'approved' ||
        status == 'published' ||
        status == 'verified' ||
        t['isApproved'] == true ||
        t['geminiApproved'] == true;
  }

  /// Checks if a topic was rejected
  bool isTopicRejected(Map<String, dynamic> t) {
    final status = (t['status'] ?? '').toString().toLowerCase();
    return status == 'verificationrejected' ||
        status == 'verification_rejected' ||
        status == 'rejected' ||
        status == 'banned' ||
        status == 'suspended';
  }

  /// Checks if an image/post is confirmed rejected by admin
  bool isImagePostRejected(Map<String, dynamic> img) {
    final status = (img['status'] ?? '').toString().toUpperCase();
    final modStatus = (img['moderation']?['status'] ?? '').toString().toUpperCase();
    return status == 'REJECTED' ||
        status == 'MANUALLY_REJECTED' ||
        status == 'ADMIN_REJECTED' ||
        status == 'DELETED' ||
        status == 'REMOVED' ||
        status == 'BANNED' ||
        modStatus == 'REJECTED' ||
        modStatus == 'MANUALLY_REJECTED';
  }

  /// Checks if an image/post is pending review (including items flagged by SafeSearch/Vision AI)
  bool isImagePostPending(Map<String, dynamic> img) {
    if (isImagePostRejected(img)) return false;
    final status = (img['status'] ?? '').toString().toUpperCase().replaceAll('_', '').replaceAll(' ', '');
    final modStatus = (img['moderation']?['status'] ?? '').toString().toUpperCase().replaceAll('_', '').replaceAll(' ', '');

    if (status == 'PENDINGREVIEW' ||
        status == 'PENDING' ||
        status == 'PROCESSING' ||
        status == 'UNDERREVIEW' ||
        status == 'PENDINGAPPROVAL' ||
        status == 'UNVERIFIED' ||
        status == 'INREVIEW' ||
        status == 'FLAGGED' ||
        status == 'FLAGGEDFORREVIEW' ||
        status == 'FLAGGEDBYAI' ||
        status == 'VERIFICATIONREJECTED' ||
        status == 'QUARANTINED' ||
        status == 'NEEDSREVIEW' ||
        status == 'AWAITINGREVIEW' ||
        status == 'AWAITINGAPPROVAL' ||
        status == 'FAILED' ||
        modStatus == 'PENDING' ||
        modStatus == 'PENDINGREVIEW' ||
        modStatus == 'FLAGGED' ||
        modStatus == 'VERIFICATIONREJECTED') {
      return true;
    }

    if (img['isApproved'] == false &&
        status != 'APPROVED' &&
        status != 'ACTIVE' &&
        status != 'PUBLISHED' &&
        status != 'PASSED') {
      return true;
    }
    return false;
  }

  /// Checks if an image/post is approved/published
  bool isImagePostApproved(Map<String, dynamic> img) {
    if (isImagePostRejected(img)) return false;
    if (isImagePostPending(img)) return false;
    final status = (img['status'] ?? '').toString().toUpperCase();
    final modStatus = (img['moderation']?['status'] ?? '').toString().toUpperCase();
    return status == 'APPROVED' ||
        status == 'ACTIVE' ||
        status == 'PUBLISHED' ||
        status == 'PASSED' ||
        status == 'SUCCESS' ||
        modStatus == 'APPROVED' ||
        img['isApproved'] == true;
  }

  /// Checks if a video/content report is pending
  bool isReportPending(Map<String, dynamic> r) {
    if (isReportResolved(r)) return false;
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    return status == 'pending' ||
        status == 'under_review' ||
        status == 'underreview' ||
        status == 'in_review' ||
        status == 'unresolved' ||
        status == 'new';
  }

  /// Checks if a video/content report is resolved or dismissed
  bool isReportResolved(Map<String, dynamic> r) {
    final status = (r['status'] ?? '').toString().toLowerCase();
    return r['isResolved'] == true ||
        r['resolved'] == true ||
        status == 'resolved' ||
        status == 'dismissed' ||
        status == 'resolved_rejected' ||
        status == 'resolved_dismissed' ||
        status == 'closed';
  }

  /// Cancels all active Firestore listeners

  Future<bool> moderateVideo(
    String videoId,
    String action,
    String reason,
  ) async {
    isActionSubmitting.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final newStatus = action == 'approve' ? 'approved' : 'rejected';
      final adminUid = user?.uid ?? 'admin';

      // 0ms Optimistic UI update
      final vIdx = videos.indexWhere((v) => v['id'] == videoId);
      if (vIdx != -1) {
        if (action == 'reject') {
          videos.removeAt(vIdx);
        } else {
          final item = Map<String, dynamic>.from(videos[vIdx]);
          item['status'] = 'published';
          item['isApproved'] = true;
          item['visibility'] = 'public';
          item['moderation'] = {
            'status': 'approved',
            'moderationReason': reason,
            'overriddenByAdmin': true,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
            'moderatedBy': adminUid,
          };
          videos[vIdx] = item;
        }
        videos.refresh();
        pendingVideos.value = videos.where(isVideoPending).length;
      }

      // 1. Direct Firestore update/delete for immediate real-time sync
      if (action == 'reject') {
        unawaited(
          FirebaseFirestore.instance.collection('videos').doc(videoId).delete().catchError((e) {
            debugPrint('Firestore moderateVideo delete error: $e');
          }),
        );
      } else {
        unawaited(
          FirebaseFirestore.instance.collection('videos').doc(videoId).set({
            'moderation': {
              'status': 'approved',
              'moderationReason': reason,
              'overriddenByAdmin': true,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
              'moderatedBy': adminUid,
            },
            'status': 'published',
            'isApproved': true,
            'visibility': 'public',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((e) {
            debugPrint('Firestore moderateVideo set error: $e');
          }),
        );
      }

      // 2. Call Cloud Function endpoint if user is authenticated
      if (user != null) {
        unawaited(
          (() async {
            try {
              final idToken = await user.getIdToken();
              await http.post(
                Uri.parse(
                  '${AppConfig.cloudFunctionsBaseUrl}/moderateVideoManual',
                ),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
                body: jsonEncode({
                  'videoId': videoId,
                  'action': action,
                  'reason': reason,
                }),
              );
            } catch (cfErr, cfStack) {
              ErrorHandler.log(
                cfErr,
                stackTrace: cfStack,
                tag: 'AdminContentModerationMixin.moderateVideo.cloudFunction',
              );
            }
          })(),
        );
      }

      AppSnackbar.info(
        'Video status updated to ${newStatus.toUpperCase()}${newStatus == 'rejected' ? ' (Admin Override)' : ''}.',
        title: 'Video ${newStatus == 'approved' ? 'Approved' : 'Rejected'}',
      );
      selectedVideo.value = null;
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update video status. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Executes manual image moderation action (Approve/Reject)
  Future<bool> moderateImage(
    String verificationId,
    String action,
    String reason,
  ) async {
    isActionSubmitting.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Session expired. Please log in again.');
      }

      final newStatus = action == 'approve' ? 'APPROVED' : 'REJECTED';
      final adminUid = user.uid;

      // 0ms Optimistic UI update
      final imgIdx = images.indexWhere((img) => img['id'] == verificationId);
      if (imgIdx != -1) {
        final item = Map<String, dynamic>.from(images[imgIdx]);
        item['status'] = newStatus;
        item['isApproved'] = action == 'approve';
        item['moderation'] = {
          'status': newStatus,
          'moderationReason': reason,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'moderatedBy': adminUid,
        };
        images[imgIdx] = item;
        images.refresh();
        pendingImages.value = images.where(isImagePostPending).length;
      }

      // Direct Firestore updates for immediate real-time UI sync
      final updateData = <String, dynamic>{
        'status': newStatus,
        'isApproved': action == 'approve',
        'moderation': {
          'status': newStatus,
          'moderationReason': reason,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'moderatedBy': adminUid,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.community)
            .doc(verificationId)
            .set(updateData, SetOptions(merge: true))
            .catchError((_) {}),
      );

      unawaited(
        FirebaseFirestore.instance
            .collection('flagged_images_review')
            .doc(verificationId)
            .set(updateData, SetOptions(merge: true))
            .catchError((_) {}),
      );

      unawaited(
        FirebaseFirestore.instance
            .collection('image_verification')
            .doc(verificationId)
            .set({
              'status': action == 'approve' ? 'APPROVED' : 'REJECTED',
              'reason': reason.isNotEmpty
                  ? reason
                  : 'Manually ${action}d by administrator.',
              'reviewedBy': adminUid,
              'reviewedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((_) {}),
      );

      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.topics)
            .doc(verificationId)
            .set({
              'isApproved': action == 'approve',
              'thumbnailStatus': newStatus,
              'status': action == 'approve' ? 'active' : 'rejected',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((_) {}),
      );

      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.playlists)
            .doc(verificationId)
            .set({
              'isApproved': action == 'approve',
              'thumbnailStatus': newStatus,
              'status': action == 'approve' ? 'active' : 'rejected',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((_) {}),
      );

      try {
        final idToken = await user.getIdToken();
        final response = await http.post(
          Uri.parse(
            '${AppConfig.cloudFunctionsBaseUrl}/moderateImageManual',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'verificationId': verificationId,
            'action': action,
            'reason': reason,
          }),
        );

        if (response.statusCode != 200) {
          ErrorHandler.log(
            'Cloud function moderateImage warning: ${response.body}',
            tag: 'AdminContentModerationMixin.moderateImage.response',
          );
        }
      } catch (cfErr, cfStack) {
        ErrorHandler.log(
          cfErr,
          stackTrace: cfStack,
          tag: 'AdminContentModerationMixin.moderateImage.cloudFunction',
        );
      }

      AppSnackbar.success(
        'Image successfully ${action}ed.',
      );
      selectedImage.value = null;
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update image status. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Executes manual channel moderation action (Approve/Reject)
  Future<bool> moderateChannel(
    String channelId,
    String action,
    String reason,
  ) async {
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
        pendingChannels.value = channels.where(isChannelPending).length;
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
            }).catchError((e) {
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
  Future<bool> moderateTopic(
    String topicId,
    String action,
    String reason,
  ) async {
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
        pendingTopics.value = topics.where(isTopicPending).length;
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
                tag: 'AdminContentModerationMixin.moderateTopic.cloudFunction',
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

  Future<bool> moderateAd(
    String adId,
    String action, {
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
            }).catchError((e) {
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

  final RxBool isGeneratingAllVideoAdsAI = false.obs;

  /// Trigger batch AI dubbing and subtitles generation for ALL video ads across Truthworld
  Future<void> generateAllVideoAdsAI({
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

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Search & Bulk Moderation Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Toggles selection of an item for bulk operations
  void toggleItemSelection(String id) {
    if (selectedItemIds.contains(id)) {
      selectedItemIds.remove(id);
    } else {
      selectedItemIds.add(id);
    }
  }

  /// Clears all selected items
  void clearSelection() => selectedItemIds.clear();

  /// Selects all items in the current view
  void selectAllItems(List<Map<String, dynamic>> items) {
    selectedItemIds.assignAll(
      items.map((e) => (e['id'] ?? '').toString()).where((id) => id.isNotEmpty),
    );
  }

  /// Executes bulk moderation action on selected items
  Future<void> bulkModerate(
    String contentType,
    String action,
    String reason,
  ) async {
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
      clearSelection();
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to complete bulk moderation. Please try again.',
      );
    } finally {
      isBulkActionSubmitting.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: User Management Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Maps raw Firestore user document into standard Map structure for admin UI

  Future<bool> moderateReport(
    String reportId,
    String action,
    String reviewReason,
  ) async {
    isActionSubmitting.value = true;
    try {
      final reportRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.reports)
          .doc(reportId);
      final reportSnap = await reportRef.get();
      if (!reportSnap.exists) {
        throw Exception('Report not found');
      }
      final reportData = reportSnap.data()!;
      final videoId = reportData['videoId'] as String?;

      if (action == 'reject' && videoId != null) {
        // Reject the video as well (this will call moderateVideoCloudFunction)
        final success = await moderateVideo(videoId, 'reject', reviewReason);
        if (!success) {
          throw Exception(
            'Failed to reject the video associated with this report.',
          );
        }
      }

      // 0ms Optimistic UI update
      final rIdx = reports.indexWhere((r) => r['id'] == reportId);
      if (rIdx != -1) {
        final item = Map<String, dynamic>.from(reports[rIdx]);
        item['status'] = action == 'reject' ? 'resolved_rejected' : 'resolved_dismissed';
        item['isResolved'] = true;
        item['resolutionComment'] = reviewReason;
        reports[rIdx] = item;
        reports.refresh();
        pendingReports.value = reports.where(isReportPending).length;
      }

      unawaited(
        reportRef.update({
          'status': action == 'reject'
              ? 'resolved_rejected'
              : 'resolved_dismissed',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolutionComment': reviewReason,
        }).catchError((e) {
          debugPrint('Firestore moderateReport update error: $e');
        }),
      );

      AppSnackbar.success(
        'Report successfully resolved.',
      );
      selectedReport.value = null;
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to resolve report. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }



  List<Map<String, dynamic>> get filteredVideos {
    final q = searchQuery.value.trim().toLowerCase();
    final cat = filterCategory.value.trim().toLowerCase();
    final tab = videoFilterTab.value.toLowerCase();
    return videos.where((v) {
      if (tab == 'pending' && !isVideoPending(v)) return false;
      if (tab == 'approved' && !isVideoApproved(v)) return false;
      if (tab == 'rejected' && !isVideoRejected(v)) return false;
      if (cat.isNotEmpty && cat != 'all') {
        final itemCat = (v['category'] ?? '').toString().toLowerCase();
        if (itemCat != cat) return false;
      }
      if (q.isNotEmpty) {
        final title = (v['title'] ?? '').toString().toLowerCase();
        final id = (v['id'] ?? '').toString().toLowerCase();
        final user = (v['userId'] ?? v['creatorId'] ?? '').toString().toLowerCase();
        if (!title.contains(q) && !id.contains(q) && !user.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get filteredChannels {
    final q = searchQuery.value.trim().toLowerCase();
    final tab = channelFilterTab.value.toLowerCase();
    return channels.where((c) {
      if (tab == 'pending' && !isChannelPending(c)) return false;
      if (tab == 'approved' && !isChannelApproved(c)) return false;
      if (tab == 'rejected' && !isChannelRejected(c)) return false;
      if (q.isNotEmpty) {
        final name = (c['name'] ?? c['displayName'] ?? c['channelName'] ?? '').toString().toLowerCase();
        final id = (c['id'] ?? '').toString().toLowerCase();
        final handle = (c['handle'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !id.contains(q) && !handle.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get filteredTopics {
    final q = searchQuery.value.trim().toLowerCase();
    final tab = topicFilterTab.value.toLowerCase();
    return topics.where((t) {
      if (tab == 'pending' && !isTopicPending(t)) return false;
      if (tab == 'approved' && !isTopicApproved(t)) return false;
      if (tab == 'rejected' && !isTopicRejected(t)) return false;
      if (q.isNotEmpty) {
        final title = (t['title'] ?? t['name'] ?? '').toString().toLowerCase();
        final id = (t['id'] ?? '').toString().toLowerCase();
        if (!title.contains(q) && !id.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get filteredImages {
    final q = searchQuery.value.trim().toLowerCase();
    final tab = imageFilterTab.value.toLowerCase();
    return images.where((img) {
      if (tab == 'pending' && !isImagePostPending(img)) return false;
      if (tab == 'approved' && !isImagePostApproved(img)) return false;
      if (tab == 'rejected' && !isImagePostRejected(img)) return false;
      if (q.isNotEmpty) {
        final cat = (img['category'] ?? '').toString().toLowerCase();
        final id = (img['id'] ?? '').toString().toLowerCase();
        final reason = (img['reason'] ?? '').toString().toLowerCase();
        if (!cat.contains(q) && !id.contains(q) && !reason.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get filteredReports {
    final q = searchQuery.value.trim().toLowerCase();
    final tab = reportFilterTab.value.toLowerCase();
    return reports.where((r) {
      if (tab == 'pending' && !isReportPending(r)) return false;
      if (tab == 'resolved' && !isReportResolved(r)) return false;
      if (q.isNotEmpty) {
        final reason = (r['reason'] ?? r['reportReason'] ?? '').toString().toLowerCase();
        final id = (r['id'] ?? '').toString().toLowerCase();
        final vId = (r['videoId'] ?? '').toString().toLowerCase();
        if (!reason.contains(q) && !id.contains(q) && !vId.contains(q)) return false;
      }
      return true;
    }).toList();
  }


}
