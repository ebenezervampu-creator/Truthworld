import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/community/presentation/controllers/saved_comments_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Sliver app bar featuring reactive search bar, back navigation, and refresh actions.
class SavedCommentsAppBar extends StatelessWidget {
  const SavedCommentsAppBar({
    required this.controller,
    super.key,
  });

  final SavedCommentsController controller;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.bgPage,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: () => Get.back<void>(),
      ),
      title: Obx(
        () => controller.isSearching.value
            ? SavedCommentsSearchBar(controller: controller)
            : const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
      ),
      actions: [
        Obx(
          () => IconButton(
            icon: Icon(
              controller.isSearching.value
                  ? Icons.close_rounded
                  : Icons.search_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: controller.toggleSearching,
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: AppColors.textPrimary,
          ),
          onSelected: (value) {
            if (value == 'refresh') {
              controller.refreshComments();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                  SizedBox(width: 12),
                  Text('Refresh comments'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Integrated search input field in the comments app bar.
class SavedCommentsSearchBar extends StatelessWidget {
  const SavedCommentsSearchBar({
    required this.controller,
    super.key,
  });

  final SavedCommentsController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller.searchController,
      maxLength: ContentValidator.defaultMaxSearchLength,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      inputFormatters: TruthworldTextInputFormatters.withLimit(
        ContentValidator.defaultMaxSearchLength,
      ),
      autofocus: true,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
      decoration: const InputDecoration(
        hintText: 'Search saved comments...',
        hintStyle: TextStyle(color: AppColors.textSecondary),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: controller.onSearchChanged,
    );
  }
}

/// Horizontal category tab pills (All, Videos, Topics, Community).
class SavedCommentsPillTabs extends StatelessWidget {
  const SavedCommentsPillTabs({
    required this.controller,
    super.key,
  });

  final SavedCommentsController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildPillButton(title: 'All', id: 'all'),
          const SizedBox(width: 8),
          _buildPillButton(title: 'Videos', id: 'video'),
          const SizedBox(width: 8),
          _buildPillButton(title: 'Topics', id: 'topic'),
          const SizedBox(width: 8),
          _buildPillButton(title: 'Community', id: 'community_post'),
        ],
      ),
    );
  }

  Widget _buildPillButton({required String title, required String id}) {
    return Obx(() {
      final isSelected = controller.selectedCategory.value == id;
      return GestureDetector(
        onTap: () => controller.setSelectedCategory(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.textPrimary : const Color(0xFF272727),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.bgPage : AppColors.textPrimary,
            ),
          ),
        ),
      );
    });
  }
}

/// Floating action button cluster (scroll to top).
class SavedCommentsFloatingActions extends StatelessWidget {
  const SavedCommentsFloatingActions({
    required this.controller,
    super.key,
  });

  final SavedCommentsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.showScrollToTop.value) {
        return const SizedBox.shrink();
      }
      return FloatingActionButton(
        heroTag: 'saved_comments_scroll_top',
        mini: true,
        onPressed: controller.scrollToTop,
        backgroundColor: AppColors.bgSurface,
        child: const Icon(
          Icons.keyboard_arrow_up_rounded,
          color: AppColors.textPrimary,
        ),
      );
    });
  }
}
