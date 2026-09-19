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

/// Service executing moderation actions for media items: videos, images, and reports.
class AdminMediaModerationService {
  const AdminMediaModerationService._();

  /// Executes manual video moderation action (Approve/Reject)
  static Future<bool> moderateVideo({
    required String videoId,
    required String action,
    required String reason,
    required RxList<Map<String, dynamic>> videos,
    required RxInt pendingVideos,
    required Rxn<Map<String, dynamic>> selectedVideo,
    required RxBool isActionSubmitting,
  }) async {
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
        pendingVideos.value =
            videos.where(AdminModerationPredicates.isVideoPending).length;
      }

      // 1. Direct Firestore update/delete for immediate real-time sync
      if (action == 'reject') {
        unawaited(
          FirebaseFirestore.instance
              .collection('videos')
              .doc(videoId)
              .delete()
              .catchError((e) {
                debugPrint('Firestore moderateVideo delete error: $e');
              }),
        );
      } else {
        unawaited(
          FirebaseFirestore.instance
              .collection('videos')
              .doc(videoId)
              .set({
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
              }, SetOptions(merge: true))
              .catchError((e) {
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
                tag: 'AdminMediaModerationService.moderateVideo.cloudFunction',
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
  static Future<bool> moderateImage({
    required String verificationId,
    required String action,
    required String reason,
    required RxList<Map<String, dynamic>> images,
    required RxInt pendingImages,
    required Rxn<Map<String, dynamic>> selectedImage,
    required RxBool isActionSubmitting,
  }) async {
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
        pendingImages.value =
            images.where(AdminModerationPredicates.isImagePostPending).length;
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
            .catchError((e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'AdminMediaModerationService.moderateImage.community',
              );
            }),
      );

      unawaited(
        FirebaseFirestore.instance
            .collection('flagged_images_review')
            .doc(verificationId)
            .set(updateData, SetOptions(merge: true))
            .catchError((e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag:
                    'AdminMediaModerationService.moderateImage.flagged_images_review',
              );
            }),
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
            .catchError((e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag:
                    'AdminMediaModerationService.moderateImage.image_verification',
              );
            }),
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
            .catchError((e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'AdminMediaModerationService.moderateImage.topics',
              );
            }),
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
            .catchError((e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'AdminMediaModerationService.moderateImage.playlists',
              );
            }),
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
            tag: 'AdminMediaModerationService.moderateImage.response',
          );
        }
      } catch (cfErr, cfStack) {
        ErrorHandler.log(
          cfErr,
          stackTrace: cfStack,
          tag: 'AdminMediaModerationService.moderateImage.cloudFunction',
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

  /// Executes manual report resolution
  static Future<bool> moderateReport({
    required String reportId,
    required String action,
    required String reviewReason,
    required RxList<Map<String, dynamic>> reports,
    required RxInt pendingReports,
    required Rxn<Map<String, dynamic>> selectedReport,
    required RxBool isActionSubmitting,
    required RxList<Map<String, dynamic>> videos,
    required RxInt pendingVideos,
    required Rxn<Map<String, dynamic>> selectedVideo,
  }) async {
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
        // Reject the video as well
        final success = await moderateVideo(
          videoId: videoId,
          action: 'reject',
          reason: reviewReason,
          videos: videos,
          pendingVideos: pendingVideos,
          selectedVideo: selectedVideo,
          isActionSubmitting: isActionSubmitting,
        );
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
        item['status'] =
            action == 'reject' ? 'resolved_rejected' : 'resolved_dismissed';
        item['isResolved'] = true;
        item['resolutionComment'] = reviewReason;
        reports[rIdx] = item;
        reports.refresh();
        pendingReports.value =
            reports.where(AdminModerationPredicates.isReportPending).length;
      }

      unawaited(
        reportRef.update({
          'status':
              action == 'reject' ? 'resolved_rejected' : 'resolved_dismissed',
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
}
