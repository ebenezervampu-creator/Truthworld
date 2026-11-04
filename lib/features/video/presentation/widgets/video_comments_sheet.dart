import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/core/widgets/ad_widgets.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/comments/premium_comment_input.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_comment_item_widget.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet for viewing and posting video comments with comment sorting,
/// threaded replies, and premium comment inputs.
class VideoCommentsSheet {
  static bool isOpen = false;

  static List<Widget> buildCommentsSlivers({
    required BuildContext context,
    required VideoController controller,
    required MainController mainController,
  }) {
    final tag = 'video_${controller.video.id}';
    final commentsController = Get.isRegistered<CommentsController>(tag: tag)
        ? Get.find<CommentsController>(tag: tag)
        : Get.put(CommentsController(video: controller.video), tag: tag);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Obx(() {
                    final count = commentsController.comments.length;
                    return Text(
                      '$count Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }),
                  const SizedBox(width: 24),
                  PopupMenuButton<bool>(
                    onSelected: commentsController.sortComments,
                    offset: const Offset(0, 30),
                    itemBuilder: (context) =>
                        <PopupMenuEntry<bool>>[
                          PopupMenuItem<bool>(
                            value: false,
                            child: Obx(() {
                              final isSelected =
                                  !commentsController.isSortNewest.value;
                              return Row(
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Top comments'),
                                ],
                              );
                            }),
                          ),
                          PopupMenuItem<bool>(
                            value: true,
                            child: Obx(() {
                              final isSelected =
                                  commentsController.isSortNewest.value;
                              return Row(
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Newest first'),
                                ],
                              );
                            }),
                          ),
                        ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sort_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sort by',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Obx(() {
                final channelId = controller.video.channelId.isNotEmpty
                    ? controller.video.channelId
                    : controller.video.ownerId;
                final channel = ChannelMemoryCache.getReactive(channelId);
                final channelAllows = channel == null || channel.allowComments;
                final videoAllows = controller.video.allowComments;
                final allowComments = channelAllows && videoAllows;

                if (!allowComments) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.comments_disabled_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          !videoAllows
                              ? 'Comments are turned off for this video.'
                              : 'Comments are turned off for this channel.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final ch = channel ??
                    controller.channelController.selectedChannel.value;
                final isMonetized = ch != null ? ch.isMonetizationActive : controller.video.isMonetized;

                return PremiumCommentInput(
                  key: ValueKey('main_comment_input_${controller.video.id}'),
                  videoId: controller.video.id,
                  channelId: controller.video.channelId,
                  videoTitle: controller.video.title,
                  isChannelMonetized: isMonetized,
                  onSubmit: (text, postAsChannel, channelId) async {
                    try {
                      final authService = AuthService.to;
                      final hasChannel =
                          postAsChannel && authService.userChannel != null;
                      final userChannel =
                          hasChannel ? authService.userChannel : null;

                      await commentsController.submitComment(
                        text: text,
                        channelId: userChannel?.id,
                        channelName: userChannel?.name,
                        channelHandle: userChannel?.handle,
                        channelProfilePicUrl: userChannel?.avatarUrl,
                        isChannel: hasChannel,
                        userProfilePicUrl: authService.userPhotoUrl.value ??
                            authService.user?.photoURL,
                      );
                      AppSnackbar.success('Comment posted');
                    } catch (e) {
                      ErrorHandler.log(e);
                      AppSnackbar.error('Unable to post comment. Please try again.');
                    }
                  },
                  onCancel: () {},
                );
              }),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Obx(() {
          if (!Get.isRegistered<AdService>() || !AdService.to.showAds.value) {
            return const SizedBox.shrink();
          }
          final sponsorAd = AdService.to.getSponsorAdForVideo(controller.video.id);
          if (sponsorAd == null) return const SizedBox.shrink();
          return PinnedSponsorCommentCard(
              ad: sponsorAd,
              videoId: controller.video.id,
              contextChannelId: controller.video.channelId,
            );
        }),
      ),

      Obx(() {
        if (commentsController.commentsError.value != null) {
          final rawErr = commentsController.commentsError.value ?? '';
          final displayMsg = UserFeedbackSanitizer.sanitizeMessage(rawErr);
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  displayMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          );
        } else if (commentsController.isLoadingComments.value &&
            commentsController.comments.isEmpty) {
          return SliverToBoxAdapter(
            child: buildShimmerCommentList(count: 3),
          );
        } else if (commentsController.comments.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.textSecondary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No comments yet',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to comment!',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          final hasLoadMore = commentsController.hasMoreComments.value;
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index < commentsController.comments.length) {
                final comment = commentsController.comments[index];
                return buildCommentItem(
                  comment: comment,
                  videoId: controller.video.id,
                  channelAvatarUrl: controller.video.channelAvatarUrl,
                  mainController: mainController,
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: OutlinedButton(
                    onPressed: commentsController.isLoadingMoreComments.value
                        ? null
                        : commentsController.loadMoreComments,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: commentsController.isLoadingMoreComments.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Load more comments',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              );
            },
            childCount: commentsController.comments.length +
                (hasLoadMore ? 1 : 0)),
          );
        }
      }),
    ];
  }

  static Widget buildCommentItem({
    required Comment comment,
    required String videoId,
    required String channelAvatarUrl,
    required MainController mainController,
  }) {
    return CommentItemWidget(
      comment: comment,
      videoId: videoId,
      channelAvatarUrl: channelAvatarUrl,
      mainController: mainController,
      textSecondary: AppColors.textSecondary,
    );
  }

  static void show({
    required BuildContext context,
    required VideoController controller,
    required MainController mainController,
    required VoidCallback onSignInPrompt,
  }) {
    if (isOpen) return;
    isOpen = true;

    final tag = 'video_${controller.video.id}';
    final commentsController = Get.isRegistered<CommentsController>(tag: tag)
        ? Get.find<CommentsController>(tag: tag)
        : Get.put(CommentsController(video: controller.video), tag: tag);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Obx(() {
                          final count = commentsController.comments.length;
                          final isFlipped =
                              commentsController.isCounterArgumentFlipped.value;
                          return Text(
                            isFlipped
                                ? 'Counter-Arguments ($count)'
                                : 'Comments ($count)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  Expanded(
                    child: Obx(() {
                      if (commentsController.isLoadingComments.value &&
                          commentsController.comments.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.brand),
                        );
                      }
                      if (commentsController.commentsError.value != null) {
                        final rawErr = commentsController.commentsError.value ?? '';
                        final displayMsg = UserFeedbackSanitizer.sanitizeMessage(rawErr);
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              displayMsg.isNotEmpty
                                  ? displayMsg
                                  : 'Unable to load comments. Please check your connection.',
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      final sponsorAd = Get.isRegistered<AdService>() && AdService.to.showAds.value
                          ? AdService.to.getSponsorAdForVideo(controller.video.id)
                          : null;
                      if (commentsController.comments.isEmpty) {
                        return ListView(
                          controller: scrollController,
                          children: [
                            if (sponsorAd != null) PinnedSponsorCommentCard(
                              ad: sponsorAd,
                              videoId: controller.video.id,
                              contextChannelId: controller.video.channelId,
                            ),
                            const SizedBox(height: 40),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    color: AppColors.textSecondary,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No comments yet',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      final hasLoadMore = commentsController.hasMoreComments.value;
                      final totalCount = commentsController.comments.length +
                          (sponsorAd != null ? 1 : 0) +
                          (hasLoadMore ? 1 : 0);

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: totalCount,
                        itemBuilder: (context, index) {
                          if (sponsorAd != null && index == 0) {
                            return PinnedSponsorCommentCard(
                              ad: sponsorAd,
                              videoId: controller.video.id,
                              contextChannelId: controller.video.channelId,
                            );
                          }
                          final effectiveIndex =
                              sponsorAd != null ? index - 1 : index;
                          if (effectiveIndex <
                              commentsController.comments.length) {
                            final comment =
                                commentsController.comments[effectiveIndex];
                            return buildCommentItem(
                              comment: comment,
                              videoId: controller.video.id,
                              channelAvatarUrl:
                                  controller.video.channelAvatarUrl,
                              mainController: mainController,
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: OutlinedButton(
                                onPressed: commentsController
                                        .isLoadingMoreComments.value
                                    ? null
                                    : commentsController.loadMoreComments,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: BorderSide(
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.3),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: commentsController
                                        .isLoadingMoreComments.value
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Load more comments',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                  SafeArea(
                    top: false,
                    child: Obx(() {
                      final channelId = controller.video.channelId.isNotEmpty
                          ? controller.video.channelId
                          : controller.video.ownerId;
                      final channel = ChannelMemoryCache.getReactive(channelId);
                      final channelAllows = channel == null || channel.allowComments;
                      final videoAllows = controller.video.allowComments;
                      final allowComments = channelAllows && videoAllows;

                      if (!allowComments) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.comments_disabled_outlined,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    !videoAllows
                                        ? 'Comments are turned off for this video.'
                                        : 'Comments are turned off for this channel.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final ch = channel ??
                          controller.channelController.selectedChannel.value;
                      final isMonetized = ch != null ? ch.isMonetizationActive : controller.video.isMonetized;

                      return PremiumCommentInput(
                        key: ValueKey(
                          'popup_comment_input_${controller.video.id}',
                        ),
                        videoId: controller.video.id,
                        channelId: controller.video.channelId,
                        videoTitle: controller.video.title,
                        isChannelMonetized: isMonetized,
                        onSubmit: (text, postAsChannel, channelId) async {
                          try {
                            final authService = AuthService.to;
                            final hasChannel =
                                postAsChannel && authService.userChannel != null;
                            final userChannel =
                                hasChannel ? authService.userChannel : null;

                            await commentsController.submitComment(
                              text: text,
                              channelId: userChannel?.id,
                              channelName: userChannel?.name,
                              channelHandle: userChannel?.handle,
                              channelProfilePicUrl: userChannel?.avatarUrl,
                              isChannel: hasChannel,
                              userProfilePicUrl: authService.userPhotoUrl.value ??
                                  authService.user?.photoURL,
                            );
                          } catch (e, s) {
                            ErrorHandler.log(
                              e,
                              stackTrace: s,
                              tag: 'VideoCommentsSheet.submitComment',
                            );
                          }
                        },
                        onCancel: () {},
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
    ).whenComplete(() {
      isOpen = false;
    });
  }


}
