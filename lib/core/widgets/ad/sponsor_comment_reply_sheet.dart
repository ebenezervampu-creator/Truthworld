import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/ad/pinned_sponsor_comment_card.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Modal bottom sheet allowing users to review and submit comments and replies
/// directly on a sponsored pinned comment thread.
void showSponsorDiscussionModal({
  required BuildContext context,
  required AdItem ad,
  required String videoId,
}) {
  final replyController = TextEditingController();
  final isSubmitting = false.obs;
  final sponsorCommentId = 'sponsor_${ad.id}';

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
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF161616),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.campaign_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${ad.advertiser.isNotEmpty ? ad.advertiser : "Sponsor"} Discussion',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        PinnedSponsorCommentCard(
                          ad: ad,
                          videoId: videoId,
                          isInModal: true,
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Icon(
                              Icons.forum_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'User Replies & Discussion',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('videos')
                              .doc(videoId)
                              .collection('comments')
                              .doc(sponsorCommentId)
                              .collection('replies')
                              .orderBy('createdAt', descending: false)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                  horizontal: 16,
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: AppColors.textDisabled,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No replies yet',
                                      style: GoogleFonts.roboto(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Be the first to reply to ${ad.advertiser.isNotEmpty ? ad.advertiser : "our sponsor"}!',
                                      style: GoogleFonts.roboto(
                                        color: AppColors.textDisabled,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final replies = snapshot.data!.docs
                                .map(Reply.fromDocumentSnapshot)
                                .toList();

                            return Column(
                              children: replies.map((reply) {
                                final formattedTime =
                                    timeago.format(reply.createdAt.toDate());
                                final displayName =
                                    reply.channelName?.isNotEmpty == true
                                        ? reply.channelName!
                                        : (reply.userName.isNotEmpty
                                            ? reply.userName
                                            : 'Anonymous User');

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 15,
                                        backgroundColor:
                                            const Color(0xFF333333),
                                        child: Text(
                                          displayName[0].toUpperCase(),
                                          style: GoogleFonts.roboto(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  displayName,
                                                  style: GoogleFonts.roboto(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  formattedTime,
                                                  style: GoogleFonts.roboto(
                                                    color:
                                                        AppColors.textDisabled,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              reply.text,
                                              style: GoogleFonts.roboto(
                                                color: Colors.white,
                                                fontSize: 13,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 10,
                        bottom: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF161616),
                        border: Border(
                          top: BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: replyController,
                              inputFormatters:
                                  TruthworldTextInputFormatters.standard,
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Reply to ${ad.advertiser.isNotEmpty ? ad.advertiser : "sponsor"}...',
                                hintStyle: GoogleFonts.roboto(
                                  color: AppColors.textDisabled,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF242424),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Obx(() {
                            return IconButton(
                              onPressed: isSubmitting.value
                                  ? null
                                  : () async {
                                      final text = replyController.text.trim();
                                      if (text.isEmpty) return;

                                      final validation =
                                          ContentValidator.validate(
                                        text,
                                        fieldName: 'Reply',
                                      );
                                      if (!validation.isValid) {
                                        AppSnackbar.warning(validation.message);
                                        return;
                                      }

                                      isSubmitting.value = true;
                                      try {
                                        final authService =
                                            Get.isRegistered<AuthService>()
                                                ? AuthService.to
                                                : null;
                                        final currentUid = FirebaseAuth
                                                .instance.currentUser?.uid ??
                                            'anon';
                                        final userName = authService
                                                ?.activeDisplayName ??
                                            'User';
                                        final userPic =
                                            authService?.activePhotoUrl ?? '';
                                        final channel =
                                            authService?.userChannel;

                                        await CommentService().addReply(
                                          videoId: videoId,
                                          commentId: sponsorCommentId,
                                          userId: currentUid,
                                          userName: userName,
                                          userProfilePicUrl: userPic,
                                          text: text,
                                          channelId:
                                              channel?.id ?? currentUid,
                                          channelName: channel?.name,
                                          channelProfilePicUrl:
                                              channel?.avatarUrl,
                                        );

                                        replyController.clear();
                                      } catch (err) {
                                        ErrorHandler.log(err);
                                        AppSnackbar.error(
                                          'Unable to post reply. Please try again.',
                                        );
                                      } finally {
                                        isSubmitting.value = false;
                                      }
                                    },
                              icon: isSubmitting.value
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                            );
                          }),
                        ],
                      ),
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
