import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Reusable state widgets (Empty, Shimmer, Error) for Playlists Management matching YouTube Studio.
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
        margin: const EdgeInsets.symmetric(vertical: 36),
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearch
                    ? Icons.search_off_rounded
                    : Icons.playlist_play_rounded,
                size: 38,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearch
                  ? 'No matching playlists found'
                  : 'No playlists created yet',
              style: const TextStyle(
                fontSize: 17,
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
                  : 'Curate your channel videos into playlists to help viewers discover and binge your content.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
                fontFamily: TWTypography.uiFamily,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSearch && onClearFilters != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(
                  Icons.filter_alt_off_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.bgSurfaceHover,
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                label: const Text(
                  'Clear Filters',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
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

/// Clean lightweight loading indicator matching YouTube Studio design.
class PlaylistsLoadingGrid extends StatelessWidget {
  const PlaylistsLoadingGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: StudioLoadingIndicator(
        message: 'Loading playlists...',
        isFullScreen: false,
      ),
    );
  }
}

// Backward-compatible alias
typedef PlaylistsShimmerGrid = PlaylistsLoadingGrid;

/// Sanitized error banner for Playlists loading failures.
class PlaylistsErrorState extends StatelessWidget {
  const PlaylistsErrorState({
    super.key,
    this.message =
        'Unable to load playlists. Please check your connection and try again.',
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 22,
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
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
