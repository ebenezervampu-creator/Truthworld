// ==========================================================================
// RESPONSIVE VIDEO GRID WIDGET
// ==========================================================================
// Adaptive grid layout that provides excellent responsive behavior
// across all device sizes with optimal column counts and spacing

import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/core/widgets/modern_video_card.dart';

class ResponsiveVideoGrid extends StatelessWidget {
  final List<Video> videos;
  final String? heroPrefix;
  final Color? accentColor;
  final bool showListView;
  final int? maxColumns;
  final double? childAspectRatio;
  final EdgeInsets? padding;
  final Function(Video)? onVideoTap;

  const ResponsiveVideoGrid({
    super.key,
    required this.videos,
    this.heroPrefix,
    this.accentColor,
    this.showListView = false,
    this.maxColumns,
    this.childAspectRatio,
    this.padding,
    this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        if (showListView || context.isMobileSmall) {
          return _buildListView(context);
        } else {
          return _buildGridView(context);
        }
      },
    );
  }

  Widget _buildListView(BuildContext context) {
    return ListView.separated(
      padding: padding ?? context.contentPadding,
      itemCount: videos.length,
      separatorBuilder: (context, index) => SizedBox(height: context.spacing),
      itemBuilder: (context, index) {
        final video = videos[index];
        return ModernVideoListCard(
          video: video,
          index: index,
          colorScheme: Theme.of(context).colorScheme,
          constraints: BoxConstraints(maxWidth: context.screenWidth),
          heroPrefix: heroPrefix ?? 'video_list',
          accentColor: accentColor ?? Theme.of(context).colorScheme.primary,
        );
      },
    );
  }

  Widget _buildGridView(BuildContext context) {
    final columns = Responsive.getGridColumns(
      context.screenWidth,
      maxColumns: maxColumns ?? 4,
    );

    return Padding(
      padding: padding ?? context.contentPadding,
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: context.spacing,
          mainAxisSpacing: context.spacing,
          childAspectRatio: childAspectRatio ?? _getAspectRatio(context),
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return ModernVideoGridCard(
            video: video,
            index: index,
            colorScheme: Theme.of(context).colorScheme,
            constraints: BoxConstraints(
              maxWidth: context.screenWidth / columns,
            ),
            heroPrefix: heroPrefix ?? 'video_grid',
            accentColor: accentColor ?? Theme.of(context).colorScheme.primary,
          );
        },
      ),
    );
  }

  double _getAspectRatio(BuildContext context) {
    if (context.isMobileSmall) return 1.2;
    if (context.isMobile) return 1.3;
    if (context.isTablet) return 1.4;
    return 1.5;
  }
}

// ==========================================================================
// RESPONSIVE VIDEO LIST WITH HEADER
// ==========================================================================
class ResponsiveVideoListWithHeader extends StatelessWidget {
  final String title;
  final List<Video> videos;
  final String? heroPrefix;
  final Color? accentColor;
  final bool showViewAll;
  final VoidCallback? onViewAll;
  final Widget? action;
  final bool showListView;
  final int? maxColumns;

  const ResponsiveVideoListWithHeader({
    super.key,
    required this.title,
    required this.videos,
    this.heroPrefix,
    this.accentColor,
    this.showViewAll = false,
    this.onViewAll,
    this.action,
    this.showListView = false,
    this.maxColumns,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        SizedBox(height: context.spacing),
        ResponsiveVideoGrid(
          videos: videos,
          heroPrefix: heroPrefix,
          accentColor: accentColor,
          showListView: showListView,
          maxColumns: maxColumns,
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize:
                    (Theme.of(context).textTheme.headlineSmall?.fontSize ??
                        24) *
                    context.fontScale,
              ),
            ),
          ),
          if (action != null) ...[
            action!,
          ] else if (showViewAll) ...[
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'View All',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize:
                      (Theme.of(context).textTheme.labelLarge?.fontSize ?? 14) *
                      context.fontScale,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================================================
// RESPONSIVE VIDEO SECTION
// ==========================================================================
class ResponsiveVideoSection extends StatelessWidget {
  final String title;
  final List<Video> videos;
  final String? heroPrefix;
  final Color? accentColor;
  final bool showListView;
  final int maxColumns;
  final EdgeInsets? sectionPadding;

  const ResponsiveVideoSection({
    super.key,
    required this.title,
    required this.videos,
    this.heroPrefix,
    this.accentColor,
    this.showListView = false,
    this.maxColumns = 4,
    this.sectionPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      padding: sectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context),
          SizedBox(height: context.spacing),
          ResponsiveVideoGrid(
            videos: videos,
            heroPrefix: heroPrefix,
            accentColor: accentColor,
            showListView: showListView,
            maxColumns: maxColumns,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
        fontSize:
            (Theme.of(context).textTheme.headlineMedium?.fontSize ?? 28) *
            context.fontScale,
      ),
    );
  }
}

// ==========================================================================
// RESPONSIVE VIDEO CAROUSEL
// ==========================================================================
class ResponsiveVideoCarousel extends StatelessWidget {
  final List<Video> videos;
  final String? heroPrefix;
  final Color? accentColor;
  final double? height;
  final bool showScrollbar;

  const ResponsiveVideoCarousel({
    super.key,
    required this.videos,
    this.heroPrefix,
    this.accentColor,
    this.height,
    this.showScrollbar = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardHeight = height ?? _getCarouselHeight(context);

    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.spacing),
        itemCount: videos.length,
        separatorBuilder: (context, index) => SizedBox(width: context.spacing),
        itemBuilder: (context, index) {
          final video = videos[index];
          final cardWidth = _getCarouselCardWidth(context);

          return SizedBox(
            width: cardWidth,
            child: ModernVideoGridCard(
              video: video,
              index: index,
              colorScheme: Theme.of(context).colorScheme,
              constraints: BoxConstraints(
                maxWidth: cardWidth,
                maxHeight: cardHeight,
              ),
              heroPrefix: heroPrefix ?? 'video_carousel',
              accentColor: accentColor ?? Theme.of(context).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }

  double _getCarouselHeight(BuildContext context) {
    if (context.isMobileSmall) return 200;
    if (context.isMobile) return 240;
    if (context.isTablet) return 280;
    return 320;
  }

  double _getCarouselCardWidth(BuildContext context) {
    if (context.isMobileSmall) return 280;
    if (context.isMobile) return 320;
    if (context.isTablet) return 360;
    return 400;
  }
}







