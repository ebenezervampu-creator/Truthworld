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
            Text(
              'Latest Content',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
            ),
            TextButton.icon(
              onPressed: onViewAll,
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 16,
              ),
              label: const Text(
                'View all',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Builder(
          builder: (context) {
            if (videos.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: isDarkMode
                            ? AppColors.textTertiary
                            : const Color(0xFFCBD5E1),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        searchQuery.isEmpty
                            ? 'No content yet'
                            : 'No matching content found',
                        style: TextStyle(
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black,
                          fontSize: 16,
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
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final video = videos[index];
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 400 + (index * 150)),
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(30 * (1 - value), 0),
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
        color: isDarkMode ? AppTheme.colors.surface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.black38,
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: isMobile ? 120 : 160,
                  height: isMobile ? 68 : 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDarkMode
                        ? const Color(0xFF374151)
                        : const Color(0xFFF1F5F9),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => ColoredBox(
                            color: isDarkMode
                                ? const Color(0xFF374151)
                                : const Color(0xFFF1F5F9),
                            child: const Icon(
                              Icons.play_circle_outline_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          errorWidget: (context, url, error) => ColoredBox(
                            color: isDarkMode
                                ? const Color(0xFF374151)
                                : const Color(0xFFF1F5F9),
                            child: const Icon(
                              Icons.play_circle_outline_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.duration,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black,
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
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${video.views} views',
                              style: TextStyle(
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.black,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'MMM d, yyyy',
                              ).format(video.uploadedAt.toDate()),
                              style: TextStyle(
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.black,
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
                  Icons.more_vert_rounded,
                  color: Colors.white,
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
