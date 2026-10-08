import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Reusable state widgets (Empty, Shimmer, Error) for Playlists Management.
class PlaylistsEmptyState extends StatelessWidget {
  const PlaylistsEmptyState({
    super.key,
    this.isSearch = false,
    this.onClearFilters,
  });

  final bool isSearch;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 40),
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.playlist_play_rounded,
                size: 40,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearch
                  ? 'No matching playlists found'
                  : 'No playlists created yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFamily: TWTypography.brandFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'Try adjusting your search terms or clearing active filters.'
                  : 'Group your channel videos into playlists to help viewers discover and binge your content.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
                fontFamily: TWTypography.uiFamily,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSearch && onClearFilters != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onClearFilters,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.bgSurfaceHover,
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.bgDivider),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Clear Filters',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading grid for Playlists.
class PlaylistsShimmerGrid extends StatelessWidget {
  const PlaylistsShimmerGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E1E),
      highlightColor: AppColors.bgSurfaceHover,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Sanitized error banner for Playlists loading failures.
class PlaylistsErrorState extends StatelessWidget {
  const PlaylistsErrorState({
    super.key,
    this.message = 'Unable to load playlists. Please check your connection and try again.',
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontFamily: TWTypography.uiFamily,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgSurfaceHover,
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.bgDivider),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
