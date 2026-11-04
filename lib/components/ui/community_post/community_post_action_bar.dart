import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/services/deep_link/deep_link_url_builder_and_share.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interaction Action Bar for Community Post Card
/// Contains Like, Dislike, Comment, and Share buttons with live counts and white icons.
class CommunityPostActionBar extends StatelessWidget {
  const CommunityPostActionBar({
    required this.post,
    required this.controller,
    required this.onOpenComments,
    super.key,
  });

  final CommunityPostModel post;
  final CommunityPostController controller;
  final VoidCallback onOpenComments;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Obx(() {
        final state = controller.reactionState.value;
        return Row(
          children: [
            // Like Button
            if (post.isLikeEnabled) ...[
              IconButton(
                icon: Icon(
                  state.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  color: Colors.white, // Rule compliance: white icon
                  size: 20,
                ),
                onPressed: controller.toggleLike,
              ),
              if (controller.showLikeCount.value)
                Text(
                  FormatUtils.formatCount(state.likes),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(width: 12),
            ],

            // Dislike Button
            if (post.isDislikeEnabled) ...[
              IconButton(
                icon: Icon(
                  state.isDisliked
                      ? Icons.thumb_down
                      : Icons.thumb_down_outlined,
                  color: Colors.white, // Rule compliance: white icon
                  size: 20,
                ),
                onPressed: controller.toggleDislike,
              ),
              if (controller.showDislikeCount.value)
                Text(
                  FormatUtils.formatCount(state.dislikes),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(width: 12),
            ],

            const Spacer(),

            // Comment Button with Icon and Text
            if (post.isCommentsEnabled) ...[
              InkWell(
                onTap: onOpenComments,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.comment_outlined,
                        color: Colors.white, // Rule compliance: white icon
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Obx(
                        () => Text(
                          FormatUtils.formatCount(
                            controller.commentCount.value,
                          ),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // Share Button with Icon and Text
            InkWell(
              onTap: () {
                ShareBottomSheet.show(
                  title: post.title.isNotEmpty ? post.title : post.description,
                  url: DeepLinkUrlBuilderAndShare.postUrl(post.id),
                  thumbnailUrl: post.images.isNotEmpty ? post.images.first : null,
                  channelName: post.channelName,
                  type: 'community_post',
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.share_outlined,
                      color: Colors.white, // Rule compliance: white icon
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post.shares.isNotEmpty
                          ? FormatUtils.formatCount(post.shares.length)
                          : 'Share',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
