import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Exact YouTube Studio Architecture Comment Management Page
/// 100% AppTheme, 100% AppFonts (GoogleFonts.roboto), Icon Guidelines Compliant
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
  final RxMap<String, bool> _isSubmittingReply = <String, bool>{}.obs;
  final RxString _selectedFilterChip = 'all'.obs;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<DashboardCommentsController>()
        ? Get.find<DashboardCommentsController>()
        : Get.put(DashboardCommentsController());
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        controller.setSelectedTab(_tabController.index);
      }
    });
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          return Column(
            children: [
              // ── Studio Header Bar & Navigation Tabs ──
              _buildHeaderBar(context, isMobile),

              // ── Filter Chips Toolbar ──
              _buildFilterToolbar(context, isMobile),

              // ── Main Comments Stream & Desktop Layout ──
              Expanded(
                child: Obx(() {
                  if (isMobile) {
                    return _buildCommentsPane(isMobile);
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Pane: Video Selector (Desktop / Tablet)
                      Container(
                        width: 320,
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Color(0xFF282828),
                            ),
                          ),
                        ),
                        child: Material(
                          color: const Color(0xFF0F0F0F),
                          child: _buildVideoSelectorPane(),
                        ),
                      ),

                      // Right Pane: Comments Stream
                      Expanded(
                        child: _buildCommentsPane(isMobile),
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
  // 1. HEADER BAR & SUB-HEADER TABS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeaderBar(BuildContext context, bool isMobile) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF282828),
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
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF333333),
                    ),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white, // Rule compliance: white icon
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
                        style: GoogleFonts.roboto(
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage and reply to viewer comments across all your videos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: const Color(0xFFAAAAAA),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs (Published vs Held for Review)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFFAAAAAA),
                labelStyle: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: GoogleFonts.roboto(
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
  // 2. FILTER CHIPS TOOLBAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFilterToolbar(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF282828),
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
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF383838),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => controller.setSearchQuery(val),
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Search comments...',
                  hintStyle: GoogleFonts.roboto(
                    fontSize: 12,
                    color: const Color(0xFF888888),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFFAAAAAA),
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
                            color: Color(0xFFAAAAAA),
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
            _buildFilterChip('all', 'All', null),
            const SizedBox(width: 6),
            _buildFilterChip(
              'unanswered',
              "I haven't responded",
              Icons.reply_rounded,
            ),
            const SizedBox(width: 6),
            _buildFilterChip('answered', 'Responded', Icons.check_rounded),
            const SizedBox(width: 6),
            _buildFilterChip(
              'hearted',
              'With Creator Heart ❤️',
              Icons.favorite_rounded,
            ),

            // Video Filter Selector Chip for Mobile
            if (isMobile) ...[
              const SizedBox(width: 6),
              _buildMobileVideoDropdownChip(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String id, String label, IconData? icon) {
    return Obx(() {
      final isSelected = _selectedFilterChip.value == id;
      return GestureDetector(
        onTap: () {
          _selectedFilterChip.value = id;
          controller.setCommentFilter(id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? Colors.white : const Color(0xFF383838),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.black : Colors.white,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMobileVideoDropdownChip() {
    return Obx(() {
      final selectedId = controller.selectedVideoId.value;
      final videos = controller.videosWithComments;
      final selectedVideo = videos.firstWhereOrNull(
        (v) => v.videoId == selectedId,
      );

      final labelText = selectedId == null
          ? 'All Videos (${controller.allComments.length})'
          : '${selectedVideo?.title ?? "Video"} (${selectedVideo?.commentCount ?? 0})';

      return PopupMenuButton<String?>(
        tooltip: 'Filter by video',
        color: const Color(0xFF1E1E1E),
        onSelected: (vId) => controller.selectVideo(vId),
        itemBuilder: (context) => [
          PopupMenuItem<String?>(
            child: Row(
              children: [
                const Icon(
                  Icons.video_library_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All Videos (${controller.allComments.length})',
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: selectedId == null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
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
                            errorWidget: (context, url, err) => const Icon(
                              Icons.play_circle_outline,
                              size: 14,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.ondemand_video_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${video.title} (${video.commentCount})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: selectedId == video.videoId
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: Colors.white,
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
                ? const Color(0xFF282828)
                : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selectedId != null ? Colors.white : const Color(0xFF383838),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.video_collection_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  labelText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: Color(0xFFAAAAAA),
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

  Widget _buildVideoSelectorPane() {
    if (controller.isLoadingVideos.value) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final videos = controller.videosWithComments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YOUR VIDEOS',
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: const Color(0xFFAAAAAA),
                ),
              ),
              Text(
                '${videos.length} videos',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: const Color(0xFF888888),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF282828)),

        // "All Videos" Option
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => controller.selectVideo(null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: controller.selectedVideoId.value == null
                    ? const Color(0xFF272727)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF202020),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.video_library_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Videos',
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            fontWeight: controller.selectedVideoId.value == null
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${controller.allComments.length} comments',
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: const Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFF282828)),

        // Video list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: videos.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: Color(0xFF202020)),
            itemBuilder: (context, index) {
              final video = videos[index];
              final isSelected =
                  controller.selectedVideoId.value == video.videoId;

              return InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => controller.selectVideo(video.videoId),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF272727)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: video.thumbnail.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: video.thumbnail,
                                width: 44,
                                height: 32,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, err) => Container(
                                  width: 44,
                                  height: 32,
                                  color: const Color(0xFF222222),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Container(
                                width: 44,
                                height: 32,
                                color: const Color(0xFF222222),
                                child: const Icon(
                                  Icons.ondemand_video_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                fontSize: 12.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${video.formattedCommentCount} • ${video.formattedViewCount} views',
                              style: GoogleFonts.roboto(
                                fontSize: 11,
                                color: const Color(0xFFAAAAAA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. MAIN BODY: COMMENTS STREAM
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCommentsPane(bool isMobile) {
    if (controller.isLoadingComments.value) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final comments = controller.getFilteredComments();

    if (comments.isEmpty) {
      final isHeldTab = controller.selectedTab.value == 1;

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isHeldTab
                    ? Icons.rate_review_outlined
                    : Icons.chat_bubble_outline_rounded,
                size: 48,
                color: const Color(0xFF666666),
              ),
              const SizedBox(height: 12),
              Text(
                isHeldTab
                    ? 'No comments held for review'
                    : 'No comments found',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isHeldTab
                    ? 'Comments that need review will appear here.'
                    : 'Try adjusting your search query or filter chips.',
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  color: const Color(0xFFAAAAAA),
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
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFF282828),
      ),
      itemBuilder: (context, index) {
        final comment = comments[index];
        return _buildVideoScreenStyleCommentCard(context, comment, isMobile);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. VIDEO SCREEN IDENTICAL COMMENT & REPLIES CARD ARCHITECTURE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildVideoScreenStyleCommentCard(
    BuildContext context,
    Comment comment,
    bool isMobile,
  ) {
    return Obx(() {
      final isLiked = controller.isCommentLikedByCreator(comment);
      final isDisliked = controller.isCommentDislikedByCreator(comment);
      final isHearted = comment.isHeartedByCreator;
      final showReplyBox = _activeReplyBoxes[comment.id] ?? false;

      // Find parent video if available
      final video = controller.videosWithComments.firstWhereOrNull(
        (v) => v.videoId == comment.videoId,
      );

      return Container(
        color: const Color(0xFF0F0F0F),
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
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF2C2C2C),
                    ),
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
                                errorWidget: (context, url, err) => const Icon(
                                  Icons.play_circle_outline,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.ondemand_video_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          video?.title ?? 'Video: ${comment.videoId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (video != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          video.formattedCommentCount,
                          style: GoogleFonts.roboto(
                            fontSize: 11.5,
                            color: const Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // ── Comment Header & Body Row (Exact VideoScreen ModernCommentItem) ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commenter Avatar
                UserAvatar(
                  radius: isMobile ? 18 : 20,
                  photoUrl: comment.avatarUrl,
                  displayName: comment.displayName,
                  backgroundColor: const Color(0xFF252525),
                  textColor: Colors.white,
                  fontSize: 14,
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
                          Text(
                            comment.displayName,
                            style: GoogleFonts.roboto(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (comment.channelId.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF333333),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFF444444),
                                ),
                              ),
                              child: Text(
                                'CHANNEL',
                                style: GoogleFonts.roboto(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(comment.createdAt.toDate()),
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              color: const Color(0xFFAAAAAA),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Comment Content Text
                      Text(
                        comment.text,
                        style: GoogleFonts.roboto(
                          fontSize: 13.5,
                          height: 1.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Action Buttons Row (VideoScreen Style) ──
                      Row(
                        children: [
                          // Like Button
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(
                              right: 4,
                              top: 4,
                              bottom: 4,
                            ),
                            icon: Icon(
                              isLiked
                                  ? Icons.thumb_up_rounded
                                  : Icons.thumb_up_alt_outlined,
                              size: 16,
                              color: isLiked
                                  ? Colors.white
                                  : const Color(0xFFAAAAAA),
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
                              style: GoogleFonts.roboto(
                                fontSize: 11,
                                color: const Color(0xFFAAAAAA),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ] else
                            const SizedBox(width: 8),

                          // Dislike Button
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            icon: Icon(
                              isDisliked
                                  ? Icons.thumb_down_rounded
                                  : Icons.thumb_down_alt_outlined,
                              size: 16,
                              color: isDisliked
                                  ? Colors.white
                                  : const Color(0xFFAAAAAA),
                            ),
                            onPressed: () => controller.dislikeCommentAsChannel(
                              videoId: comment.videoId,
                              commentId: comment.id,
                              asChannel: true,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Creator Heart ❤️ Badge Overlay
                          GestureDetector(
                            onTap: () => controller.heartComment(
                              videoId: comment.videoId,
                              commentId: comment.id,
                              isHearted: !isHearted,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  UserAvatar(
                                    radius: 10,
                                    photoUrl: controller.userChannelAvatar.value,
                                    displayName:
                                        controller
                                            .userChannelName
                                            .value
                                            .isNotEmpty
                                        ? controller.userChannelName.value
                                        : 'C',
                                    backgroundColor: const Color(0xFF252525),
                                    textColor: Colors.white,
                                    fontSize: 8,
                                  ),
                                  Positioned(
                                    bottom: -3,
                                    right: -4,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF0F0F0F),
                                      ),
                                      child: Icon(
                                        isHearted
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 10,
                                        color: isHearted
                                            ? Colors.red
                                            : const Color(0xFFAAAAAA),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Reply Button (Interactive Material Ripple)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                _activeReplyBoxes[comment.id] = !showReplyBox;
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: showReplyBox
                                      ? const Color(0xFF272727)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.reply_rounded,
                                      size: 15,
                                      color: Colors.white, // Rule compliance: white icon
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'REPLY',
                                      style: GoogleFonts.roboto(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const Spacer(),

                          // Options Menu
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              size: 18,
                              color: Color(0xFFAAAAAA),
                            ),
                            padding: EdgeInsets.zero,
                            color: const Color(0xFF1E1E1E),
                            onSelected: (val) {
                              Get.snackbar(
                                'Comment Action',
                                val,
                                backgroundColor: const Color(0xFF252525),
                                colorText: Colors.white,
                              );
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'Pin comment',
                                child: Text(
                                  'Pin comment',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'Remove',
                                child: Text(
                                  'Remove',
                                  style: GoogleFonts.roboto(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'Report',
                                child: Text(
                                  'Report spam or abuse',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // ── Inline Reply Drawer ──
                      if (showReplyBox) ...[
                        const SizedBox(height: 10),
                        _buildInlineReplyDrawer(context, comment),
                      ],

                      // ── Indented Replies Section (Exact VideoScreen ModernRepliesSection) ──
                      const SizedBox(height: 8),
                      _buildRepliesStreamSection(
                        comment.videoId,
                        comment.id,
                        isMobile,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. REPLIES STREAM SECTION (EXACT VIDEOSCREEN REPLIES ARCHITECTURE)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRepliesStreamSection(
    String videoId,
    String commentId,
    bool isMobile,
  ) {
    if (commentId.isEmpty) {
      return const SizedBox.shrink();
    }

    final targetVid = videoId.isNotEmpty
        ? videoId
        : (controller.videosWithComments.isNotEmpty
            ? controller.videosWithComments.first.videoId
            : '');

    if (targetVid.isEmpty) {
      return const SizedBox.shrink();
    }

    final repliesRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.videos)
        .doc(targetVid)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('createdAt', descending: false);

    return StreamBuilder<QuerySnapshot>(
      stream: repliesRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final replies = snapshot.data!.docs
            .map(Reply.fromDocumentSnapshot)
            .toList();

        return _DashboardCommentRepliesWidget(
          replies: replies,
          videoId: targetVid,
          commentId: commentId,
          isMobile: isMobile,
          controller: controller,
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. INLINE REPLY DRAWER WITH QUICK CHIPS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInlineReplyDrawer(BuildContext context, Comment comment) {
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
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF333333),
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
                    backgroundColor: const Color(0xFF252525),
                    labelStyle: GoogleFonts.roboto(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    onPressed: () {
                      replyCtrl.text = qr;
                      replyCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: replyCtrl.text.length),
                      );
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
            autofocus: true,
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'Reply publicly as channel...',
              hintStyle: GoogleFonts.roboto(
                fontSize: 12,
                color: const Color(0xFF888888),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF383838),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white),
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
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: const Color(0xFFAAAAAA),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final isSubmitting =
                    _isSubmittingReply[comment.id] ?? false;

                return ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final text = replyCtrl.text.trim();
                          if (text.isEmpty) {
                            Get.snackbar(
                              'Empty Reply',
                              'Please enter a reply message.',
                              backgroundColor: const Color(0xFF252525),
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                            return;
                          }

                          _isSubmittingReply[comment.id] = true;
                          final success =
                              await controller.replyToCommentAsChannel(
                            videoId: comment.videoId,
                            commentId: comment.id,
                            replyText: text,
                          );
                          _isSubmittingReply[comment.id] = false;

                          if (success) {
                            _activeReplyBoxes[comment.id] = false;
                            replyCtrl.clear();
                            Get.snackbar(
                              'Reply Sent',
                              'Publicly replied as channel',
                              backgroundColor: const Color(0xFF252525),
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          } else {
                            Get.snackbar(
                              'Reply Failed',
                              'Could not send reply. Please try again.',
                              backgroundColor: const Color(0xFF252525),
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          size: 14,
                          color: Colors.black,
                        ),
                  label: Text(
                    isSubmitting ? 'Sending...' : 'Reply',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXPANDABLE REPLIES LIST WIDGET MATCHING VIDEOSCREEN MODERNREPLIESSECTION
// ═════════════════════════════════════════════════════════════════════════════

class _DashboardCommentRepliesWidget extends StatefulWidget {
  const _DashboardCommentRepliesWidget({
    required this.replies,
    required this.videoId,
    required this.commentId,
    required this.isMobile,
    required this.controller,
  });

  final List<Reply> replies;
  final String videoId;
  final String commentId;
  final bool isMobile;
  final DashboardCommentsController controller;

  @override
  State<_DashboardCommentRepliesWidget> createState() =>
      _DashboardCommentRepliesWidgetState();
}

class _DashboardCommentRepliesWidgetState
    extends State<_DashboardCommentRepliesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;
  final RxBool _isExpanded = false.obs;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expansionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // L-shaped connecting line
        Positioned(
          left: widget.isMobile ? -14 : -18,
          top: -6,
          bottom: 12,
          child: Container(
            width: 2,
            decoration: const BoxDecoration(
              color: Color(0xFF282828),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
              ),
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.only(
            left: widget.isMobile ? 8 : 14,
            top: 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  _isExpanded.value = !_isExpanded.value;
                  if (_isExpanded.value) {
                    _expansionController.forward();
                  } else {
                    _expansionController.reverse();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Obx(() {
                    final isExpanded = _isExpanded.value;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Channel Mini Avatar
                        UserAvatar(
                          radius: 10,
                          photoUrl: widget.controller.userChannelAvatar.value,
                          displayName:
                              widget.controller.userChannelName.value.isNotEmpty
                              ? widget.controller.userChannelName.value
                              : 'C',
                          backgroundColor: const Color(0xFF252525),
                          textColor: Colors.white,
                          fontSize: 8,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.replies.length} ${widget.replies.length == 1 ? 'reply' : 'replies'}',
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: const Color(0xFFAAAAAA),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              SizeTransition(
                sizeFactor: _expansionAnimation,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: widget.replies
                        .map(_buildSingleReplyItem)
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleReplyItem(Reply reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF282828),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            radius: 13,
            photoUrl: reply.avatarUrl,
            displayName: reply.displayName,
            backgroundColor: const Color(0xFF252525),
            textColor: Colors.white,
            fontSize: 10,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.displayName,
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    if (reply.channelId ==
                        widget.controller.userChannelId.value) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: const Color(0xFF444444),
                          ),
                        ),
                        child: Text(
                          'CREATOR',
                          style: GoogleFonts.roboto(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(reply.createdAt.toDate()),
                      style: GoogleFonts.roboto(
                        color: const Color(0xFFAAAAAA),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.text,
                  style: GoogleFonts.roboto(
                    fontSize: 12.5,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      reply.likeCount > 0
                          ? Icons.thumb_up_rounded
                          : Icons.thumb_up_alt_outlined,
                      size: 14,
                      color: const Color(0xFFAAAAAA),
                    ),
                    if (reply.likeCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${reply.likeCount}',
                        style: GoogleFonts.roboto(
                          fontSize: 10.5,
                          color: const Color(0xFFAAAAAA),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
