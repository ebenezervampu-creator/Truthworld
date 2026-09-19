import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/data/models/community_draft.dart';
import 'package:truthworld/features/community/data/models/poll_model.dart';
import 'package:truthworld/features/community/presentation/controllers/upload/community_post_upload_state_base.dart';

/// Mixin handling draft saving, validation, and post publishing workflows.
mixin CommunityPostPublishMixin on CommunityPostUploadStateBase {
  @override
  Future<void> saveDraft({
    required String title,
    required String description,
    required String tagsRaw,
  }) async {
    if (title.trim().isNotEmpty) {
      final titleVal = await validateContent(title, fieldName: 'Draft Title');
      if (!titleVal.isValid) {
        AppSnackbar.show(
          'Inappropriate Content',
          titleVal.message,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    }
    isSavingDraft.value = true;
    try {
      final uid = auth.currentUser?.uid ?? AuthService.to.user?.uid;
      if (uid == null) {
        AppSnackbar.show(
          'Authentication Required',
          'Please sign in to save drafts.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final draftId = currentDraft.value?.id.isNotEmpty == true
          ? currentDraft.value!.id
          : uuid.v4();

      final parsedTags = tagsRaw
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .take(5)
          .toList();

      final draft = CommunityDraft(
        id: draftId,
        ownerId: uid,
        channelId: selectedChannel.value?.channelId ?? '',
        type: 'post',
        title: title,
        description: description,
        tags: parsedTags,
        category: selectedCategory.value,
        visibility: selectedVisibility.value,
        isKidFriendly: isKidFriendly.value,
        imageUrls: List<String>.from(imageUrls),
        scheduledPublishDate: isScheduled.value
            ? scheduledDate.value.toIso8601String()
            : null,
        createdAt: currentDraft.value?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        poll: hasPoll.value
            ? PollModel(
                question: pollQuestion.value,
                type: pollType.value,
                options: pollType.value == PollType.multiChoice
                    ? pollOptions
                        .asMap()
                        .entries
                        .map(
                          (e) => PollOption(
                            id: 'opt_${e.key}',
                            text: e.value,
                          ),
                        )
                        .toList()
                    : const [
                        PollOption(id: 'opt_yes', text: 'Yes'),
                        PollOption(id: 'opt_no', text: 'No'),
                      ],
              )
            : null,
      );

      await firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('communityDrafts')
          .doc(draftId)
          .set(draft.toMap());

      currentDraft.value = draft;

      AppSnackbar.success(
        'Your post was saved as a draft.',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to save draft. Please try again.',
      );
    } finally {
      isSavingDraft.value = false;
    }
  }

  @override
  Future<void> publishPost({
    required String title,
    required String description,
    required String tagsRaw,
  }) async {
    final titleVal = await validateContent(title, fieldName: 'Post Title');
    if (!titleVal.isValid) {
      AppSnackbar.show(
        'Inappropriate Content',
        titleVal.message,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (description.trim().isNotEmpty) {
      final descVal =
          await validateContent(description, fieldName: 'Post Description');
      if (!descVal.isValid) {
        AppSnackbar.show(
          'Inappropriate Content',
          descVal.message,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    }

    final parsedTags = tagsRaw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (parsedTags.length > 5) {
      AppSnackbar.show(
        'Too Many Tags',
        'Maximum 5 tags allowed (currently ${parsedTags.length})',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (parsedTags.isNotEmpty) {
      final tagsVal = await validateTags(parsedTags);
      if (!tagsVal.isValid) {
        AppSnackbar.show(
          'Inappropriate Content',
          tagsVal.message,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    }

    if (hasPoll.value) {
      final qVal =
          await validateContent(pollQuestion.value, fieldName: 'Poll Question');
      if (!qVal.isValid) {
        AppSnackbar.show(
          'Inappropriate Content',
          qVal.message,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      if (pollType.value == PollType.multiChoice) {
        for (var i = 0; i < pollOptions.length; i++) {
          final opt = pollOptions[i];
          if (opt.trim().isNotEmpty) {
            final optVal =
                await validateContent(opt, fieldName: 'Poll Option ${i + 1}');
            if (!optVal.isValid) {
              AppSnackbar.show(
                'Inappropriate Content',
                optVal.message,
                snackPosition: SnackPosition.BOTTOM,
              );
              return;
            }
          }
        }
      }
    }

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
            'Your channel details are currently under review by our Verification System. You can publish posts once approved.';
      } else if (selectedChannel.value!.status ==
          ChannelStatus.verificationRejected) {
        message = selectedChannel.value!.moderationReason != null &&
                selectedChannel.value!.moderationReason!.isNotEmpty
            ? 'Branding Rejected: ${selectedChannel.value!.moderationReason!}'
            : 'Your channel details were rejected by our Verification System. Please update your channel details in customization to re-verify.';
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

    // Only block if any image was explicitly REJECTED (verifying images do not block)
    if (moderationStatuses.values.any((s) => s == 'REJECTED')) {
      final reason = moderationReasons.values.firstWhere(
        (r) => r.isNotEmpty,
        orElse: () => 'Violates Community Guidelines',
      );
      AppSnackbar.show(
        'Moderation Blocked',
        'Your image was rejected: $reason. Please replace or remove it before publishing.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!hasConfirmedCopyrightDeclaration.value) {
      AppSnackbar.show(
        'Declaration Required',
        'Please confirm the creator declaration before publishing.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isUploading.value = true;
    try {
      final docRef = firestore.collection(FirestoreCollections.community).doc();
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
        'ownerId': auth.currentUser?.uid,
        'channelId': selectedChannel.value!.channelId,
        'channelName': selectedChannel.value!.channelName,
        'channelImage': selectedChannel.value!.avatarUrl,
        'category': selectedCategory.value,
        'visibility':
            isScheduled.value ? 'Scheduled' : selectedVisibility.value,
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
        final topicQuery = await firestore
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
      AppSnackbar.success(
        'Your community post is live.',
      );
    } catch (e) {
      isUploading.value = false;
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to publish post. Please try again.',
      );
    }
  }

  /// Convenience handler for saving draft from the upload screen.
  void handleSaveDraftSubmit() {
    saveDraft(
      title: titleCtrl.text.trim(),
      description: descCtrl.text.trim(),
      tagsRaw: '',
    );
  }

  /// Convenience handler for validating and publishing from the upload screen.
  void handlePublishSubmit() {
    if (pickedImages.isEmpty && imageUrls.isEmpty) {
      AppSnackbar.warning(
        'Please upload an image for your post.',
        title: 'Image Required',
      );
      return;
    }

    final title = titleCtrl.text.trim();
    if (title.isEmpty) {
      formKey.currentState?.validate();
      AppSnackbar.warning(
        'Enter Title',
        title: 'Title Required',
      );
      return;
    } else if (title.length < 5) {
      formKey.currentState?.validate();
      AppSnackbar.warning(
        'Title is too short (min 5 characters)',
        title: 'Invalid Title',
      );
      return;
    }

    final desc = descCtrl.text.trim();
    if (desc.isEmpty) {
      formKey.currentState?.validate();
      AppSnackbar.warning(
        'Enter Description',
        title: 'Description Required',
      );
      return;
    } else if (desc.length < 10) {
      formKey.currentState?.validate();
      AppSnackbar.warning(
        'Description is too short (min 10 characters)',
        title: 'Invalid Description',
      );
      return;
    }

    if (moderationStatuses.values.any((s) => s == 'REJECTED')) {
      final reason = moderationReasons.values.firstWhere(
        (r) => r.isNotEmpty,
        orElse: () => 'Violates Community Guidelines',
      );
      AppSnackbar.warning(
        'Your image was rejected: $reason. Please replace it before publishing.',
        title: 'Image Rejected',
      );
      return;
    }

    if (formKey.currentState?.validate() != true) {
      return;
    }

    if (!hasConfirmedCopyrightDeclaration.value) {
      AppSnackbar.warning(
        'Please confirm the creator copyright declaration before publishing.',
        title: 'Declaration Required',
      );
      return;
    }

    publishPost(
      title: title,
      description: desc,
      tagsRaw: '',
    );
  }
}
