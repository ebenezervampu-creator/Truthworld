import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/widgets/ad/ad_card_controller.dart';
import 'package:truthworld/core/widgets/ad/ad_media_widget.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Compact horizontal layout native ad card designed for vertical scroll feeds,
/// search results, and sidebar video recommendations.
class ScrollAdCard extends StatelessWidget {
  const ScrollAdCard({required this.ad, super.key});
  final AdItem ad;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<AdService>()) {
        try {
          AdService.to.recordImpression(ad.id);
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'ScrollAdCard.impression',
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
                onTap: () => AdService.to.handleAdTap(ad),
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
                      AdOptionsMenuButton(ad: ad),
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
