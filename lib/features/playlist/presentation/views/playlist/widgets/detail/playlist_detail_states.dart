import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_detail_constants.dart';

/// Shimmer skeleton state while playlist videos are loading from Firestore.
class PlaylistVideoShimmer extends StatelessWidget {
  const PlaylistVideoShimmer({
    super.key,
    this.isDesktop = false,
  });

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: ytSurface,
      highlightColor: ytSurfaceLight,
      child: ListView.builder(
        shrinkWrap: !isDesktop,
        physics: isDesktop
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const SizedBox(width: 32),
              Container(
                width: 140,
                height: 79,
                decoration: BoxDecoration(
                  color: ytSurfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 16, color: ytSurfaceLight),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 100, color: ytSurfaceLight),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state when no videos match active playlist filters or the playlist has 0 items.
class PlaylistDetailEmptyState extends StatelessWidget {
  const PlaylistDetailEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_remove, size: 64, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'No videos found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: ytTextPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This playlist is empty',
              style: TextStyle(
                fontSize: 14,
                color: ytTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state displaying standard user-friendly explanation and retry button.
class PlaylistDetailErrorState extends StatelessWidget {
  const PlaylistDetailErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: ytTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: ytTextPrimary,
                foregroundColor: ytBackground,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
