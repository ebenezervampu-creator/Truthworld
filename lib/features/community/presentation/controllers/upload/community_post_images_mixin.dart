import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/community/presentation/controllers/upload/community_post_upload_state_base.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';

/// Mixin handling image picking, Firebase Storage upload, moderation streaming, and image removal.
mixin CommunityPostImagesMixin on CommunityPostUploadStateBase {
  Future<void> pickImages() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result != null) {
        // Since we only want a single image, if there is already an image picked,
        // we clear it first so the new one replaces it.
        pickedImages.clear();
        imageUrls.clear();
        imageUploadProgress.clear();
        for (final sub in moderationListeners.values) {
          sub.cancel();
        }
        moderationListeners.clear();
        moderationStatuses.clear();
        moderationReasons.clear();

        if (pickedImages.length + result.files.length >
            CommunityPostUploadStateBase.maxImages) {
          AppSnackbar.show(
            'Limit Reached',
            'You can only upload 1 image.',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }

        // Validate format and size of each file
        for (final file in result.files) {
          final extension = file.extension?.toLowerCase();
          const allowedExtensions = {'jpg', 'jpeg', 'png', 'gif'};
          if (extension == null || !allowedExtensions.contains(extension)) {
            AppSnackbar.warning(
              'Unsupported image format. Allowed formats: JPG, JPEG, PNG, GIF.',
            );
            return;
          }
          if (file.size > CommunityPostUploadStateBase.maxImageSizeBytes) {
            AppSnackbar.warning(
              'Selected image exceeds the 20MB limit.',
            );
            return;
          }
        }

        final startIndex = pickedImages.length;
        pickedImages.addAll(result.files);

        // Parallel uploads to storage
        for (var i = 0; i < result.files.length; i++) {
          final globalIndex = startIndex + i;
          uploadSingleImage(globalIndex, result.files[i]);
        }
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to select images. Please try again.',
      );
    }
  }

  Future<void> uploadSingleImage(int index, PlatformFile file) async {
    try {
      // 1. Initial State
      imageUploadProgress[index] = 0.0;
      moderationStatuses[index] = 'PENDING';

      final fileExt = file.extension ?? 'jpg';
      final fileName = '${uuid.v4()}.$fileExt';
      final ref = storage.ref('community_images/$fileName');

      final currentUid = auth.currentUser?.uid;
      final chId = selectedChannel.value?.id ?? '';
      final isTrustedChannel =
          selectedChannel.value?.trustedModerationBypass == true;
      final metadata = SettableMetadata(
        contentType: 'image/$fileExt',
        customMetadata: {
          'uploaderId': currentUid ?? '',
          'channelId': chId,
        },
      );
      final uploadTask = ref.putData(await file.xFile.readAsBytes(), metadata);

      // 2. Track Progress
      uploadTask.snapshotEvents.listen(
        (snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          imageUploadProgress[index] = progress;
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'CommunityPostUploadController.uploadTask',
        ),
      );

      // 3. Complete Upload
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Ensure we don't exceed list size if user removed image during upload
      if (index < imageUrls.length) {
        imageUrls[index] = downloadUrl;
      } else {
        imageUrls.add(downloadUrl);
      }

      if (lastPublishedPostId.value != null) {
        await firestore
            .collection(FirestoreCollections.community)
            .doc(lastPublishedPostId.value)
            .update({
              'images': FieldValue.arrayUnion([downloadUrl]),
              'image': downloadUrl,
            })
            .catchError((e, stackTrace) {
              ErrorHandler.log(
                e,
                stackTrace: stackTrace,
                tag: 'CommunityPostUploadController.updatePostImages',
              );
            });
      }

      // 4. Content Moderation / Verification (Async)
      if (isTrustedChannel) {
        moderationStatuses[index] = 'APPROVED';
        moderationReasons[index] = 'Trusted channel exemption';
        return;
      }

      startModerationCheck(index, fileName);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommunityPostUploadController.uploadImage',
      );
      imageUploadProgress[index] = -1.0; // Error indicator
      moderationStatuses[index] = 'REJECTED';
      moderationReasons[index] = 'Upload failed';
    }
  }

  void startModerationCheck(int index, String docId) {
    moderationListeners[index]?.cancel();
    moderationStatuses[index] = 'PENDING';

    final sub = imageVerificationService
        .streamVerificationStatus(docId)
        .listen((result) {
          final status = result.status.name.toUpperCase();
          final reason = result.reason;

          moderationStatuses[index] = status;
          moderationReasons[index] = reason;

          if (status == 'REJECTED') {
            final uid = auth.currentUser?.uid;
            if (uid != null && uid.isNotEmpty) {
              userNotificationService.createNotification(
                userId: uid,
                type: 'verification_result',
                severity: NotificationSeverity.priority,
                title: 'Community Image Rejected',
                message:
                    'Your community post image was rejected: $reason. Please upload a new image to proceed.',
                actionUrl: '/community',
                metadata: {
                  'docId': docId,
                  'reason': reason,
                  'itemType': 'community_image',
                },
              );
            }
            AppSnackbar.warning(
              'One of your images was rejected: $reason',
              title: 'Image Rejected',
            );
          }
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'CommunityPostUploadController.moderationCheck',
        ),
      );
    trackSubscription(sub);
    moderationListeners[index] = sub;
  }

  /// Remove an image from the picked images list
  void removeImage(int index) {
    if (index >= 0 && index < pickedImages.length) {
      pickedImages.removeAt(index);
      if (index < imageUrls.length) {
        imageUrls.removeAt(index);
      }
      moderationListeners[index]?.cancel();
      moderationListeners.remove(index);
      moderationStatuses.remove(index);
      moderationReasons.remove(index);
    }
  }
}
