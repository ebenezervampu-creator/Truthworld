import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/community/presentation/controllers/upload/community_post_upload_barrel.dart';

export 'package:truthworld/features/community/presentation/controllers/upload/community_post_upload_barrel.dart';

/// Dedicated GetX controller for the **Community Post Upload** flow.
///
/// Supports:
/// - Single-image picking (1 image, any aspect ratio)
/// - Parallel image uploads with progress tracking and real-time moderation
/// - Polls (Yes/No or Multi-Choice with 3–5 options)
/// - Content validation via [ContentValidationMixin]
/// - Draft persistence and instant publishing
class CommunityPostUploadController extends CommunityPostUploadStateBase
    with
        CommunityPostChannelTopicMixin,
        CommunityPostImagesMixin,
        CommunityPostPollFormMixin,
        CommunityPostPublishMixin {
  @override
  void onInit() {
    super.onInit();
    final authService = AuthService.to;
    if (authService.hasChannel.value) {
      selectedChannel.value = authService.userChannel;
    }
    fetchChannelsForCommunity();
    fetchAvailableTopics();
  }

  @override
  void onClose() {
    for (final sub in moderationListeners.values) {
      sub.cancel();
    }
    super.onClose();
  }
}
