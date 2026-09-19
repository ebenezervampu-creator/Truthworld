import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/data/models/community_draft.dart';
import 'package:truthworld/features/community/data/models/poll_model.dart';
import 'package:truthworld/features/notifications/data/services/user_notification_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:uuid/uuid.dart';

/// Base state class holding all reactive observables, form controllers,
/// and dependencies for community post uploading.
abstract class CommunityPostUploadStateBase extends BaseController
    with ContentValidationMixin {
  // ── Firebase & Repositories ───────────────────────────────────────────────
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final Uuid uuid = const Uuid();
  final ImageVerificationService imageVerificationService =
      ImageVerificationService();
  final UserNotificationService userNotificationService =
      UserNotificationService();
  final TopicRepository topicRepository = TopicRepository();

  // ── Reactive State ────────────────────────────────────────────────────────

  /// Mandatory creator copyright & rights ownership declaration
  final RxBool hasConfirmedCopyrightDeclaration = false.obs;

  // Topic Selection State
  final RxString selectedTopicId = ''.obs;
  final RxMap<String, dynamic> newTopicData = <String, dynamic>{}.obs;
  final RxList<Topic> availableTopics = <Topic>[].obs;
  final RxBool isTopicsLoading = false.obs;
  final RxString topicSearchQuery = ''.obs;

  // Channel Management
  final RxList<Channel> channels = <Channel>[].obs;
  final Rx<Channel?> selectedChannel = Rx<Channel?>(null);
  final RxBool isChannelsLoading = false.obs;
  final RxString channelsError = ''.obs;

  // Moderation
  final Map<int, StreamSubscription> moderationListeners = {};
  final RxMap<int, String> moderationStatuses = <int, String>{}.obs;
  final RxMap<int, String> moderationReasons = <int, String>{}.obs;

  // Images (single image, any aspect ratio)
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
  final Rx<int?> pollDurationDays = Rx<int?>(null); // null = no expiry

  // Form
  final RxString selectedCategory = 'General'.obs;
  final RxString selectedVisibility = 'Public'.obs;
  final RxBool isKidFriendly = false.obs;
  final RxBool isScheduled = false.obs;
  final Rx<DateTime> scheduledDate =
      DateTime.now().add(const Duration(days: 1)).obs;

  // Post Interactive Settings
  final RxBool isLikeEnabled = true.obs;
  final RxBool showLikeCount = true.obs;
  final RxBool isDislikeEnabled = true.obs;
  final RxBool showDislikeCount = true.obs;
  final RxBool isCommentsEnabled = true.obs;
  final RxBool isPinnedPost = false.obs;
  final RxString descriptionText = ''.obs;

  // Form Controls (tracked for automatic disposal)
  late final TextEditingController titleCtrl =
      trackTextController(TextEditingController());
  late final TextEditingController descCtrl =
      trackTextController(TextEditingController());
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Draft Management
  final Rx<CommunityDraft?> currentDraft = Rx<CommunityDraft?>(null);
  final RxBool isSavingDraft = false.obs;
  final Rxn<String> lastPublishedPostId = Rxn<String>();

  // Categories
  final List<String> communityCategories = [
    'General',
    'Announcement',
    'Question',
    'Discussion',
    'Support',
    'Feedback',
  ];

  /// Whether the user has satisfied all requirements to publish.
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

    // Only block if an image was explicitly rejected (verifying/pending images do not block)
    if (moderationStatuses.values.any((s) => s == 'REJECTED')) {
      return false;
    }

    if (!hasConfirmedCopyrightDeclaration.value) {
      return false;
    }

    return true;
  }

  // Abstract cross-mixin contracts
  void resetForm();
  Future<void> fetchChannelsForCommunity();
  Future<void> fetchAvailableTopics();
  Future<void> saveDraft({
    required String title,
    required String description,
    required String tagsRaw,
  });
  Future<void> publishPost({
    required String title,
    required String description,
    required String tagsRaw,
  });
}
