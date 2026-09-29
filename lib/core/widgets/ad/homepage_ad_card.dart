import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/widgets/ad/ad_card_controller.dart';
import 'package:truthworld/core/widgets/ad/ad_media_widget.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:visibility_detector/visibility_detector.dart';


/// Large native feed ad card matching the visual scale
/// and layout of feed video cards.
class HomepageAdCard extends StatelessWidget {
  const HomepageAdCard({
    required this.ad,
    this.contextChannelId = '',
    super.key,
  });
  final AdItem ad;

  /// The channel whose feed this ad was shown in. Used for 70% revenue attribution.
  final String contextChannelId;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<AdService>()) {
        try {
          AdService.to.recordImpression(
            ad.id,
            channelId: contextChannelId,
          );
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'HomepageAdCard.impression',
          );
        }
      }
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
                onTap: () => AdService.to.handleAdTap(ad),
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
                            if (ad.imageUrl.isEmpty && !ad.hasVideo)
                              _buildTextFallbackBanner()
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
                                child: AdOptionsMenuButton(ad: ad, iconSize: 18),
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
                          // Options Vert Button
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

  Widget _buildTextFallbackBanner() {
    final isLightBg = ad.gradientColors.first.computeLuminance() > 0.5;
    final textColor = isLightBg
        ? AppColors.bgPage.withValues(alpha: 0.6)
        : AppColors.textSecondary;
    final titleColor = isLightBg ? AppColors.bgPage : AppColors.textPrimary;
    final iconColor = isLightBg
        ? AppColors.bgPage.withValues(alpha: 0.1)
        : AppColors.textPrimary.withValues(alpha: 0.12);

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Icon(
            ad.fallbackIcon ?? Icons.ads_click_rounded,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    ad.fallbackIcon ?? Icons.ads_click_rounded,
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
  }
}
