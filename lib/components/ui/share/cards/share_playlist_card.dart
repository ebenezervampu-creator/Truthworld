import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Preview card displaying a playlist with stacked styling, item count badge, and playlist details.
class SharePlaylistCard extends StatelessWidget {
  const SharePlaylistCard({
    required this.title,
    super.key,
    this.thumbnailUrl,
    this.subtitle,
    this.videoCount,
    this.channelName,
  });

  final String title;
  final String? thumbnailUrl;
  final String? subtitle;
  final int? videoCount;
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
          // Playlist Thumbnail + Overlay Badge
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
                          errorWidget: (context, url, err) => const Icon(
                            Icons.playlist_play_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        )
                      : const Icon(
                          Icons.playlist_play_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                ),
              ),
              // Truthworld-style playlist right side overlay bar
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: 38,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgPage.withValues(alpha: 0.75),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(10),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${videoCount ?? 0}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Icon(
                        Icons.playlist_play_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Playlist Info
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
                        'PLAYLIST',
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
                        channelName ?? 'TruthWorld Playlist',
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
                const SizedBox(height: 4),
                Text(
                  subtitle ?? 'Playlist • ${videoCount ?? 0} videos',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
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
