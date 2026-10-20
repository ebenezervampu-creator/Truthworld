import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/content_ai_features_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/content_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/edit_videoscreen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_content_details_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Ultra-wide and desktop sticky-header sortable data table for Studio Content.
/// Replicates YouTube Studio Desktop Web tabular experience with customizable columns,
/// inline hover quick actions, and real-time column sorting.
class DesktopContentDataTable extends StatefulWidget {
  const DesktopContentDataTable({
    required this.videos,
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final List<Video> videos;
  final VideoManagementController controller;
  final bool isDarkMode;

  @override
  State<DesktopContentDataTable> createState() => _DesktopContentDataTableState();
}

enum VideoSortColumn { title, date, views, comments, likes }

class _DesktopContentDataTableState extends State<DesktopContentDataTable> {
  VideoSortColumn _sortColumn = VideoSortColumn.date;
  bool _sortAscending = false;

  // Bulk Multi-Row Selection State
  final Set<String> _selectedVideoIds = <String>{};

  bool get _allSelected =>
      widget.videos.isNotEmpty && _selectedVideoIds.length == widget.videos.length;

  bool get _isIndeterminate =>
      _selectedVideoIds.isNotEmpty && !_allSelected;

  void _toggleSelectAll(bool? select) {
    setState(() {
      if (_allSelected) {
        _selectedVideoIds.clear();
      } else {
        _selectedVideoIds.addAll(widget.videos.map((v) => v.id));
      }
    });
  }

  void _toggleSelectVideo(String videoId, bool? select) {
    setState(() {
      if (select == true) {
        _selectedVideoIds.add(videoId);
      } else {
        _selectedVideoIds.remove(videoId);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedVideoIds.clear);
  }

  // Customizable column visibility
  bool _showRestrictions = true;
  bool _showDate = true;
  bool _showViews = true;
  bool _showComments = true;
  bool _showLikes = true;

  String? _hoveredVideoId;

  List<Video> get _sortedVideos {
    final list = List<Video>.from(widget.videos);
    list.sort((a, b) {
      var cmp = 0;
      switch (_sortColumn) {
        case VideoSortColumn.title:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case VideoSortColumn.date:
          final aDate = a.createdAt.toDate();
          final bDate = b.createdAt.toDate();
          cmp = aDate.compareTo(bDate);
        case VideoSortColumn.views:
          cmp = a.views.compareTo(b.views);
        case VideoSortColumn.comments:
          cmp = a.commentCount.compareTo(b.commentCount);
        case VideoSortColumn.likes:
          cmp = a.likeCount.compareTo(b.likeCount);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  void _onSort(VideoSortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final videos = _sortedVideos;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sticky Table Header
          _buildTableHeader(context),

          // Scrollable Table Body
          Expanded(
            child: ListView.separated(
              itemCount: videos.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: AppColors.bgDivider,
              ),
              itemBuilder: (context, index) {
                final video = videos[index];
                final isHovered = _hoveredVideoId == video.id;
                final isSelected = _selectedVideoIds.contains(video.id);

                return MouseRegion(
                  onEnter: (_) => setState(() => _hoveredVideoId = video.id),
                  onExit: (_) => setState(() => _hoveredVideoId = null),
                  child: Container(
                    color: isSelected
                        ? AppColors.brand.withValues(alpha: 0.1)
                        : (isHovered
                            ? AppColors.bgSurfaceHover
                            : (index.isEven
                                ? AppColors.bgSurface
                                : const Color(0xFF1E1E1E))),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        // Row Checkbox (44px)
                        SizedBox(
                          width: 44,
                          child: Semantics(
                            label: 'Select video ${video.title}',
                            child: Checkbox(
                              value: isSelected,
                              activeColor: AppColors.brand,
                              checkColor: Colors.black,
                              onChanged: (val) => _toggleSelectVideo(video.id, val),
                            ),
                          ),
                        ),

                        // Video Info Column (Flex 5)
                        Expanded(
                          flex: 5,
                          child: _buildVideoCell(video, isHovered),
                        ),

                        // Visibility Column (Flex 2)
                        Expanded(
                          flex: 2,
                          child: _buildVisibilityCell(video),
                        ),

                        // Restrictions Column (Flex 2)
                        if (_showRestrictions)
                          Expanded(
                            flex: 2,
                            child: _buildRestrictionsCell(video),
                          ),

                        // Date Column (Flex 2)
                        if (_showDate)
                          Expanded(
                            flex: 2,
                            child: _buildDateCell(video),
                          ),

                        // Views Column (Flex 2)
                        if (_showViews)
                          Expanded(
                            flex: 2,
                            child: _buildMetricCell(
                              _formatMetric(video.views),
                              subtitle: '${_formatMetric(video.viewCount)} total',
                            ),
                          ),

                        // Comments Column (Flex 2)
                        if (_showComments)
                          Expanded(
                            flex: 2,
                            child: _buildMetricCell(
                              _formatMetric(video.commentCount),
                            ),
                          ),

                        // Likes Column (Flex 2)
                        if (_showLikes)
                          Expanded(
                            flex: 2,
                            child: _buildLikesCell(video),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Sticky Batch Action Bar
          if (_selectedVideoIds.isNotEmpty)
            _buildBatchActionBar(context, videos),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        border: Border(bottom: BorderSide(color: AppColors.bgDivider)),
      ),
      child: Row(
        children: [
          // Header Checkbox (44px)
          SizedBox(
            width: 44,
            child: Semantics(
              label: 'Select all videos',
              child: Checkbox(
                value: _allSelected ? true : (_isIndeterminate ? null : false),
                tristate: true,
                activeColor: AppColors.brand,
                checkColor: Colors.black,
                onChanged: _toggleSelectAll,
              ),
            ),
          ),

          // Video Column Header
          Expanded(
            flex: 5,
            child: _buildSortableHeaderItem(
              'Video',
              VideoSortColumn.title,
            ),
          ),

          // Visibility Column Header
          const Expanded(
            flex: 2,
            child: Text(
              'Visibility',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          // Restrictions Column Header
          if (_showRestrictions)
            const Expanded(
              flex: 2,
              child: Text(
                'Restrictions',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

          // Date Column Header
          if (_showDate)
            Expanded(
              flex: 2,
              child: _buildSortableHeaderItem(
                'Date',
                VideoSortColumn.date,
              ),
            ),

          // Views Column Header
          if (_showViews)
            Expanded(
              flex: 2,
              child: _buildSortableHeaderItem(
                'Views',
                VideoSortColumn.views,
              ),
            ),

          // Comments Column Header
          if (_showComments)
            Expanded(
              flex: 2,
              child: _buildSortableHeaderItem(
                'Comments',
                VideoSortColumn.comments,
              ),
            ),

          // Likes Column Header
          if (_showLikes)
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: _buildSortableHeaderItem(
                      'Likes (%)',
                      VideoSortColumn.likes,
                    ),
                  ),
                  _buildColumnToggleMenu(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortableHeaderItem(String label, VideoSortColumn column) {
    final isSelected = _sortColumn == column;
    final sortDirection = isSelected ? (_sortAscending ? 'ascending' : 'descending') : 'not sorted';
    return Semantics(
      button: true,
      label: 'Sort by $label, currently $sortDirection',
      child: Tooltip(
        message: 'Sort by $label',
        child: InkWell(
          onTap: () => _onSort(column),
          borderRadius: BorderRadius.circular(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isSelected ? AppColors.brand : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isSelected
                    ? (_sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 14,
                color: isSelected ? AppColors.brand : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumnToggleMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Customize columns',
      icon: const Icon(
        Icons.view_column_rounded,
        size: 16,
        color: AppColors.textSecondary,
      ),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          checked: _showRestrictions,
          value: 'restrictions',
          child: const Text('Restrictions', style: TextStyle(color: Colors.white)),
        ),
        CheckedPopupMenuItem(
          checked: _showDate,
          value: 'date',
          child: const Text('Date', style: TextStyle(color: Colors.white)),
        ),
        CheckedPopupMenuItem(
          checked: _showViews,
          value: 'views',
          child: const Text('Views', style: TextStyle(color: Colors.white)),
        ),
        CheckedPopupMenuItem(
          checked: _showComments,
          value: 'comments',
          child: const Text('Comments', style: TextStyle(color: Colors.white)),
        ),
        CheckedPopupMenuItem(
          checked: _showLikes,
          value: 'likes',
          child: const Text('Likes', style: TextStyle(color: Colors.white)),
        ),
      ],
      onSelected: (value) {
        setState(() {
          switch (value) {
            case 'restrictions':
              _showRestrictions = !_showRestrictions;
            case 'date':
              _showDate = !_showDate;
            case 'views':
              _showViews = !_showViews;
            case 'comments':
              _showComments = !_showComments;
            case 'likes':
              _showLikes = !_showLikes;
          }
        });
      },
    );
  }

  Widget _buildVideoCell(Video video, bool isHovered) {
    return Row(
      children: [
        // Thumbnail preview with Hero flight transition
        InkWell(
          onTap: () {
            Get.to<dynamic>(
              () => VideoContentDetailsScreen(
                video: video,
                isDarkMode: widget.isDarkMode,
              ),
            );
          },
          child: Hero(
            tag: 'video-thumb-${video.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  SizedBox(
                    width: 80,
                    height: 45,
                    child: video.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: video.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(color: AppColors.bgInput),
                          )
                        : Container(color: AppColors.bgInput),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        video.duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Title and description / Hover Quick Action Buttons
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  Get.to<dynamic>(
                    () => VideoContentDetailsScreen(
                      video: video,
                      isDarkMode: widget.isDarkMode,
                    ),
                  );
                },
                child: Text(
                  video.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: TWTypography.uiFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              if (isHovered)
                _buildHoverActionButtons(video)
              else
                Text(
                  video.description.isEmpty ? 'Add description' : video.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontFamily: TWTypography.uiFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHoverActionButtons(Video video) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Details',
          onTap: () {
            Get.to<dynamic>(
              () => EditVideoScreen(
                video: video,
              ),
            );
          },
        ),
        const SizedBox(width: 6),
        _buildActionIconButton(
          icon: Icons.analytics_outlined,
          tooltip: 'Analytics',
          onTap: () {
            Get.to<dynamic>(
              () => const WatchTimePage(),
              arguments: {
                'channelId': video.channelId,
                'channelName': video.channelName,
                'videoId': video.id,
              },
            );
          },
        ),
        const SizedBox(width: 6),
        _buildActionIconButton(
          icon: Icons.play_arrow_outlined,
          tooltip: 'View on TruthWorld',
          onTap: () {
            MiniplayerNavigationHelper.navigateToVideoScreen(video: video);
          },
        ),
        const SizedBox(width: 6),
        _buildActionIconButton(
          icon: Icons.auto_awesome_rounded,
          tooltip: 'AI Dubbing & Insights',
          onTap: () {
            showGenerateAIFeaturesDialog(
              context,
              video,
              widget.controller,
            );
          },
        ),
        const SizedBox(width: 6),
        _buildActionIconButton(
          icon: Icons.more_vert_rounded,
          tooltip: 'Options',
          onTap: () {
            showVideoActionOptionsModal(
              context,
              video,
              isDarkMode: widget.isDarkMode,
              controller: widget.controller,
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Icon(
              icon,
              size: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityCell(Video video) {
    final vis = video.visibility.toLowerCase();
    var badgeColor = AppColors.success;
    var icon = Icons.visibility_rounded;
    var label = 'Public';

    if (vis == 'unlisted') {
      badgeColor = AppColors.warning;
      icon = Icons.link_rounded;
      label = 'Unlisted';
    } else if (vis == 'private') {
      badgeColor = AppColors.textSecondary;
      icon = Icons.lock_outline_rounded;
      label = 'Private';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: badgeColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: TWTypography.uiFamily,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestrictionsCell(Video video) {
    final isClean = video.status != VideoStatus.rejected;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isClean ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
          size: 14,
          color: isClean ? AppColors.textSecondary : AppColors.error,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            isClean ? 'None' : 'Notice',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isClean ? AppColors.textSecondary : AppColors.error,
              fontSize: 12,
              fontFamily: TWTypography.uiFamily,
            ),
          ),
        ),
      ],
    );
  }

  String _formatMetric(int count) {
    if (count >= 1000000) {
      final val = (count / 1000000).toStringAsFixed(1);
      return '${val.endsWith(".0") ? val.substring(0, val.length - 2) : val}M';
    } else if (count >= 1000) {
      final val = (count / 1000).toStringAsFixed(1);
      return '${val.endsWith(".0") ? val.substring(0, val.length - 2) : val}K';
    }
    return count.toString();
  }

  Widget _buildDateCell(Video video) {
    final date = video.createdAt.toDate();
    final dateStr = DateFormat('MMM d, yyyy').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dateStr,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontFamily: TWTypography.uiFamily,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Published',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontFamily: TWTypography.uiFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCell(String value, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: TWTypography.uiFamily,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontFamily: TWTypography.uiFamily,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLikesCell(Video video) {
    final likes = video.likeCount;
    final totalReactions = video.likeCount + video.dislikeCount;
    final percentage = totalReactions > 0
        ? '${((likes / totalReactions) * 100).toStringAsFixed(0)}%'
        : '100%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          likes.toString(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: TWTypography.uiFamily,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$percentage likes',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontFamily: TWTypography.uiFamily,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bulk Multi-Row Operations & Sticky Batch Action Bar
  // ---------------------------------------------------------------------------

  Widget _buildBatchActionBar(BuildContext context, List<Video> allVideos) {
    final selectedVideos =
        allVideos.where((v) => _selectedVideoIds.contains(v.id)).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        border: const Border(top: BorderSide(color: AppColors.bgDivider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Checkbox & Selection Counter
          Semantics(
            label: '${_selectedVideoIds.length} videos selected',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: true,
                  activeColor: AppColors.brand,
                  checkColor: Colors.black,
                  onChanged: (_) => _clearSelection(),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_selectedVideoIds.length} selected',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: TWTypography.uiFamily,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedVideoIds.length < allVideos.length) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedVideoIds.addAll(allVideos.map((v) => v.id));
                });
              },
              child: Text(
                'Select all (${allVideos.length})',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
          const Spacer(),

          // Batch Action 1: Bulk Edit Visibility
          _buildBulkVisibilityMenu(context),
          const SizedBox(width: 10),

          // Batch Action 2: Batch AI Pipeline
          ElevatedButton.icon(
            onPressed: () {
              showBatchGenerateAIFeaturesDialog(
                context,
                selectedVideos,
                widget.controller,
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.black),
            label: const Text('Batch AI Pipeline'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Batch Action 3: Bulk Delete
          OutlinedButton.icon(
            onPressed: () => _confirmBulkDelete(context, selectedVideos),
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 16,
              color: AppColors.error,
            ),
            label: Text('Delete (${_selectedVideoIds.length})'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Batch Action 4: Clear Selection
          Semantics(
            button: true,
            label: 'Clear selection',
            child: Tooltip(
              message: 'Clear selection',
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: _clearSelection,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkVisibilityMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Change visibility for selected videos',
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined, size: 16, color: AppColors.textPrimary),
            SizedBox(width: 6),
            Text(
              'Edit Visibility',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
      onSelected: (visibility) async {
        final ids = _selectedVideoIds.toList();
        await widget.controller.batchChangeVideoVisibility(ids, visibility);
        if (mounted) {
          _clearSelection();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'public',
          child: Row(
            children: [
              Icon(Icons.public_rounded, size: 16, color: AppColors.success),
              SizedBox(width: 10),
              Text('Public', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'unlisted',
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: 16, color: AppColors.warning),
              SizedBox(width: 10),
              Text('Unlisted', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'private',
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 10),
              Text('Private', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmBulkDelete(BuildContext context, List<Video> selectedVideos) {
    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Move ${selectedVideos.length} Videos to Trash?',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontFamily: TWTypography.brandFamily,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to move ${selectedVideos.length} selected videos to Trash? Deleted items are retained for 30 days before permanent deletion.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: Get.back<void>,
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.buttonText.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      Get.back<void>();
                      await widget.controller.batchDeleteVideos(selectedVideos);
                      if (mounted) {
                        _clearSelection();
                      }
                    },
                    child: Text('Move to Trash (${selectedVideos.length})'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
