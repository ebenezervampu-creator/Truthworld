import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/features/home/presentation/views/home/components/home_theme.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Optimized Video Card Component with RepaintBoundary for performance
/// Extracted from monolithic home.dart
class VideoCard extends StatelessWidget {
  final Video video;
  final String heroPrefix;
  final String Function(int) formatViews;
  final String Function(Timestamp) formatTimestamp;
  final bool isCompact;

  const VideoCard({
    required this.video, required this.heroPrefix, required this.formatViews, required this.formatTimestamp, super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: HomeTheme.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: HomeTheme.darkOnSurfaceVariant.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              MiniplayerNavigationHelper.navigateToVideoScreen(
                video: video,
                routeArguments: {'video': video},
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnail(context),
                _buildVideoInfo(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return Hero(
      tag: '${heroPrefix}_${video.id}',
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: video.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildShimmer(),
                errorWidget: (context, url, error) => _buildError(),
                memCacheWidth: 400,
                memCacheHeight: 225,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    video.duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            imageUrl: video.channelImage,
            radius: 18,
            placeholderText: video.channelName.safeSubstring(0, 1).toUpperCase(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    fontSize: 15,
                    color: HomeTheme.darkOnSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  video.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: HomeTheme.darkOnSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatViews(video.views)} views • ${formatTimestamp(video.uploadedAt)}',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: HomeTheme.darkOnSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: Colors.white,
            ),
            onPressed: () => VideoOptionsSheet.show(context, video),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.3),
      highlightColor: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.1),
      child: Container(color: HomeTheme.darkSurfaceVariant),
    );
  }

  Widget _buildError() {
    return ColoredBox(
      color: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.3),
      child: const Icon(
        Icons.broken_image_rounded,
        color: HomeTheme.darkOnSurfaceVariant,
        size: 40,
      ),
    );
  }
}

/// Avatar widget extracted for reusability
class _Avatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? placeholderText;

  const _Avatar({
    required this.radius,
    this.imageUrl,
    this.placeholderText,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(imageUrl!),
        backgroundColor: HomeTheme.primaryAccent.withValues(alpha: 0.2),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: HomeTheme.primaryAccent,
      child: Text(
        placeholderText ?? '?',
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

/// Loading skeleton for video cards
class VideoCardSkeleton extends StatelessWidget {
  final bool isCompact;

  const VideoCardSkeleton({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: HomeTheme.darkSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnailSkeleton(),
            _buildInfoSkeleton(),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailSkeleton() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Shimmer.fromColors(
          baseColor: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.3),
          highlightColor: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.1),
          child: Container(color: HomeTheme.darkSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildInfoSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.3),
            highlightColor: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.1),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: HomeTheme.darkSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLine(width: double.infinity, height: 14),
                const SizedBox(height: 6),
                _buildLine(width: double.infinity, height: 12),
                const SizedBox(height: 6),
                _buildLine(width: 150, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLine({required double width, required double height}) {
    return Shimmer.fromColors(
      baseColor: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.3),
      highlightColor: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.1),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: HomeTheme.darkSurfaceVariant,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
