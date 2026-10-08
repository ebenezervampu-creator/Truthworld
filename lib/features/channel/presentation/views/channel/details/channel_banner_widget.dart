import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_theme.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Cover banner widget for channel profile with moderation status overlays.
class ChannelBannerWidget extends StatelessWidget {
  final Channel channel;
  final ChannelController controller;
  final bool isDesktop;
  final bool isTablet;
  final bool isDashboard;

  const ChannelBannerWidget({
    required this.channel,
    required this.controller,
    this.isDesktop = false,
    this.isTablet = false,
    this.isDashboard = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bannerHeight = isDesktop ? 220.0 : (isTablet ? 170.0 : 130.0);
    final rawBannerUrl = channel.bannerImageUrl.isNotEmpty
        ? channel.bannerImageUrl
        : channel.bannerUrl;
    final cleanBannerUrl = rawBannerUrl.trim().replaceAll(' ', '%20');

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24.0 : (isTablet ? 16.0 : 0.0),
        vertical: isDesktop || isTablet ? 16.0 : 0.0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isDesktop || isTablet ? 16.0 : 0.0),
        child: SizedBox(
          height: bannerHeight,
          width: double.infinity,
          child: Builder(
            builder: (context) => Stack(
              children: [
                if (cleanBannerUrl.isNotEmpty) ...[
                  // Ambient background backdrop with blur for dynamic banner aspect ratios
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: cleanBannerUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) {
                        if (kIsWeb) {
                          return Image.network(
                            cleanBannerUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, err, stack) =>
                                const ColoredBox(color: ytSurface),
                          );
                        }
                        return const ColoredBox(color: ytSurface);
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(color: Colors.black.withValues(alpha: 0.4)),
                    ),
                  ),
                  // Primary full-bleed banner cover
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: cleanBannerUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const ColoredBox(
                        color: ytSurface,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: ytTextSecondary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        if (kIsWeb) {
                          return Image.network(
                            cleanBannerUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, err, stack) =>
                                const ColoredBox(
                              color: ytSurface,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: ytTextTertiary,
                                ),
                              ),
                            ),
                          );
                        }
                        return const ColoredBox(
                          color: ytSurface,
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: ytTextTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else
                  const Positioned.fill(
                    child: ColoredBox(
                      color: ytSurface,
                      child: Center(
                        child: Icon(
                          Icons.image_rounded,
                          color: ytTextTertiary,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                if (isDashboard || Navigator.of(context).canPop())
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgPage.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
                        ),
                        tooltip: 'Back',
                        onPressed: () {
                          if (isDashboard &&
                              Get.isRegistered<HomeController>()) {
                            Get.find<HomeController>().goBackFromSpecialPage(
                              HomeController.indexDiscover,
                            );
                          } else {
                            Get.back();
                          }
                        },
                      ),
                    ),
                  ),
                Builder(
                  builder: (context) {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser == null ||
                        channel.ownerId != currentUser.uid) {
                      return const SizedBox.shrink();
                    }

                    return Obx(() {
                      final status = controller.detailsBannerStatus.value;
                      if (status.isEmpty || status == 'APPROVED') {
                        return const SizedBox.shrink();
                      }

                      var overlayColor = AppColors.bgPage54;
                      var badgeColor = const Color(0xFF3B82F6);
                      var text = 'Banner Verification Pending';
                      var icon = Icons.sync_rounded;
                      final isPending = status == 'PENDING';

                      if (status == 'REJECTED') {
                        overlayColor = AppColors.bgPage.withValues(alpha: 0.8);
                        badgeColor = const Color(0xFFEF4444);
                        text =
                            "Banner Rejected: ${controller.detailsBannerReason.value.isNotEmpty ? controller.detailsBannerReason.value : 'Violated Community Guidelines'}";
                        icon = Icons.error_outline_rounded;
                      } else if (status == 'FLAGGED') {
                        overlayColor = AppColors.bgPage.withValues(alpha: 0.7);
                        badgeColor = const Color(0xFFF59E0B);
                        text =
                            'Banner Review Needed: ${controller.detailsBannerReason.value}';
                        icon = Icons.warning_amber_rounded;
                      }

                      return Positioned.fill(
                        child: Container(
                          color: overlayColor,
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: badgeColor.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isPending)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.textPrimary,
                                            ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      icon,
                                      color: AppColors.textPrimary,
                                      size: 18,
                                    ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      text,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

  }
}
