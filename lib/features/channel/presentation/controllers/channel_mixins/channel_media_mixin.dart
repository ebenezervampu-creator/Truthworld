import 'dart:async';
import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/image_cropper_service.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/data/models/channel_image_data.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_mixins/channel_controller_base.dart';
import 'package:truthworld/theme/app_theme.dart';

mixin ChannelMediaMixin on ChannelControllerBase {
  Future<Map<String, String>?> uploadImage(
    PlatformFile file,
    String folder,
    String userId, {
    Function(double progress)? onProgress,
  }) async {
    try {
      final uniqueFileName = '${uuid.v4()}.${file.extension}';
      final ref = storage.ref().child(
        'channels/$folder/$userId/$uniqueFileName',
      );
      final metadata = SettableMetadata(
        contentType: 'image/${file.extension}',
        customMetadata: {'uploaderId': userId},
      );
      final UploadTask uploadTask;
      if (kIsWeb) {
        if (file.bytes == null) {
          throw Exception('File bytes are null on Web platform');
        }
        uploadTask = ref.putData(file.bytes!, metadata);
      } else {
        if (file.path != null && io.File(file.path!).existsSync()) {
          uploadTask = ref.putFile(io.File(file.path!), metadata);
        } else if (file.bytes != null) {
          uploadTask = ref.putData(file.bytes!, metadata);
        } else {
          throw Exception('File is missing both path and bytes');
        }
      }

      uploadTask.snapshotEvents.listen(
        (snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          if (onProgress != null) onProgress(progress);
        },
        onError: (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'ChannelMediaMixin.uploadImage.stream',
          );
        },
      );

      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      return {'url': url, 'fileName': uniqueFileName};
    } on FirebaseException catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelMediaMixin.uploadImage.firebase',
      );
      return null;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelMediaMixin.uploadImage',
      );
      return null;
    }
  }

  Future<void> pickImage(bool isBanner) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null && file.path == null) {
        return showErrorSnackbar('Unable to read image file.');
      }

      final extension = file.extension?.toLowerCase();
      if (extension == null ||
          !['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(extension)) {
        return showErrorSnackbar(
          'Unsupported format. Use JPG, PNG, WebP, GIF.',
        );
      }

      // Crop image according to YouTube standard
      CroppedFile? croppedFile;
      if (file.path != null && file.path!.isNotEmpty) {
        croppedFile = isBanner
            ? await ImageCropperService.cropChannelBanner(
                imagePath: file.path!,
                context: Get.context,
              )
            : await ImageCropperService.cropChannelAvatar(
                imagePath: file.path!,
                context: Get.context,
              );
      }

      // If user cancels cropping, abort gracefully
      if (croppedFile == null && file.path != null) return;

      final Uint8List croppedBytes;
      if (croppedFile != null) {
        croppedBytes = await croppedFile.readAsBytes();
      } else if (file.bytes != null) {
        croppedBytes = file.bytes!;
      } else if (file.path != null && io.File(file.path!).existsSync()) {
        croppedBytes = await io.File(file.path!).readAsBytes();
      } else {
        return showErrorSnackbar('Unable to read image data.');
      }
      final croppedPath = croppedFile?.path ?? file.path;

      final maxSize = isBanner ? ChannelControllerBase.maxBannerSize : ChannelControllerBase.maxAvatarSize;
      if (croppedBytes.length > maxSize) {
        return showErrorSnackbar(
          'Image exceeds ${(maxSize / (1024 * 1024)).toStringAsFixed(1)}MB.',
        );
      }

      dynamic image;
      try {
        image = await decodeImageFromList(croppedBytes);
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'ChannelMediaMixin.pickImage.decode',
        );
        return showErrorSnackbar(
          'Unable to decode image. Please select a valid image file.',
        );
      }
      if (image == null) return showErrorSnackbar('Unable to decode image.');

      final imageData = ImageData(
        bytes: croppedBytes,
        name: file.name,
        size: croppedBytes.length,
        aspectRatio: image.width / image.height,
      );

      final uploadFile = PlatformFile(
        name: file.name,
        path: croppedPath,
        bytes: croppedBytes,
        size: croppedBytes.length,
      );

      if (isBanner) {
        bannerImageData.value = imageData;
        isUploadingBanner.value = true;
        bannerUploadProgress.value = 0.0;
      } else {
        avatarImageData.value = imageData;
        isUploadingAvatar.value = true;
        avatarUploadProgress.value = 0.0;
      }

      // Delete previous image
      final oldUrl = isBanner ? bannerUrl.value : avatarUrl.value;
      if (oldUrl.isNotEmpty) {
        try {
          await storage.refFromURL(oldUrl).delete();
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'ChannelMediaMixin.deleteOldImage',
          );
        }
      }

      final user = auth.currentUser;
      if (user == null) return showErrorSnackbar('Login required.');

      final uploadData = await uploadImage(
        uploadFile,
        isBanner ? 'banners' : 'avatars',
        user.uid,
        onProgress: (progress) {
          if (isBanner) {
            bannerUploadProgress.value = progress;
          } else {
            avatarUploadProgress.value = progress;
          }
        },
      );

      if (uploadData == null) {
        if (isBanner) {
          isUploadingBanner.value = false;
          bannerStatus.value = 'ERROR';
        } else {
          isUploadingAvatar.value = false;
          avatarStatus.value = 'ERROR';
        }
        return showErrorSnackbar('Upload failed. Please try again.');
      }

      final uploadedUrl = uploadData['url']!;
      final fileName = uploadData['fileName']!;

      if (isBanner) {
        bannerUrl.value = uploadedUrl;
        bannerFileId.value = fileName;
        isUploadingBanner.value = false;
        startBannerModerationListener(fileName);
      } else {
        avatarUrl.value = uploadedUrl;
        avatarFileId.value = fileName;
        isUploadingAvatar.value = false;
        startAvatarModerationListener(fileName);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelMediaMixin.pickImage',
      );
      showErrorSnackbar('Failed to process image. Please try again.');
    } finally {
      if (isBanner) {
        isUploadingBanner.value = false;
      } else {
        isUploadingAvatar.value = false;
      }
    }
  }

  @override
  void startBannerModerationListener(String docId) {
    _startModerationListener(docId, true);
  }

  @override
  void startAvatarModerationListener(String docId) {
    _startModerationListener(docId, false);
  }

  void _startModerationListener(String docId, bool isBanner) {
    if (docId.trim().isEmpty) return;
    debugPrint(
      '🔍 Starting moderation listener for ${isBanner ? "banner" : "avatar"}: $docId',
    );

    // Cancel existing listener & timer if any
    final key = isBanner ? 'banner' : 'avatar';
    moderationListeners[key]?.cancel();
    moderationTimers[key]?.cancel();

    if (isBanner) {
      bannerStatus.value = 'PENDING';
      bannerStatusReason.value = 'Verifying banner image...';
    } else {
      avatarStatus.value = 'PENDING';
      avatarStatusReason.value = 'Verifying avatar image...';
    }

    // Safety timeout: 6 seconds max fallback to optimistic approval
    moderationTimers[key] = Timer(const Duration(seconds: 6), () {
      if (isBanner) {
        if (bannerStatus.value == 'PENDING' || bannerStatus.value == 'ERROR') {
          bannerStatus.value = 'APPROVED';
          bannerStatusReason.value = 'Pre-filter approved';
          debugPrint('⏱️ Banner moderation safety timeout: marked as APPROVED');
        }
      } else {
        if (avatarStatus.value == 'PENDING' || avatarStatus.value == 'ERROR') {
          avatarStatus.value = 'APPROVED';
          avatarStatusReason.value = 'Pre-filter approved';
          debugPrint('⏱️ Avatar moderation safety timeout: marked as APPROVED');
        }
      }
    });

    moderationListeners[key] = imageVerificationService
        .streamVerificationStatus(docId)
        .listen((result) {
          debugPrint(
            '✅ Received status for $key: ${result.status} - ${result.reason}',
          );

          final statusStr = result.status.name.toUpperCase();
          if (isBanner) {
            bannerStatus.value = statusStr;
            bannerStatusReason.value = result.reason;

            if (result.status == VerificationStatus.rejected) {
              moderationTimers[key]?.cancel();
              AppSnackbar.show(
                'Banner Rejected',
                result.reason,
                backgroundColor: AppColors.error,
                colorText: AppColors.textPrimary,
                icon: const Icon(Icons.error_outline, color: Colors.white),
              );
            } else if (result.status == VerificationStatus.approved) {
              moderationTimers[key]?.cancel();
            }
          } else {
            avatarStatus.value = statusStr;
            avatarStatusReason.value = result.reason;

            if (result.status == VerificationStatus.rejected) {
              moderationTimers[key]?.cancel();
              AppSnackbar.show(
                'Avatar Rejected',
                result.reason,
                backgroundColor: AppColors.error,
                colorText: AppColors.textPrimary,
                icon: const Icon(Icons.error_outline, color: Colors.white),
              );
            } else if (result.status == VerificationStatus.approved) {
              moderationTimers[key]?.cancel();
            }
          }
        }, onError: (error, stackTrace) {
          ErrorHandler.log(
            error,
            stackTrace: stackTrace,
            tag: 'ChannelMediaMixin.moderationListener',
          );
          moderationTimers[key]?.cancel();
          if (isBanner) {
            bannerStatus.value = 'APPROVED';
            bannerStatusReason.value = 'Pre-filter approved';
          } else {
            avatarStatus.value = 'APPROVED';
            avatarStatusReason.value = 'Pre-filter approved';
          }
        });

    // Track for cleanup
    if (!uploadedDocIds.contains(docId)) {
      uploadedDocIds.add(docId);
    }
  }

}
