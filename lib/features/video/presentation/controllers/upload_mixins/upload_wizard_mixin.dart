import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_controller_base.dart';

mixin UploadWizardMixin on UploadControllerBase {
  /// Overall progress indicator (0.0 to 1.0)
  double get overallProgress => (uploadStage.value + 1) / 4.0;

  void setFormValid(bool valid) {
    isFormValid.value = valid;
  }

  /// Update the current upload stage
  void setUploadStage(int stage) {
    uploadStage.value = stage;
    final stages = ['Upload Media', 'All Details', 'Settings', 'Publish'];
    uploadStageLabel.value = stages[stage];
    debugPrint('📍 Moved to stage $stage: ${stages[stage]}');
  }

  /// Check if current stage is complete and valid
  bool isCurrentStageValid() {
    switch (uploadStage.value) {
      case 0: // Upload Media
        return pickedVideo.value != null && videoUrl.value.isNotEmpty;
      case 1: // All Details
        return videoMetadata.containsKey('title') &&
            videoMetadata['title'].toString().isNotEmpty;
      case 2: // Settings
        return videoMetadata.containsKey('category');
      case 3: // Publish
        return true;
      default:
        return false;
    }
  }

  /// Advance to the next stage
  Future<bool> advanceUploadStage() async {
    if (!isCurrentStageValid()) {
      AppSnackbar.warning(
        'Please complete the current stage before advancing.',
      );
      return false;
    }

    if (uploadStage.value < 3) {
      setUploadStage(uploadStage.value + 1);
      return true;
    }
    return false;
  }

  /// Load an existing video draft from Firestore into UploadController
  void loadFromVideo(Video video) {
    resumedVideoDraft.value = video;
    currentVideoId = video.id;

    videoUrl.value = video.originalUrl.isNotEmpty
        ? video.originalUrl
        : video.videoUrl;
    thumbnailUrl.value = video.thumbnailUrl;
    if (video.thumbnailUrl.isNotEmpty) {
      finalstatus.value = 'APPROVED';
    }
    isUploading.value = false;
    isProcessing.value = false;
    uploadProgress.value = 1.0;
    videoUploadProgress.value = 1.0;

    // Title pre-fill: if generic 'Uploading...' or empty
    if (video.title.isNotEmpty &&
        video.title != 'Uploading...' &&
        video.title != 'Untitled' &&
        video.title != 'Untitled Draft') {
      titleController.text = video.title;
    }

    // Description pre-fill: if generic 'Processing...'
    if (video.description.isNotEmpty && video.description != 'Processing...') {
      descriptionController.text = video.description;
    }

    if (video.category.isNotEmpty) {
      selectedCategory.value = video.category;
    }

    if (video.visibility.isNotEmpty &&
        video.visibility.toLowerCase() != 'draft') {
      selectedVisibility.value = video.visibility;
    }

    if (video.tags.isNotEmpty) {
      tagController.text = video.tags.join(', ');
    }

    if (video.topics.isNotEmpty) {
      selectedTopicId.value = video.topics.first;
    }

    // Match channel
    if (video.channelId.isNotEmpty && channels.isNotEmpty) {
      final matching = channels.firstWhereOrNull(
        (c) => c.channelId == video.channelId || c.id == video.channelId,
      );
      if (matching != null) {
        selectedChannel.value = matching;
      }
    }

    if (video.geminiApproved != null && video.geminiApproved!) {
      videoModerationStatus.value = 'APPROVED';
    }

    isFormValid.value = titleController.text.trim().length >= 5;
    canAdvanceStage.value = true;
    uploadStage.value = 1; // Details stage

    debugPrint(
      '🎬 Video draft loaded into controller: ${video.id} (title: "${titleController.text}")',
    );
  }

  /// Load an existing video draft by document ID from Firestore
  Future<void> loadVideoById(String videoId) async {
    try {
      final doc = await firestore.collection('videos').doc(videoId).get();
      if (doc.exists && doc.data() != null) {
        final v = Video.fromMap(doc.data()!, doc.id);
        loadFromVideo(v);
        final rawFileName = doc.data()!['fileName'] as String?;
        final moderation = doc.data()!['moderation'] as Map<String, dynamic>?;

        if (titleController.text.isEmpty &&
            rawFileName != null &&
            rawFileName.isNotEmpty) {
          final cleanName = rawFileName
              .replaceAll(
                RegExp(r'\.(mp4|mov|avi|mkv|webm)$', caseSensitive: false),
                '',
              )
              .replaceAll('_', ' ')
              .replaceAll('-', ' ');
          titleController.text = cleanName;
        }

        if (descriptionController.text.isEmpty && moderation != null) {
          final summary = moderation['summary'] as String?;
          if (summary != null && summary.isNotEmpty) {
            descriptionController.text = summary;
          }
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UploadWizardMixin.loadDraft',
      );
    }
  }

  Future<void> refreshTitleDescriptionValidation(
    String title,
    String description,
  ) async {
    if (title.trim().isEmpty && description.trim().isEmpty) {
      titleValidationStatus.value = 'UNKNOWN';
      descriptionValidationStatus.value = 'UNKNOWN';
      titleValidationReason.value = '';
      descriptionValidationReason.value = '';
      return;
    }

    titleValidationStatus.value = 'PENDING';
    titleValidationReason.value = 'Checking title content...';
    descriptionValidationStatus.value = 'PENDING';
    descriptionValidationReason.value = 'Checking description content...';

    try {
      final titleResult = await validateContent(title, fieldName: 'Title');
      if (titleResult.isValid) {
        titleValidationStatus.value = 'APPROVED';
        titleValidationReason.value =
            'Title passed profanity and content validation checks.';
      } else {
        titleValidationStatus.value = 'REJECTED';
        titleValidationReason.value = titleResult.message;
      }
    } catch (e, stackTrace) {
      titleValidationStatus.value = 'REJECTED';
      titleValidationReason.value =
          'Unable to validate title content at this time.';
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UploadWizardMixin.validateTitle',
      );
    }

    try {
      final descriptionResult = await validateContent(
        description,
        fieldName: 'Description',
        checkPhoneNumbers: true,
      );

      if (descriptionResult.isValid) {
        descriptionValidationStatus.value = 'APPROVED';
        descriptionValidationReason.value =
            'Description passed profanity and content validation checks.';
      } else {
        descriptionValidationStatus.value = 'REJECTED';
        descriptionValidationReason.value = descriptionResult.message;
      }
    } catch (e, stackTrace) {
      descriptionValidationStatus.value = 'REJECTED';
      descriptionValidationReason.value =
          'Unable to validate description content at this time.';
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UploadWizardMixin.validateDescription',
      );
    }
  }

  Future<void> uploadCommunityPost(
    String title,
    String description,
    String channelName,
    String channelId,
    String channelImage,
    List<String> tags,
  ) async {
    if (isCommunityPostUploading.value) {
      AppSnackbar.info(
        'A community post is already being published.',
      );
      return;
    }

    // Check Moderation Status - only block if explicitly REJECTED
    if (communityImageStatus.value == 'REJECTED') {
      AppSnackbar.warning(
        'Your community post image was rejected: ${communityImageStatusReason.value}. Please upload a compliant image.',
      );
      return;
    }

    if (pickedCommunityImage.value == null && communityImageUrl.value.isEmpty) {
      AppSnackbar.warning('Please select an image.');
      return;
    }

    // If image is still uploading in background, await it
    if (communityImageUrl.value.isEmpty && pickedCommunityImage.value != null) {
      if (currentUploadTaskCommunity != null) {
        final snapshot = await currentUploadTaskCommunity!.whenComplete(() {});
        communityImageUrl.value = await snapshot.ref.getDownloadURL();
      } else {
        await startImageUpload(pickedCommunityImage.value!, forCommunity: true);
      }
    }

    // CONTENT VALIDATION - Title
    if (title.isEmpty) {
      AppSnackbar.warning('Title cannot be empty.');
      return;
    }

    if (title.length > UploadControllerBase.maxTitleLength) {
      AppSnackbar.warning('Title cannot exceed ${UploadControllerBase.maxTitleLength} characters.');
      return;
    }

    final titleValidation = await validateContent(title, fieldName: 'Title');
    if (!titleValidation.isValid) {
      AppSnackbar.warning(titleValidation.message);
      return;
    }

    // CONTENT VALIDATION - Description
    if (description.isEmpty) {
      AppSnackbar.warning('Description cannot be empty.');
      return;
    }

    if (description.length > UploadControllerBase.maxDescriptionLength) {
      AppSnackbar.warning(
        'Description cannot exceed ${UploadControllerBase.maxDescriptionLength} characters.',
      );
      return;
    }

    final descValidation = await validateContent(
      description,
      fieldName: 'Description',
      checkPhoneNumbers: true,
    );
    if (!descValidation.isValid) {
      AppSnackbar.warning(descValidation.message);
      return;
    }

    // CONTENT VALIDATION - Tags
    final validTags = tags.where((t) => t.trim().isNotEmpty).toList();
    if (validTags.isNotEmpty) {
      final tagsValidation = await validateTags(validTags);
      if (!tagsValidation.isValid) {
        AppSnackbar.warning(tagsValidation.message);
        return;
      }
    }

    try {
      debugPrint('🔐 Refreshing token before community post...');
      final authValid = await verifyAuthentication();
      if (!authValid) {
        throw Exception(
          'Authentication failed before uploading community post',
        );
      }

      isUploading.value = true;
      isCommunityPostUploading.value = true;
      final DocumentReference docRef = firestore.collection('Community').doc();
      debugPrint('Attempting to publish community post with ID: ${docRef.id}');

      final data = <String, dynamic>{
        'id': docRef.id,
        'title': title.trim(),
        'description': description.trim(),
        'images': [communityImageUrl.value],
        'image': communityImageUrl.value,
        'likes': 0,
        'likeCount': 0,
        'dislikes': 0,
        'dislikeCount': 0,
        'commentCount': 0,
        'views': 0,
        'viewCount': 0,
        'shareCount': 0,
        'downloads': 0,
        'uploadedAt': Timestamp.now(),
        'ownerId': FirebaseAuth.instance.currentUser!.uid,
        'channelName': channelName.trim(),
        'channelId': channelId.trim(),
        'channelImage': channelImage,
        'selectedCategory': selectedCategory.value,
        'tags': validTags,
        'processed': false,
        'visibility': selectedVisibility.value,
        'isKidFriendly': isKidFriendly.value,
      };

      if (isScheduled.value) {
        data['scheduledTime'] = Timestamp.fromDate(scheduledDate.value);
      }

      await docRef.set(data);
      debugPrint('Community post published successfully!');

      AppSnackbar.success('Community post published successfully!');
      uploadProgress.value = 0.0;
      resetUploads();
      if (Get.currentRoute != '/studio') {
        Get.offAllNamed('/studio');
      }
    } on FirebaseException catch (e) {
      ErrorHandler.log(e, context: 'UploadController.uploadCommunityPost');
      var errorMessage = 'Unable to upload community post. Please try again.';
      if (e.code == 'permission-denied' ||
          (e.message?.contains('not authorized') ?? false)) {
        errorMessage = 'Authentication expired. Please sign in again.';
      }
      AppSnackbar.error(errorMessage);
    } catch (e) {
      ErrorHandler.log(e, context: 'UploadController.uploadCommunityPost');
      AppSnackbar.error('Unable to publish community post. Please try again.');
    } finally {
      isUploading.value = false;
      isCommunityPostUploading.value = false;
    }
  }

  @override
  void resetUploads() {
    // 1. Dispose external non-state resources
    videoUploadTask = null;
    currentUploadTaskVideo = null;
    currentUploadTaskCommunity = null;
    communityImageModerationSubscription?.cancel();
    communityImageModerationSubscription = null;
    thumbnailModerationSubscription?.cancel();
    thumbnailModerationSubscription = null;
    videoPlayerController?.dispose();
    videoPlayerController = null;

    // 2. Atomically reset state in a single tick
    updateState((s) => s.resetUploads());
  }
}
