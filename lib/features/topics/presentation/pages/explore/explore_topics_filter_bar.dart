import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_constants.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Horizontal filter bar for switching between explore feed modes
/// (Discover, Trending, Yearly).
class ExploreTopicsFilterBar extends StatelessWidget {
  const ExploreTopicsFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreTopicsController>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ExploreMode.values.map((mode) {
          return Obx(() {
            final isSelected = controller.exploreMode.value == mode;
            final label = mode.name.capitalizeFirst ?? mode.name;

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  controller.setExploreMode(mode);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.textPrimary : buttonBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textPrimary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.bgPage : primaryText,
                    ),
                  ),
                ),
              ),
            );
          });
        }).toList(),
      ),
    );
  }
}
