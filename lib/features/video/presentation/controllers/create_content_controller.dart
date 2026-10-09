import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/dashboard/data/models/draft_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/create_playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/create_playlist_screen.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/models/upload_type.dart';

class CreateContentController extends GetxController {
  CreateContentController({
    UploadType? uploadType,
    this.existingVideo,
  }) : uploadType = uploadType ?? UploadType.video;

  final UploadType uploadType;
  final Video? existingVideo;

  late final UploadController uploadController;
  late final PlaylistController playlistController;

  final GlobalKey<FormState> videoDetailsFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> communityDetailsFormKey = GlobalKey<FormState>();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController tagsController = TextEditingController();

  final TextEditingController communityTitleController = TextEditingController();
  final TextEditingController communityDescriptionController = TextEditingController();
  final TextEditingController communityTagsController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    if (!Get.isRegistered<UploadController>()) {
      Get.put(UploadController());
    }
    uploadController = Get.find<UploadController>();

    if (!Get.isRegistered<PlaylistController>()) {
      Get.put(PlaylistController());
    }
    playlistController = Get.find<PlaylistController>();

    if (existingVideo != null) {
      applyDraftVideo(existingVideo!);
    } else {
      loadDraftFromArguments();
    }
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    tagsController.dispose();
    communityTitleController.dispose();
    communityDescriptionController.dispose();
    communityTagsController.dispose();
    super.onClose();
  }

  /// Thoroughly applies an existing Video draft to form inputs and UploadController
  void applyDraftVideo(Video video) {
    if (video.title.isNotEmpty &&
        video.title != 'Uploading...' &&
        video.title != 'Untitled' &&
        video.title != 'Untitled Draft') {
      titleController.text = video.title;
    }
    if (video.description.isNotEmpty && video.description != 'Processing...') {
      descriptionController.text = video.description;
    }
    if (video.tags.isNotEmpty) {
      tagsController.text = video.tags.join(', ');
    }

    uploadController.loadFromVideo(video);
    uploadController.resumedVideoDraft.value = video;
    uploadController.currentVideoId = video.id;

    final effectiveVideoUrl =
        video.originalUrl.isNotEmpty ? video.originalUrl : video.videoUrl;
    if (effectiveVideoUrl.isNotEmpty) {
      uploadController.videoUrl.value = effectiveVideoUrl;
    }

    if (video.thumbnailUrl.isNotEmpty) {
      uploadController.thumbnailUrl.value = video.thumbnailUrl;
      uploadController.finalstatus.value = 'APPROVED';
    }

    if (video.category.isNotEmpty) {
      uploadController.selectedCategory.value = video.category;
    }

    if (video.visibility.isNotEmpty &&
        video.visibility.toLowerCase() != 'draft') {
      uploadController.selectedVisibility.value = video.visibility;
    }

    if (video.topics.isNotEmpty) {
      uploadController.selectedTopicId.value = video.topics.first;
    }

    uploadController.isUploading.value = false;
    uploadController.isProcessing.value = false;
    uploadController.uploadProgress.value = 1.0;
    uploadController.videoUploadProgress.value = 1.0;

    if (video.durationMs > 0) {
      uploadController.videoDuration.value =
          Duration(milliseconds: video.durationMs);
      uploadController.videoDurationSeconds.value = video.durationMs ~/ 1000;
    } else if (video.durationValue.inMilliseconds > 0) {
      uploadController.videoDuration.value = video.durationValue;
      uploadController.videoDurationSeconds.value =
          video.durationValue.inSeconds;
    }

    if (video.channelId.isNotEmpty && uploadController.channels.isNotEmpty) {
      final matching = uploadController.channels.firstWhereOrNull(
        (c) => c.channelId == video.channelId || c.id == video.channelId,
      );
      if (matching != null) {
        uploadController.selectedChannel.value = matching;
      }
    }

    if (uploadController.videoUrl.value.isNotEmpty) {
      uploadController.initializeVideoPlayer();
    }

    if (video.isFactChecked ||
        video.hasAiCredibility ||
        video.factCheckTier == 'full_ground' ||
        video.factCheckTier == 'standard') {
      uploadController.aiFactCheckEnabled.value = true;
      uploadController.aiFactCheckTier.value =
          video.factCheckTier.isNotEmpty ? video.factCheckTier : 'full_ground';
    }
    if (video.factCheckReviewMode.isNotEmpty) {
      uploadController.aiFactCheckReviewMode.value = video.factCheckReviewMode;
    }

    uploadController.update();
    debugPrint(
      '🎬 Successfully applied draft video: ${video.id} ("${video.title}")',
    );
  }

  Future<void> _loadVideoDocById(
    String videoId, {
    DraftModel? fallbackDraft,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();
      if (doc.exists && doc.data() != null) {
        final v = Video.fromMap(doc.data()!, doc.id);
        applyDraftVideo(v);

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

        final aiFeaturesMap = doc.data()!['aiFeatures'] as Map<String, dynamic>?;
        if (aiFeaturesMap != null) {
          final factCheckFlag = aiFeaturesMap['factChecking'] == true ||
              aiFeaturesMap['enableFactCheck'] == true ||
              aiFeaturesMap['truthVerification'] == true ||
              doc.data()!['enableFactCheck'] == true ||
              doc.data()!['factChecking'] == true ||
              doc.data()!['truthVerification'] == true ||
              doc.data()!['factCheckTier'] == 'full_ground';
          if (factCheckFlag) {
            uploadController.aiFactCheckEnabled.value = true;
            uploadController.aiFactCheckTier.value = 'full_ground';
          }
        }
      } else {
        // Document not found in 'videos', check 'user_drafts' collection
        final draftDoc = await FirebaseFirestore.instance
            .collection('user_drafts')
            .doc(videoId)
            .get();
        if (draftDoc.exists && draftDoc.data() != null) {
          final dm = DraftModel.fromMap(draftDoc.data()!, draftDoc.id);
          _applyDraftModel(dm);
        } else if (fallbackDraft != null) {
          _applyDraftModel(fallbackDraft);
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CreateContentController._loadVideoDocById',
      );
      if (fallbackDraft != null) {
        _applyDraftModel(fallbackDraft);
      }
    }
  }

  void _applyDraftModel(DraftModel draft) {
    if (draft.title.isNotEmpty) {
      titleController.text = draft.title;
    }
    if (draft.content.isNotEmpty) {
      descriptionController.text = draft.content;
    }
    uploadController.currentVideoId = draft.id;
    if (draft.mediaUrl != null && draft.mediaUrl!.isNotEmpty) {
      uploadController.thumbnailUrl.value = draft.mediaUrl!;
      uploadController.finalstatus.value = 'APPROVED';
    }
    if (draft.channelId.isNotEmpty && uploadController.channels.isNotEmpty) {
      final matching = uploadController.channels.firstWhereOrNull(
        (c) => c.channelId == draft.channelId || c.id == draft.channelId,
      );
      if (matching != null) {
        uploadController.selectedChannel.value = matching;
      }
    }
    uploadController.update();
  }

  void loadDraftFromArguments() {
    final args = Get.arguments;
    if (args == null) return;

    if (args is Video) {
      applyDraftVideo(args);
      return;
    }

    if (args is String && args.isNotEmpty) {
      _loadVideoDocById(args);
      return;
    }

    if (args is Map) {
      final videoArg = args['video'] ?? args['draftVideo'];
      final draftArg = args['draft'];
      final videoId = (args['videoId'] as String?) ??
          (args['id'] as String?) ??
          (args['draftId'] as String?);

      if (videoArg is Video) {
        applyDraftVideo(videoArg);
      } else if (videoId != null && videoId.isNotEmpty) {
        _loadVideoDocById(
          videoId,
          fallbackDraft: draftArg is DraftModel ? draftArg : null,
        );
      } else if (draftArg is Video) {
        applyDraftVideo(draftArg);
      } else if (draftArg is DraftModel) {
        _applyDraftModel(draftArg);
      }
    }
  }

  bool canPublishVideo() {
    final hasMedia = uploadController.videoUrl.value.isNotEmpty ||
        uploadController.pickedVideo.value != null ||
        uploadController.resumedVideoDraft.value != null;
    final hasThumb = uploadController.thumbnailUrl.value.isNotEmpty ||
        uploadController.pickedImage.value != null;
    final hasCategory = uploadController.selectedCategory.value.isNotEmpty;
    final hasChannel = uploadController.selectedChannel.value != null;
    return hasMedia && hasThumb && hasCategory && hasChannel;
  }

  void showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard upload?'),
        content: const Text('Your progress will be lost if you leave now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Get.back();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> handleVideoUpload({bool isDraft = false}) async {
    if (!isDraft) {
      final selectedChannel = uploadController.selectedChannel.value;
      if (selectedChannel != null &&
          selectedChannel.status != ChannelStatus.active) {
        var message = 'Your channel is not active.';
        if (selectedChannel.status == ChannelStatus.underReview) {
          message =
              'Your channel details are currently under review by our Verification System. You can publish videos once approved.';
        } else if (selectedChannel.status == ChannelStatus.verificationRejected) {
          message = selectedChannel.moderationReason != null &&
                  selectedChannel.moderationReason!.isNotEmpty
              ? 'Branding Rejected: ${selectedChannel.moderationReason!}'
              : 'Your channel details were rejected by our Verification System. Please update your channel details in customization to re-verify.';
        } else if (selectedChannel.status == ChannelStatus.verificationPending) {
          message =
              'Your channel is currently verification pending. You can publish videos once your branding is verified.';
        } else if (selectedChannel.status == ChannelStatus.suspended) {
          message = 'Your channel is suspended. Publishing is disabled.';
        }
        AppSnackbar.warning(message, title: 'Verification Required');
        return;
      }

      if (!uploadController.hasConfirmedCopyrightDeclaration.value) {
        AppSnackbar.warning(
          'Please confirm and check the copyright ownership declaration before publishing your video.',
          title: 'Copyright Declaration Required',
        );
        return;
      }

      final rawTitle = titleController.text.trim();
      final rawDesc = descriptionController.text.trim();
      final rawTags = tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final titleValidation = ContentValidator.validate(
        rawTitle,
        fieldName: 'Title',
        minLength: 5,
        maxLength: 100,
      );
      if (!titleValidation.isValid) {
        AppSnackbar.warning(titleValidation.message, title: 'Invalid Title');
        return;
      }

      final descValidation = ContentValidator.validate(
        rawDesc,
        fieldName: 'Description',
        minLength: 10,
        maxLength: 500,
        checkPhoneNumbers: true,
      );
      if (!descValidation.isValid) {
        AppSnackbar.warning(descValidation.message, title: 'Invalid Description');
        return;
      }

      if (rawTags.isNotEmpty) {
        final tagsValidation = ContentValidator.validateTags(rawTags);
        if (!tagsValidation.isValid) {
          AppSnackbar.warning(tagsValidation.message, title: 'Invalid Tags');
          return;
        }
      }

      final canPublish = canPublishVideo();
      if (!canPublish) {
        final reasons = <String>[];
        if (uploadController.videoUrl.value.isEmpty &&
            uploadController.pickedVideo.value == null &&
            uploadController.resumedVideoDraft.value == null) {
          reasons.add('Video file or draft is required');
        }
        if (uploadController.thumbnailUrl.value.isEmpty &&
            uploadController.pickedImage.value == null) {
          reasons.add('Thumbnail image is required');
        }
        if (uploadController.selectedCategory.value.isEmpty) {
          reasons.add('Category is required');
        }
        if (uploadController.selectedChannel.value == null) {
          reasons.add('Channel is required');
        }

        AppSnackbar.warning(
          reasons.join('. '),
          title: 'Cannot Publish',
        );
        return;
      }

      final status = uploadController.finalstatus.value;
      if (status == 'REJECTED') {
        AppSnackbar.error(
          'You cannot publish because the thumbnail was rejected: ${uploadController.finalstatusReason.value}',
          title: 'Thumbnail Rejected',
        );
        return;
      }
      if (uploadController.pickedImage.value != null && status != 'APPROVED') {
        AppSnackbar.info(
          'Your thumbnail is still being verified. Please wait a moment.',
          title: 'Verification Pending',
        );
        return;
      }
    }

    final channel = uploadController.selectedChannel.value;
    if (channel == null) {
      AppSnackbar.warning('Please select a channel to publish to.', title: 'Channel Required');
      return;
    }

    try {
      uploadController.isProcessing.value = true;
      uploadController.processingMessage.value =
          isDraft ? 'Saving draft...' : 'Publishing video...';

      final rawTags = tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (rawTags.length > ContentValidator.defaultMaxTags) {
        throw Exception(
          'Maximum ${ContentValidator.defaultMaxTags} tags allowed (currently ${rawTags.length})',
        );
      }

      final tags = rawTags.take(ContentValidator.defaultMaxTags).toList();
      final selectedLanguages = uploadController.aiTranslationLanguages.toList();

      await uploadController.uploadVideo(
        titleController.text.trim(),
        descriptionController.text.trim(),
        channel.channelName,
        channel.channelId,
        channel.avatarUrl,
        tags,
        selectedLanguages,
        isDraft: isDraft,
      );

      HapticFeedback.mediumImpact();
      AppSnackbar.success(
        isDraft
            ? 'Your video was saved as a draft successfully.'
            : 'Your video is being processed and will be available soon.',
      );
      Get.offAllNamed('/studio');
    } catch (e) {
      ErrorHandler.log(e);
      var errorMessage = 'Failed to upload video. Please try again.';
      if (e is FirebaseException) {
        errorMessage = 'Firebase error: ${e.message ?? e.code}';
      } else if (e is io.IOException) {
        errorMessage = 'Network error: Check your internet connection.';
      } else if (e is FormatException) {
        errorMessage = 'Invalid data format. Please check your input.';
      } else {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '').trim();
        if (cleanMsg.isNotEmpty) {
          errorMessage = cleanMsg;
        }
      }
      AppSnackbar.error(errorMessage);
    } finally {
      uploadController.isProcessing.value = false;
    }
  }

  Future<void> handleCommunityUpload() async {
    final channel = uploadController.selectedChannel.value;
    if (channel == null) {
      AppSnackbar.warning('Please select a channel for this post.', title: 'Channel Required');
      return;
    }

    try {
      uploadController.isProcessing.value = true;
      uploadController.processingMessage.value = 'Publishing community post...';

      final rawCommunityTags = communityTagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (rawCommunityTags.length > ContentValidator.defaultMaxTags) {
        throw Exception(
          'Maximum ${ContentValidator.defaultMaxTags} tags allowed (currently ${rawCommunityTags.length})',
        );
      }

      final tags = rawCommunityTags.take(ContentValidator.defaultMaxTags).toList();

      await uploadController.uploadCommunityPost(
        communityTitleController.text.trim(),
        communityDescriptionController.text.trim(),
        channel.channelName,
        channel.channelId,
        channel.avatarUrl,
        tags,
      );

      HapticFeedback.mediumImpact();
      AppSnackbar.success('Your community post has been published successfully.');
      Get.offAllNamed('/studio');
    } catch (e) {
      ErrorHandler.log(e);
      var errorMessage = 'Failed to publish community post. Please try again.';
      if (e is FirebaseException) {
        errorMessage = 'Firebase error: ${e.message ?? e.code}';
      } else if (e is io.IOException) {
        errorMessage = 'Network error: Check your internet connection.';
      } else if (e is FormatException) {
        errorMessage = 'Invalid data format. Please check your input.';
      } else {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '').trim();
        if (cleanMsg.isNotEmpty) {
          errorMessage = cleanMsg;
        }
      }
      AppSnackbar.error(errorMessage, title: 'Post Failed');
    } finally {
      uploadController.isProcessing.value = false;
    }
  }

  void showCreateTopicModal(BuildContext context, bool isDark) {
    final currentChannelId = uploadController.selectedChannel.value?.id ?? '';
    CreateTopicDialog.show(
      context: context,
      isDarkMode: isDark,
      isFromUpload: true,
      channelVideosFuture: currentChannelId.isNotEmpty
          ? FirebaseFirestore.instance
                .collection(FirestoreCollections.videos)
                .where('channelId', isEqualTo: currentChannelId)
                .get()
                .then(
                  (snap) => snap.docs
                      .map((doc) => {'id': doc.id, ...doc.data()})
                      .toList(),
                )
          : Future.value([]),
      onCreateTopicSubmitted: (createCtrl) async {
        final title = createCtrl.titleController.text.trim();
        var rawHandle = createCtrl.handleController.text.trim();
        if (rawHandle.startsWith('T/') || rawHandle.startsWith('t/')) {
          rawHandle = rawHandle.substring(2);
        }
        final cleanHandle = rawHandle
            .replaceAll(RegExp('[^a-zA-Z0-9_-]'), '-')
            .replaceAll(RegExp('-+'), '-');
        final finalHandle = 'T/$cleanHandle';
        final finalHandleLowercase = finalHandle.toLowerCase();

        final existingHandle = await FirebaseFirestore.instance
            .collection(FirestoreCollections.topics)
            .where('handleLowercase', isEqualTo: finalHandleLowercase)
            .limit(1)
            .get();

        if (existingHandle.docs.isNotEmpty) {
          AppSnackbar.warning('Topic handle is already taken. Please choose a different one.');
          throw Exception('Handle already taken');
        }

        uploadController.newTopicData.value = {
          'title': title,
          'handle': finalHandle,
          'description': createCtrl.descriptionController.text.trim(),
          'category': createCtrl.categoryController.text,
          'visibilityType': createCtrl.selectedVisibility.value,
          'accessCode': createCtrl.accessCodeController.text.trim(),
          'thumbnailSource': createCtrl.thumbnailSource.value,
          'customThumbnailBytes': createCtrl.pickedCustomImageBytes.value,
          'customThumbnailName': createCtrl.pickedCustomImageName.value,
        };

        uploadController.selectedTopicId.value = 'new_topic_draft';
        AppSnackbar.success('Topic draft created! It will be published along with your video.');
      },
    );
  }

  Future<void> showCreatePlaylistModal(BuildContext context, bool isDark) async {
    final createCtrl = Get.isRegistered<CreatePlaylistController>()
        ? Get.find<CreatePlaylistController>()
        : Get.put(CreatePlaylistController());
    createCtrl.resetForm();

    final dynamic created = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (ctx) => const CreatePlaylistScreen(fromUpload: true),
      ),
    );

    if (created is PlaylistModel) {
      playlistController.refreshPlaylistsTick();
      await playlistController.refreshPlaylists();
      uploadController.selectedPlaylist.value = created.id;
      AppSnackbar.success(
        'Playlist created! Video will be added upon publishing.',
      );
    }
  }
}

