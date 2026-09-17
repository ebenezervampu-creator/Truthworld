import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_constants.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_empty_states.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';

/// 3D perspective PageView for carousel topic presentation mode,
/// with desktop navigation arrows and animated page indicators.
class ExploreTopicsPageView extends StatelessWidget {
  const ExploreTopicsPageView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreTopicsController>();
    final isMobile = MediaQuery.of(context).size.width < kMobileBreakpoint;
    final bannerHeight = isMobile ? 360.0 : 540.0;

    return Obx(() {
      final itemsCount = controller.topics.length;
      final totalPages = itemsCount + (controller.isLoadingMore.value ? 1 : 0);

      return Container(
        height: bannerHeight,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: Stack(
          children: [
            PageView.builder(
              controller: controller.pageController,
              itemCount: totalPages,
              itemBuilder: (context, index) {
                if (index == itemsCount) {
                  return const TopicPageViewShimmerWidget();
                }

                final topic = controller.topics[index];
                return AnimatedBuilder(
                  animation: controller.pageController,
                  builder: (context, child) {
                    var pageOffset = 0.0;
                    if (controller.pageController.hasClients) {
                      try {
                        pageOffset = controller.pageController.page! - index;
                      } catch (_) {
                        pageOffset = 0.0;
                      }
                    }

                    final scale = (1 - (pageOffset.abs() * 0.12)).clamp(
                      0.88,
                      1.0,
                    );
                    final opacity = (1 - (pageOffset.abs() * 0.4)).clamp(
                      0.0,
                      1.0,
                    );

                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    );
                  },
                  child: TopicCardWidget(topic: topic),
                );
              },
            ),

            // Navigation Buttons (Desktop only or large tablets)
            if (!isMobile && itemsCount > 1) ...[
              TopicNavButton(
                isLeft: true,
                onTap: () {
                  if (controller.pageController.hasClients) {
                    controller.pageController.previousPage(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                },
              ),
              TopicNavButton(
                isLeft: false,
                onTap: () {
                  if (controller.pageController.hasClients) {
                    controller.pageController.nextPage(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                },
              ),
            ],

            // Page Indicators
            if (itemsCount > 1)
              Positioned(
                bottom: 28,
                left: 0,
                right: 0,
                child: Obx(() {
                  final currentIndex = controller.currentTopicIndex.value;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(itemsCount, (index) {
                      final isSelected = currentIndex == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isSelected ? 32 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryText : secondaryText,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: primaryText.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      );
                    }),
                  );
                }),
              ),
          ],
        ),
      );
    });
  }
}

/// Circular glassmorphic navigation button for previous/next topic paging.
class TopicNavButton extends StatelessWidget {
  const TopicNavButton({
    required this.isLeft,
    required this.onTap,
    super.key,
  });

  final bool isLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: isLeft ? 24 : null,
      right: isLeft ? null : 24,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor.withValues(alpha: 0.5),
                border: Border.all(
                  color: primaryText.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                isLeft
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: primaryText,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
