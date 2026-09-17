import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
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
        color: const Color(0xFF0F0F0F),
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
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF2C2C2C),
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
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.ondemand_video_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          video?.title ?? 'Video: ${comment.videoId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (video != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          video.formattedCommentCount,
                          style: GoogleFonts.roboto(
                            fontSize: 11.5,
                            color: const Color(0xFFAAAAAA),
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
                  backgroundColor: const Color(0xFF252525),
                  textColor: Colors.white,
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
                            style: GoogleFonts.roboto(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
                                color: const Color(0xFF333333),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFF444444),
                                ),
                              ),
                              child: Text(
                                'CHANNEL',
                                style: GoogleFonts.roboto(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(comment.createdAt.toDate()),
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              color: const Color(0xFFAAAAAA),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Comment Content Text
                      Text(
                        comment.text,
                        style: GoogleFonts.roboto(
                          fontSize: 13.5,
                          height: 1.4,
                          color: Colors.white,
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
                              color: Colors.white,
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
                              style: GoogleFonts.roboto(
                                fontSize: 11,
                                color: const Color(0xFFAAAAAA),
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
                              color: Colors.white,
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
                                    backgroundColor: const Color(0xFF252525),
                                    textColor: Colors.white,
                                    fontSize: 8,
                                  ),
                                  Positioned(
                                    bottom: -3,
                                    right: -4,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF0F0F0F),
                                      ),
                                      child: Icon(
                                        isHearted
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 10,
                                        color: isHearted
                                            ? Colors.red
                                            : Colors.white,
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
                                      ? const Color(0xFF272727)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.reply_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'REPLY',
                                      style: GoogleFonts.roboto(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
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
                              color: Colors.white,
                            ),
                            padding: EdgeInsets.zero,
                            color: const Color(0xFF1E1E1E),
                            onSelected: AppSnackbar.info,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'Pin comment',
                                child: Text(
                                  'Pin comment',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'Remove',
                                child: Text(
                                  'Remove',
                                  style: GoogleFonts.roboto(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'Report',
                                child: Text(
                                  'Report spam or abuse',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
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
