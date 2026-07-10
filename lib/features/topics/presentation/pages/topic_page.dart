import 'package:flutter/material.dart';
import 'package:truthworld/components/ui/back_symbol.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_hero_widget.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_video_grid.dart';
import 'package:truthworld/features/topics/presentation/widgets/related_topics_widget.dart';

/// Topic Page - /topic/:slug
///
/// Displays:
/// - Topic hero with cover image
/// - Featured video section
/// - Video grid with infinite scroll
/// - Related topics
///
/// Responsive: desktop, tablet, mobile
class TopicPage extends StatefulWidget {
  final String? slug;

  const TopicPage({super.key, this.slug});

  @override
  State<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends State<TopicPage> {
  final TopicController controller = Get.put(TopicController());
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupInfiniteScroll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupInfiniteScroll() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 500) {
        controller.loadMoreVideos();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 1024;
    final bool isTablet = size.width >= 768 && size.width < 1024;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Obx(() {
        if (controller.isLoading.value && controller.videos.isEmpty) {
          return _buildLoadingState(isDesktop, isTablet);
        }

        if (controller.hasError.value) {
          return _buildErrorState();
        }

        return CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar
            _buildSliverAppBar(isDesktop, isTablet),

            // Hero Section
            SliverToBoxAdapter(
              child: TopicHeroWidget(
                topic: controller.topic.value,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
            ),

            // Featured Video Section
            if (controller.featuredVideos.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildFeaturedSection(isDesktop, isTablet),
              ),

            // Related Topics
            if (controller.relatedTopics.isNotEmpty)
              SliverToBoxAdapter(
                child: RelatedTopicsWidget(
                  topics: controller.relatedTopics,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
              ),

            // Video Grid
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Videos', isDesktop, isTablet),
                    const SizedBox(height: 16),
                    TopicVideoGrid(
                      videos: controller.videos,
                      isLoadingMore: controller.isLoadingMore.value,
                      hasMore: controller.hasMoreVideos.value,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                      heroPrefix: 'topic_${controller.topicSlug}',
                      onLoadMore: controller.loadMoreVideos,
                    ),
                    // Bottom padding
                    SizedBox(height: isDesktop ? 64 : 32),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSliverAppBar(bool isDesktop, bool isTablet) {
    return SliverAppBar(
      floating: true,
      pinned: false,
      snap: true,
      backgroundColor: AppColors.bgPage.withValues(alpha: 0.95),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
          vertical: 16,
        ),
        centerTitle: false,
        title: Row(
          children: [
            // Back button
            IconButton(
              onPressed: () => Get.back(),
              icon: const BackSymbol(),
              color: AppColors.textPrimary,
              splashRadius: 20,
            ),
            const SizedBox(width: 8),
            // Topic title
            Expanded(
              child: Obx(() => Text(
                controller.topicTitle,
                style: GoogleFonts.roboto(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )),
            ),
          ],
        ),
      ),
      actions: [
        // Refresh button
        IconButton(
          onPressed: controller.refreshTopic,
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.textPrimary,
          tooltip: 'Refresh',
        ),
        SizedBox(width: isDesktop ? 48 : 16),
      ],
    );
  }

  Widget _buildFeaturedSection(bool isDesktop, bool isTablet) {
    final featured = controller.featuredVideos.first;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Featured', isDesktop, isTablet),
          const SizedBox(height: 16),
          _buildFeaturedCard(featured, isDesktop, isTablet),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(dynamic video, bool isDesktop, bool isTablet) {
    final height = isDesktop ? 400.0 : (isTablet ? 300.0 : 220.0);

    return InkWell(
      onTap: () => Get.toNamed(
        '/watch?v=${video.id}',
        arguments: {
          'video': video,
          'heroTag': controller.getHeroTag(video.id),
        },
      ),
      child: Hero(
        tag: controller.getHeroTag(video.id),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radius.xl),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radius.xl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail
                Image.network(
                  video.thumbnailUrl ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.bgSurfaceContainerHighest,
                    child: Icon(
                      Icons.videocam_off_rounded,
                      color: AppColors.textTertiary,
                      size: 48,
                    ),
                  ),
                ),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.bgPage.withValues(alpha: 0.8),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),

                // Content info
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video title
                      Text(
                        video.title,
                        style: GoogleFonts.roboto(
                          fontSize: isDesktop ? 24 : (isTablet ? 20 : 18),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Channel & meta
                      Text(
                        '${video.channelName} • ${video.views} views',
                        style: GoogleFonts.roboto(
                          fontSize: isDesktop ? 16 : 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Play button
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.textPrimary,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDesktop, bool isTablet) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.roboto(
            fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(bool isDesktop, bool isTablet) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          floating: true,
          pinned: false,
          backgroundColor: AppColors.bgPage,
          title: Text(
            'Loading...',
            style: GoogleFonts.roboto(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TopicHeroWidget(
            topic: null,
            isDesktop: isDesktop,
            isTablet: isTablet,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
            vertical: 24,
          ),
          sliver: SliverToBoxAdapter(
            child: TopicVideoGridSkeleton(
              isDesktop: isDesktop,
              isTablet: isTablet,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppTokens.colors.error,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            controller.errorMessage.value,
            style: GoogleFonts.roboto(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: controller.refreshTopic,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}





