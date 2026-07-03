import 'package:flutter/material.dart';

import 'skeleton_base.dart';

/// Skeleton loading state for the video detail / watch page.
class VideoDetailSkeleton extends StatelessWidget {
  const VideoDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0014),
      body: SafeArea(
        child: SkeletonBase(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1024;

              if (isWide) {
                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main content column
                      Expanded(flex: 3, child: _buildMainColumn()),
                      const SizedBox(width: 24),
                      // Sidebar: recommended videos
                      Expanded(flex: 1, child: _buildSidebar()),
                    ],
                  ),
                );
              }

              // Narrow / mobile layout – no sidebar
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: _buildMainColumn(),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Main column ──────────────────────────────────────────────────────────

  Widget _buildMainColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 16:9 video player
        const AspectRatio(
          aspectRatio: 16 / 9,
          child: SkeletonBox(borderRadius: 12),
        ),
        const SizedBox(height: 16),

        // Title
        const SkeletonBox(height: 20, width: double.infinity),
        const SizedBox(height: 8),
        const SkeletonBox(height: 14, width: 220),
        const SizedBox(height: 20),

        // Channel info row
        Row(
          children: const [
            SkeletonCircle(size: 44),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 14, width: 160),
                  SizedBox(height: 6),
                  SkeletonBox(height: 12, width: 100),
                ],
              ),
            ),
            SkeletonBox(height: 36, width: 110, borderRadius: 20),
          ],
        ),
        const SizedBox(height: 24),

        // Description area
        ..._descriptionLines(),
        const SizedBox(height: 28),

        // Comments header
        const SkeletonBox(height: 16, width: 120),
        const SizedBox(height: 16),

        // Comment skeletons
        ..._commentSkeletons(),
      ],
    );
  }

  List<Widget> _descriptionLines() {
    return const [
      SkeletonBox(height: 12, width: double.infinity),
      SizedBox(height: 8),
      SkeletonBox(height: 12, width: double.infinity),
      SizedBox(height: 8),
      SkeletonBox(height: 12, width: 240),
    ];
  }

  List<Widget> _commentSkeletons() {
    return List.generate(3, (_) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonCircle(size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(height: 12, width: 140),
                  SizedBox(height: 8),
                  SkeletonBox(height: 12, width: double.infinity),
                  SizedBox(height: 6),
                  SkeletonBox(height: 12, width: 200),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Sidebar ──────────────────────────────────────────────────────────────

  Widget _buildSidebar() {
    return Column(
      children: List.generate(4, (_) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 168,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: SkeletonBox(borderRadius: 8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(height: 12, width: double.infinity),
                    SizedBox(height: 6),
                    SkeletonBox(height: 10, width: 100),
                    SizedBox(height: 4),
                    SkeletonBox(height: 10, width: 70),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
