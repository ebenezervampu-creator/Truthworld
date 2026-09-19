import 'package:truthworld/features/community/data/models/community_draft.dart';
import 'package:truthworld/features/community/data/models/poll_model.dart';
import 'package:truthworld/features/community/presentation/controllers/upload/community_post_upload_state_base.dart';

/// Mixin handling poll operations, draft loading, and form reset.
mixin CommunityPostPollFormMixin on CommunityPostUploadStateBase {
  /// Reset the upload form to its default state
  @override
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
    for (final sub in moderationListeners.values) {
      sub.cancel();
    }
    moderationListeners.clear();
    hasConfirmedCopyrightDeclaration.value = false;
    titleCtrl.clear();
    descCtrl.clear();
    descriptionText.value = '';

    currentDraft.value = null;
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
    titleCtrl.text = draft.title;
    descCtrl.text = draft.description;
    descriptionText.value = draft.description;
  }
}
