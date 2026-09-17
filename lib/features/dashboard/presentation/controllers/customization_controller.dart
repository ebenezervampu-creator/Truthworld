import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/image_cropper_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';

class CustomizationController extends BaseController with ContentValidationMixin {
  CustomizationController({required this.channelId, required this.ownerId});
  final String channelId;
  final String ownerId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final RxString status = 'active'.obs;
  final RxBool geminiApproved = false.obs;
  final RxString moderationReason = ''.obs;


  // Image Verification Statuses (Reactive)
  final RxString avatarStatus = 'APPROVED'.obs;
  final RxString bannerStatus = 'APPROVED'.obs;
  final RxString avatarStatusReason = ''.obs;
  final RxString bannerStatusReason = ''.obs;
  final RxString avatarFileId = ''.obs;
  final RxString bannerFileId = ''.obs;

  // Loading States
  final RxBool rxIsLoading = false.obs;
  final RxBool isSaving = false.obs;

  // Controllers
  late final TextEditingController channelNameController = trackTextController(TextEditingController());
  late final TextEditingController descriptionController = trackTextController(TextEditingController());
  late final TextEditingController customUrlController = trackTextController(TextEditingController());
  late final TextEditingController contactEmailController = trackTextController(TextEditingController());
  late final TextEditingController websiteUrlController = trackTextController(TextEditingController());
  late final TextEditingController categoryController = trackTextController(TextEditingController());
  late final TextEditingController languageController = trackTextController(TextEditingController());
  late final TextEditingController tagsController = trackTextController(TextEditingController());

  // Social links
  late final TextEditingController twitterController = trackTextController(TextEditingController());
  late final TextEditingController instagramController = trackTextController(TextEditingController());
  late final TextEditingController facebookController = trackTextController(TextEditingController());

  // Settings (Reactive)
  final RxBool isPublic = true.obs;
  final RxBool allowComments = true.obs;
  final RxBool allowSubscriptions = true.obs;
  final RxBool showSubscriberCount = true.obs;

  // Images (Reactive)
  final RxString avatarUrl = ''.obs;
  final RxString bannerUrl = ''.obs;
  final Rx<Uint8List?> newAvatarBytes = Rx<Uint8List?>(null);
  final Rx<Uint8List?> newBannerBytes = Rx<Uint8List?>(null);
  final Rx<String?> newAvatarName = Rx<String?>(null);
  final Rx<String?> newBannerName = Rx<String?>(null);

  @override
  void onInit() {
    super.onInit();
    loadChannelData();
  }

  void _listenToChannelChanges() {
    trackSubscription(_firestore
        .collection(FirestoreCollections.channels)
        .doc(channelId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data()!;
            geminiApproved.value = (data['geminiApproved'] as bool?) ?? false;
            status.value = (data['status'] as String?) ?? 'active';
            if (geminiApproved.value) {
              status.value = 'active';
            }
            moderationReason.value =
                (data['moderationReason'] as String?) ?? '';
            avatarStatus.value =
                (data['avatarStatus'] as String?) ?? 'APPROVED';
            bannerStatus.value =
                (data['bannerStatus'] as String?) ?? 'APPROVED';
            avatarStatusReason.value =
                (data['avatarStatusReason'] as String?) ?? '';
            bannerStatusReason.value =
                (data['bannerStatusReason'] as String?) ?? '';
            avatarFileId.value = (data['avatarFileId'] as String?) ?? '';
            bannerFileId.value = (data['bannerFileId'] as String?) ?? '';

            final bUrl =
                (data['bannerImageUrl'] as String?) ??
                (data['bannerUrl'] as String?) ??
                (data['banner'] as String?) ??
                (data['bannerPicUrl'] as String?) ??
                '';
            if (bUrl.isNotEmpty) bannerUrl.value = bUrl;

            final aUrl =
                (data['avatarUrl'] as String?) ??
                (data['photoUrl'] as String?) ??
                '';
            if (aUrl.isNotEmpty) avatarUrl.value = aUrl;
          }
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'CustomizationController._listenToChannelChanges',
        ),
      ),
    );
  }

  Future<void> loadChannelData() async {
    rxIsLoading.value = true;
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        channelNameController.text =
            (data['channelName'] as String?) ?? (data['name'] as String?) ?? '';
        descriptionController.text = (data['description'] as String?) ?? '';
        customUrlController.text =
            (data['customUrl'] as String?) ?? (data['handle'] as String?) ?? '';
        contactEmailController.text = (data['contactEmail'] as String?) ?? '';
        websiteUrlController.text = (data['websiteUrl'] as String?) ?? '';
        categoryController.text = (data['category'] as String?) ?? '';
        languageController.text = (data['language'] as String?) ?? 'en';

        avatarUrl.value =
            (data['avatarUrl'] as String?) ??
            (data['photoUrl'] as String?) ??
            '';
        bannerUrl.value =
            (data['bannerImageUrl'] as String?) ??
            (data['bannerUrl'] as String?) ??
            (data['banner'] as String?) ??
            (data['bannerPicUrl'] as String?) ??
            '';

        avatarStatus.value = (data['avatarStatus'] as String?) ?? 'APPROVED';
        bannerStatus.value = (data['bannerStatus'] as String?) ?? 'APPROVED';
        avatarStatusReason.value =
            (data['avatarStatusReason'] as String?) ?? '';
        bannerStatusReason.value =
            (data['bannerStatusReason'] as String?) ?? '';
        avatarFileId.value = (data['avatarFileId'] as String?) ?? '';
        bannerFileId.value = (data['bannerFileId'] as String?) ?? '';
        isPublic.value = (data['isPublic'] as bool?) ?? true;
        allowComments.value = (data['allowComments'] as bool?) ?? true;
        allowSubscriptions.value =
            (data['allowSubscriptions'] as bool?) ?? true;
        showSubscriberCount.value =
            (data['showSubscriberCount'] as bool?) ?? true;

        final tags = data['tags'] as List<dynamic>?;
        tagsController.text = tags?.join(', ') ?? '';

        final socialLinks = data['socialLinks'] as Map<String, dynamic>?;
        if (socialLinks != null) {
          twitterController.text = (socialLinks['twitter'] as String?) ?? '';
          instagramController.text =
              (socialLinks['instagram'] as String?) ?? '';
          facebookController.text = (socialLinks['facebook'] as String?) ?? '';
        }
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to load channel details. Please try again.',
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  Future<void> bypassVerification(bool isBanner) async {
    try {
      final fileId = isBanner ? bannerFileId.value : avatarFileId.value;
      final statusField = isBanner ? 'bannerStatus' : 'avatarStatus';
      final reasonField = isBanner
          ? 'bannerStatusReason'
          : 'avatarStatusReason';

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update({
            statusField: 'APPROVED',
            reasonField: 'Bypassed in local/debug environment.',
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

      if (fileId.isNotEmpty) {
        await _firestore.collection('image_verification').doc(fileId).set({
          'status': 'APPROVED',
          'reason': 'Bypassed in local/debug environment.',
          'category': isBanner ? 'banner' : 'avatar',
          'processedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      AppSnackbar.success(
        "Successfully approved the ${isBanner ? 'banner' : 'avatar'} for local testing.",
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to complete verification update. Please try again.',
      );
    }
  }

  Future<void> requestManualReview({
    required bool isBanner,
    String? appealReason,
  }) async {
    try {
      final fileId = isBanner ? bannerFileId.value : avatarFileId.value;
      final statusField = isBanner ? 'bannerStatus' : 'avatarStatus';
      final reasonField = isBanner
          ? 'bannerStatusReason'
          : 'avatarStatusReason';

      final userReason = appealReason ?? 'Creator requested manual review.';

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update({
            statusField: 'MANUAL_REVIEW',
            reasonField: userReason,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

      if (fileId.isNotEmpty) {
        await _firestore.collection('image_verification').doc(fileId).set({
          'status': 'MANUAL_REVIEW',
          'appealReason': userReason,
          'category': isBanner ? 'banner' : 'avatar',
          'appealedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (isBanner) {
        bannerStatus.value = 'MANUAL_REVIEW';
        bannerStatusReason.value = userReason;
      } else {
        avatarStatus.value = 'MANUAL_REVIEW';
        avatarStatusReason.value = userReason;
      }

      AppSnackbar.success(
        'Your image has been queued for manual review.',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to submit request for manual review. Please try again.',
      );
    }
  }

  Future<void> pickImage(bool isAvatar) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final croppedFile = isAvatar
            ? await ImageCropperService.cropChannelAvatar(
                imagePath: pickedFile.path,
                context: Get.context,
              )
            : await ImageCropperService.cropChannelBanner(
                imagePath: pickedFile.path,
                context: Get.context,
              );

        if (croppedFile == null) return; // User cancelled cropping

        final imageBytes = await croppedFile.readAsBytes();
        if (isAvatar) {
          newAvatarBytes.value = imageBytes;
          newAvatarName.value =
              'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        } else {
          newBannerBytes.value = imageBytes;
          newBannerName.value =
              'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to select image. Please try again.',
      );
    }
  }

  Future<String?> _uploadImage(Uint8List bytes, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaderId': ?currentUid,
          'uploaded': DateTime.now().toString(),
        },
      );
      await ref.putData(bytes, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> saveChanges() async {
    final name = channelNameController.text.trim();
    if (name.isEmpty) {
      AppSnackbar.warning('Please enter a channel name before saving.');
      return;
    }

    final nameVal = await validateContent(name, fieldName: 'Channel Name');
    if (!nameVal.isValid) {
      AppSnackbar.warning(nameVal.message);
      return;
    }

    if (customUrlController.text.trim().isNotEmpty) {
      final handleVal = await validateContent(
        customUrlController.text.trim(),
        fieldName: 'Channel Handle',
      );
      if (!handleVal.isValid) {
        AppSnackbar.warning(handleVal.message);
        return;
      }
    }

    if (descriptionController.text.trim().isNotEmpty) {
      final descVal = await validateContent(
        descriptionController.text.trim(),
        fieldName: 'Channel Description',
      );
      if (!descVal.isValid) {
        AppSnackbar.warning(descVal.message);
        return;
      }
    }

    final tags = tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(5)
        .toList();

    if (tags.isNotEmpty) {
      final tagsVal = await validateTags(tags);
      if (!tagsVal.isValid) {
        AppSnackbar.warning(tagsVal.message);
        return;
      }
    }

    if (contactEmailController.text.trim().isNotEmpty) {
      final emailVal = await validateContent(
        contactEmailController.text.trim(),
        fieldName: 'Contact Email',
      );
      if (!emailVal.isValid) {
        AppSnackbar.warning(emailVal.message);
        return;
      }
    }

    if (websiteUrlController.text.trim().isNotEmpty) {
      final webVal = await validateContent(
        websiteUrlController.text.trim(),
        fieldName: 'Website URL',
      );
      if (!webVal.isValid) {
        AppSnackbar.warning(webVal.message);
        return;
      }
    }

    for (final entry in {
      'Twitter': twitterController.text.trim(),
      'Instagram': instagramController.text.trim(),
      'Facebook': facebookController.text.trim(),
    }.entries) {
      if (entry.value.isNotEmpty) {
        final linkVal = await validateContent(
          entry.value,
          fieldName: '${entry.key} Link',
        );
        if (!linkVal.isValid) {
          AppSnackbar.warning(linkVal.message);
          return;
        }
      }
    }

    isSaving.value = true;
    try {
      String? updatedAvatarUrl = avatarUrl.value;
      String? updatedBannerUrl = bannerUrl.value;

      String? uploadedAvatarFileName;
      if (newAvatarBytes.value != null) {
        uploadedAvatarFileName =
            newAvatarName.value ??
            'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        updatedAvatarUrl = await _uploadImage(
          newAvatarBytes.value!,
          'channels/avatars/$ownerId/$uploadedAvatarFileName',
        );
      }

      String? uploadedBannerFileName;
      if (newBannerBytes.value != null) {
        uploadedBannerFileName =
            newBannerName.value ??
            'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
        updatedBannerUrl = await _uploadImage(
          newBannerBytes.value!,
          'channels/banners/$ownerId/$uploadedBannerFileName',
        );
      }

      final socialLinks = {
        if (twitterController.text.isNotEmpty)
          'twitter': twitterController.text,
        if (instagramController.text.isNotEmpty)
          'instagram': instagramController.text,
        if (facebookController.text.isNotEmpty)
          'facebook': facebookController.text,
        if (websiteUrlController.text.isNotEmpty)
          'website': websiteUrlController.text,
      };

      final updateData = <String, dynamic>{
        'name': channelNameController.text,
        'nameLowercase': channelNameController.text.toLowerCase(),
        'channelName': channelNameController.text,
        'channelNameLowercase': channelNameController.text.toLowerCase(),
        'description': descriptionController.text,
        'customUrl': customUrlController.text.isNotEmpty
            ? customUrlController.text
            : null,
        'customUrlLowercase': customUrlController.text.isNotEmpty
            ? customUrlController.text.toLowerCase()
            : null,
        'handle': customUrlController.text.isNotEmpty
            ? customUrlController.text
            : null,
        'handleLowercase': customUrlController.text.isNotEmpty
            ? customUrlController.text.toLowerCase()
            : null,
        'avatarUrl': updatedAvatarUrl,
        'photoUrl': updatedAvatarUrl,
        'bannerUrl': updatedBannerUrl,
        'bannerImageUrl': updatedBannerUrl,
        'banner': updatedBannerUrl,
        'bannerPicUrl': updatedBannerUrl,
        'isPublic': isPublic.value,
        'allowComments': allowComments.value,
        'allowSubscriptions': allowSubscriptions.value,
        'showSubscriberCount': showSubscriberCount.value,
        'contactEmail': contactEmailController.text.isNotEmpty
            ? contactEmailController.text
            : null,
        'websiteUrl': websiteUrlController.text.isNotEmpty
            ? websiteUrlController.text
            : null,
        'category': categoryController.text.isNotEmpty
            ? categoryController.text
            : null,
        'language': languageController.text,
        'tags': tags,
        'socialLinks': socialLinks.isNotEmpty ? socialLinks : null,
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'underReview',
        'geminiApproved': FieldValue.delete(),
        'moderationReason': FieldValue.delete(),
        'brandingApprovedDismissed': false,
        'approvalBannerDismissed': false,
      };

      if (uploadedAvatarFileName != null) {
        updateData['avatarFileId'] = uploadedAvatarFileName;
        updateData['avatarStatus'] = 'PENDING';
        updateData['avatarStatusReason'] = FieldValue.delete();
      }

      if (uploadedBannerFileName != null) {
        updateData['bannerFileId'] = uploadedBannerFileName;
        updateData['bannerStatus'] = 'PENDING';
        updateData['bannerStatusReason'] = FieldValue.delete();
      }

      GetStorage().remove('approval_shown_$channelId');

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update(updateData);

      if (updatedAvatarUrl != null) avatarUrl.value = updatedAvatarUrl;
      if (updatedBannerUrl != null) bannerUrl.value = updatedBannerUrl;
      newAvatarBytes.value = null;
      newBannerBytes.value = null;

      AppSnackbar.success(
        'Channel updated successfully!',
      );

      // Redirect to the Dashboard tab (tab index 1)
      try {
        final dashboardController = Get.find<DashboardController>();
        dashboardController.selectedIndex.value = 1;
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'CustomizationController.redirectToDashboard',
        );
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to save changes. Please try again.',
      );
    } finally {
      isSaving.value = false;
    }
  }
}
