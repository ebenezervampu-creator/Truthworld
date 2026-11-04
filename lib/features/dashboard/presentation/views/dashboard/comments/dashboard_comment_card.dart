import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/comments/dashboard_comment_replies_section.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/comments/dashboard_comment_reply_drawer.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Studio Comment Card
/// Displays comment with video association context, user info, actions, inline reply drawer, and replies stream.
class DashboardCommentCard extends StatelessWidget {
  const DashboardCommentCard({
    required this.comment,
    required this.isMobile,
    required this.controller,
    super.key,
  });

  final Comment comment;
  final bool isMobile;
  final DashboardCommentsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLiked = controller.isCommentLikedByCreator(comment);
      final isDisliked = controller.isCommentDislikedByCreator(comment);
      final isHearted = comment.isHeartedByCreator;
      final showReplyBox = controller.activeReplyBoxes[comment.id] ?? false;

      // Find parent video if available
      final video = controller.videosWithComments.firstWhereOrNull(
        (v) => v.videoId == comment.videoId,
      );

      return Container(
        color: AppColors.bgPage,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Context Bar (Thumbnail + Title Bar)
            if (video != null || comment.videoId.isNotEmpty) ...[
              GestureDetector(
                onTap: () {
                  if (video != null) {
                    controller.selectVideo(video.videoId);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.bgDivider,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: video?.thumbnail.isNotEmpty ?? false
                            ? CachedNetworkImage(
                                imageUrl: video!.thumbnail,
                                width: 32,
                                height: 22,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, err) => const Icon(
                                  Icons.play_circle_outline,
                                  size: 14,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : const Icon(
                                Icons.ondemand_video_rounded,
                                size: 16,
                                color: AppColors.textPrimary,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          video?.title ?? 'Video: ${comment.videoId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (video != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          video.formattedCommentCount,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Comment Header & Body Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  radius: isMobile ? 18 : 20,
                  photoUrl: comment.avatarUrl,
                  displayName: comment.displayName,
                  backgroundColor: AppColors.bgSurface,
                  textColor: AppColors.textPrimary,
                  fontSize: 14,
                ),
                const SizedBox(width: 12),

                // Comment Body & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Author Row
                      Row(
                        children: [
                          Text(
                            comment.displayName,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (comment.channelId ==
                              controller.userChannelId.value) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.bgDivider,
                                ),
                              ),
                              child: const Text(
                                'CHANNEL',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontFamilyFallback: TWTypography.fallbackFamilies,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(comment.createdAt.toDate()),
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Comment Content Text
                      ClickableUrlText(
                        text: comment.text,
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: 13.5,
                          height: 1.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Action Buttons Row
                      Row(
                        children: [
                          // Like Button
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(
                              right: 4,
                              top: 4,
                              bottom: 4,
                            ),
                            icon: Icon(
                              isLiked
                                  ? Icons.thumb_up_rounded
                                  : Icons.thumb_up_alt_outlined,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () => controller.likeCommentAsChannel(
                              videoId: comment.videoId,
                              commentId: comment.id,
                              asChannel: true,
                            ),
                          ),
                          if (comment.likeCount > 0) ...[
                            Text(
                              '${comment.likeCount}',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontFamilyFallback: TWTypography.fallbackFamilies,
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ] else
                            const SizedBox(width: 8),

                          // Dislike Button
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            icon: Icon(
                              isDisliked
                                  ? Icons.thumb_down_rounded
                                  : Icons.thumb_down_alt_outlined,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () => controller.dislikeCommentAsChannel(
                              videoId: comment.videoId,
                              commentId: comment.id,
                              asChannel: true,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Creator Heart Badge Overlay
                          GestureDetector(
                            onTap: () => controller.heartComment(
                              videoId: comment.videoId,
                              commentId: comment.id,
                              isHearted: !isHearted,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  UserAvatar(
                                    radius: 10,
                                    photoUrl: controller.userChannelAvatar.value,
                                    displayName:
                                        controller.userChannelName.value.isNotEmpty
                                            ? controller.userChannelName.value
                                            : 'C',
                                    backgroundColor: AppColors.bgSurface,
                                    textColor: AppColors.textPrimary,
                                    fontSize: 8,
                                  ),
                                  Positioned(
                                    bottom: -3,
                                    right: -4,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.bgPage,
                                      ),
                                      child: Icon(
                                        isHearted
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 10,
                                        color: isHearted
                                            ? AppColors.error
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Reply Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => controller.toggleReplyBox(comment.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: showReplyBox
                                      ? AppColors.bgSurfaceHover
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.reply_rounded,
                                      size: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'REPLY',
                                      style: TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        fontFamilyFallback: TWTypography.fallbackFamilies,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const Spacer(),

                          // Options Menu
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              size: 18,
                              color: AppColors.textPrimary,
                            ),
                            padding: EdgeInsets.zero,
                            color: AppColors.bgSurface,
                            onSelected: AppSnackbar.info,
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'Pin comment',
                                child: Text(
                                  'Pin comment',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontFamilyFallback: TWTypography.fallbackFamilies,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'Remove',
                                child: Text(
                                  'Remove',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontFamilyFallback: TWTypography.fallbackFamilies,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'Report',
                                child: Text(
                                  'Report spam or abuse',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontFamilyFallback: TWTypography.fallbackFamilies,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Inline Reply Drawer
                      if (showReplyBox) ...[
                        const SizedBox(height: 10),
                        DashboardCommentReplyDrawer(
                          comment: comment,
                          controller: controller,
                        ),
                      ],

                      // Indented Replies Section
                      const SizedBox(height: 8),
                      DashboardRepliesStreamSection(
                        videoId: comment.videoId,
                        commentId: comment.id,
                        isMobile: isMobile,
                        controller: controller,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
