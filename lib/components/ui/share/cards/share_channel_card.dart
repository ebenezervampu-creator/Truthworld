import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Preview card displaying a channel with banner, avatar, title, verified badge, handle, and subscriber stats.
class ShareChannelCard extends StatelessWidget {
  const ShareChannelCard({
    required this.title,
    super.key,
    this.thumbnailUrl,
    this.bannerUrl,
    this.subtitle,
    this.avatarUrl,
    this.videoCount,
    this.subscriberCount,
    this.handle,
  });

  final String title;
  final String? thumbnailUrl;
  final String? bannerUrl;
  final String? subtitle;
  final String? avatarUrl;
  final int? videoCount;
  final int? subscriberCount;
  final String? handle;

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

    final hasBanner = effectiveBanner != null && effectiveBanner.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasBanner)
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Banner Image (16:9 widescreen header)
                SizedBox(
                  height: 90,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: effectiveBanner,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const ColoredBox(
                      color: AppColors.bgInput,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, err) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.brand.withValues(alpha: 0.6),
                            AppColors.bgSurface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
                // Gradient Shadow Overlay on Banner bottom
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Channel Badge in Top Right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tv_rounded, color: Colors.white, size: 11),
                        SizedBox(width: 4),
                        Text(
                          'CHANNEL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          // Channel Details Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Circular Avatar
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.bgSurface,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 46,
                      height: 46,
                      color: AppColors.bgInput,
                      child: effectiveAvatar != null &&
                              effectiveAvatar.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: effectiveAvatar,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: AppColors.bgInput),
                              errorWidget: (context, url, err) => const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            cleanHandle,
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${subscriberCount != null ? '${FormatUtils.formatCount(subscriberCount!)} subscribers' : 'Channel'} • ${videoCount != null ? '$videoCount videos' : 'TruthWorld'}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!.trim(),
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
