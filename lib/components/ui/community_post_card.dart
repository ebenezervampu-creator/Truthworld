import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/community_post/community_post_widgets.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart';
import 'package:truthworld/features/community/presentation/views/widgets/community_post_comments.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/components/ui/community_post/community_post_widgets.dart';
export 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart'
    show CommunityPostCardReactionEngine, CommunityPostReactionState;
export 'package:truthworld/features/community/presentation/views/widgets/community_post_comments.dart';

// Backward compatibility aliases
typedef _CommunityCommentItemWidget = CommunityCommentItemWidget;
typedef _CommunityReplyItem = CommunityReplyItem;

/// Declarative Community Post Card
/// 100% AppTheme, Icon Guidelines Compliant, Zero setState Policy.
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    required this.post,
    super.key,
    this.onTap,
    this.isFullWidth = true,
  });

  final CommunityPostModel post;
  final VoidCallback? onTap;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<CommunityPostController>(tag: post.id)
        ? Get.find<CommunityPostController>(tag: post.id)
        : Get.put(CommunityPostController(post: post), tag: post.id);

    return Obx(() {
      if (controller.isHidden.value) {
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
              ),
            ),
            const SizedBox(height: 12),

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
