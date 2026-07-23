import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Professional YouTube Studio Comment Management Page
/// Built with GetX, App Colors & Typography Design Tokens
class DashboardCommentsPage extends StatefulWidget {
  const DashboardCommentsPage({super.key});

  @override
  State<DashboardCommentsPage> createState() => _DashboardCommentsPageState();
}

class _DashboardCommentsPageState extends State<DashboardCommentsPage> with SingleTickerProviderStateMixin {
  late final DashboardCommentsController controller;
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  final RxMap<String, bool> _activeReplyBoxes = <String, bool>{}.obs;
  final RxString _selectedFilterChip = 'all'.obs;

  @override
  void initState() {
    super.initState();
    controller = Get.put(DashboardCommentsController());
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getReplyController(String commentId) {
    if (!_replyControllers.containsKey(commentId)) {
      _replyControllers[commentId] = TextEditingController();
    }
    return _replyControllers[commentId]!;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.textSecondary,
      body: Column(
        children: [
          // ── Studio Comments Top Bar & Tabs ──
          _buildHeaderBar(context, isDarkMode),

          // ── Filter Toolbar ──
          _buildFilterToolbar(context, isDarkMode),

          // ── Main Body Split View ──
          Expanded(
            child: Obx(() {
              if (controller.videosError.value != null) {
                return _buildErrorState(controller.videosError.value!);
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Pane: Video Selector
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
                      border: Border(
                        right: BorderSide(
                          color: isDarkMode ? AppColors.bgDivider : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    child: _buildVideoSelectorPane(isDarkMode),
                  ),

                  // Right Pane: Comments Stream
                  Expanded(
                    child: _buildCommentsPane(isDarkMode),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER BAR & TABS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeaderBar(BuildContext context, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? AppColors.bgDivider : AppColors.textSecondary,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.forum_rounded, color: AppColors.brand, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Channel Comments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Manage, heart, and reply to viewer comments across all videos',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? AppColors.textSecondary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Tabs (Published vs Held for Review)
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.bgInput : AppColors.textSecondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: isDarkMode ? AppColors.textSecondary : AppColors.textSecondary,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Published'),
                Tab(text: 'Held for Review'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTER TOOLBAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFilterToolbar(BuildContext context, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgPage : AppColors.textSecondary,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? AppColors.bgDivider : AppColors.textSecondary,
          ),
        ),
      ),
      child: Row(
        children: [
          // Filter Chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Comments', Icons.chat_bubble_outline_rounded, isDarkMode),
                  const SizedBox(width: 8),
                  _buildFilterChip('unanswered', "I haven't responded", Icons.reply_rounded, isDarkMode),
                  const SizedBox(width: 8),
                  _buildFilterChip('answered', 'Responded', Icons.done_all_rounded, isDarkMode),
                  const SizedBox(width: 8),
                  _buildFilterChip('hearted', 'With Creator Heart ❤️', Icons.favorite_rounded, isDarkMode),
                ],
              ),
            ),
          ),

          // Search Field
          Container(
            width: 240,
            height: 36,
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDarkMode ? AppColors.bgDivider : AppColors.textSecondary,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => controller.setSearchQuery(val),
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
              ),
              decoration: InputDecoration(
                hintText: 'Search comments...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? AppColors.textTertiary : AppColors.textSecondary,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(top: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String id, String label, IconData icon, bool isDarkMode) {
    return Obx(() {
      final isSelected = _selectedFilterChip.value == id;
      return ChoiceChip(
        avatar: Icon(icon, size: 14, color: isSelected ? AppColors.textPrimary : AppColors.brand),
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            _selectedFilterChip.value = id;
            if (id == 'answered' || id == 'unanswered' || id == 'all') {
              controller.setCommentFilter(id);
            }
          }
        },
        selectedColor: AppColors.brand,
        backgroundColor: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.textPrimary : (isDarkMode ? AppColors.textPrimary : AppColors.bgPage),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? AppColors.brand : (isDarkMode ? AppColors.bgDivider : AppColors.textSecondary),
          ),
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEFT PANE: VIDEO SELECTOR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildVideoSelectorPane(bool isDarkMode) {
    if (controller.isLoadingVideos.value) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }

    final videos = controller.videosWithComments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VIDEOS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: isDarkMode ? AppColors.textSecondary : AppColors.textSecondary,
                ),
              ),
              Text(
                '${videos.length} videos',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? AppColors.textTertiary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.bgDivider),

        // "All Videos" option
        ListTile(
          selected: controller.selectedVideoId.value == null,
          selectedTileColor: AppColors.brand.withValues(alpha: 0.15),
          leading: const Icon(Icons.video_library_rounded, color: AppColors.brand),
          title: Text(
            'All Videos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: controller.selectedVideoId.value == null ? FontWeight.bold : FontWeight.w500,
              color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
            ),
          ),
          subtitle: Text(
            '${controller.allComments.length} total comments',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? AppColors.textSecondary : AppColors.textSecondary,
            ),
          ),
          onTap: () => controller.selectVideo(null),
        ),
        const Divider(height: 1, color: AppColors.bgDivider),

        // Videos list
        Expanded(
          child: ListView.separated(
            itemCount: videos.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.bgDivider),
            itemBuilder: (context, index) {
              final video = videos[index];
              final isSelected = controller.selectedVideoId.value == video.videoId;

              return ListTile(
                selected: isSelected,
                selectedTileColor: AppColors.brand.withValues(alpha: 0.15),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: video.thumbnail.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: video.thumbnail,
                          width: 48,
                          height: 36,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, err) => Container(color: AppColors.textSecondary),
                        )
                      : Container(width: 48, height: 36, color: AppColors.textSecondary),
                ),
                title: Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
                  ),
                ),
                subtitle: Text(
                  '${video.formattedCommentCount} • ${video.formattedViewCount} views',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? AppColors.textSecondary : AppColors.textSecondary,
                  ),
                ),
                onTap: () => controller.selectVideo(video.videoId),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RIGHT PANE: COMMENTS STREAM
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCommentsPane(bool isDarkMode) {
    if (controller.isLoadingComments.value) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }

    var comments = controller.getFilteredComments();

    // Search query filtering
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      comments = comments.where((c) => c.text.toLowerCase().contains(query) || c.displayName.toLowerCase().contains(query)).toList();
    }

    // Hearted filter
    if (_selectedFilterChip.value == 'hearted') {
      comments = comments.where((c) => c.isHeartedByCreator).toList();
    }

    if (comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 56, color: isDarkMode ? AppColors.textTertiary : AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No Comments Match Criteria',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search query or filter chips.',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? AppColors.textSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return _buildYouTubeStyleCommentCard(context, comment, isDarkMode);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // YOUTUBE STUDIO STYLE COMMENT CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildYouTubeStyleCommentCard(BuildContext context, Comment comment, bool isDarkMode) {
    final isLiked = controller.isCommentLikedByCreator(comment);
    final isDisliked = controller.isCommentDislikedByCreator(comment);
    final isHearted = comment.isHeartedByCreator;
    final showReplyBox = _activeReplyBoxes[comment.id] ?? false;

    // Find parent video if available
    final video = controller.videosWithComments.firstWhereOrNull((v) => v.videoId == comment.videoId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : AppColors.textSecondary,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Video Context Header Bar ──
          if (video != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.bgInput : AppColors.textSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.ondemand_video_rounded, size: 14, color: AppColors.brand),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.textSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.brand.withValues(alpha: 0.2),
                backgroundImage: comment.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(comment.avatarUrl) : null,
                child: comment.avatarUrl.isEmpty
                    ? Text(
                        comment.displayName.isNotEmpty ? comment.displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Comment Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          controller.formatDateTime(comment.createdAt.toDate()),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? AppColors.textTertiary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Comment Body Text
                    Text(
                      comment.text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── YouTube Action Controls Row ──
                    Row(
                      children: [
                        // Like Button
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_off_alt_rounded,
                            size: 18,
                            color: isLiked ? AppColors.brand : (isDarkMode ? AppColors.textSecondary : AppColors.textSecondary),
                          ),
                          onPressed: () => controller.likeCommentAsChannel(
                            videoId: comment.videoId,
                            commentId: comment.id,
                            asChannel: true,
                          ),
                        ),
                        if (comment.likeCount > 0)
                          Text(
                            '${comment.likeCount}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? AppColors.textSecondary : AppColors.textSecondary,
                            ),
                          ),
                        const SizedBox(width: 8),

                        // Dislike Button
                        IconButton(
                          icon: Icon(
                            isDisliked ? Icons.thumb_down_alt_rounded : Icons.thumb_down_off_alt_rounded,
                            size: 18,
                            color: isDisliked ? AppColors.error : (isDarkMode ? AppColors.textSecondary : AppColors.textSecondary),
                          ),
                          onPressed: () => controller.dislikeCommentAsChannel(
                            videoId: comment.videoId,
                            commentId: comment.id,
                            asChannel: true,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Creator Heart ❤️ Button (YouTube Signature Feature!)
                        IconButton(
                          icon: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                isHearted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 20,
                                color: isHearted ? AppColors.error : (isDarkMode ? AppColors.textSecondary : AppColors.textSecondary),
                              ),
                              if (isHearted)
                                const Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 5,
                                    backgroundColor: AppColors.brand,
                                  ),
                                ),
                            ],
                          ),
                          tooltip: isHearted ? 'Hearted by creator' : 'Give Creator Heart',
                          onPressed: () => controller.heartComment(
                            videoId: comment.videoId,
                            commentId: comment.id,
                            isHearted: !isHearted,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Reply Button
                        TextButton.icon(
                          onPressed: () {
                            _activeReplyBoxes[comment.id] = !showReplyBox;
                          },
                          icon: const Icon(Icons.reply_rounded, size: 16),
                          label: const Text('REPLY'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.brand,
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),

                        const Spacer(),

                        // Options Menu
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded, size: 18, color: isDarkMode ? AppColors.textTertiary : AppColors.textSecondary),
                          color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
                          onSelected: (val) {
                            Get.snackbar('Comment Action', val, backgroundColor: AppColors.bgSurface, colorText: AppColors.textPrimary);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'Pin comment', child: Text('Pin comment')),
                            const PopupMenuItem(value: 'Remove', child: Text('Remove')),
                            const PopupMenuItem(value: 'Report', child: Text('Report spam or abuse')),
                          ],
                        ),
                      ],
                    ),

                    // ── Creator Reply Card (If already replied) ──
                    if (comment.hasCreatorReply && comment.creatorReply != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.mark_chat_read_rounded, color: AppColors.brand, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.creatorReply!.userName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.brand,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.brand,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'CREATOR',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comment.creatorReply!.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Animated Inline Reply Drawer ──
                    if (showReplyBox) ...[
                      const SizedBox(height: 12),
                      _buildInlineReplyDrawer(context, comment, isDarkMode),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INLINE REPLY DRAWER WITH QUICK CHIPS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInlineReplyDrawer(BuildContext context, Comment comment, bool isDarkMode) {
    final replyCtrl = _getReplyController(comment.id);
    final quickReplies = [
      'Thanks for watching! 🙏',
      'Appreciate the support! ❤️',
      'Great feedback, thank you!',
      'New video coming soon! 🚀',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgInput : AppColors.textSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Reply Suggestions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickReplies.map((qr) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 8),
                  child: ActionChip(
                    label: Text(qr),
                    backgroundColor: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
                    labelStyle: const TextStyle(fontSize: 11, color: AppColors.brand),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    onPressed: () {
                      replyCtrl.text = qr;
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          TextField(
            controller: replyCtrl,
            maxLines: 3,
            minLines: 1,
            style: TextStyle(fontSize: 13, color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage),
            decoration: InputDecoration(
              hintText: 'Reply publicly as channel...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDarkMode ? AppColors.bgDivider : AppColors.textSecondary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.brand),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  _activeReplyBoxes[comment.id] = false;
                  replyCtrl.clear();
                },
                child: const Text('Cancel', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  final text = replyCtrl.text.trim();
                  if (text.isNotEmpty) {
                    await controller.replyToCommentAsChannel(
                      videoId: comment.videoId,
                      commentId: comment.id,
                      replyText: text,
                    );
                    _activeReplyBoxes[comment.id] = false;
                    replyCtrl.clear();
                    Get.snackbar('Reply Sent', 'Publicly replied as channel', backgroundColor: AppColors.brand, colorText: AppColors.textPrimary);
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text('Reply'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMsg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            errorMsg,
            style: const TextStyle(fontSize: 16, color: AppColors.error),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => controller.loadCommentsForChannel(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
