import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Empty state widget displayed when no search results match a query.
class EmptySearchState extends StatelessWidget {
  const EmptySearchState({
    required this.query,
    super.key,
    this.onClearSearch,
  });

  final String query;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            'No results for "$query"',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try different keywords',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (onClearSearch != null)
            ElevatedButton(
              onPressed: onClearSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgDivider,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Clear Search'),
            ),
        ],
      ),
    );
  }
}
