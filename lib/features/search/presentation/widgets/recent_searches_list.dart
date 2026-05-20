import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as search_controller;

class RecentSearchesList extends StatelessWidget {
  final search_controller.SearchController controller = Get.find<search_controller.SearchController>();

  RecentSearchesList({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.recentSearches.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                TextButton(
                  onPressed: () => controller.clearRecentSearches(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'CLEAR ALL',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...controller.recentSearches.map((query) => ListTile(
                leading: const Icon(Icons.history, color: Colors.white54),
                title: Text(
                  query,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white24),
                  onPressed: () => controller.removeRecentSearch(query),
                ),
                onTap: () {
                  controller.searchQuery.value = query;
                  controller.onSearchChanged(query);
                },
              )),
        ],
      );
    });
  }
}
