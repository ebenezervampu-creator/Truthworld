import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_constants.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Responsive search bar with AI semantic exploration hint,
/// voice search integration, and reactive clear action.
class ExploreTopicsSearchBar extends StatelessWidget {
  const ExploreTopicsSearchBar({
    super.key,
    this.isMobile = false,
  });

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreTopicsController>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: buttonBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.12),
                ),
              ),
              child: TextField(
                controller: controller.searchController,
                style: const TextStyle(color: primaryText, fontSize: 14),
                decoration: InputDecoration(
                  icon: const Icon(
                    Icons.auto_awesome_outlined,
                    color: secondaryText,
                    size: 18,
                  ),
                  hintText: isMobile
                      ? 'Ask AI or explore topics (e.g. "Peace of mind", "Bible study")...'
                      : 'Ask AI or explore topics (e.g. "Peace of mind", "Bible study", "Science and faith")...',
                  hintStyle: const TextStyle(
                    color: secondaryText,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.mic_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        tooltip: 'Voice Search',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Get.dialog(
                            VoiceSearchDialog(
                              onSearch: (query) {
                                controller.searchController.text = query;
                                controller.updateSearchQuery(query);
                              },
                            ),
                          );
                        },
                      ),
                      Obx(
                        () => controller.searchQuery.value.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textPrimary,
                                  size: 20,
                                ),
                                tooltip: 'Clear',
                                onPressed: controller.clearSearch,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
