import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/navigation/app_navigator.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/community/data/models/saved_comment_model.dart';
import 'package:truthworld/features/community/presentation/controllers/saved_comments_controller.dart';
import 'package:truthworld/features/community/presentation/views/widgets/saved_comments/saved_comments_components.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/community/presentation/controllers/saved_comments_controller.dart';
export 'package:truthworld/features/community/presentation/views/widgets/saved_comments/saved_comments_components.dart';

/// Declarative, responsive screen displaying saved comments with category filters,
/// real-time search, date-grouped list tiles, and quick navigation back to source content.
class SavedCommentsScreen extends StatelessWidget {
  const SavedCommentsScreen({super.key});

  double get maxContentWidth => 720;

  SavedCommentsController _resolveController() {
    return Get.isRegistered<SavedCommentsController>()
        ? Get.find<SavedCommentsController>()
        : Get.put(SavedCommentsController());
  }

  void _navigateToSource(SavedCommentModel comment) {
    if (comment.sourceId.isEmpty) {
      AppSnackbar.warning('Source content unavailable', title: 'Notice');
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
        AppNavigator.toNamed<dynamic>('/watch/${comment.sourceId}', arguments: navArgs);
      case 'topic':
        AppNavigator.toNamed<dynamic>('/topic/${comment.sourceId}', arguments: navArgs);
      case 'community_post':
        AppNavigator.toNamed<dynamic>('/home', arguments: navArgs);
      default:
        AppNavigator.toNamed<dynamic>('/home', arguments: navArgs);
    }
  }

  void _copyCommentText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    AppSnackbar.info(
      'Comment text copied to clipboard',
      title: 'Copied',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _resolveController();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: RefreshIndicator(
            onRefresh: () async {
              controller.refreshComments();
            },
            color: AppColors.brand,
            backgroundColor: AppColors.bgSurface,
            child: CustomScrollView(
              controller: controller.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SavedCommentsAppBar(controller: controller),
                SliverToBoxAdapter(
                  child: SavedCommentsPillTabs(controller: controller),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                Obx(() {
                  if (controller.isLoading) {
                    return const SliverFillRemaining(
                      child: SavedCommentsLoadingState(),
                    );
                  }

                  if (controller.errorMessage.isNotEmpty) {
                    return SliverFillRemaining(
                      child: SavedCommentsErrorState(
                        errorMessage: controller.errorMessage,
                        onRetry: controller.refreshComments,
                      ),
                    );
                  }

                  final items = controller.filteredComments;
                  return _buildGroupedCommentsList(controller, items);
                }),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: SavedCommentsFloatingActions(controller: controller),
    );
  }

  Widget _buildGroupedCommentsList(
    SavedCommentsController controller,
    List<SavedCommentModel> items,
  ) {
    if (items.isEmpty) {
      if (controller.searchQuery.value.isNotEmpty) {
        return const SavedCommentsEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No matching saved comments',
          subtitle: 'Try searching with a different keyword',
        );
      }
      if (controller.selectedCategory.value == 'video') {
        return const SavedCommentsEmptyState(
          icon: Icons.play_circle_outline_rounded,
          title: 'No saved video comments',
          subtitle: 'Comments you save from Videos will appear here',
        );
      }
      if (controller.selectedCategory.value == 'topic') {
        return const SavedCommentsEmptyState(
          icon: Icons.tag_rounded,
          title: 'No saved topic comments',
          subtitle: 'Comments you save from Topics will appear here',
        );
      }
      if (controller.selectedCategory.value == 'community_post') {
        return const SavedCommentsEmptyState(
          icon: Icons.article_outlined,
          title: 'No saved community comments',
          subtitle: 'Comments you save from Community Posts will appear here',
        );
      }
      return const SavedCommentsEmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'No saved comments',
        subtitle:
            'Comments you save from Videos, Topics, or Community Posts will appear here',
      );
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 7));

    final todayItems = <SavedCommentModel>[];
    final weekItems = <SavedCommentModel>[];
    final olderItems = <SavedCommentModel>[];

    for (final item in items) {
      if (item.savedAt.isAfter(todayStart) ||
          item.savedAt.isAtSameMomentAs(todayStart)) {
        todayItems.add(item);
      } else if (item.savedAt.isAfter(weekStart) ||
          item.savedAt.isAtSameMomentAs(weekStart)) {
        weekItems.add(item);
      } else {
        olderItems.add(item);
      }
    }

    final listWidgets = <Widget>[];

    if (todayItems.isNotEmpty) {
      listWidgets.add(_buildSectionHeader('Today'));
      for (final item in todayItems) {
        listWidgets.add(
          CompactSavedCommentTile(
            comment: item,
            controller: controller,
            onTap: () => _navigateToSource(item),
            onCopyText: () => _copyCommentText(item.text),
            onUnsave: () => controller.unsaveComment(item.id),
          ),
        );
      }
    }

    if (weekItems.isNotEmpty) {
      listWidgets.add(_buildSectionHeader('This week'));
      for (final item in weekItems) {
        listWidgets.add(
          CompactSavedCommentTile(
            comment: item,
            controller: controller,
            onTap: () => _navigateToSource(item),
            onCopyText: () => _copyCommentText(item.text),
            onUnsave: () => controller.unsaveComment(item.id),
          ),
        );
      }
    }

    if (olderItems.isNotEmpty) {
      listWidgets.add(_buildSectionHeader('Older'));
      for (final item in olderItems) {
        listWidgets.add(
          CompactSavedCommentTile(
            comment: item,
            controller: controller,
            onTap: () => _navigateToSource(item),
            onCopyText: () => _copyCommentText(item.text),
            onUnsave: () => controller.unsaveComment(item.id),
          ),
        );
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => listWidgets[index],
        childCount: listWidgets.length,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
