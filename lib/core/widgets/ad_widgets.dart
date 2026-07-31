import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/widgets/mobile_friendly_video_player.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

class AdMediaWidget extends StatefulWidget {
  const AdMediaWidget({required this.ad, super.key, this.fit = BoxFit.cover});
  final AdItem ad;
  final BoxFit fit;

  @override
  State<AdMediaWidget> createState() => _AdMediaWidgetState();
}

class _AdMediaWidgetState extends State<AdMediaWidget> {
  VideoPlayerController? _controller;
  final RxBool _isMuted = true.obs;
  final RxBool _isInitialized = false.obs;
  final RxInt _rebuildTrigger = 0.obs;

  @override
  void initState() {
    super.initState();
    if (widget.ad.videoUrl != null && widget.ad.videoUrl!.isNotEmpty) {
      _initializeVideo();
    }
  }

  void _initializeVideo() {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.ad.videoUrl!),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
      ),
    );
    _controller!
        .initialize()
        .then((_) {
          if (mounted) {
            _controller!.setVolume(0);
            _controller!.setLooping(true);
            _controller!.play();
            _isInitialized.value = true;
          }
        })
        .catchError((e) {
          debugPrint('[AdMediaWidget] Error initializing video: $e');
        });
  }

  @override
  void didUpdateWidget(AdMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad.videoUrl != widget.ad.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isInitialized.value = false;
      if (widget.ad.videoUrl != null && widget.ad.videoUrl!.isNotEmpty) {
        _initializeVideo();
      } else {
        _rebuildTrigger.value++;
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      _rebuildTrigger.value; // register dependency
      if (widget.ad.videoUrl != null &&
          widget.ad.videoUrl!.isNotEmpty &&
          _controller != null) {
        if (!_isInitialized.value) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.ad.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.textTertiary),
                ),
              ),
            ),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: _controller!.value.size.width > 0
                    ? _controller!.value.size.width
                    : 160,
                height: _controller!.value.size.height > 0
                    ? _controller!.value.size.height
                    : 90,
                child: MobileFriendlyVideoPlayer(
                  controller: _controller!,
                  looping: true,
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  _isMuted.value = !_isMuted.value;
                  _controller?.setVolume(_isMuted.value ? 0.0 : 1.0);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.textDisabled,
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    _isMuted.value
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: AppColors.textPrimary,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      }

      if (widget.ad.imageUrl.isNotEmpty) {
        return Image.network(
          widget.ad.imageUrl,
          fit: widget.fit,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const ColoredBox(
              color: Colors.black26,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.textTertiary),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackGradient(),
        );
      }

      return _buildFallbackGradient();
    });
  }

  Widget _buildFallbackGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.ad.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          widget.ad.fallbackIcon ?? Icons.ads_click_rounded,
          size: 48,
          color: AppColors.textPrimary.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

class AdCardController extends GetxController {
  bool isHovered = false;
  void setHovered(bool val) {
    isHovered = val;
    update();
  }
}

class HomepageAdCard extends StatelessWidget {
  const HomepageAdCard({required this.ad, super.key});
  final AdItem ad;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService.to.recordImpression(ad.id);
    });
    return GetBuilder<AdCardController>(
      init: AdCardController(),
      global: false,
      builder: (controller) {
        return MouseRegion(
          onEnter: (_) => controller.setHovered(true),
          onExit: (_) => controller.setHovered(false),
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            transform: Matrix4.diagonal3Values(
              controller.isHovered ? 1.02 : 1.0,
              controller.isHovered ? 1.02 : 1.0,
              1,
            ),
            transformAlignment: Alignment.center,
            duration: AppTheme.animations.normal,
            curve: AppTheme.animations.easeOutCubic,
            decoration: BoxDecoration(
              color: controller.isHovered
                  ? AppTheme.colors.surfaceVariant
                  : AppTheme.colors.surface,
              borderRadius: AppTheme.radius.circularLg,
              border: Border.all(
                color: controller.isHovered
                    ? AppTheme.colors.primary.withValues(alpha: 0.3)
                    : AppTheme.colors.border.withValues(alpha: 0.3),
                width: AppTheme.components.dividerThickness,
              ),
              boxShadow: controller.isHovered
                  ? [
                      BoxShadow(
                        color: AppColors.bgPage.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : AppTheme.shadows.elevationSm,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: AppTheme.radius.circularLg,
              child: InkWell(
                onTap: () => AdService.to.showAdPromoDialog(context, ad),
                borderRadius: AppTheme.radius.circularLg,
                splashColor: AppTheme.colors.primary.withValues(alpha: 0.2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ad Banner Visual (Matches video card thumbnail size & aspect ratio)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppTheme.radius.lg),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AdMediaWidget(ad: ad),
                            if (ad.videoUrl != null &&
                                    ad.videoUrl!.isNotEmpty ||
                                ad.imageUrl.isNotEmpty)
                              Container(
                                color: AppColors.bgPage.withValues(alpha: 0.3),
                              ),
                            () {
                              final isLightBg =
                                  ad.gradientColors.first.computeLuminance() >
                                  0.5;
                              final textColor = isLightBg
                                  ? AppColors.bgPage.withValues(alpha: 0.6)
                                  : AppColors.textSecondary;
                              final titleColor = isLightBg
                                  ? AppColors.bgPage
                                  : AppColors.textPrimary;
                              final logoColor = isLightBg
                                  ? AppColors.bgPage
                                  : AppColors.textPrimary;
                              final iconColor = isLightBg
                                  ? AppColors.bgPage.withValues(alpha: 0.1)
                                  : AppColors.textPrimary.withValues(
                                      alpha: 0.12,
                                    );

                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Decorative Background Icon
                                  if (ad.videoUrl == null ||
                                      ad.videoUrl!.isEmpty)
                                    if (ad.imageUrl.isEmpty)
                                      Center(
                                        child: Icon(
                                          ad.fallbackIcon ??
                                              Icons.ads_click_rounded,
                                          size: 72,
                                          color: iconColor,
                                        ),
                                      ),
                                  // Left-Aligned Promotional Content
                                  Positioned(
                                    left: 16,
                                    top: 16,
                                    bottom: 16,
                                    right: 80,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              ad.fallbackIcon ??
                                                  Icons.ads_click_rounded,
                                              size: 16,
                                              color: logoColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              ad.advertiser.toUpperCase(),
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          ad.title,
                                          maxLines: 2,
                                          style: TextStyle(
                                            color: titleColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.bgPage.withValues(
                                              alpha: 0.8,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: AppColors.textPrimary
                                                  .withValues(
                                                    alpha: 0.15,
                                                  ),
                                            ),
                                          ),
                                          child: Text(
                                            ad.ctaText.toUpperCase(),
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // External Link/Arrow Overlay on Bottom Right
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.bgPage.withValues(
                                          alpha: 0.6,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.north_east_rounded,
                                        color: AppColors.textPrimary,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }(),
                          ],
                        ),
                      ),
                    ),

                    // Ad Info & Details (Exact padding & layout matching VideoCard details)
                    Padding(
                      padding: EdgeInsets.only(
                        left: AppTheme.spacing.xs,
                        right: AppTheme.spacing.xs,
                        top: AppTheme.spacing.xs,
                        bottom: AppTheme.spacing.sm,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Text Block - Full Width (No Avatar as per YouTube Spec)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Title Line
                                Text(
                                  ad.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.typography.body.copyWith(
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Description Line
                                Text(
                                  ad.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.typography.bodyMedium
                                      .copyWith(
                                        color: AppTheme.colors.textSecondary,
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                // Sponsored Badge Line
                                RichText(
                                  text: TextSpan(
                                    style: AppTheme.typography.caption.copyWith(
                                      fontSize: 11,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Sponsored',
                                        style: TextStyle(
                                          color: AppTheme.colors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' • ${ad.advertiser}',
                                        style: TextStyle(
                                          color: AppTheme.colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Options Vert Button (Matches VideoCard)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.more_vert_rounded,
                              size: 20,
                              color: AppTheme.colors.textTertiary,
                            ),
                            onPressed: () =>
                                AdService.to.showAdPromoDialog(context, ad),
                          ),
                        ],
                      ),
                    ),
                    buildAdActionBar(context, ad),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ScrollAdCard extends StatelessWidget {
  const ScrollAdCard({required this.ad, super.key});
  final AdItem ad;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService.to.recordImpression(ad.id);
    });
    return GetBuilder<AdCardController>(
      init: AdCardController(),
      global: false,
      builder: (controller) {
        return MouseRegion(
          onEnter: (_) => controller.setHovered(true),
          onExit: (_) => controller.setHovered(false),
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: AppTheme.animations.normal,
            curve: AppTheme.animations.easeOutCubic,
            margin: EdgeInsets.only(bottom: AppTheme.spacing.md),
            decoration: BoxDecoration(
              color: controller.isHovered
                  ? AppTheme.colors.surfaceVariant
                  : AppTheme.colors.surface,
              borderRadius: AppTheme.radius.circularLg,
              border: Border.all(
                color: controller.isHovered
                    ? AppTheme.colors.primary.withValues(alpha: 0.3)
                    : AppTheme.colors.border.withValues(alpha: 0.3),
                width: AppTheme.components.dividerThickness,
              ),
              boxShadow: controller.isHovered
                  ? [
                      BoxShadow(
                        color: AppColors.bgPage.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : AppTheme.shadows.elevationSm,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: AppTheme.radius.circularLg,
              child: InkWell(
                onTap: () => AdService.to.showAdPromoDialog(context, ad),
                borderRadius: AppTheme.radius.circularLg,
                splashColor: AppTheme.colors.primary.withValues(alpha: 0.2),
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail (Matches VideoCard list layout size exactly)
                      SizedBox(
                        width: AppTheme.sizes.thumbnailMediumWidth,
                        height: AppTheme.sizes.thumbnailMediumHeight,
                        child: ClipRRect(
                          borderRadius: AppTheme.radius.circularLg,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AdMediaWidget(ad: ad),
                              Positioned(
                                top: AppTheme.spacing.xs,
                                left: AppTheme.spacing.xs,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text(
                                    'Ad',
                                    style: TextStyle(
                                      color: AppColors.bgPage,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: AppTheme.spacing.sm),

                      // Details (Matches VideoCard list layout details exactly)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ad.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.typography.body.copyWith(
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ad.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.typography.bodyMedium.copyWith(
                                color: AppTheme.colors.textSecondary,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: AppTheme.typography.caption.copyWith(
                                  fontSize: 11,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Sponsored',
                                    style: TextStyle(
                                      color: AppTheme.colors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' • ${ad.advertiser}',
                                    style: TextStyle(
                                      color: AppTheme.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            buildAdActionBar(context, ad),
                          ],
                        ),
                      ),

                      // Options button (Matches VideoCard)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: AppTheme.colors.textTertiary,
                        ),
                        onPressed: () =>
                            AdService.to.showAdPromoDialog(context, ad),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget buildAdActionBar(BuildContext context, AdItem ad) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Row(
      children: [
        // Thumbs Up (Like)
        Obx(() {
          final isLiked = AdService.to.likedAdIds.contains(ad.id);
          return StreamBuilder<int>(
            stream: AdService.to.getAdLikesCountStream(ad.id),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return TextButton.icon(
                onPressed: () => AdService.to.toggleLikeAd(ad.id),
                icon: Icon(
                  isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  size: 14,
                  color: isLiked ? AppColors.warning : AppColors.textSecondary,
                ),
                label: Text(
                  '$count',
                  style: TextStyle(
                    color: isLiked
                        ? AppColors.warning
                        : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            },
          );
        }),
        const SizedBox(width: 12),
        // Comments
        StreamBuilder<int>(
          stream: AdService.to.getAdCommentsCountStream(ad.id),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return TextButton.icon(
              onPressed: () =>
                  AdService.to.showAdCommentsBottomSheet(context, ad),
              icon: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              label: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );
          },
        ),
        const Spacer(),
        // Save / Bookmark
        Obx(() {
          final isSaved = AdService.to.savedAdIds.contains(ad.id);
          return IconButton(
            onPressed: () => AdService.to.toggleSaveAd(ad.id),
            icon: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              size: 16,
              color: isSaved ? AppColors.warning : AppColors.textSecondary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          );
        }),
      ],
    ),
  );
}
