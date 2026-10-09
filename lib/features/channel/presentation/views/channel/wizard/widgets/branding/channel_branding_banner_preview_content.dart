import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/painters/channel_banner_painters.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Renders multi-device banner preview content across All (16:9), Desktop, and Mobile modes.
class ChannelBrandingBannerPreviewContent extends StatelessWidget {
  const ChannelBrandingBannerPreviewContent({
    required this.bannerData,
    required this.bannerUrl,
    required this.mode,
    required this.showGuides,
    required this.controller,
    super.key,
  });

  final ImageData? bannerData;
  final String bannerUrl;
  final int mode;
  final bool showGuides;
  final ChannelController controller;

  @override
  Widget build(BuildContext context) {
    final cleanBannerUrl = bannerUrl.trim().replaceAll(' ', '%20');
    final imageWidget = bannerData != null
        ? Image.memory(bannerData!.bytes, fit: BoxFit.cover)
        : CachedNetworkImage(
            imageUrl: cleanBannerUrl,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) {
              if (kIsWeb && cleanBannerUrl.isNotEmpty) {
                return Image.network(
                  cleanBannerUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, err, stack) => const ColoredBox(
                    color: Color(0xFF212121),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                );
              }
              return const ColoredBox(
                color: Color(0xFF212121),
                child: Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              );
            },
          );

    if (mode == 1) {
      return _buildDesktopMockup(imageWidget);
    } else if (mode == 2) {
      return _buildMobileMockup(imageWidget);
    }

    // Default Mode 0: Full 16:9 View (2560 x 1440)
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          if (showGuides)
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: YouTubeBannerSafeAreaPainter(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopMockup(Widget imageWidget) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E2E32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mini Desktop Browser Window Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF202024),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121214),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'truthworld.in/@${controller.customUrl.text.isNotEmpty ? controller.customUrl.text : "channel"}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Desktop Banner: Full 16:9 Canvas (Zero Cropping)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageWidget,
                if (showGuides)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: YouTubeBannerSafeAreaPainter(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Miniature Channel Header preview bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: ClipOval(
                    child: controller.avatarImageData.value != null
                        ? Image.memory(
                            controller.avatarImageData.value!.bytes,
                            fit: BoxFit.cover,
                          )
                        : (controller.avatarUrl.value.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: controller.avatarUrl.value,
                                fit: BoxFit.cover,
                              )
                            : const Icon(
                                Icons.person,
                                size: 13,
                                color: Colors.white,
                              )),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        controller.channelName.text.isNotEmpty
                            ? controller.channelName.text
                            : 'Channel Name',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${controller.customUrl.text.isNotEmpty ? controller.customUrl.text : "handle"} • Desktop Display',
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMockup(Widget imageWidget) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2E2E32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phone Status Bar Mockup
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF202024),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '9:41',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  width: 32,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi, size: 9, color: Colors.white70),
                    SizedBox(width: 4),
                    Icon(Icons.battery_full, size: 9, color: Colors.white70),
                  ],
                ),
              ],
            ),
          ),
          // Mobile Banner: Full 16:9 Canvas (Zero Cropping)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageWidget,
                if (showGuides)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: YouTubeBannerSafeAreaPainter(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Miniature Channel Header preview bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: ClipOval(
                    child: controller.avatarImageData.value != null
                        ? Image.memory(
                            controller.avatarImageData.value!.bytes,
                            fit: BoxFit.cover,
                          )
                        : (controller.avatarUrl.value.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: controller.avatarUrl.value,
                                fit: BoxFit.cover,
                              )
                            : const Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.white,
                              )),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        controller.channelName.text.isNotEmpty
                            ? controller.channelName.text
                            : 'Channel Name',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${controller.customUrl.text.isNotEmpty ? controller.customUrl.text : "handle"} • Mobile Display',
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
