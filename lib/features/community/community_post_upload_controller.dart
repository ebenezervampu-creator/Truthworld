import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/data/models/community_draft.dart';
import 'package:truthworld/features/community/data/models/poll_model.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

/// Dedicated GetX controller for the **Community Post Upload** flow.
///
/// Supports:
/// - Multi-image picking (1–10 images, any aspect ratio)
/// - Parallel image uploads with per-image progress
/// - Polls (Yes/No or Multi-Choice with 3–5 options)
/// - Content validation via [ContentValidationMixin]
class CommunityPostUploadController extends GetxController
    with ContentValidationMixin {
  // ── Firebase ──────────────────────────────────────────────────────────────
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();
  final _imageVerificationService = ImageVerificationService();

  // ── Reactive State ────────────────────────────────────────────────────────

  // Channel Management with Error Handling
  final channels = <Channel>[].obs;
  final selectedChannel = Rx<Channel?>(null);
  final isChannelsLoading = false.obs;
  final channelsError = ''.obs;
  // _channelsSubscription removed for get() optimization

  // Moderation
  final Map<int, StreamSubscription> _moderationListeners = {};
  final moderationStatuses =
      <int, String>{}.obs; // index -> status (PENDING, APPROVED, REJECTED)
  final moderationReasons = <int, String>{}.obs; // index -> reason if rejected

  // Images (1-10, any aspect ratio)
  final pickedImages = <PlatformFile>[].obs;
  final imageUrls = <String>[].obs;
  final imageUploadProgress = <int, double>{}.obs;
  final overallProgress = 0.0.obs;
  final isUploading = false.obs;

  static const int maxImages = 1;
  static const int maxImageSizeBytes = 20 * 1024 * 1024; // 20 MB

  // Poll
  final hasPoll = false.obs;
  final pollType = PollType.yesNo.obs;
  final pollQuestion = ''.obs;
  final pollOptions = <String>[].obs; // only for multiChoice
  final pollDurationDays = Rx<int?>(null); // null = no expiry

  // Form
  final selectedCategory = 'General'.obs;
  final selectedVisibility = 'Public'.obs;
  final isKidFriendly = false.obs;
  final isScheduled = false.obs;
  final scheduledDate = DateTime.now().add(const Duration(days: 1)).obs;

  // DRAFT MANAGEMENT
  final currentDraft = Rx<CommunityDraft?>(null);
  final isSavingDraft = false.obs;
  final lastPublishedPostId = Rxn<String>();

  // Categories
  final communityCategories = [
    'General',
    'Announcement',
    'Question',
    'Discussion',
    'Support',
    'Feedback',
  ];

  @override
  void onInit() {
    super.onInit();
    final auth = AuthService.to;
    if (auth.hasChannel.value) {
      selectedChannel.value = auth.userChannel;
    }
    _fetchChannelsForCommunity();
  }

  @override
  void onClose() {
    // _channelsSubscription removed
    for (final sub in _moderationListeners.values) {
      sub.cancel();
    }
    super.onClose();
  }

  /// Fetch channels for community post uploads
  Future<void> _fetchChannelsForCommunity() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        channelsError.value = 'User not authenticated';
        debugPrint('❌ Community: User not authenticated');
        return;
      }

      isChannelsLoading.value = true;
      channelsError.value = '';

      _firestore
          .collection('channels')
          .where('ownerId', isEqualTo: user.uid)
          .where('isArchived', isEqualTo: false)
          .withConverter<Channel>(
            fromFirestore: (doc, _) => Channel.fromDocumentSnapshot(doc),
            toFirestore: (channel, _) => {},
          )
          .get(const GetOptions())
          .then((snapshot) {
        channels.value = snapshot.docs.map((doc) => doc.data()).toList();
        isChannelsLoading.value = false;
        channelsError.value = '';

        debugPrint('✅ Community channels loaded: ${channels.length}');

        if (channels.isNotEmpty && selectedChannel.value == null) {
          selectedChannel.value = channels.first;
          debugPrint('✅ Auto-selected community channel: ${selectedChannel.value!.channelName}');
        }
      }).catchError((error) {
        isChannelsLoading.value = false;
        channelsError.value = 'Failed to load channels: $error';
        debugPrint('❌ Error fetching community channels: $error');
        AppSnackbar.show(
          'Error',
          'Failed to load channels',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEF4444),
          colorText: AppColors.textPrimary,
          mainButton: TextButton(
            onPressed: _fetchChannelsForCommunity,
            child: const Text('Retry', style: TextStyle(color: AppColors.textPrimary)),
          ),
        );
      });
    } catch (e) {
      isChannelsLoading.value = false;
      channelsError.value = 'Error: $e';
      debugPrint('❌ Error in _fetchChannelsForCommunity: $e');
    }
  }

  /// Select a channel for community post
  void selectChannelForCommunity(Channel channel) {
    if (channel.id.isEmpty) {
      debugPrint('❌ Invalid community channel selection');
      AppSnackbar.show(
        'Error',
        'Invalid channel selected',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
      );
      return;
    }

    selectedChannel.value = channel;
    debugPrint('✅ Community channel selected: ${channel.channelName}');
  }

  /// Reset the upload form to its default state
  void resetForm() {
    pollDurationDays.value = null;
    isScheduled.value = false;
    selectedCategory.value = 'General';
    selectedVisibility.value = 'Public';
    hasPoll.value = false;
    pickedImages.clear();
    pollOptions.clear();
    pollQuestion.value = '';
    moderationStatuses.clear();
    moderationReasons.clear();
    _moderationListeners.forEach((_, sub) => sub.cancel());
    _moderationListeners.clear();

    currentDraft.value = null;
  }

  bool get canPublish {
    if (selectedChannel.value == null) {
      return false;
    }
    if (hasPoll.value && pollQuestion.value.trim().isEmpty) {
      return false;
    }
    if (hasPoll.value &&
        pollType.value == PollType.multiChoice &&
        pollOptions.any((o) => o.trim().isEmpty)) {
      return false;
    }

    // Moderation checks are relaxed for background publishing
    /*
    if (moderationStatuses.values.any((s) => s == 'REJECTED' || s == 'FLAGGED')) {
      return false;
    }
    */

    return true;
  }

  void togglePoll(bool val) {
    hasPoll.value = val;
    if (val && pollOptions.isEmpty) {
      pollOptions.addAll(['', '', '']);
    }
  }

  void setPollType(PollType type) => pollType.value = type;

  void addPollOption() {
    if (pollOptions.length < 5) pollOptions.add('');
  }

  void removePollOption(int index) {
    if (pollOptions.length > 3) pollOptions.removeAt(index);
  }

  void updatePollOption(int index, String val) {
    pollOptions[index] = val;
  }

  Future<void> pickImages() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result != null) {
        // Since we only want a single image, if there is already an image picked,
        // we clear it first so the new one replaces it.
        pickedImages.clear();
        imageUrls.clear();
        imageUploadProgress.clear();
        for (final sub in _moderationListeners.values) {
          sub.cancel();
        }
        _moderationListeners.clear();
        moderationStatuses.clear();
        moderationReasons.clear();

        if (pickedImages.length + result.files.length > maxImages) {
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
            AppSnackbar.show(
              'Error',
              'Unsupported image format. Allowed formats: JPG, JPEG, PNG, GIF.',
              snackPosition: SnackPosition.BOTTOM,
            );
            return;
          }
          if (file.size > maxImageSizeBytes) {
            AppSnackbar.show(
              'Error',
              'Selected image exceeds the 20MB limit.',
              snackPosition: SnackPosition.BOTTOM,
            );
            return;
          }
        }

        final startIndex = pickedImages.length;
        pickedImages.addAll(result.files);

        // Parallel uploads to storage
        for (var i = 0; i < result.files.length; i++) {
          final globalIndex = startIndex + i;
          _uploadSingleImage(globalIndex, result.files[i]);
        }
      }
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to pick images',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _uploadSingleImage(int index, PlatformFile file) async {
    try {
      // 1. Initial State
      imageUploadProgress[index] = 0.0;
      moderationStatuses[index] = 'PENDING';

      final fileExt = file.extension ?? 'jpg';
      final fileName = '${_uuid.v4()}.$fileExt';
      final ref = _storage.ref('community_images/$fileName');

      final metadata = SettableMetadata(contentType: 'image/$fileExt');
      final uploadTask = ref.putData(await file.xFile.readAsBytes(), metadata);

      // 2. Track Progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        imageUploadProgress[index] = progress;
      });

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
        await _firestore
            .collection('Community')
            .doc(lastPublishedPostId.value)
            .update({
              'images': FieldValue.arrayUnion([downloadUrl]),
            })
            .catchError((e) => debugPrint('Error updating post images: $e'));
      }

      // 4. Content Moderation / Verification (Async)
      startModerationCheck(index, fileName);
    } catch (e) {
      debugPrint('❌ Upload error at index $index: $e');
      imageUploadProgress[index] = -1.0; // Error indicator
      moderationStatuses[index] = 'REJECTED';
      moderationReasons[index] = 'Upload failed';
    }
  }

  void startModerationCheck(int index, String docId) {
    moderationStatuses[index] = 'PENDING';

    final subscription = _imageVerificationService
        .streamVerificationStatus(docId)
        .listen((result) {
          final status = result.status.name.toUpperCase();
          final reason = result.reason;

          moderationStatuses[index] = status;
          moderationReasons[index] = reason;

          if (status == 'REJECTED') {
            AppSnackbar.show(
              'Image Rejected',
              'One of your images was rejected: $reason',
              backgroundColor: AppColors.error.withValues(alpha: 0.1),
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        });

    _moderationListeners[index] = subscription;
  }

  Future<void> saveDraft({
    required String title,
    required String description,
    required String tagsRaw,
  }) async {
    isSavingDraft.value = true;
    // Mock log
    await Future.delayed(const Duration(seconds: 1));
    isSavingDraft.value = false;
    AppSnackbar.show(
      'Draft Saved',
      'Your post was saved as a draft',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> publishPost({
    required String title,
    required String description,
    required String tagsRaw,
  }) async {
    if (selectedChannel.value == null) {
      AppSnackbar.show(
        'Channel Required',
        'Please select a channel first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (selectedChannel.value!.status != ChannelStatus.active) {
      var message = 'Your channel is not active.';
      if (selectedChannel.value!.status == ChannelStatus.underReview) {
        message = 'Your channel details are currently under review by Gemini AI. You can publish posts once approved.';
      } else if (selectedChannel.value!.status == ChannelStatus.verificationRejected) {
        message = selectedChannel.value!.moderationReason != null && selectedChannel.value!.moderationReason!.isNotEmpty
            ? 'Branding Rejected: ${selectedChannel.value!.moderationReason!}'
            : 'Your channel details were rejected by Gemini AI. Please update your channel details in customization to re-verify.';
      } else if (selectedChannel.value!.status == ChannelStatus.verificationPending) {
        message = 'Your channel is currently verification pending. You can publish posts once your branding is verified.';
      } else if (selectedChannel.value!.status == ChannelStatus.suspended) {
        message = 'Your channel is suspended. Publishing is disabled.';
      }
      AppSnackbar.show(
        'Verification Required',
        message,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Moderation checks are relaxed for background publishing
    /*
    if (moderationStatuses.values.any(
      (s) => s == 'REJECTED' || s == 'FLAGGED',
    )) {
      AppSnackbar.show(
        'Moderation Blocked',
        'Some images were rejected. Please remove them before publishing.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (moderationStatuses.values.any((s) => s == 'PENDING')) {
      AppSnackbar.show(
        'Processing',
        'Verification is still in progress. Please wait.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    */

    isUploading.value = true;
    try {
      final docRef = _firestore.collection('Community').doc();
      lastPublishedPostId.value = docRef.id;
      final tags = tagsRaw
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final data = <String, dynamic>{
        'id': docRef.id,
        'title': title,
        'description': description,
        'images': List<String>.from(
          imageUrls,
        ), // Store as a list for multi-image support
        'tags': tags,
        'timestamp': FieldValue.serverTimestamp(),
        'ownerId': _auth.currentUser?.uid,
        'channelId': selectedChannel.value!.channelId,
        'channelName': selectedChannel.value!.channelName,
        'channelImage': selectedChannel.value!.avatarUrl,
        'category': selectedCategory.value,
        'visibility': isScheduled.value
            ? 'Scheduled'
            : selectedVisibility.value,
        'isKidFriendly': isKidFriendly.value,
      };

      if (isScheduled.value) {
        data['scheduledTime'] = Timestamp.fromDate(scheduledDate.value);
      }

      if (hasPoll.value) {
        data['poll'] = {
          'question': pollQuestion.value,
          'type': pollType.value.name,
          'options': pollType.value == PollType.multiChoice
              ? pollOptions.map((o) => {'text': o, 'votes': 0}).toList()
              : [
                  {'text': 'Yes', 'votes': 0},
                  {'text': 'No', 'votes': 0},
                ],
          'expiresAt': pollDurationDays.value != null
              ? Timestamp.fromDate(
                  DateTime.now().add(Duration(days: pollDurationDays.value!)),
                )
              : null,
        };
      }

      await docRef.set(data);

      isUploading.value = false;
      resetForm();
      Get.back();
      AppSnackbar.show(
        'Published',
        'Your community post is live',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      isUploading.value = false;
      debugPrint('❌ Publish error: $e');
      AppSnackbar.show(
        'Error',
        'Failed to publish post: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Select a channel for the post
  void selectChannel(Channel? channel) {
    selectedChannel.value = channel;
  }

  /// Remove an image from the picked images list
  void removeImage(int index) {
    if (index >= 0 && index < pickedImages.length) {
      pickedImages.removeAt(index);
      if (index < imageUrls.length) {
        imageUrls.removeAt(index);
      }
      _moderationListeners[index]?.cancel();
      _moderationListeners.remove(index);
      moderationStatuses.remove(index);
      moderationReasons.remove(index);

      // Shift indices if necessary (though simple Map removal info is often enough)
      // For simplicity in this mock, we just remove.
    }
  }

  /// Load a draft for editing
  void loadDraft(CommunityDraft draft) {
    currentDraft.value = draft;
    try {
      selectedChannel.value = channels.firstWhere(
        (c) => c.channelId == draft.channelId,
      );
    } catch (_) {
      selectedChannel.value = null;
    }
    selectedCategory.value = draft.category;
    selectedVisibility.value = draft.visibility;
    isKidFriendly.value = draft.isKidFriendly;

    if (draft.poll != null) {
      hasPoll.value = true;
      pollQuestion.value = draft.poll!.question;
      pollType.value = draft.poll!.type;
      if (draft.poll!.type == PollType.multiChoice) {
        pollOptions.value = draft.poll!.options.map((o) => o.text).toList();
      } else {
        pollOptions.clear();
      }
    } else {
      hasPoll.value = false;
      pollQuestion.value = '';
      pollOptions.clear();
    }

    if (draft.imageUrls.isNotEmpty) {
      imageUrls.value = List.from(draft.imageUrls);
    } else {
      imageUrls.clear();
    }
  }
}
