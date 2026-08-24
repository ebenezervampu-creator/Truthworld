import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/features/community/data/models/saved_comment_model.dart';
import 'package:truthworld/features/community/presentation/controllers/saved_comments_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

enum _CardMenuOption { openSource, copyText, unsave }

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
    controller = Get.find<SavedCommentsController>();
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

  void _copyCommentText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    Get.snackbar(
      'Copied',
      'Comment text copied to clipboard',
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.bgSurfaceHover,
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
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
        return 'Post Comment';
      default:
        return 'Comment';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentUser = AuthService.to.currentUser.value;

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
              'Comments',
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
              style: GoogleFonts.roboto(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
        );
      }

      final screenWidth = MediaQuery.of(context).size.width;
      final crossAxisCount = screenWidth > 600 ? (screenWidth / 220).floor() : 2;

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
                style: GoogleFonts.roboto(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Search saved comments...',
                  hintStyle: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: controller.setSearchQuery,
              );
            }
            return Text(
              'Comments',
              style: GoogleFonts.roboto(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            );
          }),
        actions: [
          Obx(
            () => IconButton(
              icon: Icon(
                controller.isSearching.value ? Icons.close : Icons.search,
                color: AppColors.textPrimary,
              ),
              onPressed: controller.toggleSearching,
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }

        if (controller.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage,
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.refreshComments,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }

        final filtered = controller.filteredComments;

        return Column(
          children: [
            // Category Filter Chips Bar (Videos, Topics, Community Posts, All)
            _buildCategoryFilterChips(controller),
            const SizedBox(height: 4),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
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
                                : _getEmptyCategoryTitle(
                                    controller.selectedCategory.value,
                                  ),
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
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        controller.refreshComments();
                      },
                      color: AppColors.brand,
                      backgroundColor: AppColors.bgSurface,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Saved Section Header
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                12,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _getCategoryTitle(
                                      controller.selectedCategory.value,
                                    ),
                                    style: GoogleFonts.roboto(
                                      color: AppColors.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${filtered.length}',
                                      style: GoogleFonts.roboto(
                                        color: AppColors.brand,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Saved Comment Grid
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final comment = filtered[index];
                                  return _SavedCommentCard(
                                    comment: comment,
                                    onTap: () => _navigateToSource(comment),
                                    onUnsave: () =>
                                        controller.unsaveComment(comment.id),
                                    onCopyText: () =>
                                        _copyCommentText(comment.text),
                                    sourceIcon: _getSourceIcon(
                                      comment.sourceType,
                                    ),
                                    sourceLabel: _getSourceLabel(
                                      comment.sourceType,
                                    ),
                                  );
                                },
                                childCount: filtered.length,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 1.15,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      }),
    );
    });
  }

  Widget _buildCategoryFilterChips(SavedCommentsController controller) {
    final categories = [
      {
        'id': 'all',
        'label': 'All',
        'icon': Icons.all_inbox_rounded,
        'count': controller.totalCount,
      },
      {
        'id': 'video',
        'label': 'Videos',
        'icon': Icons.play_circle_fill_rounded,
        'count': controller.videoCount,
      },
      {
        'id': 'topic',
        'label': 'Topics',
        'icon': Icons.tag_rounded,
        'count': controller.topicCount,
      },
      {
        'id': 'community_post',
        'label': 'Community',
        'icon': Icons.article_rounded,
        'count': controller.communityCount,
      },
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final id = cat['id'] as String? ?? 'all';
          final label = cat['label'] as String? ?? '';
          final icon = cat['icon'] as IconData? ?? Icons.comment;
          final count = cat['count'] as int? ?? 0;

          return Obx(() {
            final isSelected = controller.selectedCategory.value == id;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => controller.setSelectedCategory(id),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.brand : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.brand
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.black.withValues(alpha: 0.25)
                              : AppColors.bgSurfaceHover,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.roboto(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'video':
        return 'Saved Video Comments';
      case 'topic':
        return 'Saved Topic Comments';
      case 'community_post':
        return 'Saved Community Comments';
      default:
        return 'All Saved Comments';
    }
  }

  String _getEmptyCategoryTitle(String category) {
    switch (category) {
      case 'video':
        return 'No saved video comments';
      case 'topic':
        return 'No saved topic comments';
      case 'community_post':
        return 'No saved community post comments';
      default:
        return 'No saved comments yet';
    }
  }
}

class _SavedCommentCard extends StatelessWidget {
  const _SavedCommentCard({
    required this.comment,
    required this.onTap,
    required this.onUnsave,
    required this.onCopyText,
    required this.sourceIcon,
    required this.sourceLabel,
  });

  final SavedCommentModel comment;
  final VoidCallback onTap;
  final VoidCallback onUnsave;
  final VoidCallback onCopyText;
  final IconData sourceIcon;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final rawHandle = comment.userName.replaceAll(' ', '_').toLowerCase();
    final handle = rawHandle.startsWith('@')
        ? rawHandle.substring(1)
        : rawHandle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Avatar + "Comment from @..." + Options Menu
              Row(
                children: [
                  UserAvatar(
                    radius: 14,
                    photoUrl: comment.userImage,
                    displayName: comment.userName,
                    fontSize: 10,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comment from',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          '@$handle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_CardMenuOption>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    color: AppColors.bgSurfaceHover,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    onSelected: (option) {
                      switch (option) {
                        case _CardMenuOption.openSource:
                          onTap();
                        case _CardMenuOption.copyText:
                          onCopyText();
                        case _CardMenuOption.unsave:
                          onUnsave();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _CardMenuOption.openSource,
                        height: 36,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'View source',
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _CardMenuOption.copyText,
                        height: 36,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Copy text',
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _CardMenuOption.unsave,
                        height: 36,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.bookmark_remove_rounded,
                              size: 16,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Unsave',
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Comment Body Text
              Expanded(
                child: ClickableUrlText(
                  text: comment.text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Source Badge/Pill Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(sourceIcon, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        comment.sourceTitle.isNotEmpty
                            ? comment.sourceTitle
                            : sourceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
