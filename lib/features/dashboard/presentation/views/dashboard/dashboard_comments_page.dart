import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';

/// Professional Dashboard Comments Page (Industry Standard)
/// 
/// Displays:
/// - Creator's videos with comment counts
/// - Comments grouped by answered/unanswered
/// - Like, dislike, reply functionality
/// - All with proper styling and error handling
class DashboardCommentsPage extends StatefulWidget {
  const DashboardCommentsPage({super.key});

  @override
  State<DashboardCommentsPage> createState() => _DashboardCommentsPageState();
}

class _DashboardCommentsPageState extends State<DashboardCommentsPage> {
  final controller = Get.put(DashboardCommentsController());
  final replyTextController = TextEditingController();

  @override
  void dispose() {
    replyTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: _buildAppBar(context),
      body: Obx(() {
        // Show error if any
        if (controller.videosError.value != null) {
          return _buildErrorWidget(controller.videosError.value!);
        }

        return Row(
          children: [
            // Left: Videos list
            Expanded(
              flex: 1,
              child: _buildVideosList(),
            ),
            // Right: Comments view showing all or filtered comments
            Expanded(
              flex: 2,
              child: _buildCommentsView(),
            ),
          ],
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bgSurface,
      elevation: 0,
      title: Text(
        'Comment Management',
        style: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIDEOS LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildVideosList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
          right: BorderSide(
            color: AppColors.bgDivider,
            width: 1,
          ),
        ),
      ),
      child: Obx(() {
        if (controller.isLoadingVideos.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.brand),
            ),
          );
        }

        if (controller.videosWithComments.isEmpty) {
          return Center(
            child: Text(
              'No videos yet',
              style: GoogleFonts.roboto(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: controller.videosWithComments.length + 1,
          separatorBuilder: (_, _) => Divider(
            color: AppColors.bgDivider,
            height: 1,
          ),
          itemBuilder: (context, index) {
            if (index == 0) {
              final isSelected = controller.selectedVideoId.value == null;
              return Material(
                color: isSelected ? AppTheme.secondaryBackground : Colors.transparent,
                child: InkWell(
                  onTap: () => controller.selectVideo(null),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          height: 50,
                          width: 80,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.video_library_rounded,
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All Videos',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final video = controller.videosWithComments[index - 1];
            final isSelected = controller.selectedVideoId.value == video.videoId;

            return Material(
              color: isSelected ? AppTheme.secondaryBackground : Colors.transparent,
              child: InkWell(
                onTap: () => controller.selectVideo(video.videoId),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          video.thumbnail,
                          height: 80,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 80,
                            color: AppTheme.secondaryBackground,
                            child: const Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Title
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${controller.formatViewCount(video.viewCount)} views',
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '💬 ${video.commentCount}',
                              style: GoogleFonts.roboto(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // COMMENTS VIEW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCommentsView() {
    return Column(
      children: [
        // Filter tabs
        _buildFilterTabs(),
        // Comments list
        Expanded(
          child: Obx(() {
            if (controller.isLoadingComments.value) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.brand),
                ),
              );
            }

            if (controller.commentsError.value != null) {
              return Center(
                child: Text(
                  controller.commentsError.value!,
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final comments = controller.getFilteredComments();

            if (comments.isEmpty) {
              return Center(
                child: Text(
                  controller.commentsFilter.value == 'all'
                      ? 'No comments yet'
                      : 'No ${controller.commentsFilter.value} comments',
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              );
            }

            return ListView.separated(
              itemCount: comments.length,
              separatorBuilder: (_, _) => Divider(
                color: AppColors.bgDivider,
                height: 1,
              ),
              itemBuilder: (context, index) => _buildCommentTile(comments[index]),
            );
          }),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTER TABS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFilterTabs() {
    return Container(
      color: AppColors.bgSurface,
      child: Obx(() => Row(
            children: [
              _buildFilterChip('all', 'All'),
              _buildFilterChip('answered', 'Answered'),
              _buildFilterChip('unanswered', 'Needs Reply'),
            ],
          )),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = controller.commentsFilter.value == value;
    return Expanded(
      child: InkWell(
        onTap: () => controller.setCommentFilter(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.brand : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
              color: isSelected
                  ? AppColors.brand
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMMENT TILE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCommentTile(Comment comment) {
    return Container(
      color: comment.hasCreatorReply
          ? AppColors.brand.withValues(alpha: 0.05)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Comment header
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(comment.userProfilePicUrl),
                  onBackgroundImageError: (_, _) => const Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '@${comment.userName}',
                            style: GoogleFonts.roboto(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (comment.channelId.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brand,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'Channel',
                                  style: GoogleFonts.roboto(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        controller.formatDateTime(comment.createdAt.toDate()),
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                if (comment.hasCreatorReply)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '✓ Answered',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  ),
                if (controller.isCommentLikedByCreator(comment))
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Liked by You',
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Comment text
            Text(
              comment.text,
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            // Interactions
            _buildInteractions(comment, comment.videoId),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMMENT INTERACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInteractions(Comment comment, String videoId) {
    final bool isLiked = controller.isCommentLikedByCreator(comment);
    final bool isDisliked = controller.isCommentDislikedByCreator(comment);

    return Row(
      children: [
        // Like Icon
        IconButton(
          icon: Icon(
            isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
            size: 18,
            color: isLiked ? AppColors.brand : AppColors.textSecondary,
          ),
          onPressed: () => controller.likeCommentAsChannel(
            videoId: videoId,
            commentId: comment.id,
            asChannel: true,
          ),
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
        ),
        if (comment.likeCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '${comment.likeCount}',
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(width: 16),
        // Dislike Icon
        IconButton(
          icon: Icon(
            isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
            size: 18,
            color: isDisliked ? Colors.red : AppColors.textSecondary,
          ),
          onPressed: () => controller.dislikeCommentAsChannel(
            videoId: videoId,
            commentId: comment.id,
            asChannel: true,
          ),
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: 16),
        // Creator Heart Avatar Badge (Overlay Style)
        if (comment.isHeartedByCreator)
          GestureDetector(
            onTap: () => controller.heartComment(
              videoId: videoId,
              commentId: comment.id,
              isHearted: false,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: CircleAvatar(
                    radius: 11,
                    backgroundImage: (comment.channelProfilePicUrl ?? '').isNotEmpty
                        ? NetworkImage(comment.channelProfilePicUrl!)
                        : null,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                    child: (comment.channelProfilePicUrl ?? '').isEmpty
                        ? const Icon(Icons.person, size: 10)
                        : null,
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      size: 10,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          // Heart Outline (to heart it)
          IconButton(
            icon: const Icon(Icons.favorite_border, size: 18),
            onPressed: () => controller.heartComment(
              videoId: videoId,
              commentId: comment.id,
              isHearted: true,
            ),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            color: AppColors.textSecondary,
          ),
        const SizedBox(width: 16),
        // Reply Text
        InkWell(
          onTap: () => _showReplyDialog(comment),
          child: Text(
            'Reply',
            style: GoogleFonts.roboto(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REPLY DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  void _showReplyDialog(Comment comment) {
    replyTextController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reply as Channel',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Original comment:',
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.secondaryBackground,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                comment.text,
                style: GoogleFonts.roboto(fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replyTextController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Type your reply...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _submitReply(comment);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
            ),
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReply(Comment comment) async {
    final replyText = replyTextController.text.trim();
    if (replyText.isEmpty) return;

    final videoId = comment.videoId;
    await controller.replyToCommentAsChannel(
      videoId: videoId,
      commentId: comment.id,
      replyText: replyText,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply posted successfully!')),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ERROR WIDGET
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            error,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => controller.onInit(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}






