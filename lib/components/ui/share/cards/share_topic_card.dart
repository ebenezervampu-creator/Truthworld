import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Preview card displaying a topic/category with hashtag badges, explorer icons, and follower metrics.
class ShareTopicCard extends StatelessWidget {
  const ShareTopicCard({
    required this.title,
    super.key,
    this.thumbnailUrl,
    this.subtitle,
    this.videoCount,
    this.followerCount,
    this.handle,
  });

  final String title;
  final String? thumbnailUrl;
  final String? subtitle;
  final int? videoCount;
  final int? followerCount;
  final String? handle;

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
          color: AppColors.brand.withValues(alpha: 0.35),
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
          // Topic Thumbnail with brand border ring + Hashtag badge overlay
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 124,
                    height: 124 * 9 / 16,
                    color: AppColors.bgInput,
                    child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, err) =>
                                    Container(color: AppColors.bgInput),
                              ),
                              Container(
                                color: Colors.black.withValues(alpha: 0.65),
                              ),
                              CachedNetworkImage(
                                imageUrl: thumbnailUrl!,
                                fit: BoxFit.contain,
                                placeholder: (context, url) =>
                                    Container(color: AppColors.bgInput),
                                errorWidget: (context, url, err) =>
                                    const Center(
                                  child: Icon(
                                    Icons.tag_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: Icon(
                              Icons.tag_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bgPage.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: Colors.black,
                    size: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Topic Info
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
                        color: AppColors.brand.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'TOPIC',
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
                        handle != null && handle!.isNotEmpty
                            ? (handle!.startsWith('#') ||
                                    handle!.startsWith('T/') ||
                                    handle!.startsWith('t/')
                                ? handle!
                                : '#${handle!}')
                            : '#topic',
                        style: const TextStyle(
                          color: AppColors.brand,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ??
                      '${followerCount != null ? '${FormatUtils.formatCount(followerCount!)} followers' : 'Topic'} • ${videoCount != null ? '$videoCount videos' : 'TruthWorld'}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
