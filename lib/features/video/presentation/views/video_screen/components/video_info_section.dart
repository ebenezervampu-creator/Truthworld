import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import '../theme/video_screen_theme.dart';

/// Video information section displaying title, metadata, and description
class VideoInfoSection extends StatelessWidget {
  final VideoController controller;
  final bool isDesktop;

  const VideoInfoSection({
    super.key,
    required this.controller,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          VideoScreenTheme.spacingMd,
          VideoScreenTheme.spacingMd,
          VideoScreenTheme.spacingMd,
          VideoScreenTheme.spacingSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoTitle(),
            const SizedBox(height: 12),
            if (controller.video.videoRating > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _buildTruthIndexBadge(),
              ),
            // Action buttons will be inserted here by parent
            const SizedBox(height: 16),
            _buildDescriptionBox(context),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoTitle() {
    return Text(
      controller.video.title,
      style: VideoScreenTheme.titleLarge,
    );
  }

  Widget _buildTruthIndexBadge() {
    // Import from widgets directory
    return Container(); // Placeholder - will use actual TruthIndexBadge widget
  }

  Widget _buildDescriptionBox(BuildContext context) {
    return Obx(() {
      final isExpanded = controller.isDescriptionExpanded.value;
      final description = controller.video.description ?? '';

      if (description.isEmpty) {
        return const SizedBox.shrink();
      }

      // Simple implementation - full extraction in separate component
      return Container(
        padding: const EdgeInsets.all(VideoScreenTheme.spacingMd),
        decoration: VideoScreenTheme.surfaceDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isExpanded ? description : _truncateDescription(description),
              style: VideoScreenTheme.bodyMedium,
            ),
            if (description.length > 200)
              TextButton(
                onPressed: () =>
                    controller.isDescriptionExpanded.value = !isExpanded,
                child: Text(
                  isExpanded ? 'Show less' : 'Show more',
                  style: VideoScreenTheme.button.copyWith(
                    color: VideoScreenTheme.primary,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  String _truncateDescription(String description) {
    if (description.length <= 200) return description;
    return '${description.substring(0, 200)}...';
  }
}
