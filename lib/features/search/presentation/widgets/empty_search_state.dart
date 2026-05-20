import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart' as search_controller;
import 'package:truthworld/theme/app_theme.dart';

class EmptySearchState extends StatelessWidget {
  final String query;

  const EmptySearchState({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<search_controller.SearchController>();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off, size: 60, color: Colors.white24),
            ),
            const SizedBox(height: 24),
            Text(
              'No results found',
              style: AppTheme.typography.h3.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find anything for "$query"',
              textAlign: TextAlign.center,
              style: AppTheme.typography.body.copyWith(color: AppTheme.colors.textSecondary),
            ),
            const SizedBox(height: 32),
            Obx(() {
              final hasFilters = controller.selectedSearchType.value != 'all' ||
                  controller.selectedSortBy.value != 'relevance' ||
                  controller.selectedUploadDate.value != 'any' ||
                  controller.selectedDuration.value != 'any';

              if (!hasFilters) return const SizedBox.shrink();

              return Column(
                children: [
                  const Text(
                    'Try clearing your filters to see more results',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => controller.resetFilters(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Clear All Filters'),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
