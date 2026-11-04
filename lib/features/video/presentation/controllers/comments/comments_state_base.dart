import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/repositories/firestore_comments_repository.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';
import 'package:truthworld/features/video/domain/repositories/video_comments_repository.dart';

/// Abstract base class holding reactive observables, dependencies, and lifecycle for comments.
abstract class CommentsStateBase extends BaseController
    with ContentValidationMixin {
  CommentsStateBase({
    this.video,
    this.isOffline = false,
    VideoCommentsRepository? commentsRepository,
    CommentService? commentService,
  })  : commentsRepository =
            commentsRepository ?? FirestoreCommentsRepository(),
        commentService = commentService ?? CommentService();

  final VideoCommentsRepository commentsRepository;
  final CommentService commentService;

  // Video data
  Video? video;
  @override
  bool isOffline;

  // Reactive state
  final comments = RxList<Comment>();
  final RxBool isLoadingComments = false.obs;
  final RxBool hasMoreComments = true.obs;
  final commentsError = Rx<String?>(null);
  final RxBool isSortNewest = false.obs;
  final RxBool isCounterArgumentFlipped = false.obs;

  // Reactive targets for comment/reply deep linking
  final targetCommentId = Rx<String?>(null);
  final targetReplyId = Rx<String?>(null);
  bool hasScrolledToTarget = false;

  // For creating comments
  final RxBool isSubmittingComment = false.obs;
  final commentError = Rx<String?>(null);

  // For interactions (likes/dislikes)
  final userCommentInteractions = RxMap<String, Map<String, bool>>();

  // Pagination
  static const int commentsPerPage = 25;
  final RxBool isLoadingMoreComments = false.obs;
  DocumentSnapshot? lastCommentDoc;

  // Current user info
  String? currentUserIdOverride;
  String get currentUserId => currentUserIdOverride ?? AuthService.to.uid;
  String get currentUserName => AuthService.to.activeDisplayName;

  @override
  void onInit() {
    super.onInit();
    final argCommentId =
        Get.arguments is Map ? (Get.arguments['commentId'] as String?) : null;
    final paramCommentId = Get.parameters['commentId'];
    final resolvedCommentId = (argCommentId != null && argCommentId.isNotEmpty)
        ? argCommentId
        : ((paramCommentId != null && paramCommentId.isNotEmpty)
            ? paramCommentId
            : null);
    if (resolvedCommentId != null) {
      targetCommentId.value = resolvedCommentId;
    }

    final argReplyId =
        Get.arguments is Map ? (Get.arguments['replyId'] as String?) : null;
    final paramReplyId = Get.parameters['replyId'];
    final resolvedReplyId = (argReplyId != null && argReplyId.isNotEmpty)
        ? argReplyId
        : ((paramReplyId != null && paramReplyId.isNotEmpty)
            ? paramReplyId
            : null);
    if (resolvedReplyId != null) {
      targetReplyId.value = resolvedReplyId;
    }

    if (video != null && video!.id.isNotEmpty && !isOffline) {
      initializeComments();
    }
  }

  void enableOnlineMode() {
    if (isOffline && video != null && video!.id.isNotEmpty) {
      isOffline = false;
      initializeComments();
    }
  }

  @override
  void onClose() {
    comments.clear();
    userCommentInteractions.clear();
    super.onClose();
  }

  // Cross-mixin contracts
  void initializeComments();
  void sortComments(bool newest);
  Future<void> loadMoreComments();
}
