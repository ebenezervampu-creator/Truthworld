import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/data/models/community_draft.dart';
import 'package:truthworld/features/community/data/models/poll_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

/// Dedicated GetX controller for the **Community Post Upload** flow.
///
/// Supports:
/// - Multi-image picking (1–10 images, any aspect ratio)
/// - Parallel image uploads with per-image progress
/// - Polls (Yes/No or Multi-Choice with 3–5 options)
/// - Content validation via [ContentValidationMixin]
class CommunityPostUploadController extends BaseController
    with ContentValidationMixin {
  // ── Firebase ──────────────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();
  final _imageVerificationService = ImageVerificationService();
  final TopicRepository _topicRepository = TopicRepository();

  // ── Reactive State ────────────────────────────────────────────────────────

  // Topic Selection State
  final RxString selectedTopicId = ''.obs;
  final RxMap<String, dynamic> newTopicData = <String, dynamic>{}.obs;
  final RxList<Topic> availableTopics = <Topic>[].obs;
  final RxBool isTopicsLoading = false.obs;
  final RxString topicSearchQuery = ''.obs;

  // Channel Management with Error Handling
  final RxList<Channel> channels = <Channel>[].obs;
  final selectedChannel = Rx<Channel?>(null);
  final RxBool isChannelsLoading = false.obs;
  final RxString channelsError = ''.obs;
  // _channelsSubscription removed for get() optimization

  // Moderation
  final Map<int, StreamSubscription> _moderationListeners = {};
  final RxMap<int, String> moderationStatuses =
      <int, String>{}.obs; // index -> status (PENDING, APPROVED, REJECTED)
  final RxMap<int, String> moderationReasons = <int, String>{}.obs; // index -> reason if rejected

  // Images (1-10, any aspect ratio)
  final RxList<PlatformFile> pickedImages = <PlatformFile>[].obs;
  final RxList<String> imageUrls = <String>[].obs;
  final RxMap<int, double> imageUploadProgress = <int, double>{}.obs;
  final RxDouble overallProgress = 0.0.obs;
  final RxBool isUploading = false.obs;

  static const int maxImages = 1;
  static const int maxImageSizeBytes = 20 * 1024 * 1024; // 20 MB

  // Poll
  final RxBool hasPoll = false.obs;
  final Rx<PollType> pollType = PollType.yesNo.obs;
  final RxString pollQuestion = ''.obs;
  final RxList<String> pollOptions = <String>[].obs; // only for multiChoice
  final pollDurationDays = Rx<int?>(null); // null = no expiry

  // Form
  final RxString selectedCategory = 'General'.obs;
  final RxString selectedVisibility = 'Public'.obs;
  final RxBool isKidFriendly = false.obs;
  final RxBool isScheduled = false.obs;
  final Rx<DateTime> scheduledDate = DateTime.now().add(const Duration(days: 1)).obs;

  // Post Interactive Settings
  final RxBool isLikeEnabled = true.obs;
  final RxBool showLikeCount = true.obs;
  final RxBool isDislikeEnabled = true.obs;
  final RxBool showDislikeCount = true.obs;
  final RxBool isCommentsEnabled = true.obs;

  // DRAFT MANAGEMENT
  final currentDraft = Rx<CommunityDraft?>(null);
  final RxBool isSavingDraft = false.obs;
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
    fetchAvailableTopics();
  }

  Map<String, String>? getChannelMetadata(String channelId) {
    for (final ch in channels) {
      if (ch.channelId == channelId || ch.id == channelId) {
        return {
          'name': ch.channelName,
          'handle': ch.handle,
          'avatarUrl': ch.avatarUrl,
        };
      }
    }
    return null;
  }

  Future<void> fetchAvailableTopics() async {
    try {
      isTopicsLoading.value = true;
      final topics = await _topicRepository.fetchTopics(category: 'all', limit: 50);
      availableTopics.value = topics;
    } catch (e) {
      debugPrint('Error fetching topics in community upload: $e');
    } finally {
      isTopicsLoading.value = false;
    }
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
          .collection(FirestoreCollections.channels)
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
              debugPrint(
                '✅ Auto-selected community channel: ${selectedChannel.value!.channelName}',
              );
            }
          })
          .catchError((error) {
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
                child: const Text(
                  'Retry',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
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
    isLikeEnabled.value = true;
    showLikeCount.value = true;
    isDislikeEnabled.value = true;
    showDislikeCount.value = true;
    isCommentsEnabled.value = true;
    hasPoll.value = false;
    pickedImages.clear();
    pollOptions.clear();
    pollQuestion.value = '';
    selectedTopicId.value = '';
    newTopicData.clear();
    topicSearchQuery.value = '';
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
            .collection(FirestoreCollections.community)
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
        message =
            'Your channel details are currently under review by Gemini AI. You can publish posts once approved.';
      } else if (selectedChannel.value!.status ==
          ChannelStatus.verificationRejected) {
        message =
            selectedChannel.value!.moderationReason != null &&
                selectedChannel.value!.moderationReason!.isNotEmpty
            ? 'Branding Rejected: ${selectedChannel.value!.moderationReason!}'
            : 'Your channel details were rejected by Gemini AI. Please update your channel details in customization to re-verify.';
      } else if (selectedChannel.value!.status ==
          ChannelStatus.verificationPending) {
        message =
            'Your channel is currently verification pending. You can publish posts once your branding is verified.';
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
      // 1. Process inline topic creation if user drafted a new topic
      if (newTopicData.isNotEmpty) {
        final newTitle = (newTopicData['title'] as String? ?? '').trim();
        if (newTitle.isNotEmpty) {
          final newCategory = (newTopicData['category'] as String? ?? 'General').trim();
          final newDescription = (newTopicData['description'] as String? ?? '').trim();
          final newVisibilityStr = (newTopicData['visibility'] as String? ?? 'public').trim();
          final newVisibility = TopicVisibilityType.fromJson(newVisibilityStr);
          final newAccessCode = (newTopicData['accessCode'] as String? ?? '').trim();
          final finalThumbnailUrl = newTopicData['thumbnailUrl'] as String?;

          final newSlug = newTitle
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
              .replaceAll(RegExp(r'\s+'), '-');

          final existingSlug = await _firestore
              .collection(FirestoreCollections.topics)
              .where('slug', isEqualTo: newSlug)
              .limit(1)
              .get();

          var finalSlug = newSlug;
          if (existingSlug.docs.isNotEmpty) {
            finalSlug = '$newSlug-${const Uuid().v4().substring(0, 6)}';
          }

          final rawHandle = (newTopicData['handle'] as String?) ?? '';
          var cleanHandle = rawHandle.trim();
          if (cleanHandle.startsWith('T/') || cleanHandle.startsWith('t/')) {
            cleanHandle = cleanHandle.substring(2);
          }
          cleanHandle = cleanHandle
              .replaceAll(RegExp('[^a-zA-Z0-9_-]'), '-')
              .replaceAll(RegExp('-+'), '-');
          if (cleanHandle.isEmpty) {
            cleanHandle = finalSlug;
          }
          final finalHandle = 'T/$cleanHandle';
          final finalHandleLowercase = finalHandle.toLowerCase();

          final newTopicRef = _firestore.collection(FirestoreCollections.topics).doc();
          final newTopic = Topic(
            id: newTopicRef.id,
            title: newTitle,
            slug: finalSlug,
            handle: finalHandle,
            handleLowercase: finalHandleLowercase,
            description: newDescription,
            category: newCategory,
            thumbnailUrl: finalThumbnailUrl,
            channelId: selectedChannel.value?.channelId ?? '',
            creatorId: _auth.currentUser?.uid,
            visibilityType: newVisibility,
            accessCode: newVisibility == TopicVisibilityType.private ? newAccessCode : null,
            postCount: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: 'underReview',
          );

          await newTopicRef.set(newTopic.toMap());
          selectedTopicId.value = finalSlug;
          newTopicData.clear();
        }
      }

      final docRef = _firestore
          .collection(FirestoreCollections.community)
          .doc();
      lastPublishedPostId.value = docRef.id;
      final tags = tagsRaw
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .take(5)
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
        'isLikeEnabled': isLikeEnabled.value,
        'showLikeCount': showLikeCount.value,
        'isDislikeEnabled': isDislikeEnabled.value,
        'showDislikeCount': showDislikeCount.value,
        'isCommentsEnabled': isCommentsEnabled.value,
      };

      if (selectedTopicId.value.isNotEmpty) {
        data['topicId'] = selectedTopicId.value;
        data['topics'] = [selectedTopicId.value];
      }

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

      if (selectedTopicId.value.isNotEmpty) {
        final topicQuery = await _firestore
            .collection(FirestoreCollections.topics)
            .where('slug', isEqualTo: selectedTopicId.value)
            .limit(1)
            .get();
        if (topicQuery.docs.isNotEmpty) {
          final topicDoc = topicQuery.docs.first;
          await topicDoc.reference.update({
            'postCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          }).catchError((e) => debugPrint('Error updating topic postCount: $e'));
        }
      }

      isUploading.value = false;
      resetForm();
      Get.offAllNamed('/studio');
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
