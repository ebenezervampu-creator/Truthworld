import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';

/// High-fidelity preview card displaying a video according to TruthWorld social preview architecture:
/// - Exact 16:9 uncropped thumbnail at top without losing any part
/// - Duration overlay badge on thumbnail
/// - Channel name & video badge header
/// - Video Title (bold, white, up to 2 lines)
/// - Two lines of description / metadata (truncated with ellipsis)
/// - Truthworld text at the bottom with link icon & chevron
/// - Interactive tap to navigate directly to Truthworld
class ShareVideoCard extends StatelessWidget {
  const ShareVideoCard({
    required this.title,
    super.key,
    this.url,
    this.thumbnailUrl,
    this.subtitle,
    this.durationMs,
    this.channelName,
    this.onTap,
  });

  final String title;
  final String? url;
  final String? thumbnailUrl;
  final String? subtitle;
  final int? durationMs;
  final String? channelName;
  final VoidCallback? onTap;

  void _handleNavigate() {
    if (onTap != null) {
      onTap!();
      return;
    }
    if (Get.isBottomSheetOpen ?? false) {
      Get.back<void>();
    }
    if (url != null && url!.isNotEmpty) {
      DeepLinkService.instance.handleDeepLink(url!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanDescription = (subtitle != null && subtitle!.trim().isNotEmpty)
        ? subtitle!.trim()
        : 'Watch family-safe, verified video with epistemic clarity on Truthworld.';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleNavigate,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161719),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Top Section: Exact 16:9 Thumbnail without losing any part
              LayoutBuilder(
                builder: (context, constraints) {
                  final bannerHeight =
                      constraints.maxWidth.isFinite && constraints.maxWidth > 0
                          ? (constraints.maxWidth * (9 / 16)).clamp(120.0, 210.0)
                          : 155.0;

                  return Container(
                    height: bannerHeight,
                    width: double.infinity,
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: thumbnailUrl!,
                            fit: BoxFit.contain, // Exact uncropped thumbnail
                            placeholder: (context, url) => const ColoredBox(
                              color: Color(0xFF0A0014),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, err) =>
                                _buildThumbnailFallback(),
                          )
                        else
                          _buildThumbnailFallback(),

                        // Optional Duration Overlay Badge
                        if (durationMs != null && durationMs! > 0)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                FormatUtils.formatDuration(
                                  Duration(milliseconds: durationMs!),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

              // 2. Video Info & Two Lines of Description
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Channel Name & Video Tag Header Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'VIDEO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (channelName != null && channelName!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              channelName!,
                              style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Video Title (bold, white, up to 2 lines)
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Two lines of description / metadata
                    Text(
                      cleanDescription,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 14),

                    // Truthworld Footer with Link Icon & Chevron
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Truthworld',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF19042B),
            Color(0xFF2A0A4A),
            Color(0xFF0A0014),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 6),
          Text(
            'TRUTHWORLD',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.22),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}
