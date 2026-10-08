import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/utils/get_instance_extensions.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_more_options_sheet.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_notification_options_sheet.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/dark_professional_theme.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Featured video/topic banner carousel widget extracted from home.dart
class FeaturedVideoBanner extends StatefulWidget {
  const FeaturedVideoBanner({
    required this.horizontalPadding,
    super.key,
  });

  final double horizontalPadding;

  @override
  State<FeaturedVideoBanner> createState() => FeaturedVideoBannerState();
}

class FeaturedVideoBannerState extends State<FeaturedVideoBanner> {
  late PageController _pageController;
  Timer? _timer;
  final RxInt _currentIndex = 0.obs;
  final RxBool _isHovering = false.obs;
  final RxBool _isVisible = true.obs;
  static const int _infiniteItems = 10000;

  late final HomeController _homeController;
  late final Worker _topicsWorker;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _homeController = Get.find<HomeController>();

    // Listen to changes in featuredTopics to reinitialize PageController
    _topicsWorker = ever(_homeController.featuredTopics, (_) {
      if (mounted) {
        _reinitPageController();
      }
    });

    // Initialize PageController with cached topics if they are already available
    final initialTopics = _homeController.featuredTopics
        .where((t) => t.isValidTopic && t.videoCount > 0)
        .toList();
    if (initialTopics.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reinitPageController();
        }
      });
    }
  }

  void _reinitPageController() {
    final topics = _homeController.featuredTopics
        .where((t) => t.isValidTopic && t.videoCount > 0)
        .toList();
    if (topics.isEmpty) return;
    final itemsCount = topics.length;
    final initialPage =
        (_infiniteItems ~/ 2) - ((_infiniteItems ~/ 2) % itemsCount);
    try {
      _pageController.dispose();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeaturedBanner.reinitPageController.dispose',
      );
    }
    _pageController = PageController(initialPage: initialPage);
    _currentIndex.value = initialPage % itemsCount;
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (_pageController.hasClients &&
          !_isHovering.value &&
          _isVisible.value) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutQuart,
        );
      }
    });
  }

  @override
  void dispose() {
    _topicsWorker.dispose();
    _timer?.cancel();
    try {
      _pageController.dispose();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeaturedBanner.dispose',
      );
    }
    super.dispose();
  }

  void _navigateToTopic(BuildContext context, Topic topic) {
    if (!topic.isValidTopic || topic.slug.trim().isEmpty) return;
    if (Get.isRegistered<TopicController>()) {
      Get.find<TopicController>().topic.value = topic;
    } else {
      Get.put(TopicController()).topic.value = topic;
    }

    Get.toNamed(
      topic.topicRoute,
      arguments: {'slug': topic.slug, 'fromCard': true, 'topic': topic},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < kTabletBreakpoint;
    final bannerHeight = isMobile ? 320.0 : 460.0;

    return Obx(() {
      final topics = _homeController.featuredTopics
          .where((t) => t.isValidTopic && t.videoCount > 0)
          .toList();

      if (_homeController.isLoadingFeaturedTopics.value && topics.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.horizontalPadding,
            vertical: 16,
          ),
          child: Shimmer.fromColors(
            baseColor: modernDarkProfessionalTheme
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            highlightColor: modernDarkProfessionalTheme
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.1),
            child: Container(
              height: bannerHeight,
              decoration: BoxDecoration(
                color: modernDarkProfessionalTheme
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        );
      }

      if (topics.isEmpty) {
        return const SizedBox.shrink();
      }

      final itemsCount = topics.length;
      return VisibilityDetector(
        key: const Key('featured_banner_visibility'),
        onVisibilityChanged: (info) {
          if (!mounted) return;
          final visible = info.visibleFraction > 0.1;
          if (_isVisible.value != visible) {
            _isVisible.value = visible;
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.horizontalPadding,
            vertical: 16,
          ),
          child: MouseRegion(
            onEnter: (_) => _isHovering.value = true,
            onExit: (_) => _isHovering.value = false,
            child: Container(
              height: bannerHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _infiniteItems,
                      onPageChanged: (index) =>
                          _currentIndex.value = index % itemsCount,
                      itemBuilder: (context, index) {
                        final bannerIndex = index % itemsCount;
                        final bannerWidget = _buildBannerItem(
                          context,
                          topic: topics[bannerIndex],
                          isMobile: isMobile,
                        );
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double pageOffset = 0;
                            if (_pageController.hasClients) {
                              try {
                                pageOffset = _pageController.page! - index;
                              } catch (e) {
                                pageOffset = 0;
                              }
                            }

                            // Awesome transition effects
                            final scale = (1 - (pageOffset.abs() * 0.3)).clamp(
                              0.7,
                              1.0,
                            );
                            final opacity = (1 - (pageOffset.abs() * 0.5))
                                .clamp(0.0, 1.0);

                            return Opacity(
                              opacity: opacity,
                              child: Transform.scale(
                                scale: scale,
                                child: child,
                              ),
                            );
                          },
                          child: bannerWidget,
                        );
                      },
                    ),

                    // Navigation Buttons (Desktop and Tablets)
                    if (!isMobile && itemsCount > 1) ...[
                      _buildNavButton(
                        isLeft: true,
                        onTap: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOutQuart,
                        ),
                      ),
                      _buildNavButton(
                        isLeft: false,
                        onTap: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOutQuart,
                        ),
                      ),
                    ],

                    // Page Indicators
                    if (itemsCount > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(itemsCount, (index) {
                            return Obx(() {
                              final isSelected = _currentIndex.value == index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: isSelected ? 28 : 7,
                                height: 5,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white
                                          .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.white
                                                .withValues(alpha: 0.5),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                              );
                            });
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildNavButton({required bool isLeft, required VoidCallback onTap}) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: isLeft ? 18 : null,
      right: isLeft ? null : 18,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.45),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isLeft
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerItem(
    BuildContext context, {
    required Topic topic,
    required bool isMobile,
    double pageOffset = 0.0,
  }) {
    return _buildBannerItemContent(
      context,
      topic: topic,
      isMobile: isMobile,
      pageOffset: pageOffset,
    );
  }

  Widget _buildBannerItemContent(
    BuildContext context, {
    required Topic topic,
    required bool isMobile,
    double pageOffset = 0.0,
  }) {
    final bannerImageUrl = (topic.coverImage?.isNotEmpty ?? false
            ? topic.coverImage
            : topic.thumbnailUrl?.isNotEmpty ?? false
            ? topic.thumbnailUrl
            : null) ??
        'https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&w=800&q=75';

    return GestureDetector(
      onTap: () => _navigateToTopic(context, topic),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Background Image with subtle Parallax
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(pageOffset * 60, 0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: bannerImageUrl,
                    memCacheWidth: 1200,
                    maxWidthDiskCache: 1200,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    errorWidget: (context, url, error) =>
                        const ColoredBox(color: AppColors.bgSurface),
                    placeholder: (context, url) =>
                        const ColoredBox(color: AppColors.bgSurface),
                  ),
                  // Left-to-right gradient overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.95),
                          Colors.black.withValues(alpha: 0.80),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 0.72, 1.0],
                      ),
                    ),
                  ),
                  // Subtle bottom gradient for indicators
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.only(
              left: isMobile ? 18 : 64,
              right: isMobile ? 18 : 64,
              top: isMobile ? 18 : 28,
              bottom: isMobile ? 18 : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // TOPIC Pill Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        color: Color(0xFFFFD54F),
                        size: 13,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'TOPIC',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Title
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 680,
                  ),
                  child: Text(
                    topic.title,
                    style: GoogleFonts.roboto(
                      fontSize: isMobile ? 22 : 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                // Meta Info
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${topic.videoCount} ${topic.videoCount == 1 ? 'video' : 'videos'}',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      '•',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      timeago.format(topic.createdAt),
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (topic.category.isNotEmpty) ...[
                      const Text(
                        '•',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          topic.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Subtitle / Description
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                  child: Text(
                    topic.description.trim().isNotEmpty
                        ? topic.description
                        : topic.title,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                // Action Buttons Row (Follow Pill, Circular Share, Circular More Options)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BannerFollowButton(topic: topic),
                    const SizedBox(width: 10),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'Share',
                        icon: const Icon(
                          Icons.reply_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        onPressed: () {
                          final slug = topic.slug;
                          final title = topic.title;
                          final imageUrl = topic.coverImage ?? topic.thumbnailUrl;
                          final topicUrl = DeepLinkService.topicUrl(slug);
                          final followingCtrl =
                              Get.findIfInstantiated<FollowingTopicsController>();
                          final currentFollowerCount =
                              followingCtrl?.getFollowerCount(topic) ??
                                  topic.followerCount;
                          ShareBottomSheet.show(
                            title: title,
                            url: topicUrl,
                            thumbnailUrl: imageUrl,
                            followerCount: currentFollowerCount,
                            videoCount: topic.videoCount,
                            handle: slug,
                            type: 'topic',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'More options',
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        onPressed: () {
                          TopicMoreOptionsBottomSheet.show(
                            context,
                            topic: topic,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Followers Count (Top Right)
          Positioned(
            top: isMobile ? 16 : 24,
            right: isMobile ? 16 : 28,
            child: _BannerFollowerCountBadge(
              topic: topic,
              formatCount: _formatCount,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 0) count = 0;
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/// Follow button for the featured banner that avoids eager initialization of
/// [FollowingTopicsController] until the user explicitly requests follow interactions.
class _BannerFollowButton extends StatelessWidget {
  const _BannerFollowButton({required this.topic});

  final Topic topic;

  IconData _getNotificationIcon(String? setting) {
    if (setting == 'all') {
      return Icons.notifications_active_rounded;
    }
    if (setting == 'none') {
      return Icons.notifications_off_outlined;
    }
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final followingController =
        Get.findIfInstantiated<FollowingTopicsController>();

    if (followingController != null) {
      final ctrl = followingController;
      return Obx(() {
        final isFollowed = ctrl.isTopicFollowed(topic.id);
        final setting = ctrl.topicNotificationSettings[topic.id];
        return _buildButton(
          context,
          isFollowed: isFollowed,
          icon: isFollowed
              ? _getNotificationIcon(setting)
              : Icons.play_arrow_rounded,
          onPressed: () {
            if (isFollowed) {
              TopicNotificationOptionsSheet.show(
                context,
                topic: topic,
              );
            } else {
              ctrl.toggleFollowTopic(topic);
            }
          },
        );
      });
    }

    return _buildButton(
      context,
      isFollowed: false,
      icon: Icons.play_arrow_rounded,
      onPressed: () {
        final ctrl = Get.isRegistered<FollowingTopicsController>()
            ? Get.find<FollowingTopicsController>()
            : Get.put(FollowingTopicsController());
        if (ctrl.isTopicFollowed(topic.id)) {
          TopicNotificationOptionsSheet.show(
            context,
            topic: topic,
          );
        } else {
          ctrl.toggleFollowTopic(topic);
        }
      },
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required bool isFollowed,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: isFollowed ? Colors.white : Colors.black,
        size: 16,
      ),
      label: Text(
        isFollowed ? 'Following' : 'Follow',
        style: TextStyle(
          color: isFollowed ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isFollowed
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white,
        foregroundColor: isFollowed ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: isFollowed
              ? BorderSide(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 0.8,
                )
              : BorderSide.none,
        ),
        elevation: 0,
      ),
    );
  }
}

/// Follower count badge that resolves reactively if [FollowingTopicsController]
/// is active, but falls back to static metadata without triggering lazy instantiation.
class _BannerFollowerCountBadge extends StatelessWidget {
  const _BannerFollowerCountBadge({
    required this.topic,
    required this.formatCount,
  });

  final Topic topic;
  final String Function(int) formatCount;

  @override
  Widget build(BuildContext context) {
    final followingController =
        Get.findIfInstantiated<FollowingTopicsController>();

    if (followingController != null) {
      final ctrl = followingController;
      return Obx(() {
        final count = ctrl.getFollowerCount(topic);
        return _buildBadge(count);
      });
    }

    return _buildBadge(topic.followerCount);
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people_outline_rounded,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            '${formatCount(count)} ${count == 1 ? 'Follower' : 'Followers'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Backward-compatibility aliases
typedef HomeFeaturedBanner = FeaturedVideoBanner;
