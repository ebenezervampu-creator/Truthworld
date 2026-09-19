import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/following/following_topics_barrel.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'following/following_topics_barrel.dart';

/// Screen displaying topics followed by the current user, along with horizontal video feeds
/// and community posts for each topic.
class FollowingTopicsPage extends GetView<FollowingTopicsController> {
  const FollowingTopicsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  FollowingTopicsController get controller =>
      Get.isRegistered<FollowingTopicsController>()
          ? Get.find<FollowingTopicsController>()
          : Get.put(FollowingTopicsController());

  Future<void> _refreshFollowingTopics() async {
    await controller.fetchFollowingTopics();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Header (Back button + Search bar)
            SliverToBoxAdapter(
              child: FollowingTopicsHeader(
                controller: controller,
                isMobile: isMobile,
                isDashboard: isDashboard,
              ),
            ),

            // Horizontal Topic Pills (Chips)
            SliverToBoxAdapter(
              child: FollowingTopicsPills(controller: controller),
            ),

            // Saved Topics Horizontal Video Content
            Obx(() {
              if (!AuthService.to.isAuthenticated.value) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: FollowingTopicsAuthRequiredState(),
                );
              }

              if (controller.isLoading) {
                return SliverToBoxAdapter(
                  child: FollowingTopicsLoadingState(
                    isMobile: isMobile,
                    isTablet: isTablet,
                  ),
                );
              }

              if (controller.errorMessage.isNotEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: FollowingTopicsErrorState(
                    errorMessage: controller.errorMessage,
                    onRetry: _refreshFollowingTopics,
                  ),
                );
              }

              var topics = List<Topic>.from(controller.followedTopics);

              // Filter by search query if active
              if (controller.searchQuery.value.isNotEmpty) {
                topics = topics.where((t) {
                  return t.title.toLowerCase().contains(
                    controller.searchQuery.value.toLowerCase(),
                  );
                }).toList();
              }

              if (topics.isEmpty) {
                if (controller.searchQuery.value.isNotEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: FollowingTopicsNoResultsState(),
                  );
                }
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: FollowingTopicsEmptyState(),
                );
              }

              // Display active selected topic or all topics
              final selectedTopic = controller.selectedTopic.value;
              var displayTopics = topics;
              if (selectedTopic != null &&
                  topics.any((t) => t.id == selectedTopic.id)) {
                displayTopics = [selectedTopic];
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final topic = displayTopics[index];
                    return FollowingTopicSection(
                      topic: topic,
                      controller: controller,
                      isMobile: isMobile,
                    );
                  },
                  childCount: displayTopics.length,
                ),
              );
            }),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
