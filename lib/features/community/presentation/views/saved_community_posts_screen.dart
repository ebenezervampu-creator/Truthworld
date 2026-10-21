import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/community/presentation/controllers/saved_community_posts_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class SavedCommunityPostsScreen
    extends GetView<SavedCommunityPostsController> {
  const SavedCommunityPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          final currentUser = AuthService.to.currentUser.value;
          if (currentUser == null || !controller.isSearching.value) {
            return Text(
              'Saved Posts',
              style: GoogleFonts.roboto(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            );
          }
          return TextField(
            autofocus: true,
            maxLength: 100,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            inputFormatters: TruthworldTextInputFormatters.withLimit(100),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
            decoration: const InputDecoration(
              hintText: 'Search saved posts...',
              hintStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              border: InputBorder.none,
            ),
            onChanged: controller.setSearchQuery,
          );
        }),
        actions: [
          Obx(() {
            final currentUser = AuthService.to.currentUser.value;
            if (currentUser == null) return const SizedBox.shrink();
            return IconButton(
              icon: Icon(
                controller.isSearching.value ? Icons.close : Icons.search,
                color: AppColors.textPrimary,
              ),
              onPressed: controller.toggleSearching,
            );
          }),
        ],
      ),
      body: Obx(() {
        final currentUser = AuthService.to.currentUser.value;
        if (currentUser == null) {
          return const Center(
            child: Text(
              'Please sign in to view your saved posts',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
          );
        }

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
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.refreshPosts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final filtered = controller.filteredPosts;

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
                    Icons.bookmark_outline_rounded,
                    size: 40,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  controller.searchQuery.value.isNotEmpty
                      ? 'No matching saved posts'
                      : 'No saved posts yet',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.searchQuery.value.isNotEmpty
                      ? 'Try searching with a different keyword'
                      : 'Community posts you save will appear here',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            controller.refreshPosts();
          },
          color: AppColors.brand,
          backgroundColor: AppColors.bgSurface,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final post = filtered[index];
              return CommunityPostCard(
                key: ValueKey(post.id),
                post: post,
                isChannelContext: true,
              );
            },
          ),
        );
      }),
    );
  }
}
