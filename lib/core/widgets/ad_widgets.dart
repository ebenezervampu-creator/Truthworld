import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/mobile_friendly_video_player.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class AdMediaWidget extends StatefulWidget {
  const AdMediaWidget({
    required this.ad,
    super.key,
    this.fit = BoxFit.cover,
    this.isHovered = false,
  });
  final AdItem ad;
  final BoxFit fit;
  final bool isHovered;

  @override
  State<AdMediaWidget> createState() => _AdMediaWidgetState();
}

class _AdMediaWidgetState extends State<AdMediaWidget> {
  final Rxn<VideoPlayerController> _controller = Rxn<VideoPlayerController>();
  Timer? _hoverTimer;
  final RxBool _isMuted = true.obs;
  final RxBool _isInitialized = false.obs;
  final RxBool _isLoading = false.obs;

  String? get _effectiveVideoUrl {
    final v = widget.ad.videoUrl;
    if (v != null && v.trim().isNotEmpty && !v.trim().startsWith('blob:')) {
      return v.trim();
    }
    final mid = widget.ad.midrollVideoUrl;
    if (mid != null && mid.trim().isNotEmpty && !mid.trim().startsWith('blob:')) {
      return mid.trim();
    }
    if (widget.ad.resolutions != null && widget.ad.resolutions!.isNotEmpty) {
      for (final res in widget.ad.resolutions!) {
        final u = res['url'] as String?;
        if (u != null && u.trim().isNotEmpty && !u.trim().startsWith('blob:')) {
          return u.trim();
        }
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.isHovered) {
      _startHoverTimer();
    }
  }

  @override
  void didUpdateWidget(AdMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad.videoUrl != widget.ad.videoUrl ||
        oldWidget.ad.midrollVideoUrl != widget.ad.midrollVideoUrl ||
        oldWidget.ad.id != widget.ad.id) {
      _cancelAndDispose();
      if (widget.isHovered) {
        _startHoverTimer();
      }
    } else if (oldWidget.isHovered != widget.isHovered) {
      if (widget.isHovered) {
        _startHoverTimer();
      } else {
        _cancelAndDispose();
      }
    }
  }

  void _startHoverTimer() {
    final url = _effectiveVideoUrl;
    if (url == null || url.isEmpty) {
      return;
    }
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && widget.isHovered) {
        _initializeVideo();
      }
    });
  }

  void _cancelAndDispose() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    final ctrl = _controller.value;
    _controller.value = null;
    _isInitialized.value = false;
    _isLoading.value = false;
    if (ctrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (ctrl.value.isInitialized) {
            ctrl.pause();
          }
          ctrl.dispose();
        } catch (e) {
          debugPrint('[AdMediaWidget] Error disposing video: $e');
        }
      });
    }
  }

  Future<void> _initializeVideo() async {
    final rawUrl = _effectiveVideoUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      _isInitialized.value = false;
      _isLoading.value = false;
      return;
    }

    if (_controller.value != null || _isLoading.value) return;
    _isLoading.value = true;

    var playUrl = rawUrl;
    // Resolve Firebase Storage URLs if needed
    if (playUrl.startsWith('gs://') ||
        playUrl.startsWith('https://storage.googleapis.com/') ||
        (playUrl.contains('firebasestorage.googleapis.com') &&
            !playUrl.contains('token='))) {
      try {
        playUrl = await FirebaseStorage.instance
            .refFromURL(playUrl)
            .getDownloadURL();
      } catch (e) {
        debugPrint('[AdMediaWidget] Error resolving storage URL ($playUrl): $e');
        final fallback = StorageUtils.getFastDownloadUrl(playUrl);
        if (fallback.isNotEmpty && fallback != playUrl) {
          playUrl = fallback;
        }
      }
    }

    if (!mounted || !widget.isHovered) {
      _isLoading.value = false;
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(playUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
        ),
      );
      _controller.value = controller;

      await controller.initialize();

      if (mounted && widget.isHovered && _controller.value == controller) {
        await controller.setVolume(_isMuted.value ? 0.0 : 1.0);
        await controller.setLooping(true);
        await controller.play();
        _isInitialized.value = true;
        _isLoading.value = false;
      } else {
        await controller.dispose();
        if (_controller.value == controller) {
          _controller.value = null;
        }
        _isLoading.value = false;
        _isInitialized.value = false;
      }
    } catch (e) {
      debugPrint('[AdMediaWidget] Error initializing video: $e');
      _isLoading.value = false;
      _isInitialized.value = false;
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _controller.value?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isInitialized = _isInitialized.value;
      final controller = _controller.value;
      final hasVideo = _effectiveVideoUrl != null;

      Widget mediaChild;

      if (isInitialized && controller != null) {
        mediaChild = Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: controller.value.size.width > 0
                    ? controller.value.size.width
                    : 160,
                height: controller.value.size.height > 0
                    ? controller.value.size.height
                    : 90,
                child: MobileFriendlyVideoPlayer(
                  controller: controller,
                  looping: true,
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final nextMuted = !_isMuted.value;
                  _isMuted.value = nextMuted;
                  if (!nextMuted) {
                    HoverPreviewCoordinator.pauseAllMainPlayers();
                    _controller.value?.setVolume(1.0);
                  } else {
                    _controller.value?.setVolume(0.0);
                  }
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
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      } else if (widget.ad.imageUrl.isNotEmpty) {
        mediaChild = Image.network(
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
      } else {
        mediaChild = _buildFallbackGradient();
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          mediaChild,
          if (hasVideo && _isLoading.value && !isInitialized)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.bgPage.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      );
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
        final cardContent = MouseRegion(
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
                onTap: () => AdService.to.launchCtaUrl(ad),
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
                            AdMediaWidget(
                              ad: ad,
                              isHovered: controller.isHovered,
                            ),
                            if (ad.imageUrl.isEmpty &&
                                (ad.videoUrl == null || ad.videoUrl!.isEmpty))
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
                                final iconColor = isLightBg
                                    ? AppColors.bgPage.withValues(alpha: 0.1)
                                    : AppColors.textPrimary.withValues(
                                        alpha: 0.12,
                                      );

                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Center(
                                      child: Icon(
                                        ad.fallbackIcon ??
                                            Icons.ads_click_rounded,
                                        size: 72,
                                        color: iconColor,
                                      ),
                                    ),
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
                                                color: Colors.white,
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
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }()
                            else
                              const SizedBox.shrink(),

                            // Floating CTA Button Badge on Bottom Right of Media
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: GestureDetector(
                                onTap: () => AdService.to.launchCtaUrl(ad),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgPage.withValues(
                                      alpha: 0.85,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        ad.ctaText.toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.north_east_rounded,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Top-Right More Vertical (3-dot) Options Menu
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  color: const Color(0xFF1E1E1E),
                                  onSelected: (value) {
                                    if (value == 'report') {
                                      AdService.to.showReportAdDialog(
                                        context,
                                        ad,
                                      );
                                    } else if (value == 'copy') {
                                      Clipboard.setData(
                                        ClipboardData(text: ad.ctaTarget),
                                      );
                                      AppSnackbar.show(
                                        'Link Copied',
                                        'Ad destination link copied.',
                                      );
                                    } else if (value == 'save') {
                                      AdService.to.toggleSaveAd(ad.id);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem<String>(
                                      value: 'report',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.report_problem_outlined,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            "Report Ad / Don't Show",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'copy',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.link_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Copy Ad Link',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'save',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.bookmark_outline_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            AdService.to.savedAdIds.contains(
                                                  ad.id,
                                                )
                                                ? 'Remove Bookmark'
                                                : 'Save Ad',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                          // Text Block - Full Width (No Avatar as per Truthworld Spec)
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
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            onPressed: () =>
                                AdService.to.showAdPromoDialog(context, ad),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      behavior: HitTestBehavior.opaque,
                      child: buildAdActionBar(context, ad),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final isMobile = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS);

        if (!isMobile) {
          return cardContent;
        }

        return VisibilityDetector(
          key: Key('homepage_ad_${ad.id}'),
          onVisibilityChanged: (info) {
            if (info.visibleFraction >= 0.8) {
              if (!controller.isHovered) {
                controller.setHovered(true);
              }
            } else {
              if (controller.isHovered) {
                controller.setHovered(false);
              }
            }
          },
          child: cardContent,
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
        final cardContent = MouseRegion(
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
                onTap: () => AdService.to.launchCtaUrl(ad),
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
                              AdMediaWidget(
                                ad: ad,
                                isHovered: controller.isHovered,
                              ),
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
                            GestureDetector(
                              onTap: () {},
                              behavior: HitTestBehavior.opaque,
                              child: buildAdActionBar(context, ad),
                            ),
                          ],
                        ),
                      ),

                      // Options button with PopupMenu (Report Ad, Copy Link, Save Ad)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        color: const Color(0xFF1E1E1E),
                        onSelected: (value) {
                          if (value == 'report') {
                            AdService.to.showReportAdDialog(context, ad);
                          } else if (value == 'copy') {
                            Clipboard.setData(
                              ClipboardData(text: ad.ctaTarget),
                            );
                            AppSnackbar.show(
                              'Link Copied',
                              'Ad destination link copied.',
                            );
                          } else if (value == 'save') {
                            AdService.to.toggleSaveAd(ad.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.report_problem_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  "Report Ad / Don't Show",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'copy',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Copy Ad Link',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'save',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bookmark_outline_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  AdService.to.savedAdIds.contains(ad.id)
                                      ? 'Remove Bookmark'
                                      : 'Save Ad',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
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
            ),
          ),
        );

        final isMobile = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS);

        if (!isMobile) {
          return cardContent;
        }

        return VisibilityDetector(
          key: Key('scroll_ad_${ad.id}'),
          onVisibilityChanged: (info) {
            if (info.visibleFraction >= 0.8) {
              if (!controller.isHovered) {
                controller.setHovered(true);
              }
            } else {
              if (controller.isHovered) {
                controller.setHovered(false);
              }
            }
          },
          child: cardContent,
        );
      },
    );
  }
}

Widget buildAdActionBar(BuildContext context, AdItem ad) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
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
                  color: Colors.white,
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
        const SizedBox(width: 8),
        // Save / Bookmark
        Obx(() {
          final isSaved = AdService.to.savedAdIds.contains(ad.id);
          return IconButton(
            onPressed: () => AdService.to.toggleSaveAd(ad.id),
            icon: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              size: 16,
              color: Colors.white,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          );
        }),
      ],
    ),
  );
}

Widget _buildAdvertiserLogoAvatar(AdItem ad, {double radius = 16}) {
  final logoUrl = ad.imageUrl.trim();
  final isValidUrl = logoUrl.isNotEmpty && (logoUrl.startsWith('http://') || logoUrl.startsWith('https://'));

  if (isValidUrl) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF333333),
      child: ClipOval(
        child: Image.network(
          logoUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                ad.advertiser.isNotEmpty ? ad.advertiser[0].toUpperCase() : 'S',
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.8,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFF333333),
    child: Text(
      ad.advertiser.isNotEmpty ? ad.advertiser[0].toUpperCase() : 'S',
      style: GoogleFonts.roboto(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.8,
      ),
    ),
  );
}

class PinnedSponsorCommentCard extends StatelessWidget {
  const PinnedSponsorCommentCard({
    required this.ad,
    this.videoId,
    this.onOpenDiscussion,
    this.isInModal = false,
    super.key,
  });

  final AdItem ad;
  final String? videoId;
  final VoidCallback? onOpenDiscussion;
  final bool isInModal;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService.to.recordImpression(ad.id);
    });

    final commentText = ad.pinnedCommentText?.isNotEmpty == true
        ? ad.pinnedCommentText!
        : 'Welcome viewers! Feel free to ask us any questions or check out our exclusive offer!';

    final sponsorCommentId = 'sponsor_${ad.id}';
    final targetVideoId = videoId ?? ad.videoId ?? 'default_video';

    return InkWell(
      onTap: isInModal
          ? null
          : (onOpenDiscussion ??
              () => showSponsorDiscussionModal(context: context, ad: ad, videoId: targetVideoId)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isInModal ? 0 : 16,
          vertical: isInModal ? 4 : 8,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pinned Header
            Row(
              children: [
                const Icon(
                  Icons.push_pin_rounded,
                  size: 13,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  'Pinned Sponsor',
                  style: GoogleFonts.roboto(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAdvertiserLogoAvatar(ad),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            ad.advertiser.isNotEmpty ? ad.advertiser : 'Official Sponsor',
                            style: GoogleFonts.roboto(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D9BF0).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SPONSOR',
                              style: GoogleFonts.roboto(
                                color: const Color(0xFF1D9BF0),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        commentText,
                        style: GoogleFonts.roboto(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      if (ad.ctaText.isNotEmpty && ad.ctaTarget.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => AdService.to.launchCtaUrl(ad),
                          child: Text(
                            '${ad.ctaText} →',
                            style: GoogleFonts.roboto(
                              color: const Color(0xFF1D9BF0),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (!isInModal) ...[
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('videos')
                    .doc(targetVideoId)
                    .collection('comments')
                    .doc(sponsorCommentId)
                    .collection('replies')
                    .snapshots(),
                builder: (context, snapshot) {
                  final replyCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        replyCount == 0
                            ? 'Reply to Sponsor'
                            : '$replyCount ${replyCount == 1 ? 'Reply' : 'Replies'}',
                        style: GoogleFonts.roboto(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void showSponsorDiscussionModal({
  required BuildContext context,
  required AdItem ad,
  required String videoId,
}) {
  final replyController = TextEditingController();
  final isSubmitting = false.obs;
  final sponsorCommentId = 'sponsor_${ad.id}';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF161616),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${ad.advertiser.isNotEmpty ? ad.advertiser : "Sponsor"} Discussion',
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      PinnedSponsorCommentCard(
                        ad: ad,
                        videoId: videoId,
                        isInModal: true,
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(
                            Icons.forum_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'User Replies & Discussion',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('videos')
                            .doc(videoId)
                            .collection('comments')
                            .doc(sponsorCommentId)
                            .collection('replies')
                            .orderBy('createdAt', descending: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: AppColors.textDisabled,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No replies yet',
                                    style: GoogleFonts.roboto(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Be the first to reply to ${ad.advertiser.isNotEmpty ? ad.advertiser : "our sponsor"}!',
                                    style: GoogleFonts.roboto(
                                      color: AppColors.textDisabled,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final replies = snapshot.data!.docs
                              .map(Reply.fromDocumentSnapshot)
                              .toList();

                          return Column(
                            children: replies.map((reply) {
                              final formattedTime = timeago.format(reply.createdAt.toDate());
                              final displayName = reply.channelName?.isNotEmpty == true
                                  ? reply.channelName!
                                  : (reply.userName.isNotEmpty ? reply.userName : 'Anonymous User');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 15,
                                      backgroundColor: const Color(0xFF333333),
                                      child: Text(
                                        displayName[0].toUpperCase(),
                                        style: GoogleFonts.roboto(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                displayName,
                                                style: GoogleFonts.roboto(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                formattedTime,
                                                style: GoogleFonts.roboto(
                                                  color: AppColors.textDisabled,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            reply.text,
                                            style: GoogleFonts.roboto(
                                              color: Colors.white,
                                              fontSize: 13,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 10,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF161616),
                    border: Border(
                      top: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: replyController,
                          style: GoogleFonts.roboto(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Reply to ${ad.advertiser.isNotEmpty ? ad.advertiser : "sponsor"}...',
                            hintStyle: GoogleFonts.roboto(color: AppColors.textDisabled, fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFF242424),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Obx(() {
                        return IconButton(
                          onPressed: isSubmitting.value
                              ? null
                              : () async {
                                  final text = replyController.text.trim();
                                  if (text.isEmpty) return;

                                  isSubmitting.value = true;
                                  try {
                                    final authService = Get.isRegistered<AuthService>()
                                        ? AuthService.to
                                        : null;
                                    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
                                    final userName = authService?.activeDisplayName ?? 'User';
                                    final userPic = authService?.activePhotoUrl ?? '';
                                    final channel = authService?.userChannel;

                                    await CommentService().addReply(
                                      videoId: videoId,
                                      commentId: sponsorCommentId,
                                      userId: currentUid,
                                      userName: userName,
                                      userProfilePicUrl: userPic,
                                      text: text,
                                      channelId: channel?.id ?? currentUid,
                                      channelName: channel?.name,
                                      channelProfilePicUrl: channel?.avatarUrl,
                                    );

                                    replyController.clear();
                                  } catch (err) {
                                    AppSnackbar.show(
                                      'Reply Error',
                                      'Could not post reply: $err',
                                      backgroundColor: AppColors.error,
                                      colorText: Colors.white,
                                    );
                                  } finally {
                                    isSubmitting.value = false;
                                  }
                                },
                          icon: isSubmitting.value
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
