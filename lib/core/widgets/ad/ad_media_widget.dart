import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/widgets/ad/ad_media_controller.dart';
import 'package:truthworld/core/widgets/mobile_friendly_video_player.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Pure declarative stateless widget rendering ad media (video player or image cover)
/// backed by reactive AdMediaController.
class AdMediaWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tag = 'ad_media_${ad.id}';
    final mediaCtrl = Get.isRegistered<AdMediaController>(tag: tag)
        ? Get.find<AdMediaController>(tag: tag)
        : Get.put(AdMediaController(), tag: tag);

    mediaCtrl.onAdHoverChanged(ad: ad, isHovered: isHovered);

    return Obx(() {
      final isInitialized = mediaCtrl.isInitialized.value;
      final controller = mediaCtrl.videoController.value;
      final hasVideo = ad.effectiveVideoUrl != null;

      Widget mediaChild;

      if (isInitialized && controller != null) {
        mediaChild = Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: fit,
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
                onTap: mediaCtrl.toggleMute,
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
                    mediaCtrl.isMuted.value
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
      } else if (ad.imageUrl.isNotEmpty) {
        mediaChild = CachedNetworkImage(
          imageUrl: ad.imageUrl,
          fit: fit,
          placeholder: (context, url) => const ColoredBox(
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
          ),
          errorWidget: (context, url, error) => _buildFallbackGradient(),
        );
      } else {
        mediaChild = _buildFallbackGradient();
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          mediaChild,
          if (hasVideo && mediaCtrl.isLoading.value && !isInitialized)
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
          colors: ad.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          ad.fallbackIcon ?? Icons.ads_click_rounded,
          size: 48,
          color: AppColors.textPrimary.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}
