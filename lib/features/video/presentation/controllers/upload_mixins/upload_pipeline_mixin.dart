import 'dart:async';
import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_controller_base.dart';
import 'package:uuid/uuid.dart';

mixin UploadPipelineMixin on UploadControllerBase {
  final Uuid _uuid = const Uuid();

  // Separate refs/tasks for video thumbnails vs community post images
  Reference? _currentImageRefVideo;
  Reference? _currentImageRefCommunity;

  // Track uploaded doc ids (both video and community)
  final List<String> uploadedDocIds = [];

  /// Returns the upload progress as a formatted percentage string (e.g., '42%')
  String get uploadProgressPercent =>
      '${(uploadProgress.value * 100).toStringAsFixed(0)}%';

  Future<String?> uploadThumbnailWithRepo(
    Uint8List bytes,
    String fileName,
  ) async {
    final result = await uploadRepository.uploadThumbnailBytes(
      imageBytes: bytes,
      fileName: fileName,
    );
    return result.when(
      success: (url) {
        thumbnailUrl.value = url;
        return url;
      },
      failure: (err) => null,
    );
  }

  /// Refresh the current user's auth token to ensure it's fresh
  @override
  Future<bool> refreshAuthToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        return false;
      }

      // Force a token refresh with explicit caching invalidation
      final idToken = await user.getIdToken(true);

      // For web: ensure the token is persisted to localStorage
      if (kIsWeb) {
        debugPrint('🌐 Web platform detected - ensuring token persistence');
      }

      debugPrint('✅ Auth token refreshed successfully');
      debugPrint('🔑 Token obtained (${idToken?.substring(0, 30)}...)');
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UploadPipelineMixin.refreshAuthToken',
      );
      return false;
    }
  }

  /// Verify user is authenticated and token is valid
  @override
  Future<bool> verifyAuthentication() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Refresh token to ensure it's valid
      final refreshed = await refreshAuthToken();
      if (!refreshed) {
        throw Exception('Failed to refresh authentication token');
      }

      debugPrint('✅ Authentication verified for user: ${user.uid}');
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.warning(
        'Please log in again to continue uploading.',
      );
      return false;
    }
  }

  /// Ensure auth context is ready for Storage operations on web
  @override
  Future<void> ensureStorageAuthReady() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get the ID token and ensure it's fresh
      await user.getIdToken(true);

      // On web, add a small delay to ensure Firebase Storage SDK picks it up
      if (kIsWeb) {
        debugPrint('⏳ Waiting for Storage auth context sync...');
        await Future.delayed(const Duration(milliseconds: 300));
        debugPrint('✅ Storage auth context synchronized');
      }

      debugPrint('✅ Storage auth ready for user: ${user.uid}');
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UploadController._ensureStorageAuthReady',
      );
      throw AppException.from(e, stackTrace);
    }
  }

  @override
  Future<void> startVideoUpload(PlatformFile videoFile) async {
    // Cancel any previous upload
    if (isUploading.value) {
      await videoUploadTask?.cancel();
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;
    uploadStage.value = 0; // Start at Media upload stage
    uploadStageLabel.value = 'Upload Media';

    try {
      // ✅ STEP 0: REFRESH AUTHENTICATION TOKEN
      debugPrint('🔐 Refreshing authentication token...');
      final authValid = await verifyAuthentication();
      if (!authValid) {
        throw Exception('Authentication failed. Please log in again.');
      }

      debugPrint('🔐 Verifying authentication before upload...');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final userId = currentUser.uid;
      final uniqueId = _uuid.v4();
      currentVideoId = uniqueId;
      debugPrint('✅ Authenticated user: $userId');
      debugPrint('🆔 Generated video ID: $uniqueId');

      var preExtractDurationMs = 0;
      try {
        preExtractDurationMs = videoDurationSeconds.value * 1000;
        if (preExtractDurationMs <= 0 && videoPlayerController != null) {
          preExtractDurationMs =
              videoPlayerController!.value.duration.inMilliseconds;
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'UploadPipelineMixin.extractDuration',
        );
      }
      final preExtractDurationSecs = preExtractDurationMs ~/ 1000;

      // Validate Daily Upload Quota before starting upload
      if (selectedChannel.value != null) {
        try {
          final used =
              await getTodayUploadedDurationSeconds(selectedChannel.value!.id);
          todayUploadedDurationSeconds.value = used;
          final maxDaily = selectedChannel.value!.maxDailyVideoDurationSeconds;
          remainingDailyDurationSeconds.value =
              (maxDaily - used).clamp(0, maxDaily);
          isDailyLimitReached.value = used >= maxDaily;

          final validation = validateChannelVideoUpload(
            selectedChannel.value!,
            durationSeconds: preExtractDurationSecs,
            dailyUploadedDurationSeconds: used,
          );
          if (!validation.isValid) {
            throw Exception(validation.message);
          }
        } catch (e) {
          if (e.toString().contains('Daily') ||
              e.toString().contains('Standard channel')) {
            rethrow;
          }
          debugPrint('⚠️ Non-fatal error during video duration pre-check: $e');
        }
      }

      // --------------------------------------------------------
      // 1️⃣ Create initial Firestore document (with AI features)
      // --------------------------------------------------------
      final initialData = {
        'id': uniqueId,
        'ownerId': userId,
        'userId': userId,
        'channelId': selectedChannel.value?.channelId ?? userId,
        'status': 'uploading', // Will change via Cloud Function
        'uploadedAt': Timestamp.now(),
        'duration': preExtractDurationSecs,
        'durationMs': preExtractDurationMs,
        'title': 'Uploading...',
        'description': 'Processing...',
        'videoUrl': '',
        'thumbnailUrl': '',
        'language': effectiveVideoLanguage,
        'sourceLanguage': effectiveVideoLanguage,
        'primaryLanguage': effectiveVideoLanguage,
        'spokenLanguages': spokenLanguages.isNotEmpty
            ? spokenLanguages.toList()
            : [effectiveVideoLanguage],
        'isMultilingual': isMultilingualSpoken.value || spokenLanguages.length > 1,
        'likes': 0,
        'likeCount': 0,
        'dislikes': 0,
        'dislikeCount': 0,
        'views': 0,
        'viewCount': 0,
        'shareCount': 0,
        'downloads': 0,
        'reportCount': 0,
        'isBlocked': false,
        'visibility': selectedVisibility.value,
        'category': selectedCategory.value,
        'tags': [],
        'fileName': videoFile.name,
        // AI Processing features (read by backend pipeline)
        'aiFeatures': buildFeaturesMap(pipelineStage: 'draft'),
        'storage': {'videoPath': 'videos/$uniqueId/original.mp4'},
      };

      debugPrint('📄 Creating Firestore placeholder with AI features...');
      await firestore
          .collection('videos')
          .doc(uniqueId)
          .set(initialData);

      // --------------------------------------------------------
      // 2️⃣ Listen for Firestore status updates (from Cloud Function)
      // --------------------------------------------------------
      statusListener = firestore
          .collection('videos')
          .doc(uniqueId)
          .snapshots()
          .listen((snapshot) {
            final data = snapshot.data();
            if (data == null) return;
            final status = data['status'] as String?;
            debugPrint('📡 Firestore status update: $status');

            // ── Video Content Moderation Status ──────────────────────
            final moderation = data['moderation'] as Map<String, dynamic>?;
            if (moderation != null) {
              final modStatus =
                  (moderation['status'] as String?)?.toUpperCase() ?? 'PENDING';
              final modReason = moderation['reason'] as String? ?? '';
              final modSummary = moderation['summary'] as String? ?? '';

              // Only show snackbar on status transition
              if (modStatus != videoModerationStatus.value) {
                videoModerationStatus.value = modStatus;
                videoModerationReason.value = modReason;
                videoModerationSummary.value = modSummary;

                if (modStatus == 'APPROVED') {
                  debugPrint('✅ Video content APPROVED by Verification System moderation');
                  AppSnackbar.success(
                    'Your video complies with Community Guidelines.',
                  );
                } else if (modStatus == 'REJECTED') {
                  debugPrint('❌ Video content REJECTED: $modReason');
                  final currentUid = FirebaseAuth.instance.currentUser?.uid;
                  if (currentUid != null && currentUid.isNotEmpty) {
                    final displayTitle = titleController.text.trim().isNotEmpty &&
                            titleController.text != 'Uploading...'
                        ? titleController.text.trim()
                        : videoFile.name;
                    userNotificationService.createNotification(
                      userId: currentUid,
                      type: 'verification_result',
                      severity: NotificationSeverity.priority,
                      title: 'Video Content Moderation Rejected',
                      message:
                          'Your video "$displayTitle" was rejected by moderation: $modReason. Please update or change your video.',
                      actionUrl: '/studio',
                      metadata: {
                        'videoId': uniqueId,
                        'reason': modReason,
                        'itemType': 'video',
                      },
                    );
                  }
                  AppSnackbar.error(
                    modReason.isNotEmpty ? modReason : 'Your video does not comply with Community Guidelines.',
                  );
                } else if (modStatus == 'PROCESSING') {
                  debugPrint('🔍 Video content moderation in progress...');
                }
              }
            }

            // Sync URLs from backend if they exist
            if (data['videoUrl'] != null &&
                (data['videoUrl'] as String).isNotEmpty) {
              videoUrl.value = data['videoUrl'] as String;
            }
            if (data['thumbnailUrl'] != null &&
                (data['thumbnailUrl'] as String).isNotEmpty) {
              thumbnailUrl.value = data['thumbnailUrl'] as String;
            }

            if (status == 'processed') {
              debugPrint('✅ Processing completed successfully!');
              videoUploadProgress.value = 1.0;
              uploadProgress.value = 1.0;
              isUploading.value = false;

              if (data['videoUrl'] != null) {
                videoUrl.value = data['videoUrl'] as String;
              }
              if (data['thumbnailUrl'] != null) {
                thumbnailUrl.value = data['thumbnailUrl'] as String;
              }
              if (pickedImage.value == null && thumbnailUrl.value.isNotEmpty) {
                finalstatus.value = 'APPROVED';
              }

              AppSnackbar.success(
                'Video processed and ready to publish!',
              );
              statusListener?.cancel();
            } else if (status == 'rejected') {
              final reason =
                  data['rejectionReason'] ??
                  'Content violates Community Guidelines';
              debugPrint('❌ Video REJECTED by moderation: $reason');
              isUploading.value = false;
              videoUploadProgress.value = 0.0;
              uploadProgress.value = 0.0;

              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              if (currentUid != null && currentUid.isNotEmpty) {
                final displayTitle = titleController.text.trim().isNotEmpty &&
                        titleController.text != 'Uploading...'
                    ? titleController.text.trim()
                    : videoFile.name;
                userNotificationService.createNotification(
                  userId: currentUid,
                  type: 'verification_result',
                  severity: NotificationSeverity.priority,
                  title: 'Video Moderation Rejected',
                  message:
                      'Your video "$displayTitle" was rejected: $reason. Please update or change your video to comply with guidelines.',
                  actionUrl: '/studio',
                  metadata: {
                    'videoId': uniqueId,
                    'reason': reason,
                    'itemType': 'video',
                  },
                );
              }

              AppSnackbar.error(
                reason.isNotEmpty ? reason : 'Video processing was rejected.',
              );
              statusListener?.cancel();
            } else if (status == 'failed') {
              final error = data['error'] ?? 'Unknown processing error';
              ErrorHandler.log(
                error,
                tag: 'UploadPipelineMixin.statusListener.failed',
              );
              isUploading.value = false;
              videoUploadProgress.value = 0.0;
              uploadProgress.value = 0.0;
              AppSnackbar.error(
                'Video processing could not be completed. Please try again.',
              );
              statusListener?.cancel();
            }
          },
          onError: (error, stackTrace) {
            ErrorHandler.log(
              error,
              stackTrace: stackTrace,
              tag: 'UploadController.statusListener',
            );
          });

      // --------------------------------------------------------
      // 3️⃣ Upload video to Firebase Storage
      // --------------------------------------------------------
      debugPrint('☁️ Uploading video to Firebase Storage...');

      // 🔑 CRITICAL: Ensure Storage auth context is ready on web
      debugPrint('🔐 Preparing Storage auth context...');
      await ensureStorageAuthReady();

      // Upload to nested path: videos/{id}/original.mp4 (pipeline structure)
      final videoRef = firebaseStorage.ref().child(
        'videos/$uniqueId/original.mp4',
      );
      final metadata = SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {
          'uploaderId': userId,
          'channelId': selectedChannel.value?.id ?? '',
          'duration': '$preExtractDurationSecs',
          'durationMs': '$preExtractDurationMs',
        },
      );
      if (kIsWeb) {
        if (videoFile.bytes == null) {
          throw Exception('Video file bytes are missing on web');
        }
        videoUploadTask = videoRef.putData(videoFile.bytes!, metadata);
      } else {
        if (videoFile.path != null && io.File(videoFile.path!).existsSync()) {
          videoUploadTask = videoRef.putFile(io.File(videoFile.path!), metadata);
        } else if (videoFile.bytes != null) {
          videoUploadTask = videoRef.putData(videoFile.bytes!, metadata);
        } else {
          throw Exception('Video file is missing both path and bytes');
        }
      }

      // Upload voice sample if Dubbing with cloning is selected
      if (aiGenerateDubbing.value &&
          aiTTSVoiceType.value == 'cloned' &&
          voiceSampleFile.value != null) {
        final sampleRef = firebaseStorage.ref().child(
          'videos/$uniqueId/voice_sample.mp3',
        );
        final sampleMeta = SettableMetadata(
          contentType: 'audio/mpeg',
          customMetadata: {
            'uploaderId': userId,
          },
        );
        final sampleFile = voiceSampleFile.value!;
        if (kIsWeb) {
          if (sampleFile.bytes != null) {
            await sampleRef.putData(sampleFile.bytes!, sampleMeta);
          }
        } else {
          if (sampleFile.path != null && io.File(sampleFile.path!).existsSync()) {
            await sampleRef.putFile(io.File(sampleFile.path!), sampleMeta);
          } else if (sampleFile.bytes != null) {
            await sampleRef.putData(sampleFile.bytes!, sampleMeta);
          }
        }
        debugPrint('🎙️ Voice sample uploaded for cloning');
      }

      videoUploadTask!.snapshotEvents.listen(
        (event) {
          if (event.totalBytes > 0) {
            final progress = event.bytesTransferred / event.totalBytes;
            videoUploadProgress.value = progress;
            uploadProgress.value = progress;
            if (progress % 0.1 < 0.01) {
              debugPrint(
                '📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%',
              );
            }
          }
        },
        onError: (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'UploadController.videoUploadTask',
          );
        },
      );

      final snapshot = await videoUploadTask!.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ Video uploaded successfully');
      debugPrint('🔗 Video URL: $downloadUrl');
      videoUrl.value = downloadUrl;

      // --------------------------------------------------------
      // 4️⃣ Update Firestore with video URL
      // --------------------------------------------------------
      try {
        final latestDoc = await firestore
            .collection('videos')
            .doc(uniqueId)
            .get();
        final latestData = latestDoc.data();
        final targetStatus = latestData?['targetStatus'] as String?;
        final targetVisibility = latestData?['targetVisibility'] as String?;

        await firestore
            .collection('videos')
            .doc(uniqueId)
            .update({
              'videoUrl': downloadUrl,
              'status': targetStatus == 'draft'
                  ? 'draft'
                  : (targetStatus == 'scheduled'
                      ? 'scheduled'
                      : (targetStatus == 'published' ? 'processing' : 'uploading')),
              'visibility': (targetStatus == 'scheduled' || targetStatus == 'draft')
                  ? 'private'
                  : (targetVisibility ?? 'public'),
            });
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'UploadPipelineMixin.syncUploadCompletion',
        );
        await firestore
            .collection('videos')
            .doc(uniqueId)
            .update({
              'videoUrl': downloadUrl,
              'status': 'uploading',
            });
      }

      // --------------------------------------------------------
      // 5️⃣ Notify user that processing is in progress
      // --------------------------------------------------------
      videoUploadProgress.value = 0.99;
      uploadProgress.value = 0.99;
      isUploading.value = false;
      AppSnackbar.info(
        'Upload complete! Processing video...',
      );

      debugPrint('⏳ Waiting for Cloud Function to complete processing...');
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firebase error: ${e.message}');
      isUploading.value = false;
      uploadProgress.value = 0.0;

      if (currentVideoId != null) {
        await firestore
            .collection('videos')
            .doc(currentVideoId)
            .delete();
        debugPrint('🗑️ Cleaned up failed Firestore document');
      }

      var errorMessage = 'Unable to complete video upload. Please try again.';
      if (e.code.contains('permission-denied') ||
          e.code.contains('unauthorized') ||
          (e.message?.contains('not authorized') ?? false)) {
        errorMessage =
            'Authorization error. Please try:\n'
            '1. Clear browser cache (Ctrl+Shift+Del)\n'
            '2. Log out completely\n'
            '3. Log back in\n'
            '4. Try uploading again';
      } else if (e.code.contains('unauthenticated')) {
        errorMessage = 'Authentication expired. Please log in again.';
      }

      ErrorHandler.log(e);
      AppSnackbar.error(errorMessage);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'UploadController.uploadVideo.unexpected',
      );
      isUploading.value = false;
      uploadProgress.value = 0.0;
      statusListener?.cancel();

      if (currentVideoId != null) {
        await firestore
            .collection('videos')
            .doc(currentVideoId)
            .delete();
      }

      AppSnackbar.error(
        'Unable to complete video upload. Please check your connection and try again.',
      );
    }
  }

  @override
  Future<void> startImageUpload(
    PlatformFile file, {
    required bool forCommunity,
  }) async {
    final imageFile = file;
    uploadProgress.value = 0.0;

    final activeTask = forCommunity
        ? currentUploadTaskCommunity
        : currentUploadTaskVideo;
    final existingRef = forCommunity
        ? _currentImageRefCommunity
        : _currentImageRefVideo;

    if (activeTask != null) {
      try {
        await activeTask.cancel();
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'UploadPipelineMixin.cancelPreviousUpload',
        );
      }
    }

    if (existingRef != null) {
      try {
        await existingRef.getMetadata();
        await existingRef.delete();
      } catch (e, stackTrace) {
        if (!e.toString().contains('object-not-found')) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'UploadPipelineMixin.deletePreviousImage',
          );
        }
      }
    }

    try {
      final extension = (imageFile.extension ?? 'jpg').toLowerCase();
      final uniqueFileName = '${_uuid.v4()}.$extension';
      final storagePath = forCommunity
          ? 'community_images/$uniqueFileName'
          : 'thumbnails/$uniqueFileName';
      final imageRef = firebaseStorage.ref().child(storagePath);

      if (forCommunity) {
        _currentImageRefCommunity = imageRef;
      } else {
        _currentImageRefVideo = imageRef;
      }

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final chId = selectedChannel.value?.id ?? '';
      final isTrustedChannel =
          selectedChannel.value?.trustedModerationBypass == true;
      final metadata = SettableMetadata(
        contentType: 'image/$extension',
        customMetadata: {
          'uploaderId': currentUid ?? '',
          'channelId': chId,
        },
      );
      final UploadTask uploadTask;
      if (kIsWeb) {
        if (imageFile.bytes == null) {
          throw Exception('Image file bytes are missing on web');
        }
        uploadTask = imageRef.putData(imageFile.bytes!, metadata);
      } else {
        if (imageFile.path != null && io.File(imageFile.path!).existsSync()) {
          uploadTask = imageRef.putFile(io.File(imageFile.path!), metadata);
        } else if (imageFile.bytes != null) {
          uploadTask = imageRef.putData(imageFile.bytes!, metadata);
        } else {
          throw Exception('Image file is missing both path and bytes');
        }
      }
      if (forCommunity) {
        currentUploadTaskCommunity = uploadTask;
      } else {
        currentUploadTaskVideo = uploadTask;
      }

      uploadTask.snapshotEvents.listen(
        (event) {
          if (event.totalBytes > 0) {
            imageUploadProgress.value =
                event.bytesTransferred / event.totalBytes;
          }
        },
        onError: (e) {
          debugPrint('Image upload stream error: $e');
        },
      );

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (forCommunity) {
        communityImageUrl.value = downloadUrl;
      } else {
        thumbnailUrl.value = downloadUrl;
      }
      debugPrint('Image uploaded successfully: $downloadUrl');

      final docId = uniqueFileName;
      uploadedDocIds.add(docId);

      if (isTrustedChannel) {
        if (forCommunity) {
          communityImageStatus.value = 'APPROVED';
          communityImageStatusReason.value = 'Trusted channel exemption';
        } else {
          finalstatus.value = 'APPROVED';
          finalstatusReason.value = 'Trusted channel exemption';
        }
        debugPrint(
          '🛡️ [TRUSTED CHANNEL] Bypassing image verification polling for $docId',
        );
        return;
      }

      startImageVerification(docId, forCommunity: forCommunity);
    } catch (e) {
      uploadProgress.value = 0.0;
      ErrorHandler.log(e, context: 'UploadController.uploadImage');
      AppSnackbar.error('Unable to upload image. Please try again.');
    }
  }

  void startImageVerification(String docId, {required bool forCommunity}) {
    final subscription = imageVerificationService
        .streamVerificationStatus(docId)
        .listen(
          (result) {
            final status = result.status.name.toUpperCase();
            final reason = result.reason;

            if (forCommunity) {
              communityImageStatus.value = status;
              communityImageStatusReason.value = reason;
            } else {
              finalstatus.value = status;
              finalstatusReason.value = reason;
            }

            cacheService.setVerification(docId, result);

            debugPrint(
              '🔍 [VERIFICATION UPDATE] $docId: $status (community=$forCommunity)',
            );

            if (status == 'REJECTED') {
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              if (currentUid != null && currentUid.isNotEmpty) {
                userNotificationService.createNotification(
                  userId: currentUid,
                  type: 'verification_result',
                  severity: NotificationSeverity.priority,
                  title: forCommunity
                      ? 'Community Image Rejected'
                      : 'Thumbnail Verification Rejected',
                  message:
                      'Your ${forCommunity ? "community image" : "thumbnail"} was rejected: $reason. Please upload a new image to proceed.',
                  actionUrl: '/studio',
                  metadata: {
                    'docId': docId,
                    'reason': reason,
                    'itemType': forCommunity ? 'community_image' : 'thumbnail',
                  },
                );
              }
              AppSnackbar.error(
                reason.isNotEmpty ? 'Your image was rejected: $reason' : 'Your image was rejected by moderation.',
              );
            } else if (status == 'FLAGGED') {
              AppSnackbar.warning(
                reason.isNotEmpty ? 'Your image needs review: $reason' : 'Your image has been flagged for review.',
              );
            } else if (status == 'APPROVED') {
              AppSnackbar.success(
                'Your image was approved!',
              );
            }

            if (status == 'APPROVED' || status == 'REJECTED') {
              Future.delayed(const Duration(seconds: 2), () {
                if (forCommunity) {
                  communityImageModerationSubscription?.cancel();
                } else {
                  thumbnailModerationSubscription?.cancel();
                }
              });
            }
          },
          onError: (error, stackTrace) {
            ErrorHandler.log(
              error,
              stackTrace: stackTrace,
              tag: 'UploadController._startImageVerification',
            );
            if (forCommunity) {
              communityImageStatus.value = 'ERROR';
              communityImageStatusReason.value =
                  'Verification service is temporarily unavailable. Please try again.';
            } else {
              finalstatus.value = 'ERROR';
              finalstatusReason.value =
                  'Verification service is temporarily unavailable. Please try again.';
            }
            AppSnackbar.error(
              'Unable to verify image. Please try again.',
            );
            if (forCommunity) {
              communityImageModerationSubscription?.cancel();
            } else {
              thumbnailModerationSubscription?.cancel();
            }
          },
        );

    if (forCommunity) {
      communityImageModerationSubscription = subscription;
    } else {
      thumbnailModerationSubscription = subscription;
    }
  }

  List<String> generateKeywords(String title) {
    final cleanTitle = title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final words = cleanTitle
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final keywords = <String>{};
    for (final word in words) {
      keywords.add(word);
      for (var i = 1; i <= word.length; i++) {
        keywords.add(word.substring(0, i));
      }
    }
    return keywords.toList();
  }
}
