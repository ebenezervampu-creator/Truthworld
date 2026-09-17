import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Shimmer skeleton loading state for playlists screen.
class PlaylistShimmerLoading extends StatelessWidget {
  const PlaylistShimmerLoading({
    required this.isListView,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    super.key,
  });

  final bool isListView;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isMobile
        ? 1
        : isTablet
            ? 2
            : 3;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: isListView || isMobile
          ? ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) =>
                  const PlaylistShimmerCard(isGrid: false),
            )
          : GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: 6,
              itemBuilder: (context, index) =>
                  const PlaylistShimmerCard(isGrid: true),
            ),
    );
  }
}

class PlaylistShimmerCard extends StatelessWidget {
  const PlaylistShimmerCard({required this.isGrid, super.key});

  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.bgSurfaceHover,
      highlightColor: AppColors.bgSurface,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: isGrid
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceHover,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 16,
                    width: double.infinity,
                    color: AppColors.bgSurfaceHover,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 100,
                    color: AppColors.bgSurfaceHover,
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceHover,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          width: double.infinity,
                          color: AppColors.bgSurfaceHover,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 120,
                          color: AppColors.bgSurfaceHover,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 80,
                          color: AppColors.bgSurfaceHover,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
