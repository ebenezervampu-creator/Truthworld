import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/data/models/draft_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/drafts_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Screen displaying video and community post drafts in Creator Studio.
class DraftsScreen extends StatelessWidget {
  const DraftsScreen({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });

  final String channelId;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.colors.background,
        body: const Center(
          child: Text(
            'You must be logged in to view drafts.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final controller = Get.isRegistered<DraftsController>()
        ? Get.find<DraftsController>()
        : Get.put(DraftsController(channelId: channelId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          backgroundColor: AppColors.bgPage,
          elevation: 0,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: Row(
            children: [
              const Icon(
                Icons.drafts_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Drafts Manager',
                style: AppTextStyles.titleLarge.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.bgDivider),
                ),
              ),
              child: TabBar(
                indicatorColor: AppColors.brand,
                indicatorWeight: 3,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: TWTypography.brandFamily,
                ),
                unselectedLabelStyle: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.video_library_rounded, size: 18),
                    text: 'Video Drafts',
                  ),
                  Tab(
                    icon: Icon(Icons.article_rounded, size: 18),
                    text: 'Community Drafts',
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildDraftsTab(context, controller, isVideo: true),
            _buildDraftsTab(context, controller, isVideo: false),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftsTab(
    BuildContext context,
    DraftsController controller, {
    required bool isVideo,
  }) {
    return Obx(() {
      if (controller.isLoading && (isVideo ? controller.videoDrafts.isEmpty : controller.communityDrafts.isEmpty)) {
        return const StudioLoadingIndicator(
          message: 'Loading drafts...',
        );
      }

      final drafts =
          isVideo ? controller.videoDrafts : controller.communityDrafts;

      if (drafts.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isVideo
                      ? Icons.video_library_outlined
                      : Icons.article_outlined,
                  size: 72,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(height: 16),
                Text(
                  isVideo ? 'No Video Drafts' : 'No Community Drafts',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVideo
                      ? 'Saved video drafts will appear here.'
                      : 'Saved community post drafts will appear here.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      return RefreshIndicator(
        color: AppColors.brand,
        backgroundColor: AppColors.bgSurface,
        onRefresh: () => controller.loadDrafts(),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: drafts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildDraftCard(context, controller, drafts[index]);
          },
        ),
      );
    });
  }

  Widget _buildDraftCard(
    BuildContext context,
    DraftsController controller,
    DraftModel draft,
  ) {
    final isVideo = draft.type == 'video';

    return Card(
      color: AppColors.bgSurface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => controller.resumeDraft(draft),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail / Media preview
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 110,
                  height: 70,
                  color: AppColors.bgInput,
                  child: draft.mediaUrl != null && draft.mediaUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: draft.mediaUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Center(
                            child: Icon(
                              isVideo
                                  ? Icons.play_circle_outline_rounded
                                  : Icons.feed_outlined,
                              size: 32,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            isVideo
                                ? Icons.play_circle_outline_rounded
                                : Icons.feed_outlined,
                            size: 32,
                            color: AppColors.textPrimary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Content details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title.isEmpty ? 'Untitled Draft' : draft.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (draft.content.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        draft.content,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatLastEdited(draft.updatedAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Action buttons
              Column(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.bgSurfaceHover,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.bgDivider),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => controller.resumeDraft(draft),
                    icon: const Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: AppColors.textPrimary,
                    ),
                    label: const Text(
                      'Resume',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    tooltip: 'Delete Draft',
                    onPressed: () => _confirmDelete(context, controller, draft),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    DraftsController controller,
    DraftModel draft,
  ) {
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        title: const Text(
          'Delete Draft',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: TWTypography.brandFamily,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${draft.title.isEmpty ? 'Untitled Draft' : draft.title}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Get.back<void>();
              controller.deleteDraft(draft.id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastEdited(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) {
      return 'Edited just now';
    } else if (difference.inMinutes < 60) {
      return 'Edited ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Edited ${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return 'Edited ${difference.inDays}d ago';
    } else {
      return 'Edited ${DateFormat.yMMMd().format(dateTime)}';
    }
  }
}
