import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Exact YouTube Studio Architecture Comment Management Page
/// Optimized for Mobile (Android/iOS) and Responsive Desktop Layouts
class DashboardCommentsPage extends StatefulWidget {
  const DashboardCommentsPage({super.key});

  @override
  State<DashboardCommentsPage> createState() => _DashboardCommentsPageState();
}

class _DashboardCommentsPageState extends State<DashboardCommentsPage>
    with SingleTickerProviderStateMixin {
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
    final bgPageColor = isDarkMode ? AppColors.bgPage : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bgPageColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          return Column(
            children: [
              // ── YouTube Studio Header Bar & Navigation Tabs ──
              _buildHeaderBar(context, isDarkMode, isMobile),

              // ── YouTube Studio Horizontal Filter Chips Toolbar ──
              _buildFilterToolbar(context, isDarkMode, isMobile),

              // ── Main Comments Stream & Desktop Layout ──
              Expanded(
                child: Obx(() {
                  if (isMobile) {
                    return _buildCommentsPane(isDarkMode, isMobile);
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Pane: Video Selector (Desktop / Tablet)
                      Container(
                        width: 320,
                        decoration: BoxDecoration(
                          color: isDarkMode ? AppColors.bgSurface : Colors.white,
                          border: Border(
                            right: BorderSide(
                              color: isDarkMode
                                  ? AppColors.bgDivider
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        child: _buildVideoSelectorPane(isDarkMode),
                      ),

                      // Right Pane: Comments Stream
                      Expanded(
                        child: _buildCommentsPane(isDarkMode, isMobile),
                      ),
                    ],
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. YOUTUBE STUDIO HEADER BAR & SUB-HEADER TABS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeaderBar(BuildContext context, bool isDarkMode, bool isMobile) {
    final bgSurface = isDarkMode ? AppColors.bgPage : Colors.white;
    final textColor = isDarkMode ? AppColors.textPrimary : Colors.black87;
    final subtitleColor = isDarkMode ? AppColors.textSecondary : Colors.grey.shade700;

    return Container(
      decoration: BoxDecoration(
        color: bgSurface,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode
                ? AppColors.bgDivider
                : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Studio Title Row
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: isMobile ? 12 : 16,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.comment_rounded,
                    color: AppColors.brand,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Channel comments',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage and reply to viewer comments across all your videos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // YouTube Studio Tabs (Published vs Held for Review)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.brand,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: isDarkMode ? AppColors.textPrimary : Colors.black,
                unselectedLabelColor: subtitleColor,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                dividerColor: Colors.transparent,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.only(right: 24, bottom: 8),
                tabs: const [
                  Tab(text: 'Published'),
                  Tab(text: 'Held for review'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. YOUTUBE STUDIO HORIZONTAL FILTER CHIPS TOOLBAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFilterToolbar(BuildContext context, bool isDarkMode, bool isMobile) {
    final bgSurface = isDarkMode ? AppColors.bgPage : Colors.grey.shade100;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: bgSurface,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode
                ? AppColors.bgDivider
                : Colors.grey.shade300,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Search Input Pill
            Container(
              height: 36,
              width: isMobile ? 180 : 220,
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.bgInput : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDarkMode
                      ? AppColors.bgDivider
                      : Colors.grey.shade400,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => controller.setSearchQuery(val),
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Search comments...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? AppColors.textTertiary : Colors.grey.shade600,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            controller.setSearchQuery('');
                          },
                          child: const Icon(
                            Icons.clear_rounded,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Filter Chips
            _buildFilterChip('all', 'All', Icons.chat_bubble_outline_rounded, isDarkMode),
            const SizedBox(width: 6),
            _buildFilterChip('unanswered', "I haven't responded", Icons.reply_rounded, isDarkMode),
            const SizedBox(width: 6),
            _buildFilterChip('answered', 'Responded', Icons.done_all_rounded, isDarkMode),
            const SizedBox(width: 6),
            _buildFilterChip('hearted', 'With Creator Heart ❤️', Icons.favorite_rounded, isDarkMode),

            // Video Filter Selector Chip for Mobile
            if (isMobile) ...[
              const SizedBox(width: 6),
              _buildMobileVideoDropdownChip(isDarkMode),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String id, String label, IconData icon, bool isDarkMode) {
    return Obx(() {
      final isSelected = _selectedFilterChip.value == id;
      return GestureDetector(
        onTap: () {
          _selectedFilterChip.value = id;
          if (id == 'answered' || id == 'unanswered' || id == 'all') {
            controller.setCommentFilter(id);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brand
                : (isDarkMode ? AppColors.bgSurface : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.brand
                  : (isDarkMode
                      ? AppColors.bgDivider
                      : Colors.grey.shade400),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isDarkMode ? AppColors.textSecondary : Colors.grey.shade700),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDarkMode ? AppColors.textPrimary : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMobileVideoDropdownChip(bool isDarkMode) {
    return Obx(() {
      final selectedId = controller.selectedVideoId.value;
      final videos = controller.videosWithComments;
      final selectedVideo = videos.firstWhereOrNull((v) => v.videoId == selectedId);

      final labelText = selectedId == null
          ? 'All Videos (${controller.allComments.length})'
          : '${selectedVideo?.title ?? "Video"} (${selectedVideo?.commentCount ?? 0})';

      return PopupMenuButton<String?>(
        tooltip: 'Filter by video',
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        onSelected: (vId) => controller.selectVideo(vId),
        itemBuilder: (context) => [
          PopupMenuItem<String?>(
            child: Row(
              children: [
                const Icon(Icons.video_library_rounded, size: 18, color: AppColors.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All Videos (${controller.allComments.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selectedId == null ? FontWeight.bold : FontWeight.normal,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          ...videos.map((video) {
            return PopupMenuItem<String?>(
              value: video.videoId,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: video.thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: video.thumbnail,
                            width: 24,
                            height: 18,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, err) =>
                                const Icon(Icons.play_circle_outline, size: 14),
                          )
                        : const Icon(Icons.ondemand_video_rounded, size: 16, color: AppColors.brand),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${video.title} (${video.commentCount})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selectedId == video.videoId ? FontWeight.bold : FontWeight.normal,
                        color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selectedId != null
                ? AppColors.brand.withValues(alpha: 0.2)
                : (isDarkMode ? AppColors.bgSurface : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selectedId != null
                  ? AppColors.brand
                  : (isDarkMode ? AppColors.bgDivider : Colors.grey.shade400),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_collection_rounded, size: 14, color: AppColors.brand),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  labelText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: isDarkMode ? AppColors.textSecondary : Colors.grey.shade700,
              ),
            ],
          ),
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. LEFT PANE: VIDEO SELECTOR (DESKTOP / TABLET)
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
                'YOUR VIDEOS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDarkMode ? AppColors.textSecondary : Colors.grey.shade700,
                ),
              ),
              Text(
                '${videos.length} videos',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? AppColors.textTertiary : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300),

        // "All Videos" Option
        ListTile(
          dense: true,
          selected: controller.selectedVideoId.value == null,
          selectedTileColor: AppColors.brand.withValues(alpha: 0.15),
          leading: const Icon(Icons.video_library_rounded, color: AppColors.brand, size: 20),
          title: Text(
            'All Videos',
            style: TextStyle(
              fontSize: 13,
              fontWeight: controller.selectedVideoId.value == null ? FontWeight.bold : FontWeight.w500,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
          subtitle: Text(
            '${controller.allComments.length} comments',
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? AppColors.textSecondary : Colors.grey.shade600,
            ),
          ),
          onTap: () => controller.selectVideo(null),
        ),
        Divider(height: 1, color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300),

        // Video list
        Expanded(
          child: ListView.separated(
            itemCount: videos.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200),
            itemBuilder: (context, index) {
              final video = videos[index];
              final isSelected = controller.selectedVideoId.value == video.videoId;

              return ListTile(
                dense: true,
                selected: isSelected,
                selectedTileColor: AppColors.brand.withValues(alpha: 0.15),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: video.thumbnail.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: video.thumbnail,
                          width: 44,
                          height: 32,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, err) =>
                              ColoredBox(color: Colors.grey.shade800, child: const Icon(Icons.play_arrow, size: 16)),
                        )
                      : ColoredBox(color: Colors.grey.shade800, child: const SizedBox(width: 44, height: 32)),
                ),
                title: Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  '${video.formattedCommentCount} • ${video.formattedViewCount} views',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDarkMode ? AppColors.textSecondary : Colors.grey.shade600,
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
  // 4. RIGHT PANE / MAIN BODY: COMMENTS STREAM
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCommentsPane(bool isDarkMode, bool isMobile) {
    if (controller.isLoadingComments.value) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }

    var comments = controller.getFilteredComments();

    // Search query filtering
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      comments = comments
          .where((c) =>
              c.text.toLowerCase().contains(query) ||
              c.displayName.toLowerCase().contains(query))
          .toList();
    }

    // Hearted filter
    if (_selectedFilterChip.value == 'hearted') {
      comments = comments.where((c) => c.isHeartedByCreator).toList();
    }

    if (comments.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: isDarkMode ? AppColors.textTertiary : Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No comments found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Try adjusting your search query or filter chips.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? AppColors.textSecondary : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 0 : 16,
        vertical: isMobile ? 0 : 12,
      ),
      itemCount: comments.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
      ),
      itemBuilder: (context, index) {
        final comment = comments[index];
        return _buildYouTubeStyleCommentCard(context, comment, isDarkMode, isMobile);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. EXACT YOUTUBE STUDIO COMMENT ITEM ARCHITECTURE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildYouTubeStyleCommentCard(
      BuildContext context, Comment comment, bool isDarkMode, bool isMobile) {
    final isLiked = controller.isCommentLikedByCreator(comment);
    final isDisliked = controller.isCommentDislikedByCreator(comment);
    final isHearted = comment.isHeartedByCreator;
    final showReplyBox = _activeReplyBoxes[comment.id] ?? false;

    // Find parent video if available
    final video = controller.videosWithComments
        .firstWhereOrNull((v) => v.videoId == comment.videoId);

    final cardBg = isDarkMode ? AppColors.bgPage : Colors.white;

    return Container(
      color: cardBg,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Video Context Bar (Thumbnail + Title Bar) ──
          if (video != null || comment.videoId.isNotEmpty) ...[
            GestureDetector(
              onTap: () {
                if (video != null) {
                  controller.selectVideo(video.videoId);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.bgSurface
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: video?.thumbnail.isNotEmpty ?? false
                          ? CachedNetworkImage(
                              imageUrl: video!.thumbnail,
                              width: 32,
                              height: 22,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, err) =>
                                  const Icon(Icons.play_circle_outline, size: 14),
                            )
                          : const Icon(Icons.ondemand_video_rounded,
                              size: 16, color: AppColors.brand),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        video?.title ?? 'Video: ${comment.videoId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                        ),
                      ),
                    ),
                    if (video != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        video.formattedCommentCount,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode ? AppColors.textTertiary : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // ── Comment Header & Body Row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Commenter Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.brand.withValues(alpha: 0.2),
                backgroundImage: comment.avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(comment.avatarUrl)
                    : null,
                child: comment.avatarUrl.isEmpty
                    ? Text(
                        comment.displayName.isNotEmpty
                            ? comment.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Comment Body & Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display Name & Time Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            comment.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          controller.formatDateTime(comment.createdAt.toDate()),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? AppColors.textTertiary : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Comment Content Text
                    Text(
                      comment.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Action Buttons Row (YouTube Studio Standard) ──
                    Row(
                      children: [
                        // Like Button
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                          icon: Icon(
                            isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                            size: 16,
                            color: isLiked
                                ? AppColors.brand
                                : (isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.grey.shade600),
                          ),
                          onPressed: () => controller.likeCommentAsChannel(
                            videoId: comment.videoId,
                            commentId: comment.id,
                            asChannel: true,
                          ),
                        ),
                        if (comment.likeCount > 0) ...[
                          Text(
                            '${comment.likeCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode ? AppColors.textSecondary : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],

                        // Dislike Button
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          icon: Icon(
                            isDisliked
                                ? Icons.thumb_down_rounded
                                : Icons.thumb_down_alt_outlined,
                            size: 16,
                            color: isDisliked
                                ? AppColors.error
                                : (isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.grey.shade600),
                          ),
                          onPressed: () => controller.dislikeCommentAsChannel(
                            videoId: comment.videoId,
                            commentId: comment.id,
                            asChannel: true,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Creator Heart ❤️ Button with Avatar Badge Overlay
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          icon: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                isHearted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 18,
                                color: isHearted
                                    ? const Color(
                                        0xFFFF2E4C) // YouTube Creator Heart Red
                                    : (isDarkMode
                                        ? AppColors.textSecondary
                                        : Colors.grey.shade600),
                              ),
                              if (isHearted)
                                Positioned(
                                  bottom: -3,
                                  right: -4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDarkMode
                                            ? AppColors.bgPage
                                            : Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 5,
                                      backgroundColor: AppColors.brand,
                                      backgroundImage: controller
                                              .userChannelAvatar.value.isNotEmpty
                                          ? CachedNetworkImageProvider(
                                              controller.userChannelAvatar.value)
                                          : null,
                                      child: controller
                                              .userChannelAvatar.value.isEmpty
                                          ? const Text(
                                              'C',
                                              style: TextStyle(
                                                fontSize: 6,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
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
                        GestureDetector(
                          onTap: () {
                            _activeReplyBoxes[comment.id] = !showReplyBox;
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.reply_rounded,
                                  size: 15,
                                  color: AppColors.brand,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'REPLY',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Options Menu
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: isDarkMode ? AppColors.textTertiary : Colors.grey.shade600,
                          ),
                          padding: EdgeInsets.zero,
                          color: isDarkMode ? AppColors.bgSurface : Colors.white,
                          onSelected: (val) {
                            Get.snackbar(
                              'Comment Action',
                              val,
                              backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.black87,
                              colorText: Colors.white,
                            );
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'Pin comment', child: Text('Pin comment')),
                            PopupMenuItem(value: 'Remove', child: Text('Remove')),
                            PopupMenuItem(
                                value: 'Report', child: Text('Report spam or abuse')),
                          ],
                        ),
                      ],
                    ),

                    // ── Creator Reply Display (If already replied) ──
                    if (comment.hasCreatorReply && comment.creatorReply != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.bgSurface
                              : Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.brand.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.mark_chat_read_rounded,
                              color: AppColors.brand,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.creatorReply!.userName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.brand,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.brand,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'CREATOR',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    comment.creatorReply!.text,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? AppColors.textPrimary
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Inline Reply Drawer ──
                    if (showReplyBox) ...[
                      const SizedBox(height: 10),
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
  // 6. INLINE REPLY DRAWER WITH QUICK CHIPS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInlineReplyDrawer(
      BuildContext context, Comment comment, bool isDarkMode) {
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
        color: isDarkMode ? AppColors.bgInput : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Suggestion Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickReplies.map((qr) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 8),
                  child: ActionChip(
                    label: Text(qr),
                    backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      color: AppColors.brand,
                      fontWeight: FontWeight.w600,
                    ),
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
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Reply publicly as channel...',
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDarkMode ? AppColors.textTertiary : Colors.grey.shade600,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDarkMode
                      ? AppColors.bgDivider
                      : Colors.grey.shade300,
                ),
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
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? AppColors.textSecondary : Colors.grey.shade700,
                  ),
                ),
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
                    Get.snackbar(
                      'Reply Sent',
                      'Publicly replied as channel',
                      backgroundColor: AppColors.brand,
                      colorText: Colors.white,
                    );
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text('Reply'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
