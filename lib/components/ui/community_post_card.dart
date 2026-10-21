import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/community_post/community_post_widgets.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/components/ui/community_post/community_post_widgets.dart';
export 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart'
    show CommunityPostCardReactionEngine, CommunityPostReactionState;
export 'package:truthworld/features/community/presentation/views/widgets/community_post_comments.dart';

/// Declarative Community Post Card
/// 100% AppTheme, Icon Guidelines Compliant, Zero setState Policy.
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    required this.post,
    super.key,
    this.onTap,
    this.isFullWidth = true,
    this.isChannelContext = false,
  });

  final CommunityPostModel post;
  final VoidCallback? onTap;
  final bool isFullWidth;
  final bool isChannelContext;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<CommunityPostController>(tag: post.id)
        ? Get.find<CommunityPostController>(tag: post.id)
        : Get.put(CommunityPostController(post: post), tag: post.id);

    return Obx(() {
      final isHidden = controller.isHidden.value;
      final isOwner = controller.currentUid != null &&
          (controller.currentUid == post.ownerId || controller.currentUid == post.channelId);

      // On channel details page, studio dashboard, saved posts, or if user is the creator,
      // NEVER hide the post from view!
      if (!isChannelContext && !isOwner && isHidden) {
        return const SizedBox.shrink();
      }

      final content = Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          border: Border(
            bottom: BorderSide(
              color: AppColors.bgDivider.withValues(alpha: 0.15),
              width: 8,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            CommunityPostHeader(
              post: post,
              onOpenOptions: () => showCommunityPostOptionsMenu(
                context,
                post,
                controller,
                isChannelContext: isChannelContext,
              ),
            ),
            const SizedBox(height: 12),

            // Post Title (if distinct from description)
            if (post.title.trim().isNotEmpty &&
                post.title.trim().toLowerCase() != 'community post' &&
                post.title.trim().toLowerCase() != post.description.trim().toLowerCase()) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: TWTypography.brandFamily,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Description Text
            CommunityPostContent(
              description: post.description,
            ),
            if (post.description.isNotEmpty && post.images.isNotEmpty)
              const SizedBox(height: 12),

            // Images Carousel
            if (post.images.isNotEmpty)
              CommunityPostImageCarousel(
                images: post.images,
              ),

            // Interaction Action Bar (Like, Dislike, Comment, Share)
            CommunityPostActionBar(
              post: post,
              controller: controller,
              onOpenComments: () => showCommunityCommentsModal(
                context,
                post,
                controller,
              ),
            ),
          ],
        ),
      );

      if (onTap != null) {
        return InkWell(
          onTap: onTap,
          child: content,
        );
      }

      return content;
    });
  }
}
