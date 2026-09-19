import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Wrap list widget displaying recent search queries with chip selection and clear-all actions.
class RecentSearchesList extends StatelessWidget {
  const RecentSearchesList({
    required this.recentSearches,
    required this.onSearchSelected,
    required this.onClearAll,
    super.key,
  });

  final List<String> recentSearches;
  final Function(String) onSearchSelected;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: onClearAll,
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recentSearches
              .map(
                (search) => InkWell(
                  onTap: () => onSearchSelected(search),
                  child: Chip(
                    label: Text(
                      search,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    backgroundColor: AppColors.bgDivider,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
