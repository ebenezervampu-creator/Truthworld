import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Preview card displaying a video item with thumbnail, title, channel, duration, and metadata.
class ShareVideoCard extends StatelessWidget {
  const ShareVideoCard({
    required this.title,
    super.key,
    this.thumbnailUrl,
    this.subtitle,
    this.durationMs,
    this.channelName,
  });

  final String title;
  final String? thumbnailUrl;
  final String? subtitle;
  final int? durationMs;
  final String? channelName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.bgSurfaceHover,
            AppColors.bgSurfaceHover.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Video Thumbnail + Duration Overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 124,
                  height: 124 * 9 / 16,
                  color: AppColors.bgInput,
                  child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: AppColors.bgInput),
                          errorWidget: (context, url, err) => const Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                ),
              ),
              if (durationMs != null)
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.bgDivider,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      FormatUtils.formatDuration(
                        Duration(milliseconds: durationMs!),
                      ),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Video Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'VIDEO',
                        style: TextStyle(
                          color: AppColors.brand,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        channelName ?? 'TruthWorld Creator',
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
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
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
    );
  }
}
