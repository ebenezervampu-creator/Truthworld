import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';

/// High-fidelity preview card displaying a topic according to TruthWorld social preview architecture:
/// - Exact Topic Banner / Thumbnail at top (widescreen, rounded top corners)
/// - Topic Name with Gold Verified Checkmark Badge
/// - Topic Handle (@ handle)
/// - Follower count & Video count with separator
/// - Multi-line Topic Description (up to 3 lines)
/// - Bottom Link Pill with Link Icon, Canonical URL, and "Truthworld >"
/// - Follow option removed as requested
/// - Interactive tap to navigate directly to Truthworld topic
class ShareTopicCard extends StatelessWidget {
  const ShareTopicCard({
    String? name,
    String? title,
    super.key,
    this.url,
    this.thumbnailUrl,
    this.bannerUrl,
    this.subtitle,
    this.videoCount,
    this.followerCount,
    this.handle,
    this.isVerified = true,
    this.onTap,
  }) : name = (name != null && name != '') ? name : (title ?? '');

  final String name;
  String get title => name;
  final String? url;
  final String? thumbnailUrl;
  final String? bannerUrl;
  final String? subtitle;
  final int? videoCount;
  final int? followerCount;
  final String? handle;
  final bool isVerified;
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
    final effectiveImage = (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
        ? thumbnailUrl
        : bannerUrl;

    final cleanName = name.replaceAll(RegExp('^[#Tt]/'), '').trim();

    final cleanHandle = handle != null && handle!.isNotEmpty
        ? handle!.replaceAll(RegExp('^[#@Tt]/'), '').trim()
        : cleanName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

    final effectiveUrl = (url != null && url!.isNotEmpty)
        ? url!
        : 'https://truthworld.in/T/$cleanHandle';

    final folText = followerCount != null && followerCount! > 0
        ? '${FormatUtils.formatCount(followerCount!)} Followers'
        : '0 Followers';

    final vidText = videoCount != null && videoCount! > 0
        ? '${FormatUtils.formatCount(videoCount!)} Videos'
        : '0 Videos';

    final cleanDescription = (subtitle != null && subtitle!.trim().isNotEmpty)
        ? subtitle!.trim()
        : 'Truthworld Topics brings you the best verified channels across education, technology, science, health, spirituality, entertainment and more.';

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
              // 1. Topic Banner / Thumbnail Section (Exact Topic Thumbnail)
              LayoutBuilder(
                builder: (context, constraints) {
                  final bannerHeight =
                      constraints.maxWidth.isFinite && constraints.maxWidth > 0
                          ? (constraints.maxWidth * (7 / 16)).clamp(115.0, 180.0)
                          : 135.0;

                  return Container(
                    height: bannerHeight,
                    width: double.infinity,
                    color: const Color(0xFF0F051D),
                    child: effectiveImage != null && effectiveImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: effectiveImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const ColoredBox(
                              color: Color(0xFF0F051D),
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
                                _buildBannerFallback(cleanName),
                          )
                        : _buildBannerFallback(cleanName),
                  );
                },
              ),

              // 2. Topic Details & Metadata
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Topic Name (Follow option removed, Verified badge removed)
                    Text(
                      cleanName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 3),

                    // Handle: @ <handle>
                    Text(
                      '@ $cleanHandle',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Metrics: Followers | Videos
                    Row(
                      children: [
                        const Icon(
                          Icons.people_alt_rounded,
                          size: 16,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          folText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '|',
                            style: TextStyle(
                              color: Color(0xFF3F3F46),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.bar_chart_rounded,
                          size: 17,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          vidText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Description: up to 3 lines
                    Text(
                      cleanDescription,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 14),

                    // Bottom Link Pill: 🔗 URL ... Truthworld >
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1012),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              effectiveUrl,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Truthworld',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF8E8E93),
                            size: 16,
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

  Widget _buildBannerFallback(String title) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF090514),
            Color(0xFF180B30),
            Color(0xFF2A0F55),
            Color(0xFF0C0418),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Truthworld',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Topics',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'EXPLORE. LEARN. VERIFY. GROW.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}
