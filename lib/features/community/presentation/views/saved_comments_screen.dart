import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/features/community/data/models/saved_comment_model.dart';
import 'package:truthworld/features/community/presentation/controllers/saved_comments_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class SavedCommentsScreen extends StatefulWidget {
  const SavedCommentsScreen({super.key});

  @override
  State<SavedCommentsScreen> createState() => _SavedCommentsScreenState();
}

class _SavedCommentsScreenState extends State<SavedCommentsScreen> {
  late final SavedCommentsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<SavedCommentsController>()
        ? Get.find<SavedCommentsController>()
        : Get.put(SavedCommentsController());
  }

  void _navigateToSource(SavedCommentModel comment) {
    if (comment.sourceId.isEmpty) {
      Get.snackbar('Notice', 'Source content unavailable');
      return;
    }

    final navArgs = <String, dynamic>{
      'commentId': comment.id,
      'targetCommentId': comment.id,
      'autoOpenComments': true,
      'postId': comment.sourceId,
    };

    switch (comment.sourceType) {
      case 'video':
        Get.toNamed<dynamic>('/watch/${comment.sourceId}', arguments: navArgs);
      case 'topic':
        Get.toNamed<dynamic>('/topic/${comment.sourceId}', arguments: navArgs);
      case 'community_post':
        Get.toNamed<dynamic>('/home', arguments: navArgs);
      default:
        Get.toNamed<dynamic>('/home', arguments: navArgs);
    }
  }

  IconData _getSourceIcon(String sourceType) {
    switch (sourceType) {
      case 'video':
        return Icons.play_circle_fill_rounded;
      case 'topic':
        return Icons.tag_rounded;
      case 'community_post':
        return Icons.article_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  String _getSourceLabel(String sourceType) {
    switch (sourceType) {
      case 'video':
        return 'Video Comment';
      case 'topic':
        return 'Topic Comment';
      case 'community_post':
        return 'Community Post Comment';
      default:
        return 'Comment';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          backgroundColor: AppColors.bgPage,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Get.back<void>(),
          ),
          title: Text(
            'Saved Comments',
            style: GoogleFonts.roboto(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Please sign in to view your saved comments',
            style: GoogleFonts.roboto(color: AppColors.textPrimary, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Get.back<void>(),
        ),
        title: Obx(() {
          if (controller.isSearching.value) {
            return TextField(
              autofocus: true,
              style: GoogleFonts.roboto(color: AppColors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search saved comments...',
                hintStyle: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 16),
                border: InputBorder.none,
              ),
              onChanged: controller.setSearchQuery,
            );
          }
          return Text(
            'Saved Comments',
            style: GoogleFonts.roboto(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          );
        }),
        actions: [
          Obx(() => IconButton(
            icon: Icon(
              controller.isSearching.value ? Icons.close : Icons.search,
              color: AppColors.textPrimary,
            ),
            onPressed: controller.toggleSearching,
          )),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }

        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage.value,
                  style: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.refreshComments,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  child: Text('Retry', style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        final filtered = controller.filteredComments;

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.bgSurfaceHover,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.comment_outlined,
                    size: 40,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  controller.searchQuery.value.isNotEmpty
                      ? 'No matching saved comments'
                      : 'No saved comments yet',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    controller.searchQuery.value.isNotEmpty
                        ? 'Try searching with a different keyword'
                        : 'Comments you save from Videos, Topics, or Community Posts will appear here',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            controller.refreshComments();
          },
          color: AppColors.brand,
          backgroundColor: AppColors.bgSurface,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final comment = filtered[index];
              return _buildSavedCommentTile(comment);
            },
          ),
        );
      }),
    );
  }

  Widget _buildSavedCommentTile(SavedCommentModel comment) {
    final timeStr = timeago.format(comment.savedAt);
    final iconData = _getSourceIcon(comment.sourceType);
    final sourceLabel = _getSourceLabel(comment.sourceType);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _navigateToSource(comment),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Source Type Tag + Unsave Option (Overflow Protected)
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(iconData, size: 16, color: AppColors.brand),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              sourceLabel,
                              style: GoogleFonts.roboto(
                                color: AppColors.brand,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (comment.sourceTitle.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '• ${comment.sourceTitle}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_remove_rounded, color: Colors.white70, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Unsave comment',
                      onPressed: () => controller.unsaveComment(comment.id),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Author Row
                Row(
                  children: [
                    UserAvatar(
                      radius: 12,
                      photoUrl: comment.userImage,
                      displayName: comment.userName,
                      fontSize: 10,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              comment.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeStr,
                            style: GoogleFonts.roboto(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Comment Content Text
                Text(
                  comment.text,
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // Footer: Tap to view action
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Tap to view comment',
                      style: GoogleFonts.roboto(
                        color: AppColors.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.brand),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
