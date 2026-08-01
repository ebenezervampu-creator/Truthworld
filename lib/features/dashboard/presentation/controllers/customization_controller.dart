import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';
import 'package:truthworld/theme/app_colors.dart';

class CustomizationController extends GetxController {
  CustomizationController({required this.channelId, required this.ownerId});
  final String channelId;
  final String ownerId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final RxString status = 'active'.obs;
  final RxString moderationReason = ''.obs;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _channelSub;

  // Image Verification Statuses (Reactive)
  final RxString avatarStatus = 'APPROVED'.obs;
  final RxString bannerStatus = 'APPROVED'.obs;
  final RxString avatarStatusReason = ''.obs;
  final RxString bannerStatusReason = ''.obs;
  final RxString avatarFileId = ''.obs;
  final RxString bannerFileId = ''.obs;

  // Loading States
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  // Controllers
  final channelNameController = TextEditingController();
  final descriptionController = TextEditingController();
  final customUrlController = TextEditingController();
  final contactEmailController = TextEditingController();
  final websiteUrlController = TextEditingController();
  final categoryController = TextEditingController();
  final languageController = TextEditingController();
  final tagsController = TextEditingController();

  // Social links
  final twitterController = TextEditingController();
  final instagramController = TextEditingController();
  final facebookController = TextEditingController();

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
    _channelSub = _firestore
        .collection(FirestoreCollections.channels)
        .doc(channelId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data()!;
            status.value = (data['status'] as String?) ?? 'active';
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
        });
  }

  @override
  void onClose() {
    _channelSub?.cancel();
    channelNameController.dispose();
    descriptionController.dispose();
    customUrlController.dispose();
    contactEmailController.dispose();
    websiteUrlController.dispose();
    categoryController.dispose();
    languageController.dispose();
    tagsController.dispose();
    twitterController.dispose();
    instagramController.dispose();
    facebookController.dispose();
    super.onClose();
  }

  Future<void> loadChannelData() async {
    isLoading.value = true;
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
      Get.snackbar(
        'Error',
        'Failed to load channel data: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    } finally {
      isLoading.value = false;
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

      Get.snackbar(
        'Verification Bypassed',
        "Successfully approved the ${isBanner ? 'banner' : 'avatar'} for local testing.",
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      Get.snackbar(
        'Bypass Failed',
        e.toString(),
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<void> pickImage(bool isAvatar) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final pickedImage = await pickedFile.readAsBytes();
        if (isAvatar) {
          newAvatarBytes.value = pickedImage;
          newAvatarName.value =
              'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        } else {
          newBannerBytes.value = pickedImage;
          newBannerName.value =
              'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<String?> _uploadImage(Uint8List bytes, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploaded': DateTime.now().toString()},
      );
      await ref.putData(bytes, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> saveChanges() async {
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

      final tags = tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

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

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update(updateData);

      if (updatedAvatarUrl != null) avatarUrl.value = updatedAvatarUrl;
      if (updatedBannerUrl != null) bannerUrl.value = updatedBannerUrl;
      newAvatarBytes.value = null;
      newBannerBytes.value = null;

      Get.snackbar(
        'Success',
        'Channel updated successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );

      // Redirect to the Dashboard tab (tab index 1)
      try {
        final dashboardController = Get.find<DashboardController>();
        dashboardController.selectedIndex.value = 1;
      } catch (_) {}
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save changes: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    } finally {
      isSaving.value = false;
    }
  }
}
