import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/video/data/models/reply.dart';

/// Stream-backed Replies Section for a Dashboard Comment
class DashboardRepliesStreamSection extends StatelessWidget {
  const DashboardRepliesStreamSection({
    required this.videoId,
    required this.commentId,
    required this.isMobile,
    required this.controller,
    super.key,
  });

  final String videoId;
  final String commentId;
  final bool isMobile;
  final DashboardCommentsController controller;

  @override
  Widget build(BuildContext context) {
    if (commentId.isEmpty) {
      return const SizedBox.shrink();
    }

    final targetVid = videoId.isNotEmpty
        ? videoId
        : (controller.videosWithComments.isNotEmpty
            ? controller.videosWithComments.first.videoId
            : '');

    if (targetVid.isEmpty) {
      return const SizedBox.shrink();
    }

    final repliesRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.videos)
        .doc(targetVid)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('createdAt', descending: false);

    return StreamBuilder<QuerySnapshot>(
      stream: repliesRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final replies = snapshot.data!.docs
            .map(Reply.fromDocumentSnapshot)
            .toList();

        return DashboardCommentRepliesWidget(
          replies: replies,
          videoId: targetVid,
          commentId: commentId,
          isMobile: isMobile,
          controller: controller,
        );
      },
    );
  }
}

/// Expandable Replies List Widget
/// Declarative StatelessWidget strictly enforcing Zero setState Policy.
class DashboardCommentRepliesWidget extends StatelessWidget {
  const DashboardCommentRepliesWidget({
    required this.replies,
    required this.videoId,
    required this.commentId,
    required this.isMobile,
    required this.controller,
    super.key,
  });

  final List<Reply> replies;
  final String videoId;
  final String commentId;
  final bool isMobile;
  final DashboardCommentsController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // L-shaped connecting line
        Positioned(
          left: isMobile ? -14 : -18,
          top: -6,
          bottom: 12,
          child: Container(
            width: 2,
            decoration: const BoxDecoration(
              color: Color(0xFF282828),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
              ),
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.only(
            left: isMobile ? 8 : 14,
            top: 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => controller.toggleRepliesExpanded(commentId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Obx(() {
                    final isExpanded = controller.isReplyExpanded(commentId);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Channel Mini Avatar
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
                        const SizedBox(width: 8),
                        Text(
                          '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ],
                    );
                  }),
                ),
              ),
              Obx(() {
                final isExpanded = controller.isReplyExpanded(commentId);
                return AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: replies.map(_buildSingleReplyItem).toList(),
                    ),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleReplyItem(Reply reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF282828),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            radius: 13,
            photoUrl: reply.avatarUrl,
            displayName: reply.displayName,
            backgroundColor: const Color(0xFF252525),
            textColor: Colors.white,
            fontSize: 10,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.displayName,
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    if (reply.channelId ==
                        controller.userChannelId.value) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: const Color(0xFF444444),
                          ),
                        ),
                        child: Text(
                          'CREATOR',
                          style: GoogleFonts.roboto(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(reply.createdAt.toDate()),
                      style: GoogleFonts.roboto(
                        color: const Color(0xFFAAAAAA),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.text,
                  style: GoogleFonts.roboto(
                    fontSize: 12.5,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      reply.likeCount > 0
                          ? Icons.thumb_up_rounded
                          : Icons.thumb_up_alt_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    if (reply.likeCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${reply.likeCount}',
                        style: GoogleFonts.roboto(
                          fontSize: 10.5,
                          color: const Color(0xFFAAAAAA),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
