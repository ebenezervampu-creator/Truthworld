import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top header bar for Following Topics page with back button and search input.
class FollowingTopicsHeader extends StatelessWidget {
  const FollowingTopicsHeader({
    required this.controller,
    required this.isMobile,
    required this.isDashboard,
    super.key,
  });

  final FollowingTopicsController controller;
  final bool isMobile;
  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    final searchController = controller.searchController;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () {
              if (isDashboard) {
                Get.find<HomeController>().sideNavSelectedIndex.value =
                    HomeController.indexLibrary;
              } else {
                Get.back<void>();
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: searchController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search followed topics...',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, value, child) {
                    if (value.text.isNotEmpty) {
                      return IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          searchController.clear();
                          controller.updateSearchQuery('');
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                filled: true,
                fillColor: const Color(0xFF272727),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
