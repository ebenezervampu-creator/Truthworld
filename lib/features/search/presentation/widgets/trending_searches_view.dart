import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart' as search;
import 'package:truthworld/theme/app_theme.dart';

class TrendingSearchesView extends StatelessWidget {
  final search.SearchController controller = Get.find<search.SearchController>();

  TrendingSearchesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.trendingSearches.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: Colors.blueAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Popular Searches',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: controller.trendingSearches.map((term) {
                return ActionChip(
                  label: Text(
                    term,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  backgroundColor: AppColors.bgSurfaceHover,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () {
                    controller.searchFromSuggestion(term);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      );
    });
  }
}
