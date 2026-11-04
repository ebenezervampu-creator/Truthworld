import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/video/presentation/controllers/comments/comments_state_base.dart';

/// Mixin handling comment creation, input validation, donation records, mentions, and deletion.
mixin CommentsCrudMixin on CommentsStateBase {
  /// Submit a new comment
  Future<void> submitComment({
    required String text,
    String? channelId,
    String? channelName,
    String? channelHandle,
    String? channelProfilePicUrl,
    String? userProfilePicUrl,
    bool? isChannel,
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

    if (!video!.allowComments) {
      AppSnackbar.info('Comments are turned off for this video.');
      return;
    }

    if (!AuthService.to.isAuthenticated.value || currentUserId.isEmpty) {
      throw Exception('User not authenticated');
    }

    final validation = await validateContent(
      text,
      fieldName: 'Comment',
      maxLength: ContentValidator.defaultMaxCommentLength,
    );
    if (!validation.isValid) {
      commentError.value = validation.message;
      throw Exception(validation.message);
    }

    if (isDonatedComment || donationAmount > 0) {
      final chId = video?.channelId ?? '';
      final ch = chId.isNotEmpty ? ChannelMemoryCache.get(chId) : null;
      final monetized = ch != null ? ch.isMonetizationActive : (video?.isMonetized ?? false);
      if (!monetized) {
        throw Exception('Super Thanks and super chats are only allowed on monetized channels.');
      }
    }

    try {
      isSubmittingComment.value = true;
      commentError.value = null;

      final authService = AuthService.to;
      final hasActiveChannel = isChannel ??
          (authService.hasChannel.value && authService.userChannel != null);
      final userChannel = hasActiveChannel ? authService.userChannel : null;

      final resolvedChannelId = (channelId != null && channelId.isNotEmpty)
          ? channelId
          : (userChannel?.id ?? '');
      final resolvedChannelHandle =
          (channelHandle != null && channelHandle.isNotEmpty)
              ? channelHandle
              : userChannel?.handle;
      final resolvedChannelName =
          (channelName != null && channelName.isNotEmpty)
              ? channelName
              : userChannel?.name;
      final resolvedChannelProfilePicUrl =
          (channelProfilePicUrl != null && channelProfilePicUrl.isNotEmpty)
              ? channelProfilePicUrl
              : userChannel?.avatarUrl;

      final rawName = authService.userDisplayName.value ??
          authService.user?.displayName ??
          'User';
      final finalUserName =
          rawName.startsWith('@') ? rawName.substring(1) : rawName;
      final finalUserProfilePicUrl = userProfilePicUrl ??
          authService.userPhotoUrl.value ??
          authService.user?.photoURL ??
          '';

      // Channel Membership & Loyalty Badge lookup
      var isMember = false;
      Timestamp? memberSince;
      String? memberTierName;
      final targetChannelId = video?.channelId;
      if (targetChannelId != null && targetChannelId.isNotEmpty) {
        if (isDonatedComment || donationAmount > 0) {
      final chId = video?.channelId ?? '';
      final ch = chId.isNotEmpty ? ChannelMemoryCache.get(chId) : null;
      final monetized = ch != null ? ch.isMonetizationActive : (video?.isMonetized ?? false);
      if (!monetized) {
        throw Exception('Super Thanks and super chats are only allowed on monetized channels.');
      }
    }

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
        channelId: resolvedChannelId,
        channelName: resolvedChannelName,
        channelHandle: resolvedChannelHandle,
        channelProfilePicUrl: resolvedChannelProfilePicUrl,
        isChannel: hasActiveChannel,
        text: ContentValidator.cleanProfanity(text.trim()),
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
