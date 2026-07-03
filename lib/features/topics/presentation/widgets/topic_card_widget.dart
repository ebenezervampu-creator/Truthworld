import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topic_management_screen.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_interaction_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/saved_topics_controller.dart';

/// Unified Topic Card Widget that supports standard grid layouts and hero/carousel views.
class TopicCardWidget extends StatefulWidget {
  final Topic? topic;
  final bool isHero;
  final bool isDashboard;
  final VoidCallback? onSaveToggle;
  final VoidCallback? onExploreTap;
  final bool showEditOption;
  final VoidCallback? onPreviousTap;
  final VoidCallback? onNextTap;
  final int? currentIndex;
  final int? totalItems;

  const TopicCardWidget({
    super.key,
    this.topic,
    this.isHero = false,
    this.isDashboard = false,
    this.onSaveToggle,
    this.onExploreTap,
    this.showEditOption = true,
    this.onPreviousTap,
    this.onNextTap,
    this.currentIndex,
    this.totalItems,
  });

  @override
  State<TopicCardWidget> createState() => _TopicCardWidgetState();
}

class _TopicCardWidgetState extends State<TopicCardWidget>
    with SingleTickerProviderStateMixin {
  late TopicInteractionController _interactionController;
  late final SavedTopicsController _savedTopicsController;
  final RxBool _isHovered = false.obs;
  final RxBool _isPressed = false.obs;
  final Rx<Offset?> _hoverPosition = Rx<Offset?>(null);
  Topic? _streamedTopic;

  Topic? get topic => _streamedTopic ?? widget.topic;

  @override
  void initState() {
    super.initState();
    _savedTopicsController = Get.isRegistered<SavedTopicsController>()
        ? Get.find<SavedTopicsController>()
        : Get.put(SavedTopicsController());
    if (widget.topic != null) {
      _initControllers(widget.topic!);
    }
  }

  void _initControllers(Topic topicItem) {
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
        (oldWidget.topic == null || oldWidget.topic!.id != widget.topic!.id)) {
      _initControllers(widget.topic!);
    }
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

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;
    final bool isTablet = size.width >= 600 && size.width < 1024;
    final bool isDesktop = size.width >= 1024;

    if (widget.topic == null) {
      return _buildSkeleton(context, isMobile, isTablet, isDesktop);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('topics')
          .doc(widget.topic!.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          _streamedTopic = Topic.fromDocumentSnapshot(snapshot.data!);
          final count = _streamedTopic!.likeCount;
          if (_interactionController.initialDbLikeCount.value != count) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _interactionController.updateInitialLikeCount(count);
            });
          }
        } else {
          _streamedTopic = widget.topic;
        }

        final currentTopic = topic!;

        final ExploreTopicsController? exploreController =
            Get.isRegistered<ExploreTopicsController>()
            ? Get.find<ExploreTopicsController>()
            : null;
        final SavedTopicsController savedController = _savedTopicsController;

        final bool isOwner =
            widget.showEditOption &&
            currentTopic.channelId != null &&
            Get.isRegistered<AuthService>() &&
            AuthService.to.userChannel?.id == currentTopic.channelId;

        if (widget.isHero) {
          return _buildHeroCard(
            context,
            currentTopic,
            exploreController,
            savedController,
            isOwner,
            isMobile,
            isTablet,
            isDesktop,
          );
        } else {
          return _buildStandardCard(
            context,
            currentTopic,
            exploreController,
            savedController,
            isOwner,
            isMobile,
            isTablet,
          );
        }
      },
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    Topic currentTopic,
    ExploreTopicsController? exploreController,
    SavedTopicsController savedController,
    bool isOwner,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final height = isDesktop ? 550.0 : (isTablet ? 480.0 : 420.0);
    final horizontalMargin = isDesktop ? 48.0 : (isTablet ? 32.0 : 16.0);

    return Obx(() {
      double scale = 1.0;
      double translateY = 0.0;
      if (_isPressed.value) {
        scale = 0.98;
      } else if (_isHovered.value) {
        scale = 1.015;
        translateY = -5.0;
      }

      return MouseRegion(
        onEnter: (_) => _isHovered.value = true,
        onExit: (_) {
          _isHovered.value = false;
          _hoverPosition.value = null;
        },
        onHover: (event) {
          _hoverPosition.value = event.localPosition;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0.0, translateY, 0.0),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: Container(
              height: height,
              width: double.infinity,
              margin: EdgeInsets.symmetric(
                horizontal: horizontalMargin,
                vertical: 24,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isHovered.value
                      ? AppColors.brand.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered.value
                        ? AppColors.brand.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.5),
                    blurRadius: _isHovered.value ? 25 : 20,
                    spreadRadius: _isHovered.value ? 1 : 0,
                    offset: _isHovered.value
                        ? const Offset(0, 12)
                        : const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background Image
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _buildBackgroundImage(currentTopic),
                    ),
                  ),

                  // Spotlight hover highlight
                  Positioned.fill(
                    child: Obx(() {
                      final pos = _hoverPosition.value;
                      if (!_isHovered.value || pos == null) {
                        return const SizedBox.shrink();
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CustomPaint(
                          painter: HoverSpotlightPainter(
                            spotlightPosition: pos,
                            color: AppColors.brand.withValues(alpha: 0.15),
                          ),
                        ),
                      );
                    }),
                  ),

                  // Gradient Overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.95),
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Material InkWell ripple feedback layer
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          splashColor: AppColors.brand.withValues(alpha: 0.25),
                          highlightColor: AppColors.brand.withValues(
                            alpha: 0.1,
                          ),
                          onTapDown: (_) => _isPressed.value = true,
                          onTapCancel: () => _isPressed.value = false,
                          onTap: () {
                            _isPressed.value = false;
                            if (widget.onExploreTap != null) {
                              widget.onExploreTap!();
                            } else {
                              exploreController?.preloadTopicDetails(
                                currentTopic,
                              );
                              Get.toNamed(
                                '/topic/${currentTopic.slug}',
                                arguments: {
                                  'slug': currentTopic.slug,
                                  'fromCard': true,
                                },
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),

                  // Left Arrow
                  if (!isMobile && widget.onPreviousTap != null)
                    Positioned(
                      left: 24,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                            ),
                            onPressed: widget.onPreviousTap,
                          ),
                        ),
                      ),
                    ),

                  // Right Arrow
                  if (!isMobile && widget.onNextTap != null)
                    Positioned(
                      right: 24,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            ),
                            onPressed: widget.onNextTap,
                          ),
                        ),
                      ),
                    ),

                  // Main Content
                  Positioned(
                    left: isMobile ? 24 : 96,
                    right: isMobile ? 24 : 96,
                    top: isMobile ? 24 : 40,
                    bottom: isMobile ? 24 : 40,
                    child: IgnorePointer(
                      ignoring: false, // Ensure button clicks pass through
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row (Badges)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      currentTopic.category.toUpperCase(),
                                      style: AppTextStyles.badge.copyWith(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Title
                          Text(
                            currentTopic.title,
                            style: AppTextStyles.labelMedium.copyWith(
                              fontSize: isDesktop ? 48 : (isTablet ? 36 : 28),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: 12),

                          // Meta Row
                          Row(
                            children: [
                              Text(
                                '${_formatCount(currentTopic.videoCount)} videos • TOPIC',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                              SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  currentTopic.category,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 12),

                          // Description
                          Text(
                            currentTopic.description,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Colors.white54,
                              fontSize: isDesktop ? 16 : 14,
                              height: 1.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: 12),

                          // Metadata Badges (Views, Relative Time, Tags)
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Views Count
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.remove_red_eye_outlined,
                                    size: isMobile ? 14 : 16,
                                    color: Colors.white60,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '${_formatCount(currentTopic.views)} views',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: Colors.white60,
                                      fontSize: isMobile ? 12 : 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '•',
                                style: TextStyle(color: Colors.white30),
                              ),
                              // Relative Time Uploaded
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: isMobile ? 14 : 16,
                                    color: Colors.white60,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    timeago.format(currentTopic.createdAt),
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: Colors.white60,
                                      fontSize: isMobile ? 12 : 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '•',
                                style: TextStyle(color: Colors.white30),
                              ),
                              // Category Tag
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.brand.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  currentTopic.category.toUpperCase(),
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.brand,
                                    fontSize: isMobile ? 10 : 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Related tags
                              if (currentTopic.relatedTopics.isNotEmpty)
                                ...currentTopic.relatedTopics
                                    .take(3)
                                    .map(
                                      (tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          '#$tag',
                                          style: AppTextStyles.labelMedium
                                              .copyWith(
                                                color: Colors.white70,
                                                fontSize: isMobile ? 10 : 11,
                                              ),
                                        ),
                                      ),
                                    ),
                            ],
                          ),

                          SizedBox(height: isMobile ? 16 : 24),

                          // Action Buttons Row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                              // Explore Button
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (widget.onExploreTap != null) {
                                    widget.onExploreTap!();
                                  } else {
                                    exploreController?.preloadTopicDetails(
                                      currentTopic,
                                    );
                                    Get.toNamed(
                                      '/topic/${currentTopic.slug}',
                                      arguments: {
                                        'slug': currentTopic.slug,
                                        'fromCard': true,
                                      },
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 16 : 24,
                                    vertical: isMobile ? 10 : 14,
                                  ),
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                ),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  "Explore Topic",
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 13 : 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Love Button (Tied to TopicInteractionController)
                              Obx(() {
                                final isLiked =
                                    _interactionController.isLiked.value;
                                final likeCount =
                                    _interactionController.likeCount.value;
                                return ElevatedButton.icon(
                                  onPressed: () {
                                    _interactionController.toggleLike(
                                      currentTopic.id,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.12,
                                    ),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 16 : 24,
                                      vertical: isMobile ? 10 : 14,
                                    ),
                                    shape: const StadiumBorder(),
                                    elevation: 0,
                                  ),
                                  icon: Icon(
                                    isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 20,
                                    color: isLiked
                                        ? Colors.redAccent
                                        : Colors.white,
                                  ),
                                  label: Text(
                                    _formatCount(likeCount),
                                    style: AppTextStyles.labelMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 13 : 14,
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(width: 12),

                              // Follow/Save Button
                              Obx(() {
                                final isSaved = savedController.isTopicSaved(
                                  currentTopic.id,
                                );
                                return ElevatedButton.icon(
                                  onPressed:
                                      widget.onSaveToggle ??
                                      () {
                                        savedController.toggleFollowTopic(
                                          currentTopic,
                                        );
                                      },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.12,
                                    ),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 16 : 24,
                                      vertical: isMobile ? 10 : 14,
                                    ),
                                    shape: const StadiumBorder(),
                                    elevation: 0,
                                  ),
                                  icon: Icon(
                                    isSaved
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.bookmark_border_rounded,
                                    size: 20,
                                    color: isSaved
                                        ? AppColors.brand
                                        : Colors.white,
                                  ),
                                  label: Text(
                                    isSaved ? "Following" : "Follow Topic",
                                    style: AppTextStyles.labelMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 13 : 14,
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(width: 12),

                              // Share Button
                              ElevatedButton.icon(
                                onPressed: () {
                                  final topicUrl = DeepLinkService.topicUrl(
                                    currentTopic.slug,
                                  );
                                  ShareBottomSheet.show(
                                    title: currentTopic.title,
                                    url: topicUrl,
                                    thumbnailUrl: currentTopic.thumbnailUrl,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.12,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 16 : 24,
                                    vertical: isMobile ? 10 : 14,
                                  ),
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.share_rounded, size: 20),
                                label: Text(
                                  "Share",
                                  style: AppTextStyles.labelMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 13 : 14,
                                  ),
                                ),
                              ),

                              if (isOwner) ...[
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final topicManagementController =
                                        Get.isRegistered<
                                          TopicManagementController
                                        >()
                                        ? Get.find<TopicManagementController>()
                                        : Get.put(TopicManagementController());
                                    Get.dialog(
                                      EditTopicDialog(
                                        topic: currentTopic,
                                        channelId: currentTopic.channelId ?? '',
                                        isDarkMode: true,
                                        controller: topicManagementController,
                                      ),
                                    ).then((_) {
                                      if (Get.isRegistered<TopicController>()) {
                                        Get.find<TopicController>()
                                            .refreshTopic();
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: Colors.black,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 16 : 24,
                                      vertical: isMobile ? 10 : 14,
                                    ),
                                    shape: const StadiumBorder(),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 20,
                                    color: Colors.black,
                                  ),
                                  label: Text(
                                    "Edit Topic",
                                    style: AppTextStyles.labelMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 13 : 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),

                  // Dots Indicator
                  if (widget.totalItems != null && widget.totalItems! > 1)
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.totalItems!, (index) {
                          final isSelected = widget.currentIndex == index;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isSelected ? 24 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildStandardCard(
    BuildContext context,
    Topic currentTopic,
    ExploreTopicsController? exploreController,
    SavedTopicsController savedController,
    bool isOwner,
    bool isMobile,
    bool isTablet,
  ) {
    return ObxValue<RxBool>(
      (isHovered) => MouseRegion(
        onEnter: (_) => isHovered.value = true,
        onExit: (_) => isHovered.value = false,
        child: GestureDetector(
          onTap: () {
            if (widget.onExploreTap != null) {
              widget.onExploreTap!();
            } else {
              exploreController?.preloadTopicDetails(currentTopic);
              Get.toNamed(
                '/topic/${currentTopic.slug}',
                arguments: {'slug': currentTopic.slug, 'fromCard': true},
              );
            }
          },
          child: AnimatedScale(
            scale: isHovered.value ? 1.025 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isHovered.value
                      ? AppColors.brand.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.05),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHovered.value
                        ? AppColors.brand.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.3),
                    blurRadius: isHovered.value ? 16 : 12,
                    offset: Offset(0, isHovered.value ? 8 : 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Background Image with scale animation on hover
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedScale(
                        scale: isHovered.value ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: _buildBackgroundImage(currentTopic),
                      ),
                    ),
                  ),

                  // Gradient Overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          stops: const [0.2, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Row (Category Badge only, top-right stats badge removed)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 6 : 8,
                                vertical: isMobile ? 3 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: isMobile ? 5 : 6,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: isMobile ? 3 : 4),
                                  Text(
                                    currentTopic.category.toUpperCase(),
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: Colors.white,
                                      fontSize: isMobile ? 9 : 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Title
                        Text(
                          currentTopic.title,
                          style: AppTextStyles.labelMedium.copyWith(
                            fontSize: isMobile ? 18 : (isTablet ? 20 : 22),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.1,
                          ),
                          maxLines: isMobile ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: isMobile ? 4 : 6),

                        // Meta Row
                        Row(
                          children: [
                            Text(
                              '${_formatCount(currentTopic.videoCount)} videos • TOPIC',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white70,
                                fontSize: isMobile ? 11 : 12,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                currentTopic.category,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: Colors.white70,
                                  fontSize: isMobile ? 9 : 10,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: isMobile ? 4 : 6),

                        // Description
                        Text(
                          currentTopic.description,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white70,
                            fontSize: isMobile ? 11 : 12,
                            height: 1.3,
                          ),
                          maxLines: isMobile ? 1 : (isTablet ? 1 : 2),
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: 8),

                        // Views, time uploaded, topics tags metadata
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Views
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.remove_red_eye_outlined,
                                  size: isMobile ? 12 : 13,
                                  color: Colors.white38,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${_formatCount(currentTopic.views)} views',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: Colors.white38,
                                    fontSize: isMobile ? 10 : 11,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '•',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white24,
                                fontSize: isMobile ? 10 : 11,
                              ),
                            ),
                            // Time Uploaded
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: isMobile ? 12 : 13,
                                  color: Colors.white38,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  timeago.format(currentTopic.createdAt),
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: Colors.white38,
                                    fontSize: isMobile ? 10 : 11,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '•',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white24,
                                fontSize: isMobile ? 10 : 11,
                              ),
                            ),
                            // Category tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.brand.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                currentTopic.category.toUpperCase(),
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.brand,
                                  fontSize: isMobile ? 8 : 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Related tags
                            if (currentTopic.relatedTopics.isNotEmpty)
                              ...currentTopic.relatedTopics
                                  .take(2)
                                  .map(
                                    (tag) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '#$tag',
                                        style: AppTextStyles.labelMedium
                                            .copyWith(
                                              color: Colors.white70,
                                              fontSize: isMobile ? 8 : 9,
                                            ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),

                        SizedBox(height: isMobile ? 10 : 14),

                        // Buttons Row
                        Row(
                          children: [
                            // Explore Topic Button
                            Expanded(
                              child: SizedBox(
                                height: isMobile ? 32 : 36,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (widget.onExploreTap != null) {
                                      widget.onExploreTap!();
                                    } else {
                                      exploreController?.preloadTopicDetails(
                                        currentTopic,
                                      );
                                      Get.toNamed(
                                        '/topic/${currentTopic.slug}',
                                        arguments: {
                                          'slug': currentTopic.slug,
                                          'fromCard': true,
                                        },
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.play_arrow,
                                    size: isMobile ? 14 : 16,
                                  ),
                                  label: Text(
                                    'Explore',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: Colors.black,
                                      fontSize: isMobile ? 10.5 : 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: isMobile ? 6 : 8),

                            // Love Button
                            Obx(() {
                              final isLiked =
                                  _interactionController.isLiked.value;
                              final likeCount =
                                  _interactionController.likeCount.value;
                              return Expanded(
                                child: SizedBox(
                                  height: isMobile ? 32 : 36,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      _interactionController.toggleLike(
                                        currentTopic.id,
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: Icon(
                                      isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: isMobile ? 14 : 16,
                                      color: isLiked
                                          ? Colors.redAccent
                                          : Colors.white,
                                    ),
                                    label: Text(
                                      _formatCount(likeCount),
                                      style: AppTextStyles.labelMedium.copyWith(
                                        fontSize: isMobile ? 10.5 : 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            SizedBox(width: isMobile ? 6 : 8),

                            // Save Topic Button
                            Obx(() {
                              final isSaved = savedController.isTopicSaved(
                                currentTopic.id,
                              );
                              return Expanded(
                                child: SizedBox(
                                  height: isMobile ? 32 : 36,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        widget.onSaveToggle ??
                                        () {
                                          savedController.toggleFollowTopic(
                                            currentTopic,
                                          );
                                        },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: Icon(
                                      isSaved
                                          ? Icons.bookmark_rounded
                                          : Icons.bookmark_border_rounded,
                                      size: isMobile ? 14 : 16,
                                      color: isSaved
                                          ? AppColors.brand
                                          : Colors.white,
                                    ),
                                    label: Text(
                                      isSaved ? 'Saved' : 'Save',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        fontSize: isMobile ? 10.5 : 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            SizedBox(width: isMobile ? 6 : 8),

                            // Share Topic Button
                            SizedBox(
                              height: isMobile ? 32 : 36,
                              width: isMobile ? 32 : 36,
                              child: OutlinedButton(
                                onPressed: () {
                                  final topicUrl = DeepLinkService.topicUrl(
                                    currentTopic.slug,
                                  );
                                  ShareBottomSheet.show(
                                    title: currentTopic.title,
                                    url: topicUrl,
                                    thumbnailUrl: currentTopic.thumbnailUrl,
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                  padding: EdgeInsets.zero,
                                  shape: const CircleBorder(),
                                ),
                                child: Icon(
                                  Icons.share_rounded,
                                  size: isMobile ? 14 : 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      false.obs,
    );
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
      return CachedNetworkImage(
        imageUrl: bgUrl,
        fit: BoxFit.cover,
        errorWidget: (context, error, stackTrace) {
          return _buildGradientBackground();
        },
      );
    }
    return _buildGradientBackground();
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brand.withValues(alpha: 0.3),
            AppColors.brand.withValues(alpha: 0.15),
            Colors.black,
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
    final height = isDesktop ? 550.0 : (isTablet ? 480.0 : 420.0);
    final horizontalMargin = isDesktop ? 48.0 : (isTablet ? 32.0 : 16.0);

    return Container(
      height: height,
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const Spacer(),
              Container(
                width: isDesktop ? 400.0 : 250.0,
                height: isMobile ? 32 : 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 180,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: isMobile ? 36 : 48,
                decoration: BoxDecoration(
                  color: Colors.white,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: isMobile ? 120 : 150,
                    height: isMobile ? 40 : 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardSkeleton(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const Spacer(),
              Container(
                width: 150,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 200,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
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
    );
  }
}

class HoverSpotlightPainter extends CustomPainter {
  final Offset spotlightPosition;
  final Color color;

  HoverSpotlightPainter({required this.spotlightPosition, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, Colors.transparent],
        radius: 0.7,
      ).createShader(Rect.fromCircle(center: spotlightPosition, radius: 250));

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant HoverSpotlightPainter oldDelegate) {
    return oldDelegate.spotlightPosition != spotlightPosition ||
        oldDelegate.color != color;
  }
}
