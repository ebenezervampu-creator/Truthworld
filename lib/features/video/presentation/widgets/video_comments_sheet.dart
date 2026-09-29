import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/flip_coin_widget.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/core/widgets/ad_widgets.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
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
                      style: GoogleFonts.roboto(
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
                            style: GoogleFonts.roboto(
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
              PremiumCommentInput(
                key: ValueKey('main_comment_input_${controller.video.id}'),
                videoId: controller.video.id,
                channelId: controller.video.channelId,
                videoTitle: controller.video.title,
                onSubmit: (text, postAsChannel, channelId) async {
                  try {
                    final authService = AuthService.to;
                    final hasChannel = authService.hasChannel.value;
                    final channel = authService.userChannel;

                    final shouldPostAsChannel = postAsChannel || hasChannel;
                    final targetChannelId = shouldPostAsChannel
                        ? (channelId ?? channel?.id)
                        : null;
                    final targetChannelName = shouldPostAsChannel
                        ? (channel?.handle.isNotEmpty ?? false
                              ? channel?.handle
                              : channel?.name)
                        : null;
                    final targetChannelAvatar = shouldPostAsChannel
                        ? channel?.avatarUrl
                        : null;
                    final targetUserAvatar = AuthService.to.activePhotoUrl;

                    await commentsController.submitComment(
                      text: text,
                      channelId: targetChannelId,
                      channelName: targetChannelName,
                      channelProfilePicUrl: targetChannelAvatar,
                      userProfilePicUrl: targetUserAvatar,
                    );
                    AppSnackbar.success('Comment posted');
                  } catch (e) {
                    ErrorHandler.log(e);
                    AppSnackbar.error('Unable to post comment. Please try again.');
                  }
                },
                onCancel: () {},
              ),
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
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Error: ${commentsController.commentsError.value}',
                style: const TextStyle(color: AppColors.textSecondary),
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
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final comment = commentsController.comments[index];
              return buildCommentItem(
                comment: comment,
                videoId: controller.video.id,
                channelAvatarUrl: controller.video.channelAvatarUrl,
                mainController: mainController,
              );
            }, childCount: commentsController.comments.length),
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
    final tag = 'video_${controller.video.id}';
    final commentsController = Get.isRegistered<CommentsController>(tag: tag)
        ? Get.find<CommentsController>(tag: tag)
        : Get.put(CommentsController(video: controller.video), tag: tag);

    showModalBottomSheet(
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
                color: Color(0xFF0F0F0F),
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
                          return Row(
                            children: [
                              Text(
                                isFlipped
                                    ? 'Counter-Arguments ($count)'
                                    : 'Comments ($count)',
                                style: GoogleFonts.roboto(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FlipCoinWidget(
                                isFlipped: isFlipped,
                                size: 28,
                                tooltip:
                                    'Flip to see Verified Counter-Arguments',
                                onTap: commentsController.toggleCounterArgumentSort,
                              ),
                            ],
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
                                    style: GoogleFonts.roboto(
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
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: commentsController.comments.length + (sponsorAd != null ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (sponsorAd != null && index == 0) {
                            return PinnedSponsorCommentCard(
                              ad: sponsorAd,
                              videoId: controller.video.id,
                              contextChannelId: controller.video.channelId,
                            );
                          }
                          final commentIndex = sponsorAd != null ? index - 1 : index;
                          final comment = commentsController.comments[commentIndex];
                          return buildCommentItem(
                            comment: comment,
                            videoId: controller.video.id,
                            channelAvatarUrl: controller.video.channelAvatarUrl,
                            mainController: mainController,
                          );
                        },
                      );
                    }),
                  ),
                  SafeArea(
                    top: false,
                    child: PremiumCommentInput(
                      key: ValueKey(
                        'popup_comment_input_${controller.video.id}',
                      ),
                      videoId: controller.video.id,
                      onSubmit: (text, postAsChannel, channelId) async {
                        try {
                          final authService = AuthService.to;
                          final hasChannel = authService.hasChannel.value;
                          final channel = authService.userChannel;

                          final shouldPostAsChannel =
                              postAsChannel || hasChannel;
                          final targetChannelId = shouldPostAsChannel
                              ? (channelId ?? channel?.id)
                              : null;
                          final targetChannelName = shouldPostAsChannel
                              ? (channel?.handle.isNotEmpty ?? false
                                    ? channel?.handle
                                    : channel?.name)
                              : null;
                          final targetChannelAvatar = shouldPostAsChannel
                              ? channel?.avatarUrl
                              : null;
                          final targetUserAvatar =
                              AuthService.to.activePhotoUrl;

                          await commentsController.submitComment(
                            text: text,
                            channelId: targetChannelId,
                            channelName: targetChannelName,
                            channelProfilePicUrl: targetChannelAvatar,
                            userProfilePicUrl: targetUserAvatar,
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
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
  }


}
