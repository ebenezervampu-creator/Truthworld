import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class DashboardLatestContentSection extends StatelessWidget {
  final bool isDarkMode;
  final bool isMobile;
  final List<Video> videos;
  final String searchQuery;
  final VoidCallback onViewAll;
  final ValueChanged<Video>? onVideoTap;

  const DashboardLatestContentSection({
    required this.isDarkMode,
    required this.isMobile,
    required this.videos,
    required this.searchQuery,
    required this.onViewAll,
    this.onVideoTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Latest Content',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onViewAll,
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.textPrimary,
                size: 16,
              ),
              label: const Text(
                'View all',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            if (videos.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        searchQuery.isEmpty
                            ? 'No content yet'
                            : 'No matching content found',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: videos.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final video = videos[index];
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(20 * (1 - value), 0),
                      child: Opacity(
                        opacity: value,
                        child: DashboardContentCard(
                          video: video,
                          isDarkMode: isDarkMode,
                          isMobile: isMobile,
                          onTap: onVideoTap != null
                              ? () => onVideoTap!(video)
                              : null,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class DashboardContentCard extends StatelessWidget {
  final Video video;
  final bool isDarkMode;
  final bool isMobile;
  final VoidCallback? onTap;

  const DashboardContentCard({
    required this.video,
    required this.isDarkMode,
    required this.isMobile,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgDivider,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: isMobile ? 120 : 160,
                  height: isMobile ? 68 : 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.bgSurfaceHover,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const ColoredBox(
                            color: AppColors.bgSurfaceHover,
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: AppColors.textSecondary,
                              size: 32,
                            ),
                          ),
                          errorWidget: (context, url, error) => const ColoredBox(
                            color: AppColors.bgSurfaceHover,
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: AppColors.textSecondary,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.duration,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.visibility_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${video.views} views',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'MMM d, yyyy',
                              ).format(video.uploadedAt.toDate()),
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
