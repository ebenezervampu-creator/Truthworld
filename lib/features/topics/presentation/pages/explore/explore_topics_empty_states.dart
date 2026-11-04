import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_constants.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Error state widget displayed when topic retrieval encounters an issue,
/// providing an action to retry.
class ExploreTopicsErrorState extends StatelessWidget {
  const ExploreTopicsErrorState({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreTopicsController>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load topics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => Text(
                controller.errorMessage.isNotEmpty
                    ? controller.errorMessage
                    : 'Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: secondaryText,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                controller.initialFetch();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.bgPage,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget displayed when search or category filters yield no results.
class ExploreTopicsEmptyState extends StatelessWidget {
  const ExploreTopicsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreTopicsController>();

    return Obx(() {
      final isSearch = controller.searchQuery.value.isNotEmpty;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSearch ? Icons.search_off_rounded : Icons.explore_off_rounded,
                color: secondaryText,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                isSearch
                    ? 'No topics match "${controller.searchQuery.value}"'
                    : 'No topics available',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try switching explore modes or choose a different category.',
                textAlign: TextAlign.center,
                style: TextStyle(color: secondaryText, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (isSearch) {
                    controller.clearSearch();
                  } else {
                    controller.selectCategory('all');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.bgPage,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  isSearch ? 'Clear Search' : 'Browse All Topics',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Shimmer card shown in PageView mode while additional pages load.
class TopicPageViewShimmerWidget extends StatelessWidget {
  const TopicPageViewShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < kMobileBreakpoint;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Shimmer.fromColors(
        baseColor: cardColor,
        highlightColor: buttonBg,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 24.0 : 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 20,
                decoration: BoxDecoration(
                  color: primaryText,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: isMobile ? 200 : 400,
                height: isMobile ? 28 : 40,
                decoration: BoxDecoration(
                  color: primaryText,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: primaryText,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(height: 16),
                Container(
                  width: 300,
                  height: 14,
                  decoration: BoxDecoration(
                    color: primaryText,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 100,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryText,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 100,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryText,
                      borderRadius: BorderRadius.circular(18),
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
}
