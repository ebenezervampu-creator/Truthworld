import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/features/video/data/models/claim_comment.dart';
import 'package:truthworld/features/video/data/services/claim_comment_service.dart';

/// 🏛 ClaimCommentsController
///
/// GetX controller managing real-time evidence-backed community notes
/// and deliberation threads anchored to video claims.
class ClaimCommentsController extends BaseController {
  final ClaimCommentService _service = ClaimCommentService.instance;

  StreamSubscription<List<ClaimComment>>? _subscription;

  final RxList<ClaimComment> comments = <ClaimComment>[].obs;
  final RxBool isLoadingComments = true.obs;
  final RxBool isSubmitting = false.obs;

  @override
  bool get isLoading => isLoadingComments.value;

  // Stance filtering ('all', 'supports', 'disputes', 'context')
  final RxString selectedStanceFilter = 'all'.obs;

  // Draft note state for submission
  final RxString newCommentStance = 'supports'.obs;
  final RxList<String> attachedSources = <String>[].obs;

  late final TextEditingController noteTextController;
  late final TextEditingController sourceUrlController;

  String currentVideoId = '';
  int? currentClaimIndex;

  @override
  void onInit() {
    super.onInit();
    noteTextController = TextEditingController();
    sourceUrlController = TextEditingController();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    noteTextController.dispose();
    sourceUrlController.dispose();
    super.onClose();
  }

  /// Initializes the real-time stream for a specific video and optional claim index.
  void initForClaim({required String videoId, int? claimIndex}) {
    if (videoId.isEmpty) return;
    if (currentVideoId == videoId && currentClaimIndex == claimIndex && _subscription != null) {
      return;
    }

    currentVideoId = videoId;
    currentClaimIndex = claimIndex;
    isLoadingComments.value = true;

    _subscription?.cancel();
    _subscription = _service
        .streamClaimComments(videoId: videoId, claimIndex: claimIndex)
        .listen(
      (data) {
        comments.assignAll(data);
        isLoadingComments.value = false;
      },
      onError: (err, stack) {
        ErrorHandler.log(
          err,
          stackTrace: stack,
          context: 'ClaimCommentsController.initForClaim',
        );
        isLoadingComments.value = false;
      },
    );
  }

  /// Filtered list of comments based on the selected stance filter.
  List<ClaimComment> get filteredComments {
    final filter = selectedStanceFilter.value;
    if (filter == 'all') return comments;
    return comments.where((c) => c.stance.toLowerCase() == filter.toLowerCase()).toList();
  }

  int get supportsCount => comments.where((c) => c.isSupports).length;
  int get disputesCount => comments.where((c) => c.isDisputes).length;
  int get contextCount => comments.where((c) => c.isContext).length;

  void setStanceFilter(String stance) {
    selectedStanceFilter.value = stance;
  }

  void setNewCommentStance(String stance) {
    newCommentStance.value = stance;
  }

  void addAttachedSource(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;

    if (!SourceUrlSanitizer.isValidSourceUrl(trimmed)) {
      AppSnackbar.error(
        'Please enter a valid, canonical web URL (e.g. https://domain.org/article).',
        title: 'Invalid Source Link',
      );
      return;
    }

    final normalized = SourceUrlSanitizer.normalizeSourceUrl(trimmed);
    if (normalized != null && !attachedSources.contains(normalized)) {
      attachedSources.add(normalized);
      sourceUrlController.clear();
    }
  }

  void removeAttachedSource(int index) {
    if (index >= 0 && index < attachedSources.length) {
      attachedSources.removeAt(index);
    }
  }

  /// Submits a new community note.
  Future<bool> submitNote({
    required String videoId,
    required int claimIndex,
    required String claimText,
  }) async {
    final text = noteTextController.text.trim();
    if (text.isEmpty) {
      AppSnackbar.error(
        'Please provide factual reasoning or context before submitting.',
        title: 'Empty Note',
      );
      return false;
    }

    if (!AuthService.to.isUserSignedIn) {
      AppSnackbar.error(
        'Please sign in to submit a community deliberation note.',
        title: 'Authentication Required',
      );
      return false;
    }

    isSubmitting.value = true;
    try {
      await _service.addClaimComment(
        videoId: videoId,
        claimIndex: claimIndex,
        claimText: claimText,
        text: text,
        stance: newCommentStance.value,
        sourceUrls: List<String>.from(attachedSources),
      );

      noteTextController.clear();
      sourceUrlController.clear();
      attachedSources.clear();
      newCommentStance.value = 'supports';

      AppSnackbar.success(
        'Your community deliberation note has been published.',
        title: 'Note Submitted',
      );
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'ClaimCommentsController.submitNote',
      );
      AppSnackbar.error(
        UserFeedbackSanitizer.sanitizeMessage(
          'Unable to submit note at this time. Please try again.',
        ),
        title: 'Submission Failed',
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Toggles whether a note was helpful or unhelpful for the user.
  Future<void> toggleHelpful(ClaimComment comment, bool isHelpful) async {
    if (!AuthService.to.isUserSignedIn) {
      AppSnackbar.error(
        'Please sign in to rate community notes.',
        title: 'Sign In Required',
      );
      return;
    }

    try {
      await _service.toggleHelpfulVote(
        videoId: comment.videoId,
        commentId: comment.id,
        isHelpful: isHelpful,
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'ClaimCommentsController.toggleHelpful',
      );
      AppSnackbar.error(
        'Unable to update your rating at this time.',
        title: 'Action Failed',
      );
    }
  }

  /// Deletes a community note.
  Future<void> deleteComment(ClaimComment comment) async {
    try {
      await _service.deleteClaimComment(
        videoId: comment.videoId,
        commentId: comment.id,
      );
      AppSnackbar.success(
        'The community note has been deleted.',
        title: 'Note Removed',
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'ClaimCommentsController.deleteComment',
      );
      AppSnackbar.error(
        'Unable to delete note at this time.',
        title: 'Action Failed',
      );
    }
  }
}
