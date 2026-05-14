import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

// --- Responsive constants ---
const double kTabletBreakpoint = 768.0;
const double kDesktopBreakpoint = 1200.0;
const int kGridItemsForTablet = 3; // ✨ Changed from 2
const int kGridItemsForDesktop = 4; // ✨ Changed from 3

// --- Theme colors pulled from GetX theme ---
final Color upNextCardColor = AppTheme.secondaryBackground.withValues(
  alpha: 0.7,
);
final Color upNextPrimaryText = AppColors.textPrimary;
final Color upNextSecondaryText = AppColors.textSecondary;

Widget buildUpNext({required Video currentVideo, required String videoId}) {
  final VideoController controller = Get.find<VideoController>(tag: videoId);

  return Obx(() {
    if (controller.isLoadingRecommendations.value) {
      return _buildShimmerLoading();
    }

    final all = controller.recommendedVideos;

    if (all.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 48,
                  color: upNextSecondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Related Videos Found',
                  style: GoogleFonts.roboto(
                    color: upNextSecondaryText,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisExtent = constraints.crossAxisExtent;
        final isMobile = crossAxisExtent < kTabletBreakpoint;

        if (isMobile) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            sliver: SliverList.builder(
              itemCount: all.length,
              itemBuilder: (context, i) => _buildVideoListItem(all[i], i, videoId),
            ),
          );
        }

        final crossAxisCount = crossAxisExtent < kDesktopBreakpoint
            ? kGridItemsForTablet
            : kGridItemsForDesktop;

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 16 / 15, // 📏 Adjusted to match shimmer
            ),
            itemCount: all.length,
            itemBuilder: (context, i) => _buildVideoGridItem(all[i], i, videoId),
          ),
        );
      },
    );
  });
}

// --- Shimmer loading as slivers only ---
Widget _buildShimmerLoading() {
  return SliverLayoutBuilder(
    builder: (context, constraints) {
      final crossAxisExtent = constraints.crossAxisExtent;
      final isMobile = crossAxisExtent < kTabletBreakpoint;

      final base = Colors.grey.shade800;
      final highlight = Colors.grey.shade700;

      if (isMobile) {
        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.builder(
            itemCount: 5,
            itemBuilder: (context, _) => Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              child: _listShimmerItem(),
            ),
          ),
        );
      }

      // This logic now uses your new values
      final crossAxisCount = crossAxisExtent < kDesktopBreakpoint
          ? kGridItemsForTablet // Will now be 3
          : kGridItemsForDesktop; // Will now be 4
      return SliverPadding(
        padding: const EdgeInsets.all(24),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio:
                16 /
                15, // 📏 Adjusted to provide enough height for title and metadata
          ),
          itemCount: 6,
          itemBuilder: (context, _) => Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: _gridShimmerItem(),
          ),
        ),
      );
    },
  );
}

// --- Items (with unique Keys and scoped Hero tags) ---
Widget _buildVideoListItem(Video v, int index, String tag) {
  final controller = Get.find<VideoController>(tag: tag);
  return Padding(
    key: ValueKey('upnext-list-${v.id}'),
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.offAndToNamed(
          '/videoscreen',
          arguments: {
            'video': v,
            'heroTag': 'upnext-list-thumb-${v.id}-$index',
            'playlist': controller.currentPlaylist.value,
          },
        ),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'upnext-list-thumb-${v.id}-$index',
              child: SizedBox(
                width: 140,
                height: 140 * 9 / 16,
                child: _thumbnail(v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 140 * 9 / 16, // ✅ fixes RenderFlex overflow
                child: _details(v),
              ),
            ),
            IconButton(
              icon: Icon(Icons.more_vert, size: 20, color: upNextSecondaryText),
              onPressed: () {},
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildVideoGridItem(Video v, int index, String tag) {
  final controller = Get.find<VideoController>(tag: tag);
  return Material(
    key: ValueKey('upnext-grid-${v.id}'),
    color: upNextCardColor,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Get.offAndToNamed(
        '/videoscreen',
        arguments: {
          'video': v,
          'heroTag': 'upnext-grid-thumb-${v.id}-$index',
          'playlist': controller.currentPlaylist.value,
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'upnext-grid-thumb-${v.id}-$index',
            child: AspectRatio(aspectRatio: 16 / 9, child: _thumbnail(v)),
          ),
          Padding(padding: const EdgeInsets.all(10), child: _details(v)),
        ],
      ),
    ),
  );
}

// --- Shared parts ---
Widget _thumbnail(Video v) {
  return Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: v.thumbnailUrl.replaceAll(' ', '%20'),
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: AppColors.bgSurface.withValues(alpha: 0.3),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppColors.bgSurface,
            child: const Icon(
              Icons.play_circle_outline,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 4,
        right: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            v.duration,
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _details(Video v) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      Text(
        v.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.roboto(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '${_formatViews(v.views)} views • ${timeago.format(v.uploadedAt.toDate())}',
        style: GoogleFonts.roboto(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
  );
}

String _formatViews(int views) {
  if (views >= 1000000) {
    return '${(views / 1000000).toStringAsFixed(1)}M';
  } else if (views >= 1000) {
    return '${(views / 1000).toStringAsFixed(1)}K';
  }
  return views.toString();
}

// --- Shimmer placeholders ---
Widget _listShimmerItem() {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 150,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Container(width: 100, height: 14, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _gridShimmerItem() {
  return Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: upNextCardColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(color: Colors.white),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 16,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Container(width: 120, height: 14, color: Colors.white),
            ],
          ),
        ),
      ],
    ),
  );
}






