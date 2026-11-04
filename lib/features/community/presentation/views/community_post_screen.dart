import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/core/services/deep_link/deep_link_url_builder_and_share.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_screen_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated single Community Post view screen (YouTube parity).
///
/// Handles deep-links from push notifications, direct post URLs (/post/:postId),
/// and comment/reply anchors with interactive targeting and highlighting.
class CommunityPostScreen extends GetView<CommunityPostScreenController> {
  const CommunityPostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Get.offNamed('/');
            }
          },
        ),
        title: Text(
          'Post',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Obx(() {
            final p = controller.post.value;
            if (p == null) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
              tooltip: 'Share Post',
              onPressed: () {
                final url = DeepLinkUrlBuilderAndShare.postUrl(p.id);
                Share.share(
                  '${p.title.isNotEmpty ? p.title : p.description}\n\n$url',
                  subject: p.title.isNotEmpty ? p.title : 'TruthWorld Community Post',
                );
              },
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          );
        }

        if (controller.errorMessage.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.postId != null) {
                        controller.loadPost(controller.postId!);
                      } else {
                        Get.offNamed('/');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        final post = controller.post.value;
        if (post == null) return const SizedBox.shrink();

        return _buildPostView(context, post);
      }),
    );
  }

  Widget _buildPostView(BuildContext context, CommunityPostModel post) {
    final postCtrl = Get.isRegistered<CommunityPostController>(tag: post.id)
        ? Get.find<CommunityPostController>(tag: post.id)
        : Get.put(CommunityPostController(post: post), tag: post.id);

    // Auto-open comments bottom sheet when arriving from a comment notification (YouTube behavior)
    final hasTargetComment = controller.targetCommentId != null || controller.targetReplyId != null;
    if (hasTargetComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted) {
              showCommunityCommentsModal(
                context,
                post,
                postCtrl,
                targetCommentId: controller.targetCommentId,
                targetReplyId: controller.targetReplyId,
              );
            }
          });
        }
      });
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            CommunityPostCard(
              post: post,
            ),
          ],
        ),
      ),
    );
  }
}
