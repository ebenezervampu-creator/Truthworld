import 'package:truthworld/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/core/widgets/ad/ad_card_controller.dart';
import 'package:truthworld/core/widgets/ad/sponsor_comment_reply_sheet.dart';

/// Pinned sponsor comment card presented at the top of comment sections,
/// featuring verified advertiser badge, promotional copy, and CTA navigation.
class PinnedSponsorCommentCard extends StatelessWidget {
  const PinnedSponsorCommentCard({
    required this.ad,
    this.videoId,
    this.contextChannelId = '',
    this.onOpenDiscussion,
    this.isInModal = false,
    super.key,
  });

  final AdItem ad;
  final String? videoId;

  /// The channel this comment is pinned on. Used for 70% ad revenue attribution.
  final String contextChannelId;
  final VoidCallback? onOpenDiscussion;
  final bool isInModal;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<AdService>()) {
        try {
          AdService.to.recordImpression(
            ad.id,
            adType: 'comment',
            channelId: contextChannelId,
          );
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'PinnedSponsorCommentCard.impression',
          );
        }
      }
    });


    final commentText = ad.pinnedCommentText?.isNotEmpty == true
        ? ad.pinnedCommentText!
        : 'Welcome viewers! Feel free to ask us any questions or check out our exclusive offer!';

    final sponsorCommentId = 'sponsor_${ad.id}';
    final targetVideoId = videoId ?? ad.videoId ?? 'default_video';

    return InkWell(
      onTap: isInModal
          ? null
          : (onOpenDiscussion ??
              () => showSponsorDiscussionModal(
                    context: context,
                    ad: ad,
                    videoId: targetVideoId,
                  )),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isInModal ? 0 : 16,
          vertical: isInModal ? 4 : 8,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pinned Header
            Row(
              children: [
                const Icon(
                  Icons.push_pin_rounded,
                  size: 13,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  'Pinned Sponsor',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildAdvertiserLogoAvatar(ad),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            ad.advertiser.isNotEmpty
                                ? ad.advertiser
                                : 'Official Sponsor',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF1D9BF0).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SPONSOR',
                              style: TextStyle(
                                color: const Color(0xFF1D9BF0),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClickableUrlText(
                        text: commentText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      if (ad.ctaText.isNotEmpty && ad.ctaTarget.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => AdService.to.launchCtaUrl(ad),
                          child: Text(
                            '${ad.ctaText} →',
                            style: TextStyle(
                              color: const Color(0xFF1D9BF0),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (!isInModal) ...[
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('videos')
                    .doc(targetVideoId)
                    .collection('comments')
                    .doc(sponsorCommentId)
                    .collection('replies')
                    .snapshots(),
                builder: (context, snapshot) {
                  final replyCount =
                      snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        replyCount == 0
                            ? 'Reply to Sponsor'
                            : '$replyCount ${replyCount == 1 ? "Reply" : "Replies"}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
