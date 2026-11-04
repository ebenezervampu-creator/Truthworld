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
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/image_cropper_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';

class CustomLinkItem {
  final TextEditingController titleController;
  final TextEditingController urlController;

  CustomLinkItem({String title = '', String url = ''})
      : titleController = TextEditingController(text: title),
        urlController = TextEditingController(text: url);

  void dispose() {
    titleController.dispose();
    urlController.dispose();
  }
}

class CustomizationController extends BaseController
    with ContentValidationMixin, GetSingleTickerProviderStateMixin {
  CustomizationController({
    required String channelId,
    required String ownerId,
    this.initialTabIndex = 0,
  })  : _channelId = channelId,
        _ownerId = ownerId;

  final String _channelId;
  final String _ownerId;

  String get channelId {
    if (_channelId.isNotEmpty) return _channelId;
    if (Get.isRegistered<DashboardController>()) {
      final id = Get.find<DashboardController>().channelId;
      if (id.isNotEmpty) return id;
    }
    if (Get.isRegistered<AuthService>()) {
      final ch = AuthService.to.userChannel ?? AuthService.to.rxUserChannel.value;
      if (ch != null && ch.id.isNotEmpty) return ch.id;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  String get ownerId {
    if (_ownerId.isNotEmpty) return _ownerId;
    if (Get.isRegistered<AuthService>()) {
      final uid = AuthService.to.uid;
      if (uid.isNotEmpty) return uid;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  final int initialTabIndex;

  late final TabController tabController = TabController(
    length: 4,
    vsync: this,
    initialIndex: initialTabIndex.clamp(0, 3),
  );
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void onClose() {
    _channelSubscription?.cancel();
    tabController.dispose();
    for (final item in customLinks) {
      item.dispose();
    }
    for (final ctrl in extraSocialControllers.values) {
      ctrl.dispose();
    }
    super.onClose();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _channelSubscription;

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
  late final TextEditingController youtubeController = trackTextController(TextEditingController());
  late final TextEditingController twitterController = trackTextController(TextEditingController());
  late final TextEditingController instagramController = trackTextController(TextEditingController());
  late final TextEditingController facebookController = trackTextController(TextEditingController());
  late final TextEditingController linkedinController = trackTextController(TextEditingController());
  late final TextEditingController tiktokController = trackTextController(TextEditingController());
  late final TextEditingController whatsappController = trackTextController(TextEditingController());
  late final TextEditingController telegramController = trackTextController(TextEditingController());
  late final TextEditingController discordController = trackTextController(TextEditingController());
  late final TextEditingController githubController = trackTextController(TextEditingController());
  late final TextEditingController twitchController = trackTextController(TextEditingController());
  late final TextEditingController redditController = trackTextController(TextEditingController());
  late final TextEditingController patreonController = trackTextController(TextEditingController());
  late final TextEditingController threadsController = trackTextController(TextEditingController());
  final Map<String, TextEditingController> extraSocialControllers = {};

  // Custom links
  final RxList<CustomLinkItem> customLinks = <CustomLinkItem>[].obs;

  void addCustomLink() {
    if (customLinks.length >= 10) {
      AppSnackbar.warning('You can add up to 10 custom links.');
      return;
    }
    customLinks.add(CustomLinkItem());
  }

  void removeCustomLink(int index) {
    if (index >= 0 && index < customLinks.length) {
      final removed = customLinks.removeAt(index);
      removed.dispose();
    }
  }

  // Settings (Reactive)
  final RxString visibility = 'Public'.obs;
  final RxBool isPublic = true.obs;
  final RxBool allowComments = true.obs;
  final RxBool allowSubscriptions = true.obs;
  final RxBool showSubscriberCount = true.obs;
  final RxBool showLikeCount = true.obs;
  final RxBool showDislikeCount = true.obs;

  void setVisibility(String val) {
    visibility.value = val;
    isPublic.value = val.toLowerCase() == 'public';
  }

  // Images (Reactive)
  final RxString avatarUrl = ''.obs;
  final RxString bannerUrl = ''.obs;
  final Rx<Uint8List?> newAvatarBytes = Rx<Uint8List?>(null);
  final Rx<Uint8List?> newBannerBytes = Rx<Uint8List?>(null);
  final Rx<String?> newAvatarName = Rx<String?>(null);
  final Rx<String?> newBannerName = Rx<String?>(null);
  final RxBool hasRemovedAvatar = false.obs;
  final RxBool hasRemovedBanner = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadChannelData();
    _startRealtimeChannelListener();
  }

  void _startRealtimeChannelListener() {
    _channelSubscription?.cancel();
    _channelSubscription = _firestore
        .collection(FirestoreCollections.channels)
        .doc(channelId)
        .snapshots()
        .listen(
      (doc) {
        if (!doc.exists || doc.data() == null) return;
        final data = doc.data()!;
        final newAvatarStatus = (data['avatarStatus'] as String?) ?? 'APPROVED';
        final newBannerStatus = (data['bannerStatus'] as String?) ?? 'APPROVED';
        final newAvatarReason = (data['avatarStatusReason'] as String?) ?? '';
        final newBannerReason = (data['bannerStatusReason'] as String?) ?? '';
        final newAvatarFileId = (data['avatarFileId'] as String?) ?? '';
        final newBannerFileId = (data['bannerFileId'] as String?) ?? '';

        if (avatarStatus.value != newAvatarStatus) {
          avatarStatus.value = newAvatarStatus;
        }
        if (bannerStatus.value != newBannerStatus) {
          bannerStatus.value = newBannerStatus;
        }
        if (avatarStatusReason.value != newAvatarReason) {
          avatarStatusReason.value = newAvatarReason;
        }
        if (bannerStatusReason.value != newBannerReason) {
          bannerStatusReason.value = newBannerReason;
        }
        if (avatarFileId.value != newAvatarFileId) {
          avatarFileId.value = newAvatarFileId;
        }
        if (bannerFileId.value != newBannerFileId) {
          bannerFileId.value = newBannerFileId;
        }

        if (newAvatarBytes.value == null && !hasRemovedAvatar.value) {
          final serverAvatar = (data['avatarUrl'] as String?) ??
              (data['photoUrl'] as String?) ??
              '';
          if (serverAvatar.isNotEmpty && avatarUrl.value != serverAvatar) {
            avatarUrl.value = serverAvatar;
          }
        }
        if (newBannerBytes.value == null && !hasRemovedBanner.value) {
          final serverBanner = (data['bannerImageUrl'] as String?) ??
              (data['bannerUrl'] as String?) ??
              (data['banner'] as String?) ??
              '';
          if (serverBanner.isNotEmpty && bannerUrl.value != serverBanner) {
            bannerUrl.value = serverBanner;
          }
        }
      },
      onError: (err) {
        ErrorHandler.log(err, tag: 'CustomizationController.realtimeListener');
      },
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

        // Auto-reconcile PENDING image verifications if already approved in image_verification collection
        if (avatarStatus.value == 'PENDING' && avatarFileId.value.isNotEmpty) {
          unawaited(_reconcileImageVerification(
            fileId: avatarFileId.value,
            isBanner: false,
          ));
        }
        if (bannerStatus.value == 'PENDING' && bannerFileId.value.isNotEmpty) {
          unawaited(_reconcileImageVerification(
            fileId: bannerFileId.value,
            isBanner: true,
          ));
        }
        final rawVis = (data['visibility'] as String?)?.trim();
        if (rawVis != null && rawVis.isNotEmpty) {
          if (rawVis.toLowerCase() == 'public') {
            visibility.value = 'Public';
            isPublic.value = true;
          } else if (rawVis.toLowerCase() == 'unlisted') {
            visibility.value = 'Unlisted';
            isPublic.value = false;
          } else if (rawVis.toLowerCase() == 'private') {
            visibility.value = 'Private';
            isPublic.value = false;
          } else {
            visibility.value = rawVis;
            isPublic.value = false;
          }
        } else {
          final pub = (data['isPublic'] as bool?) ?? true;
          isPublic.value = pub;
          visibility.value = pub ? 'Public' : 'Private';
        }
        allowComments.value = (data['allowComments'] as bool?) ?? true;
        allowSubscriptions.value =
            (data['allowSubscriptions'] as bool?) ?? true;
        showSubscriberCount.value =
            (data['showSubscriberCount'] as bool?) ?? true;
        showLikeCount.value = (data['showLikeCount'] as bool?) ?? true;
        showDislikeCount.value = (data['showDislikeCount'] as bool?) ?? true;

        final tags = data['tags'] as List<dynamic>?;
        tagsController.text = tags?.join(', ') ?? '';

        final socialLinks = data['socialLinks'] as Map<String, dynamic>?;
        if (socialLinks != null) {
          youtubeController.text = (socialLinks['youtube'] as String?) ?? '';
          twitterController.text =
              (socialLinks['twitter'] as String?) ?? (socialLinks['x'] as String?) ?? '';
          instagramController.text =
              (socialLinks['instagram'] as String?) ?? '';
          facebookController.text = (socialLinks['facebook'] as String?) ?? '';
          linkedinController.text = (socialLinks['linkedin'] as String?) ?? '';
          tiktokController.text = (socialLinks['tiktok'] as String?) ?? '';
          whatsappController.text = (socialLinks['whatsapp'] as String?) ?? '';
          telegramController.text = (socialLinks['telegram'] as String?) ?? '';
          discordController.text = (socialLinks['discord'] as String?) ?? '';
          githubController.text = (socialLinks['github'] as String?) ?? '';
          twitchController.text = (socialLinks['twitch'] as String?) ?? '';
          redditController.text = (socialLinks['reddit'] as String?) ?? '';
          patreonController.text = (socialLinks['patreon'] as String?) ?? '';
          threadsController.text = (socialLinks['threads'] as String?) ?? '';

          final standardKeys = {
            'youtube', 'twitter', 'x', 'instagram', 'facebook',
            'linkedin', 'tiktok', 'whatsapp', 'telegram',
            'discord', 'github', 'twitch', 'reddit', 'patreon', 'threads',
            'website', 'customLinks',
          };
          for (final entry in socialLinks.entries) {
            if (!standardKeys.contains(entry.key) && entry.value is String) {
              if (extraSocialControllers.containsKey(entry.key)) {
                extraSocialControllers[entry.key]!.text = entry.value as String;
              } else {
                extraSocialControllers[entry.key] =
                    trackTextController(TextEditingController(text: entry.value as String));
              }
            }
          }
        }

        // Load custom links
        for (final item in customLinks) {
          item.dispose();
        }
        customLinks.clear();
        final rawCustomLinks = data['customLinks'] ?? (socialLinks != null ? socialLinks['customLinks'] : null);
        if (rawCustomLinks is Iterable) {
          for (final item in rawCustomLinks) {
            if (item is Map) {
              final title = (item['title'] ?? '').toString();
              final url = (item['url'] ?? '').toString();
              if (title.isNotEmpty || url.isNotEmpty) {
                customLinks.add(CustomLinkItem(title: title, url: url));
              }
            }
          }
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

  Future<void> _reconcileImageVerification({
    required String fileId,
    required bool isBanner,
  }) async {
    try {
      final doc = await _firestore.collection('image_verification').doc(fileId).get();
      if (doc.exists) {
        final data = doc.data();
        final ivStatus = (data?['status'] as String?)?.toUpperCase();
        final ivReason = (data?['reason'] as String?) ?? '';
        if (ivStatus == 'APPROVED') {
          if (isBanner) {
            bannerStatus.value = 'APPROVED';
            bannerStatusReason.value = ivReason;
          } else {
            avatarStatus.value = 'APPROVED';
            avatarStatusReason.value = ivReason;
          }
          await _firestore.collection(FirestoreCollections.channels).doc(channelId).update({
            isBanner ? 'bannerStatus' : 'avatarStatus': 'APPROVED',
            isBanner ? 'bannerStatusReason' : 'avatarStatusReason': ivReason,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
        } else if (ivStatus == 'REJECTED' || ivStatus == 'FLAGGED') {
          final targetStatus = ivStatus!;
          if (isBanner) {
            bannerStatus.value = targetStatus;
            bannerStatusReason.value = ivReason;
          } else {
            avatarStatus.value = targetStatus;
            avatarStatusReason.value = ivReason;
          }
          await _firestore.collection(FirestoreCollections.channels).doc(channelId).update({
            isBanner ? 'bannerStatus' : 'avatarStatus': targetStatus,
            isBanner ? 'bannerStatusReason' : 'avatarStatusReason': ivReason,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    } catch (e) {
      ErrorHandler.log(e, tag: 'CustomizationController._reconcileImageVerification');
    }
  }

  Future<void> bypassVerification(bool isBanner) async {
    try {
      final fileId = isBanner
          ? (bannerFileId.value.isNotEmpty ? bannerFileId.value : (newBannerName.value ?? ''))
          : (avatarFileId.value.isNotEmpty ? avatarFileId.value : (newAvatarName.value ?? ''));
      final statusField = isBanner ? 'bannerStatus' : 'avatarStatus';
      final reasonField = isBanner
          ? 'bannerStatusReason'
          : 'avatarStatusReason';

      // 1. Immediately update reactive controller state so the UI reflects instantly
      if (isBanner) {
        bannerStatus.value = 'APPROVED';
        bannerStatusReason.value = 'Bypassed in local/debug environment.';
      } else {
        avatarStatus.value = 'APPROVED';
        avatarStatusReason.value = 'Bypassed in local/debug environment.';
      }

      // 2. Persist to Firestore channel doc
      final channelUpdates = <String, dynamic>{
        statusField: 'APPROVED',
        reasonField: 'Bypassed in local/debug environment.',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      if (fileId.isNotEmpty) {
        channelUpdates[isBanner ? 'bannerFileId' : 'avatarFileId'] = fileId;
      }
      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update(channelUpdates);

      // 3. Persist to image_verification doc
      if (fileId.isNotEmpty) {
        await _firestore.collection('image_verification').doc(fileId).set({
          'status': 'APPROVED',
          'reason': 'Bypassed in local/debug environment.',
          'category': isBanner ? 'banner' : 'avatar',
          'processedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 4. If avatar, also update users collection
      if (!isBanner && ownerId.isNotEmpty) {
        await _firestore.collection('users').doc(ownerId).set({
          'avatarStatus': 'APPROVED',
          'avatarStatusReason': 'Bypassed in local/debug environment.',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 5. Update cached AuthService state
      if (Get.isRegistered<AuthService>()) {
        final auth = AuthService.to;
        if (auth.userChannel != null) {
          auth.setUserChannel(
            auth.userChannel!.copyWith(
              avatarStatus: !isBanner ? 'APPROVED' : auth.userChannel!.avatarStatus,
              bannerStatus: isBanner ? 'APPROVED' : auth.userChannel!.bannerStatus,
            ),
            auth.user?.uid,
          );
        }
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
          hasRemovedAvatar.value = false;
          newAvatarBytes.value = imageBytes;
          newAvatarName.value =
              'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        } else {
          hasRemovedBanner.value = false;
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

  void removeAvatar() {
    hasRemovedAvatar.value = true;
    newAvatarBytes.value = null;
    newAvatarName.value = null;
    avatarUrl.value = '';
    avatarFileId.value = '';
    avatarStatus.value = '';
    avatarStatusReason.value = '';
  }

  void removeBanner() {
    hasRemovedBanner.value = true;
    newBannerBytes.value = null;
    newBannerName.value = null;
    bannerUrl.value = '';
    bannerFileId.value = '';
    bannerStatus.value = '';
    bannerStatusReason.value = '';
  }

  Future<String?> _uploadImage(Uint8List bytes, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaderId': ?currentUid,
          'userId': ?currentUid,
          'channelId': channelId,
          'ownerId': ownerId,
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

    final allSocialEntries = <String, String>{
      'YouTube': youtubeController.text.trim(),
      'Twitter': twitterController.text.trim(),
      'Instagram': instagramController.text.trim(),
      'Facebook': facebookController.text.trim(),
      'LinkedIn': linkedinController.text.trim(),
      'TikTok': tiktokController.text.trim(),
      'WhatsApp': whatsappController.text.trim(),
      'Telegram': telegramController.text.trim(),
      'Discord': discordController.text.trim(),
      'GitHub': githubController.text.trim(),
      'Twitch': twitchController.text.trim(),
      'Reddit': redditController.text.trim(),
      'Patreon': patreonController.text.trim(),
      'Threads': threadsController.text.trim(),
    };
    for (final entry in extraSocialControllers.entries) {
      allSocialEntries[entry.key] = entry.value.text.trim();
    }

    for (final entry in allSocialEntries.entries) {
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

    // Validate custom links
    for (var i = 0; i < customLinks.length; i++) {
      final item = customLinks[i];
      final title = item.titleController.text.trim();
      final url = item.urlController.text.trim();
      if (title.isNotEmpty || url.isNotEmpty) {
        if (title.isEmpty) {
          AppSnackbar.warning('Please enter a title for custom link #${i + 1}.');
          return;
        }
        if (url.isEmpty) {
          AppSnackbar.warning('Please enter a URL for custom link #${i + 1}.');
          return;
        }
        final titleVal = await validateContent(title, fieldName: 'Custom Link Title');
        if (!titleVal.isValid) {
          AppSnackbar.warning(titleVal.message);
          return;
        }
        final urlVal = await validateContent(url, fieldName: 'Custom Link URL');
        if (!urlVal.isValid) {
          AppSnackbar.warning(urlVal.message);
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

      final socialLinks = <String, dynamic>{
        if (youtubeController.text.trim().isNotEmpty)
          'youtube': youtubeController.text.trim(),
        if (twitterController.text.trim().isNotEmpty)
          'twitter': twitterController.text.trim(),
        if (instagramController.text.trim().isNotEmpty)
          'instagram': instagramController.text.trim(),
        if (facebookController.text.trim().isNotEmpty)
          'facebook': facebookController.text.trim(),
        if (linkedinController.text.trim().isNotEmpty)
          'linkedin': linkedinController.text.trim(),
        if (tiktokController.text.trim().isNotEmpty)
          'tiktok': tiktokController.text.trim(),
        if (whatsappController.text.trim().isNotEmpty)
          'whatsapp': whatsappController.text.trim(),
        if (telegramController.text.trim().isNotEmpty)
          'telegram': telegramController.text.trim(),
        if (discordController.text.trim().isNotEmpty)
          'discord': discordController.text.trim(),
        if (githubController.text.trim().isNotEmpty)
          'github': githubController.text.trim(),
        if (twitchController.text.trim().isNotEmpty)
          'twitch': twitchController.text.trim(),
        if (redditController.text.trim().isNotEmpty)
          'reddit': redditController.text.trim(),
        if (patreonController.text.trim().isNotEmpty)
          'patreon': patreonController.text.trim(),
        if (threadsController.text.trim().isNotEmpty)
          'threads': threadsController.text.trim(),
        if (websiteUrlController.text.trim().isNotEmpty)
          'website': websiteUrlController.text.trim(),
      };
      for (final entry in extraSocialControllers.entries) {
        final val = entry.value.text.trim();
        if (val.isNotEmpty) {
          socialLinks[entry.key] = val;
        }
      }

      final savedCustomLinks = customLinks
          .where((item) => item.urlController.text.trim().isNotEmpty)
          .map((item) => {
                'title': item.titleController.text.trim().isNotEmpty
                    ? item.titleController.text.trim()
                    : 'Link',
                'url': item.urlController.text.trim(),
              })
          .toList();

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
        'visibility': visibility.value,
        'isPublic': visibility.value.toLowerCase() == 'public',
        'allowComments': allowComments.value,
        'allowSubscriptions': allowSubscriptions.value,
        'showSubscriberCount': showSubscriberCount.value,
        'showLikeCount': showLikeCount.value,
        'showDislikeCount': showDislikeCount.value,
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
        'customLinks': savedCustomLinks.isNotEmpty ? savedCustomLinks : null,
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'underReview',
        'geminiApproved': FieldValue.delete(),
        'moderationReason': FieldValue.delete(),
        'brandingApprovedDismissed': false,
        'approvalBannerDismissed': false,
      };

      if (hasRemovedAvatar.value) {
        updateData['avatarFileId'] = FieldValue.delete();
        updateData['avatarStatus'] = 'APPROVED';
        updateData['avatarStatusReason'] = FieldValue.delete();
      } else if (uploadedAvatarFileName != null) {
        updateData['avatarFileId'] = uploadedAvatarFileName;
        try {
          final ivDoc = await _firestore.collection('image_verification').doc(uploadedAvatarFileName).get();
          if (ivDoc.exists && ivDoc.data()?['status'] == 'APPROVED') {
            updateData['avatarStatus'] = 'APPROVED';
            updateData['avatarStatusReason'] = (ivDoc.data()?['reason'] as String?) ?? 'Vision AI verified';
            avatarStatus.value = 'APPROVED';
          } else {
            updateData['avatarStatus'] = 'PENDING';
            updateData['avatarStatusReason'] = FieldValue.delete();
            avatarStatus.value = 'PENDING';
          }
        } catch (_) {
          updateData['avatarStatus'] = 'PENDING';
          updateData['avatarStatusReason'] = FieldValue.delete();
          avatarStatus.value = 'PENDING';
        }
      }

      if (hasRemovedBanner.value) {
        updateData['bannerFileId'] = FieldValue.delete();
        updateData['bannerStatus'] = 'APPROVED';
        updateData['bannerStatusReason'] = FieldValue.delete();
      } else if (uploadedBannerFileName != null) {
        updateData['bannerFileId'] = uploadedBannerFileName;
        try {
          final ivDoc = await _firestore.collection('image_verification').doc(uploadedBannerFileName).get();
          if (ivDoc.exists && ivDoc.data()?['status'] == 'APPROVED') {
            updateData['bannerStatus'] = 'APPROVED';
            updateData['bannerStatusReason'] = (ivDoc.data()?['reason'] as String?) ?? 'Vision AI verified';
            bannerStatus.value = 'APPROVED';
          } else {
            updateData['bannerStatus'] = 'PENDING';
            updateData['bannerStatusReason'] = FieldValue.delete();
            bannerStatus.value = 'PENDING';
          }
        } catch (_) {
          updateData['bannerStatus'] = 'PENDING';
          updateData['bannerStatusReason'] = FieldValue.delete();
          bannerStatus.value = 'PENDING';
        }
      }

      GetStorage().remove('approval_shown_$channelId');

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update(updateData);

      hasRemovedAvatar.value = false;
      hasRemovedBanner.value = false;

      if (updatedAvatarUrl != null) {
        avatarUrl.value = updatedAvatarUrl;
        if (Get.isRegistered<AuthService>()) {
          final auth = AuthService.to;
          if (auth.userChannel != null) {
            auth.setUserChannel(
              auth.userChannel!.copyWith(
                avatarUrl: updatedAvatarUrl,
                avatarFileId: uploadedAvatarFileName,
              ),
              auth.user?.uid,
            );
          }
        }
      }
      if (updatedBannerUrl != null) {
        bannerUrl.value = updatedBannerUrl;
        if (Get.isRegistered<AuthService>()) {
          final auth = AuthService.to;
          if (auth.userChannel != null) {
            auth.setUserChannel(
              auth.userChannel!.copyWith(
                bannerUrl: updatedBannerUrl,
                bannerFileId: uploadedBannerFileName,
              ),
              auth.user?.uid,
            );
          }
        }
      }
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
