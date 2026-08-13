import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/animated_interaction_buttons.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topic_management_screen.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_interaction_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Unified Topic Card Widget matching the premium full-bleed hero card design.
class TopicCardWidget extends StatefulWidget {
  const TopicCardWidget({
    super.key,
    this.topic,
    this.isHero = false,
    this.isDashboard = false,
    this.onFollowToggle,
    this.onExploreTap,
    this.showEditOption = true,
    this.onPreviousTap,
    this.onNextTap,
    this.currentIndex,
    this.totalItems,
    this.accentColor,
    this.trailing,
  });
  final Topic? topic;
  final bool isHero;
  final bool isDashboard;
  final VoidCallback? onFollowToggle;
  final VoidCallback? onExploreTap;
  final bool showEditOption;
  final VoidCallback? onPreviousTap;
  final VoidCallback? onNextTap;
  final int? currentIndex;
  final int? totalItems;
  final Color? accentColor;
  final Widget? trailing;

  @override
  State<TopicCardWidget> createState() => _TopicCardWidgetState();
}

class _TopicCardWidgetState extends State<TopicCardWidget>
    with SingleTickerProviderStateMixin {
  late TopicInteractionController _interactionController;
  late final FollowingTopicsController _followingTopicsController;
  final RxBool _isHovered = false.obs;
  Topic? _streamedTopic;

  Topic? get topic => _streamedTopic ?? widget.topic;

  static final Map<String, double> _aspectRatioCache = {};
  final RxnDouble _resolvedAspectRatio = RxnDouble();
  String? _lastResolvedUrl;

  void _resolveImageSize(String url) {
    if (_lastResolvedUrl == url) return;
    _lastResolvedUrl = url;

    if (_aspectRatioCache.containsKey(url)) {
      _resolvedAspectRatio.value = _aspectRatioCache[url];
      return;
    }

    final ImageProvider provider = CachedNetworkImageProvider(url);
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, synchronousCall) {
        if (info.image.width > 0 && info.image.height > 0) {
          final ratio = info.image.width / info.image.height;
          _aspectRatioCache[url] = ratio;
          _resolvedAspectRatio.value = ratio;
        }
        stream.removeListener(listener);
      },
      onError: (dynamic exception, stackTrace) {
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  @override
  void initState() {
    super.initState();
    _followingTopicsController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());
    if (widget.topic != null && widget.topic!.id.trim().isNotEmpty) {
      _initControllers(widget.topic!);
    }
  }

  void _initControllers(Topic topicItem) {
    if (topicItem.id.trim().isEmpty) return;
    _interactionController =
        Get.isRegistered<TopicInteractionController>(tag: topicItem.id)
        ? Get.find<TopicInteractionController>(tag: topicItem.id)
        : Get.put(TopicInteractionController(), tag: topicItem.id);
    _interactionController.initializeTopic(topicItem);
  }

  @override
  void didUpdateWidget(covariant TopicCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.topic != null &&
        widget.topic!.id.trim().isNotEmpty &&
        (oldWidget.topic == null || oldWidget.topic!.id != widget.topic!.id)) {
      _initControllers(widget.topic!);
      _resolvedAspectRatio.value = null;
      _lastResolvedUrl = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet =
        MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1024;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    final topicVal = widget.topic;
    if (topicVal == null || topicVal.id.trim().isEmpty) {
      return _buildSkeleton(context, isMobile, isTablet, isDesktop);
    }

    _streamedTopic = topicVal;
    final currentTopic = topic!;

    final exploreController = Get.isRegistered<ExploreTopicsController>()
        ? Get.find<ExploreTopicsController>()
        : null;
    final followingController = _followingTopicsController;

    final isOwner =
        widget.showEditOption &&
        Get.isRegistered<AuthService>() &&
        ((currentTopic.channelId != null &&
                currentTopic.channelId!.isNotEmpty &&
                AuthService.to.userChannel?.id == currentTopic.channelId) ||
            (currentTopic.creatorId != null &&
                currentTopic.creatorId!.isNotEmpty &&
                AuthService.to.uid == currentTopic.creatorId));

    return _buildPremiumCard(
      context,
      currentTopic,
      exploreController,
      followingController,
      isOwner,
      isMobile,
      isTablet,
      isDesktop,
    );
  }

  Widget _buildPremiumCard(
    BuildContext context,
    Topic currentTopic,
    ExploreTopicsController? exploreController,
    FollowingTopicsController followingController,
    bool isOwner,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final isHero = widget.isHero;
    final horizontalMargin = isHero
        ? (isDesktop ? 48.0 : (isTablet ? 32.0 : 16.0))
        : 0.0;

    return Obx(() {
      final isHovered = _isHovered.value;
      final defaultRatio = isHero
          ? (isDesktop ? 16 / 9 : (isTablet ? 1.5 : 1.4))
          : 16 / 9;
      final activeRatio = _resolvedAspectRatio.value ?? defaultRatio;

      final Widget cardContent = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isHovered
                ? (widget.accentColor ?? AppColors.brand).withValues(
                    alpha: 0.25,
                  )
                : AppColors.textPrimary.withValues(alpha: 0.05),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isHovered
                  ? (widget.accentColor ?? AppColors.brand).withValues(
                      alpha: 0.15,
                    )
                  : AppColors.bgPage.withValues(alpha: 0.3),
              blurRadius: isHovered ? 16 : 12,
              offset: Offset(0, isHovered ? 8 : 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AnimatedScale(
                  scale: isHovered ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: _buildBackgroundImage(currentTopic),
                ),
              ),
            ),

            // Premium Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.bgPage.withValues(alpha: 0.75),
                      AppColors.bgPage.withValues(alpha: 0.95),
                    ],
                    stops: const [0.15, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // Main Click area for exploring the topic
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (widget.onExploreTap != null) {
                      widget.onExploreTap!();
                    } else {
                      exploreController?.preloadTopicDetails(currentTopic);
                      Get.toNamed(
                        currentTopic.topicRoute,
                        arguments: {
                          'slug': currentTopic.slug,
                          'fromCard': true,
                          'topic': currentTopic,
                        },
                      );
                    }
                  },
                  splashColor: AppColors.textPrimary.withValues(alpha: 0.05),
                  highlightColor: AppColors.textPrimary.withValues(alpha: 0.02),
                ),
              ),
            ),

            // Content Column
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isHero
                      ? (isMobile ? 24 : 64)
                      : (isMobile ? 16.0 : 20.0),
                  vertical: isHero
                      ? (isMobile ? 20 : 36)
                      : (isMobile ? 14.0 : 18.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Row (Purple TOPIC Badge and Followers Badge)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                                  // Purple TOPIC Badge
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 8 : 12,
                                      vertical: isMobile ? 4 : 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          widget.accentColor ??
                                          const Color(
                                            0xFF9333EA,
                                          ), // Purple accent
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.label_important_rounded,
                                          size: isMobile ? 12 : 14,
                                          color: AppColors.textPrimary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'TOPIC',
                                          style: AppTextStyles.labelMedium
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                                fontSize: isMobile ? 10 : 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Followers count badge and optional trailing widget
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.bgPage.withValues(
                                            alpha: 0.4,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: AppColors.textPrimary
                                                .withValues(
                                                  alpha: 0.12,
                                                ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.people_outline_rounded,
                                              size: isMobile ? 12 : 14,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${FormatUtils.formatCount(currentTopic.followerCount)} Followers',
                                              style: AppTextStyles.labelMedium
                                                  .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontSize: isMobile
                                                        ? 10
                                                        : 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (widget.trailing != null) ...[
                                        const SizedBox(width: 8),
                                        widget.trailing!,
                                      ],
                                    ],
                                  ),
                                ],
                              ),

                              if (!isHero) const Spacer(),

                              // Title, description and buttons
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    currentTopic.title,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      fontSize: isHero
                                          ? (isDesktop
                                                ? 44
                                                : (isTablet ? 32 : 24))
                                          : (isMobile ? 18 : 22),
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      height: 1.15,
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: isHero ? 2 : 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  const SizedBox(height: 8),

                                  // Metadata row (Videos count, creation time and Category capsule)
                                  Row(
                                    children: [
                                      Text(
                                        '${FormatUtils.formatCount(currentTopic.videoCount)} videos • ${timeago.format(currentTopic.createdAt)}',
                                        style: AppTextStyles.labelMedium
                                            .copyWith(
                                              color: AppColors.textSecondary,
                                              fontSize: isMobile ? 11 : 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.textPrimary
                                              .withValues(
                                                alpha: 0.12,
                                              ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          currentTopic.category,
                                          style: AppTextStyles.labelMedium
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                                fontSize: isMobile ? 9 : 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // Description
                                  Text(
                                    currentTopic.description,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: isMobile ? 11 : 12.5,
                                      height: 1.4,
                                    ),
                                    maxLines: isHero ? 3 : 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  SizedBox(height: isMobile ? 14 : 20),

                                  // Buttons Row
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: [
                                        // Follow button (regular mode) or Edit button (Dashboard mode)
                                        if (isOwner &&
                                            widget.showEditOption) ...[
                                          // Edit Button (Rose design)
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              final topicManagementController =
                                                  Get.isRegistered<
                                                    TopicManagementController
                                                  >()
                                                  ? Get.find<
                                                      TopicManagementController
                                                    >()
                                                  : Get.put(
                                                      TopicManagementController(),
                                                    );
                                              Get.dialog(
                                                EditTopicDialog(
                                                  topic: currentTopic,
                                                  channelId:
                                                      currentTopic.channelId ??
                                                      '',
                                                  isDarkMode: true,
                                                  controller:
                                                      topicManagementController,
                                                ),
                                              ).then((_) {
                                                if (Get.isRegistered<
                                                  TopicController
                                                >()) {
                                                  Get.find<TopicController>()
                                                      .refreshTopic();
                                                }
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFE11D48,
                                              ), // rose-600
                                              foregroundColor:
                                                  AppColors.textPrimary,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isMobile ? 14 : 20,
                                                vertical: isMobile ? 8 : 12,
                                              ),
                                              shape: const StadiumBorder(),
                                              elevation: 0,
                                            ),
                                            icon: Icon(
                                              Icons.edit_rounded,
                                              size: isMobile ? 15 : 18,
                                              color: AppColors.textPrimary,
                                            ),
                                            label: Text(
                                              'Edit',
                                              style: AppTextStyles.labelMedium
                                                  .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: isMobile
                                                        ? 12
                                                        : 13,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                            ),
                                          ),
                                        ] else ...[
                                          // Follow / Following Button
                                          Obx(() {
                                            final isFollowed =
                                                followingController
                                                    .isTopicFollowed(
                                                      currentTopic.id,
                                                    );
                                            return AnimatedFollowTopicButton(
                                              isFollowed: isFollowed,
                                              compact: isMobile,
                                              onPressed:
                                                  widget.onFollowToggle ??
                                                  () {
                                                    followingController
                                                        .toggleFollowTopic(
                                                          currentTopic,
                                                        );
                                                  },
                                            );
                                          }),
                                        ],

                                        const SizedBox(width: 8),

                                        // Share Button (always shown)
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            final topicUrl =
                                                DeepLinkService.topicUrl(
                                                  currentTopic.slug,
                                                );
                                            ShareBottomSheet.show(
                                              title: currentTopic.title,
                                              url: topicUrl,
                                              thumbnailUrl:
                                                  currentTopic.coverImage ??
                                                  currentTopic.thumbnailUrl,
                                              followerCount:
                                                  currentTopic.followerCount,
                                              videoCount:
                                                  currentTopic.videoCount,
                                              handle: currentTopic.slug,
                                              type: 'topic',
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors
                                                .textPrimary
                                                .withValues(alpha: 0.12),
                                            foregroundColor:
                                                AppColors.textPrimary,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isMobile ? 14 : 20,
                                              vertical: isMobile ? 8 : 12,
                                            ),
                                            shape: const StadiumBorder(),
                                            elevation: 0,
                                          ),
                                          icon: Icon(
                                            Icons.share_rounded,
                                            size: isMobile ? 15 : 18,
                                            color: AppColors.textPrimary,
                                          ),
                                          label: Text(
                                            'Share',
                                            style: AppTextStyles.labelMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: isMobile ? 12 : 13,
                                                  color: AppColors.textPrimary,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

            // Carousel arrows (only for Hero layout)
            if (isHero) ...[
              // Left Arrow
              if (widget.currentIndex != null && widget.currentIndex! > 0)
                Positioned(
                  left: isMobile ? 8 : 24,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Material(
                      color: AppColors.bgPage.withValues(alpha: 0.5),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: widget.onPreviousTap,
                      ),
                    ),
                  ),
                ),

              // Right Arrow
              if (widget.totalItems != null &&
                  widget.currentIndex != null &&
                  widget.currentIndex! < widget.totalItems! - 1)
                Positioned(
                  right: isMobile ? 8 : 24,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Material(
                      color: AppColors.bgPage.withValues(alpha: 0.5),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        icon: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: widget.onNextTap,
                      ),
                    ),
                  ),
                ),

              // Carousel dots indicators at bottom
              if (widget.totalItems != null && widget.totalItems! > 1)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.totalItems!, (index) {
                      final isSelected = widget.currentIndex == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSelected ? 24 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textPrimary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ],
        ),
      );

      Widget card = AspectRatio(aspectRatio: activeRatio, child: cardContent);

      if (isHero) {
        card = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: 24,
          ),
          child: card,
        );
      }

      return MouseRegion(
        onEnter: (_) => _isHovered.value = true,
        onExit: (_) => _isHovered.value = false,
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: isHovered ? (isHero ? 1.015 : 1.025) : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: card,
        ),
      );
    });
  }

  Widget _buildBackgroundImage(Topic currentTopic) {
    final bgUrl =
        (currentTopic.coverImage != null && currentTopic.coverImage!.isNotEmpty)
        ? currentTopic.coverImage
        : (currentTopic.thumbnailUrl != null &&
              currentTopic.thumbnailUrl!.isNotEmpty)
        ? currentTopic.thumbnailUrl
        : null;

    if (bgUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _resolveImageSize(bgUrl);
        }
      });
      return Stack(
        fit: StackFit.expand,
        children: [
          // Background ambient backdrop fill with blur
          CachedNetworkImage(
            imageUrl: bgUrl,
            fit: BoxFit.cover,
            errorWidget: (context, error, stackTrace) {
              return _buildGradientBackground();
            },
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
          // Dynamic topic artwork full-bleed cover fill
          CachedNetworkImage(
            imageUrl: bgUrl,
            fit: BoxFit.cover,
            errorWidget: (context, error, stackTrace) {
              return _buildGradientBackground();
            },
          ),
        ],
      );
    }
    return _buildGradientBackground();
  }

  Widget _buildGradientBackground() {
    final accent = widget.accentColor ?? AppColors.brand;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.3),
            accent.withValues(alpha: 0.15),
            AppColors.bgPage,
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(
    BuildContext context,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    if (widget.isHero) {
      return _buildHeroSkeleton(isMobile, isTablet, isDesktop);
    } else {
      return _buildStandardSkeleton(isMobile);
    }
  }

  Widget _buildHeroSkeleton(bool isMobile, bool isTablet, bool isDesktop) {
    final horizontalMargin = isDesktop ? 48.0 : (isTablet ? 32.0 : 16.0);
    final defaultRatio = isDesktop ? 16 / 9 : (isTablet ? 1.5 : 1.4);
    final activeRatio = _resolvedAspectRatio.value ?? defaultRatio;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 24),
      child: AspectRatio(
        aspectRatio: activeRatio,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
            ),
          ),
          child: Shimmer.fromColors(
            baseColor: const Color(0xFF161618),
            highlightColor: const Color(0xFF28282C),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 96,
                vertical: isMobile ? 24 : 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: isDesktop ? 400.0 : 250.0,
                    height: isMobile ? 32 : 48,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 180,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: isMobile ? 36 : 48,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  SizedBox(height: isMobile ? 24 : 32),
                  Row(
                    children: [
                      Container(
                        width: isMobile ? 120 : 150,
                        height: isMobile ? 40 : 48,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: isMobile ? 120 : 150,
                        height: isMobile ? 40 : 48,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardSkeleton(bool isMobile) {
    final activeRatio = _resolvedAspectRatio.value ?? 16 / 9;
    return AspectRatio(
      aspectRatio: activeRatio,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
          ),
        ),
        child: Shimmer.fromColors(
          baseColor: const Color(0xFF161618),
          highlightColor: const Color(0xFF28282C),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 150,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
