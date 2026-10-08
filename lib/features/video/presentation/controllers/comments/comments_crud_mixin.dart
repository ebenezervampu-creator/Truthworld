import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/presentation/controllers/comments/comments_state_base.dart';

/// Mixin handling comment creation, input validation, donation records, mentions, and deletion.
mixin CommentsCrudMixin on CommentsStateBase {
  /// Submit a new comment
  Future<void> submitComment({
    required String text,
    String? channelId,
    String? channelName,
    String? channelProfilePicUrl,
    String? userProfilePicUrl,
    double donationAmount = 0.0,
    String donationCurrency = r'$',
    bool isDonatedComment = false,
    String? donationColorHex,
  }) async {
    if (text.trim().isEmpty) {
      throw Exception('Comment cannot be empty');
    }

    if (video == null) {
      throw Exception('Video not loaded');
    }

    if (!AuthService.to.isAuthenticated.value || currentUserId.isEmpty) {
      throw Exception('User not authenticated');
    }

    final validation = await validateContent(text, fieldName: 'Comment');
    if (!validation.isValid) {
      commentError.value = validation.message;
      throw Exception(validation.message);
    }

    try {
      isSubmittingComment.value = true;
      commentError.value = null;

      final authService = AuthService.to;
      final hasChannel =
          authService.hasChannel.value && authService.userChannel != null;

      final finalUserName = authService.activeDisplayName;
      final finalUserProfilePicUrl =
          userProfilePicUrl ?? authService.activePhotoUrl;
      final finalChannelId = (channelId != null && channelId.isNotEmpty)
          ? channelId
          : (hasChannel ? authService.userChannel!.id : channelId);
      final finalChannelName = (channelName != null && channelName.isNotEmpty)
          ? channelName
          : (hasChannel
                ? (authService.userChannel?.handle.isNotEmpty == true
                      ? authService.userChannel!.handle
                      : authService.userChannel!.name)
                : authService.activeDisplayName);
      final finalChannelProfilePicUrl =
          channelProfilePicUrl ?? authService.activePhotoUrl;

      // Channel Membership & Loyalty Badge lookup
      var isMember = false;
      Timestamp? memberSince;
      String? memberTierName;
      final targetChannelId = video?.channelId;
      if (targetChannelId != null && targetChannelId.isNotEmpty) {
        try {
          final memDoc = await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(currentUserId)
              .collection('channel_memberships')
              .doc(targetChannelId)
              .get();
          if (memDoc.exists && memDoc.data() != null) {
            final data = memDoc.data()!;
            final status =
                (data['status'] ?? 'active').toString().toLowerCase();
            if (status == 'active') {
              isMember = true;
              memberSince = data['joinedAt'] is Timestamp
                  ? data['joinedAt'] as Timestamp
                  : null;
              memberTierName = data['tierName'] as String?;
            }
          }
        } catch (_) {}
      }

      final commentId = await commentService.addComment(
        videoId: video!.id,
        userId: currentUserId,
        userName: finalUserName,
        userProfilePicUrl: finalUserProfilePicUrl,
        channelId: finalChannelId ?? currentUserId,
        channelName: finalChannelName,
        channelProfilePicUrl: finalChannelProfilePicUrl,
        text: text.trim(),
        donationAmount: donationAmount,
        donationCurrency: donationCurrency,
        isDonatedComment: isDonatedComment,
        donationColorHex: donationColorHex,
        isMember: isMember,
        memberSince: memberSince,
        memberTierName: memberTierName,
      );

      if (donationAmount > 0 && video?.channelId.isNotEmpty == true) {
        try {
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.channels)
              .doc(video!.channelId)
              .collection('donations')
              .add({
                'amount': donationAmount,
                'currency': donationCurrency,
                'donorId': currentUserId,
                'donorName': finalUserName,
                'videoId': video!.id,
                'commentId': commentId,
                'donatedAt': FieldValue.serverTimestamp(),
                'type': 'super_thanks',
              });
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'CommentsController.recordDonation',
          );
        }
      }

      // Note: Channel mentions for new comments are automatically processed and notified
      // by the backend onCommentCreated Firestore trigger to prevent duplicate push notifications.

      commentError.value = null;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommentsController.addComment',
      );
      commentError.value =
          'Unable to post comment. Please check your connection and try again.';
      rethrow; // Re-throw so the UI can handle it
    } finally {
      isSubmittingComment.value = false;
    }
  }

  Future<void> deleteComment(String commentId) async {
    if (video == null) return;

    try {
      await commentService.deleteComment(video!.id, commentId);
      comments.removeWhere((c) => c.id == commentId);
    } catch (e) {
      ErrorHandler.log(e, context: 'CommentsController.deleteComment');
      AppSnackbar.error('Unable to delete comment. Please try again.');
    }
  }
}
