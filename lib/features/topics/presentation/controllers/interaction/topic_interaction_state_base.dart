import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';

/// Core abstract base controller holding state and subscriptions for Topic interactions.
abstract class TopicInteractionStateBase extends BaseController
    with ContentValidationMixin {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final RxInt likeCount = 0.obs;
  final RxBool isLiked = false.obs;
  final RxInt commentCount = 0.obs;

  final RxInt initialDbLikeCount = 0.obs;
  final RxBool dbIsLiked = false.obs;
  final RxBool hasCheckedInteraction = false.obs;

  final RxList<Comment> comments = <Comment>[].obs;
  final RxBool isLoadingComments = false.obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? commentsSubscription;
  String? initializedTopicId;

  // Track reply list for each comment ID
  final RxMap<String, List<Reply>> repliesMap = <String, List<Reply>>{}.obs;

  // Track user comment and reply interactions (isLiked, isDisliked)
  final RxMap<String, Map<String, bool>> userCommentInteractions =
      <String, Map<String, bool>>{}.obs;
  final RxMap<String, Map<String, bool>> userReplyInteractions =
      <String, Map<String, bool>>{}.obs;

  String get currentUserId => AuthService.to.uid;
  String get currentUserName => AuthService.to.activeDisplayName;
  String get currentUserProfilePicUrl => AuthService.to.activePhotoUrl;

  Topic? topic;

  int get displayLikeCount {
    if (!hasCheckedInteraction.value) {
      return initialDbLikeCount.value;
    }
    if (isLiked.value && !dbIsLiked.value) {
      return initialDbLikeCount.value + 1;
    }
    if (!isLiked.value && dbIsLiked.value) {
      return initialDbLikeCount.value - 1;
    }
    return initialDbLikeCount.value;
  }

  void updateLikeCount() {
    likeCount.value = displayLikeCount;
  }

  void updateInitialLikeCount(int count) {
    if (initialDbLikeCount.value != count) {
      initialDbLikeCount.value = count;
      updateLikeCount();
    }
  }

  // Cross-mixin abstract contracts
  Future<void> fetchComments(String topicId);
  void initializeTopic(Topic topic);

  @override
  void onClose() {
    commentsSubscription?.cancel();
    commentsSubscription = null;
    super.onClose();
  }
}
