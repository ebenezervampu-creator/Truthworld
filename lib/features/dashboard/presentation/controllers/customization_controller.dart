import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';

class CustomizationController extends GetxController {
  final String channelId;
  final String ownerId;

  CustomizationController({required this.channelId, required this.ownerId});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final RxString status = 'active'.obs;
  final RxString moderationReason = ''.obs;
  StreamSubscription<DocumentSnapshot>? _channelSub;

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
    _listenToChannelChanges();
  }

  void _listenToChannelChanges() {
    _channelSub = _firestore.collection('channels').doc(channelId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        status.value = data['status'] ?? 'active';
        moderationReason.value = data['moderationReason'] ?? '';
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
      final doc = await _firestore.collection('channels').doc(channelId).get();

      if (doc.exists) {
        final data = doc.data()!;
        channelNameController.text = data['channelName'] ?? '';
        descriptionController.text = data['description'] ?? '';
        customUrlController.text = data['customUrl'] ?? '';
        contactEmailController.text = data['contactEmail'] ?? '';
        websiteUrlController.text = data['websiteUrl'] ?? '';
        categoryController.text = data['category'] ?? '';
        languageController.text = data['language'] ?? 'en';
        avatarUrl.value = data['avatarUrl'] ?? '';
        bannerUrl.value = data['bannerImageUrl'] ?? '';
        isPublic.value = data['isPublic'] ?? true;
        allowComments.value = data['allowComments'] ?? true;
        allowSubscriptions.value = data['allowSubscriptions'] ?? true;
        showSubscriberCount.value = data['showSubscriberCount'] ?? true;

        final tags = data['tags'] as List<dynamic>?;
        tagsController.text = tags?.join(', ') ?? '';

        final socialLinks = data['socialLinks'] as Map<String, dynamic>?;
        if (socialLinks != null) {
          twitterController.text = socialLinks['twitter'] ?? '';
          instagramController.text = socialLinks['instagram'] ?? '';
          facebookController.text = socialLinks['facebook'] ?? '';
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load channel data: $e', 
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickImage(bool isAvatar) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final Uint8List pickedImage = await pickedFile.readAsBytes();
        if (isAvatar) {
          newAvatarBytes.value = pickedImage;
          newAvatarName.value = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        } else {
          newBannerBytes.value = pickedImage;
          newBannerName.value = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white);
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

      if (newAvatarBytes.value != null) {
        final fileName = newAvatarName.value ?? 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        updatedAvatarUrl = await _uploadImage(
          newAvatarBytes.value!,
          'channels/avatars/$ownerId/$fileName',
        );
      }

      if (newBannerBytes.value != null) {
        final fileName = newBannerName.value ?? 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
        updatedBannerUrl = await _uploadImage(
          newBannerBytes.value!,
          'channels/banners/$ownerId/$fileName',
        );
      }

      final tags = tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final socialLinks = {
        if (twitterController.text.isNotEmpty) 'twitter': twitterController.text,
        if (instagramController.text.isNotEmpty) 'instagram': instagramController.text,
        if (facebookController.text.isNotEmpty) 'facebook': facebookController.text,
        if (websiteUrlController.text.isNotEmpty) 'website': websiteUrlController.text,
      };

      await _firestore.collection('channels').doc(channelId).update({
        'name': channelNameController.text,
        'nameLowercase': channelNameController.text.toLowerCase(),
        'channelName': channelNameController.text,
        'channelNameLowercase': channelNameController.text.toLowerCase(),
        'description': descriptionController.text,
        'customUrl': customUrlController.text.isNotEmpty ? customUrlController.text : null,
        'customUrlLowercase': customUrlController.text.isNotEmpty ? customUrlController.text.toLowerCase() : null,
        'handle': customUrlController.text.isNotEmpty ? customUrlController.text : null,
        'handleLowercase': customUrlController.text.isNotEmpty ? customUrlController.text.toLowerCase() : null,
        'avatarUrl': updatedAvatarUrl,
        'bannerUrl': updatedBannerUrl,
        'bannerImageUrl': updatedBannerUrl,
        'isPublic': isPublic.value,
        'allowComments': allowComments.value,
        'allowSubscriptions': allowSubscriptions.value,
        'showSubscriberCount': showSubscriberCount.value,
        'contactEmail': contactEmailController.text.isNotEmpty ? contactEmailController.text : null,
        'websiteUrl': websiteUrlController.text.isNotEmpty ? websiteUrlController.text : null,
        'category': categoryController.text.isNotEmpty ? categoryController.text : null,
        'language': languageController.text,
        'tags': tags,
        'socialLinks': socialLinks.isNotEmpty ? socialLinks : null,
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'underReview',
        'geminiApproved': FieldValue.delete(),
        'moderationReason': FieldValue.delete(),
      });

      if (updatedAvatarUrl != null) avatarUrl.value = updatedAvatarUrl;
      if (updatedBannerUrl != null) bannerUrl.value = updatedBannerUrl;
      newAvatarBytes.value = null;
      newBannerBytes.value = null;

      Get.snackbar('Success', 'Channel updated successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white);

      // Redirect to the Dashboard tab (tab index 1)
      try {
        final dashboardController = Get.find<DashboardController>();
        dashboardController.selectedIndex.value = 1;
      } catch (_) {}
    } catch (e) {
      Get.snackbar('Error', 'Failed to save changes: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white);
    } finally {
      isSaving.value = false;
    }
  }
}





