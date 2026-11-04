import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Friendly empty state illustration and message for playlist tabs.
class PlaylistEmptyStateWidget extends StatelessWidget {
  const PlaylistEmptyStateWidget({
    required this.isPublic,
    super.key,
  });

  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.brand.withValues(alpha: 0.25),
                      AppColors.brandVariant.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  isPublic
                      ? Icons.public_off_rounded
                      : Icons.playlist_add_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isPublic ? 'No public playlists' : 'No playlists yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isPublic
                    ? 'Discover playlists shared by other creators'
                    : 'Create your first playlist to organize your favorite videos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state displayed when search query matches no playlists.
class PlaylistNoResultsWidget extends StatelessWidget {
  const PlaylistNoResultsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No playlists found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search terms',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
