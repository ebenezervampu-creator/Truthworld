import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';

/// High-fidelity preview card displaying a channel according to TruthWorld social preview architecture:
/// - Channel Banner at top (16:9 widescreen)
/// - Circular Avatar with subtle ring
/// - Channel Name (bold, white)
/// - Channel Handle (@handle)
/// - Subscriber count (e.g. 1.2M subscribers)
/// - Two lines of channel description (truncated with ellipsis)
/// - Truthworld text at the end with link icon & chevron
/// - Interactive tap to navigate directly to Truthworld channel
class ShareChannelCard extends StatelessWidget {
  const ShareChannelCard({
    required this.title,
    super.key,
    this.url,
    this.thumbnailUrl,
    this.bannerUrl,
    this.subtitle,
    this.avatarUrl,
    this.videoCount,
    this.subscriberCount,
    this.handle,
    this.onTap,
  });

  final String title;
  final String? url;
  final String? thumbnailUrl;
  final String? bannerUrl;
  final String? subtitle;
  final String? avatarUrl;
  final int? videoCount;
  final int? subscriberCount;
  final String? handle;
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
    final effectiveBanner = bannerUrl != null && bannerUrl!.isNotEmpty
        ? bannerUrl
        : (thumbnailUrl != null &&
                thumbnailUrl != avatarUrl &&
                thumbnailUrl!.isNotEmpty
            ? thumbnailUrl
            : null);
    final effectiveAvatar = avatarUrl != null && avatarUrl!.isNotEmpty
        ? avatarUrl
        : thumbnailUrl;
    final cleanHandle = handle != null && handle!.isNotEmpty
        ? (handle!.startsWith('@') ? handle! : '@${handle!}')
        : '@channel';

    final subText = subscriberCount != null && subscriberCount! > 0
        ? '${FormatUtils.formatCount(subscriberCount!)} subscribers'
        : 'Truthworld Channel';

    final cleanDescription = (subtitle != null && subtitle!.trim().isNotEmpty)
        ? subtitle!.trim()
        : 'Watch family-safe, verified videos on Truthworld. Epistemic clarity and high quality content.';

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
              // 1. Channel Banner (Widescreen Top Section)
              SizedBox(
                height: 125,
                width: double.infinity,
                child: effectiveBanner != null && effectiveBanner.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: effectiveBanner,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const ColoredBox(
                          color: Color(0xFF140521),
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
                        errorWidget: (context, url, err) => _buildBannerFallback(),
                      )
                    : _buildBannerFallback(),
              ),

              // 2. Channel Info & Two Lines of Description
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar + Name/Handle/Subscribers Row
                    Row(
                      children: [
                        // Circular Avatar with Ring
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                            color: const Color(0xFF27272A),
                          ),
                          child: ClipOval(
                            child: effectiveAvatar != null && effectiveAvatar.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: effectiveAvatar,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const ColoredBox(
                                      color: Color(0xFF27272A),
                                    ),
                                    errorWidget: (context, url, err) => _buildAvatarFallback(),
                                  )
                                : _buildAvatarFallback(),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Channel Text Header
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cleanHandle,
                                style: const TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subText,
                                style: const TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Two Lines of Channel Description
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

                    const SizedBox(height: 16),

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

  Widget _buildBannerFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1E1035),
            Color(0xFF2D1254),
            Color(0xFF0F051D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'TRUTHWORLD',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.18),
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 3.0,
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    final initial = title.trim().isNotEmpty ? title.trim().substring(0, 1).toUpperCase() : 'T';
    return Container(
      color: const Color(0xFF2A1B40),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
